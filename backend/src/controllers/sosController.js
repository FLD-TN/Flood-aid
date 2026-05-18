/**
 * SOS Controller — POST /api/sos
 * Module 1: Core Ingestion
 */

const { runParallelAiPipeline } = require('../services/aiPipeline');
const { db } = require('../db');
const crypto = require('crypto');

const SALT = process.env.PHONE_HASH_SALT || 'default_salt';

function hashPhone(phone) {
  return crypto.createHmac('sha256', SALT).update(phone).digest('hex');
}

/**
 * POST /api/sos — Tạo ca SOS mới
 */
async function createSos(req, res) {
  try {
    const { text, lat, lon, phone } = req.body;

    // Validate input
    if (!lat || !lon || !phone) {
      return res.status(400).json({ error: 'Missing required fields: lat, lon, phone' });
    }

    const phoneHash = hashPhone(phone);

    // Anti-spam: 1 SĐT chỉ có 1 ca active (RULE-1)
    const existing = await db.query(
      `SELECT id FROM cases WHERE phone_hash = $1 AND status != 'resolved' LIMIT 1`,
      [phoneHash]
    );
    if (existing.rows.length > 0) {
      return res.status(409).json({
        error: 'ACTIVE_CASE_EXISTS',
        caseId: existing.rows[0].id,
        message: 'Bạn đang có 1 ca đang được xử lý',
      });
    }

    // Chạy AI Pipeline (Parallel Race)
    const sosText = text || 'SOS - Cần cứu hộ khẩn cấp';
    const aiResult = await runParallelAiPipeline(sosText);

    // Lưu vào PostGIS
    const insert = await db.query(
      `INSERT INTO cases (phone_hash, coords, text_raw, urgency_level, tags, summary_1line, status, ai_source)
       VALUES ($1, ST_SetSRID(ST_MakePoint($2, $3), 4326), $4, $5, $6::jsonb, $7, 'pending', $8)
       RETURNING id, urgency_level, tags, summary_1line, status, created_at`,
      [phoneHash, lon, lat, sosText, aiResult.urgency_level, JSON.stringify(aiResult.tags), aiResult.summary_1line, aiResult.source]
    );

    const newCase = insert.rows[0];

    // Trigger geo-dispatch (async, không block response)
    setImmediate(() => {
      require('../services/geoDispatch').dispatchToNearbyVolunteers(newCase.id);
    });

    console.log(`[sosController] New SOS case: ${newCase.id}, urgency: ${aiResult.urgency_level}, source: ${aiResult.source}`);

    res.status(201).json({
      caseId: newCase.id,
      status: 'pending',
      urgencyLevel: aiResult.urgency_level,
      tags: aiResult.tags,
      summary: aiResult.summary_1line,
      aiSource: aiResult.source,
    });

  } catch (err) {
    console.error('[sosController][createSos]', err.message);
    res.status(500).json({ error: 'Internal error' });
  }
}

/**
 * GET /api/case/:id — Lấy thông tin ca SOS
 */
async function getCaseById(req, res) {
  try {
    const { id } = req.params;
    const result = await db.query(
      `SELECT id, urgency_level, tags, summary_1line, status, tnv_distance_m,
              ST_X(coords::geometry) AS lon, ST_Y(coords::geometry) AS lat,
              created_at, resolved_at
       FROM cases WHERE id = $1`,
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Case not found' });
    }

    res.json(result.rows[0]);
  } catch (err) {
    console.error('[sosController][getCaseById]', err.message);
    res.status(500).json({ error: 'Internal error' });
  }
}

/**
 * GET /api/case/:id/tnv-location — Nạn nhân polling vị trí TNV (15s)
 */
async function getTnvLocation(req, res) {
  try {
    const { id } = req.params;
    const result = await db.query(`
      SELECT 
        c.status,
        c.tnv_distance_m AS distance_m,
        ST_X(v.current_coords::geometry) AS lon,
        ST_Y(v.current_coords::geometry) AS lat,
        v.id AS volunteer_id
      FROM cases c
      LEFT JOIN case_assignments ca ON ca.case_id = c.id 
        AND ca.revoked_at IS NULL AND ca.completed_at IS NULL
      LEFT JOIN volunteers v ON v.id = ca.volunteer_id
      WHERE c.id = $1
      ORDER BY ca.assigned_at DESC
      LIMIT 1
    `, [id]);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Case not found' });
    }

    const row = result.rows[0];
    res.json({
      status: row.status,
      distance_m: row.distance_m,
      lat: row.lat,
      lon: row.lon,
      has_volunteer: !!row.volunteer_id,
    });
  } catch (err) {
    console.error('[sosController][getTnvLocation]', err.message);
    res.status(500).json({ error: 'Internal error' });
  }
}

/**
 * POST /api/case/:id/accept — TNV nhận ca
 */
async function acceptCase(req, res) {
  try {
    const { id } = req.params;
    const { volunteerId } = req.body;

    if (!volunteerId) {
      return res.status(400).json({ error: 'Missing volunteerId' });
    }

    // Kiểm tra ca còn active
    const caseRow = await db.query(
      `SELECT id, coords, status FROM cases WHERE id = $1 AND status IN ('pending', 'responding')`,
      [id]
    );
    if (caseRow.rows.length === 0) {
      return res.status(404).json({ error: 'Case not found or already resolved' });
    }

    // Tính khoảng cách ban đầu
    const volRow = await db.query(
      `SELECT current_coords FROM volunteers WHERE id = $1`,
      [volunteerId]
    );

    let initialDistance = null;
    if (volRow.rows[0]?.current_coords) {
      const distResult = await db.query(
        `SELECT ST_Distance($1::geography, $2::geography) AS dist_m`,
        [volRow.rows[0].current_coords, caseRow.rows[0].coords]
      );
      initialDistance = Math.round(distResult.rows[0].dist_m);
    }

    // Tạo assignment
    await db.query(
      `INSERT INTO case_assignments (case_id, volunteer_id, initial_distance_m)
       VALUES ($1, $2, $3)
       ON CONFLICT (case_id, volunteer_id) DO NOTHING`,
      [id, volunteerId, initialDistance]
    );

    // Cập nhật status ca -> responding
    await db.query(
      `UPDATE cases SET status = 'responding' WHERE id = $1 AND status = 'pending'`,
      [id]
    );

    // Mark TNV unavailable
    await db.query(
      `UPDATE volunteers SET is_available = false WHERE id = $1`,
      [volunteerId]
    );

    console.log(`[sosController] TNV ${volunteerId} accepted case ${id}, distance: ${initialDistance}m`);

    res.json({ success: true, initialDistance });
  } catch (err) {
    console.error('[sosController][acceptCase]', err.message);
    res.status(500).json({ error: 'Internal error' });
  }
}

/**
 * POST /api/case/:id/resolve — Đóng ca
 */
async function resolveCase(req, res) {
  try {
    const { id } = req.params;
    const { resolvedBy } = req.body; // 'victim' | 'volunteer' | 'admin'

    await db.query(
      `UPDATE cases SET status = 'resolved', resolved_at = NOW() WHERE id = $1`,
      [id]
    );

    // Complete all assignments
    await db.query(
      `UPDATE case_assignments SET completed_at = NOW() 
       WHERE case_id = $1 AND completed_at IS NULL`,
      [id]
    );

    // Release TNV
    await db.query(`
      UPDATE volunteers SET is_available = true 
      WHERE id IN (
        SELECT volunteer_id FROM case_assignments WHERE case_id = $1
      )
    `, [id]);

    console.log(`[sosController] Case ${id} resolved by ${resolvedBy}`);

    res.json({ success: true, resolvedBy });
  } catch (err) {
    console.error('[sosController][resolveCase]', err.message);
    res.status(500).json({ error: 'Internal error' });
  }
}

module.exports = { createSos, getCaseById, getTnvLocation, acceptCase, resolveCase };
