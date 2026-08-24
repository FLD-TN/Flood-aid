/**
 * SOS Controller — POST /api/sos
 * Module 1: Core Ingestion
 */

const { runUrgencyClassification } = require('../services/aiPipeline');
const { reverseGeocode } = require('../services/vietmap');
const { db } = require('../db');
const crypto = require('crypto');
const { emitCaseEvent } = require('./sseController');
const { broadcastToRoom } = require('../services/wsServer');
const { encryptPhone, decryptPhone } = require('../utils/crypto');

const SALT = process.env.PHONE_HASH_SALT || 'default_salt';

function hashPhone(phone) {
  return crypto.createHmac('sha256', SALT).update(phone).digest('hex');
}

/**
 * POST /api/sos — Tạo ca SOS mới
 */
async function createSos(req, res) {
  try {
    // text         = văn bản ĐÃ được client chuẩn hóa phương ngữ (dùng để phân loại + hiển thị)
    // textOriginal = văn bản GỐC từ nhận dạng giọng nói, trước chuẩn hóa (để đối chiếu,
    //                audit khi bộ chuẩn hóa thay sai, và thu thập dữ liệu cải thiện từ điển)
    const { text, textOriginal, lat, lon, fcmToken, address } = req.body;
    const phone = req.user?.phone_number || req.body.phone;
    const firebaseUid = req.user?.uid;

    // Validate input
    if (!lat || !lon || !phone) {
      return res.status(400).json({ error: 'Missing required fields: lat, lon, phone' });
    }

    const phoneHash = hashPhone(phone);

    // Upsert victims table — lưu phone_encrypted và fcm_token để TNV/server có thể liên lạc
    await db.query(
      `INSERT INTO victims (phone_hash, firebase_uid, phone_encrypted, fcm_token)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (phone_hash) DO UPDATE SET
         firebase_uid = COALESCE(EXCLUDED.firebase_uid, victims.firebase_uid),
         phone_encrypted = EXCLUDED.phone_encrypted,
         fcm_token = COALESCE(EXCLUDED.fcm_token, victims.fcm_token)`,
      [phoneHash, firebaseUid || null, encryptPhone(phone), fcmToken || null]
    );

    // Anti-spam: 1 SĐT chỉ có 1 ca active (RULE-1)
    const existing = await db.query(
      `SELECT id FROM cases WHERE phone_hash = $1 AND status NOT IN ('resolved', 'cancelled') LIMIT 1`,
      [phoneHash]
    );
    if (existing.rows.length > 0) {
      return res.status(409).json({
        error: 'ACTIVE_CASE_EXISTS',
        caseId: existing.rows[0].id,
        message: 'Bạn đang có 1 ca đang được xử lý',
      });
    }

    // Phân loại mức độ khẩn cấp (rule-based + Gemini, lấy mức cao hơn)
    const sosText = text || 'SOS - Cần cứu hộ khẩn cấp';
    const aiResult = await runUrgencyClassification(sosText);

    // Địa chỉ chữ: ưu tiên cái user tự nhập/chọn (VietMap Autocomplete/Place ở app).
    // Nếu không có → để null và reverse-geocode bất đồng bộ sau (không chặn luồng SOS khẩn cấp).
    const addressText = (typeof address === 'string' && address.trim()) ? address.trim() : null;

    // Lưu vào PostGIS
    const insert = await db.query(
      `INSERT INTO cases (phone_hash, coords, text_normalized, text_original, urgency_level, tags, summary_1line, status, ai_source, address_text)
       VALUES ($1, ST_SetSRID(ST_MakePoint($2, $3), 4326), $4, $5, $6, $7::jsonb, $8, 'pending', $9, $10)
       RETURNING id, urgency_level, tags, summary_1line, status, created_at`,
      [phoneHash, lon, lat, sosText, textOriginal || null, aiResult.urgency_level, JSON.stringify(aiResult.tags), aiResult.summary_1line, aiResult.source, addressText]
    );

    const newCase = insert.rows[0];

    // Trigger geo-dispatch (async, không block response)
    setImmediate(() => {
      require('../services/geoDispatch').dispatchToNearbyVolunteers(newCase.id);
    });

    // Reverse-geocode bất đồng bộ khi user không tự nhập địa chỉ (không chặn response).
    if (!addressText) {
      setImmediate(async () => {
        const resolved = await reverseGeocode(lat, lon);
        if (resolved) {
          await db.query('UPDATE cases SET address_text = $1 WHERE id = $2 AND address_text IS NULL', [resolved, newCase.id]);
          console.log(`[sosController] Case ${newCase.id}: reverse-geocoded → ${resolved}`);
        }
      });
    }

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
              tnv_route_distance_m, tnv_eta_sec, address_text,
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
        c.tnv_route_distance_m AS route_distance_m,
        c.tnv_eta_sec AS eta_sec,
        ST_X(v.current_coords::geometry) AS lon,
        ST_Y(v.current_coords::geometry) AS lat,
        v.id AS volunteer_id,
        v.phone_encrypted AS volunteer_phone_encrypted
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
    const volunteerPhone = decryptPhone(row.volunteer_phone_encrypted) || null;
    console.log(`[getTnvLocation] case=${id} volunteer_id=${row.volunteer_id} phone_encrypted=${row.volunteer_phone_encrypted ? 'SET' : 'NULL'} volunteerPhone=${volunteerPhone ? 'DECRYPTED' : 'NULL'}`);
    res.json({
      status: row.status,
      distance_m: row.distance_m,                 // đường chim bay (mét) — fallback
      route_distance_m: row.route_distance_m,     // quãng đường thật theo đường đi (mét)
      eta_sec: row.eta_sec,                        // thời gian tới thật (giây)
      lat: row.lat,
      lon: row.lon,
      has_volunteer: !!row.volunteer_id,
      volunteerPhone,
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
    const { volunteerId, lat, lon } = req.body;

    if (!volunteerId) {
      return res.status(400).json({ error: 'Missing volunteerId' });
    }

    // Kiểm tra TNV có đang bận ca khác không
    const busyCheck = await db.query(
      `SELECT case_id FROM case_assignments 
       WHERE volunteer_id = $1 AND revoked_at IS NULL AND completed_at IS NULL`,
      [volunteerId]
    );
    if (busyCheck.rows.length > 0) {
      const activeCaseId = busyCheck.rows[0].case_id;
      if (activeCaseId !== id) {
        return res.status(403).json({ 
          error: 'Volunteer is currently busy with another case', 
          activeCaseId 
        });
      }
    }

    // Kiểm tra ca còn active + lấy phone_hash để lookup victim
    const caseRow = await db.query(
      `SELECT id, coords, status, phone_hash FROM cases WHERE id = $1`,
      [id]
    );
    if (caseRow.rows.length === 0) {
      return res.status(404).json({ error: 'Case not found' });
    }

    const caseStatus = caseRow.rows[0].status;

    // Ca đã resolved/cancelled → reject
    if (caseStatus === 'resolved' || caseStatus === 'cancelled') {
      return res.status(409).json({ error: 'Case already resolved/cancelled' });
    }

    // Ca đang responding → kiểm tra có phải TNV này đã nhận không (idempotent)
    if (caseStatus === 'responding') {
      const existingAssignment = await db.query(
        `SELECT id FROM case_assignments 
         WHERE case_id = $1 AND volunteer_id = $2 AND revoked_at IS NULL`,
        [id, volunteerId]
      );
      if (existingAssignment.rows.length > 0) {
        // CÙNG TNV đã nhận ca này → return success (idempotent), kèm victimPhone
        console.log(`[sosController] TNV ${volunteerId} re-accepted case ${id} (idempotent)`);
        const idempotentVictimRow = await db.query(
          `SELECT phone_encrypted FROM victims WHERE phone_hash = $1`,
          [caseRow.rows[0].phone_hash]
        );
        const idempotentVictimPhone = decryptPhone(idempotentVictimRow.rows[0]?.phone_encrypted) || null;
        return res.json({ success: true, idempotent: true, victimPhone: idempotentVictimPhone });
      }
      // TNV KHÁC đã nhận ca → reject
      return res.status(409).json({ error: 'Case already accepted by another volunteer' });
    }

    // status === 'pending' → proceed normally

    // Tính khoảng cách ban đầu
    const volRow = await db.query(
      `SELECT current_coords FROM volunteers WHERE id = $1`,
      [volunteerId]
    );

    let initialDistance = null;
    const volCoords = volRow.rows[0]?.current_coords;

    if (volCoords) {
      // TNV đã có tọa độ trong DB → tính từ DB
      const distResult = await db.query(
        `SELECT ST_Distance($1::geography, $2::geography) AS dist_m`,
        [volCoords, caseRow.rows[0].coords]
      );
      initialDistance = Math.round(distResult.rows[0].dist_m);
    } else if (lat && lon) {
      // Fallback: TNV chưa có current_coords → dùng tọa độ gửi kèm từ app
      const distResult = await db.query(
        `SELECT ROUND(ST_Distance(
           $1::geography,
           ST_SetSRID(ST_MakePoint($2, $3), 4326)::geography
         ))::int AS dist_m`,
        [caseRow.rows[0].coords, lon, lat]
      );
      initialDistance = distResult.rows[0].dist_m;

      // Bonus: cập nhật luôn current_coords cho TNV (lần đầu tiên)
      await db.query(
        `UPDATE volunteers 
         SET current_coords = ST_SetSRID(ST_MakePoint($1, $2), 4326), last_seen_at = NOW()
         WHERE id = $3 AND current_coords IS NULL`,
        [lon, lat, volunteerId]
      );
    }

    // Tạo assignment (hoặc reset nếu TNV đã revoke trước đó)
    await db.query(
      `INSERT INTO case_assignments (case_id, volunteer_id, initial_distance_m)
       VALUES ($1, $2, $3)
       ON CONFLICT (case_id, volunteer_id) DO UPDATE SET
         revoked_at = NULL,
         completed_at = NULL,
         assigned_at = NOW(),
         initial_distance_m = EXCLUDED.initial_distance_m
       WHERE case_assignments.revoked_at IS NOT NULL`,
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

    // Lấy SĐT nạn nhân để TNV có thể gọi
    const victimRow = await db.query(
      `SELECT phone_encrypted FROM victims WHERE phone_hash = $1`,
      [caseRow.rows[0].phone_hash]
    );
    const victimPhone = decryptPhone(victimRow.rows[0]?.phone_encrypted) || null;

    // Lấy SĐT TNV để nạn nhân có thể gọi lại
    const volPhoneRow = await db.query(
      `SELECT phone_encrypted FROM volunteers WHERE id = $1`,
      [volunteerId]
    );
    const volunteerPhone = decryptPhone(volPhoneRow.rows[0]?.phone_encrypted) || null;

    // Emit SSE event to all listeners (victim app) — gửi kèm volunteerPhone
    console.log(`[acceptCase] Emitting case:accepted, volunteerPhone=${volunteerPhone ? 'SET' : 'NULL'}`);
    emitCaseEvent(id, 'case:accepted', {
      volunteerId,
      initialDistance,
      status: 'responding',
      volunteerPhone,
    });

    res.json({ success: true, initialDistance, victimPhone });
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

    // Guard: kiểm tra ca chưa resolved/cancelled
    const caseCheck = await db.query(
      `SELECT status FROM cases WHERE id = $1`,
      [id]
    );
    if (caseCheck.rows.length === 0) {
      return res.status(404).json({ error: 'Case not found' });
    }
    const currentStatus = caseCheck.rows[0].status;
    if (currentStatus === 'resolved' || currentStatus === 'cancelled') {
      return res.status(409).json({ error: 'Case already closed' });
    }

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

    // Xóa tin nhắn chat khi ca đóng
    await db.query(`DELETE FROM chat_messages WHERE case_id = $1`, [id]);

    console.log(`[sosController] Case ${id} resolved by ${resolvedBy}`);

    // Emit SSE event to all listeners
    emitCaseEvent(id, 'case:resolved', {
      resolvedBy,
      status: 'resolved',
    });

    // Broadcast qua WebSocket để TNV trong room nhận được ngay
    broadcastToRoom(id, {
      type: 'case:resolved',
      resolvedBy,
      status: 'resolved',
      caseId: id,
    });

    res.json({ success: true, resolvedBy });
  } catch (err) {
    console.error('[sosController][resolveCase]', err.message);
    res.status(500).json({ error: 'Internal error' });
  }
}

/**
 * GET /api/sos/active?phone=xxx — Kiểm tra ca active của 1 SĐT
 */
async function getActiveByPhone(req, res) {
  try {
    const phone = req.user?.phone_number || req.query.phone;
    if (!phone) {
      return res.status(400).json({ error: 'Missing phone' });
    }

    const phoneHash = hashPhone(phone);

    // Làm mới phone_encrypted mỗi lần victim kiểm tra ca active (fix record cũ thiếu key)
    const encryptedPhone = encryptPhone(phone);
    if (encryptedPhone) {
      await db.query(
        `UPDATE victims SET phone_encrypted = $2 WHERE phone_hash = $1`,
        [phoneHash, encryptedPhone]
      );
    }

    const result = await db.query(
      `SELECT id, urgency_level, tags, summary_1line, status, address_text,
              ST_X(coords::geometry) AS lon, ST_Y(coords::geometry) AS lat,
              created_at
       FROM cases
       WHERE phone_hash = $1 AND status NOT IN ('resolved', 'cancelled')
       ORDER BY created_at DESC
       LIMIT 1`,
      [phoneHash]
    );

    if (result.rows.length === 0) {
      return res.json({ hasActive: false });
    }

    const row = result.rows[0];
    res.json({
      hasActive: true,
      caseId: row.id,
      status: row.status,
      lat: row.lat,
      lon: row.lon,
      urgencyLevel: row.urgency_level,
      summary: row.summary_1line,
      address: row.address_text,
    });
  } catch (err) {
    console.error('[sosController][getActiveByPhone]', err.message);
    res.status(500).json({ error: 'Internal error' });
  }
}

/**
 * GET /api/cases/nearby — Danh sách ca SOS gần TNV (có khoảng cách, filter, sort)
 * Query params: lat, lon, maxDistance (km), urgency (csv), tags (csv), sortBy
 */
async function getNearbyCases(req, res) {
  try {
    const { lat, lon, maxDistance, urgency, tags, sortBy } = req.query;

    if (!lat || !lon) {
      return res.status(400).json({ error: 'Missing required: lat, lon' });
    }

    const volLat = parseFloat(lat);
    const volLon = parseFloat(lon);

    // Build dynamic WHERE clauses
    const conditions = [
      `c.status IN ('pending', 'responding', 'on_scene')`
    ];
    const params = [volLon, volLat]; // $1=lon, $2=lat

    // Distance filter
    const parsedDist = parseFloat(maxDistance);
    if (maxDistance !== 'all' && parsedDist > 0) {
      const maxDist = parsedDist || 10; // km, default 10
      params.push(maxDist * 1000);
      conditions.push(`ST_DWithin(c.coords::geography, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography, $${params.length})`);
    }

    // Filter by urgency levels
    if (urgency) {
      const levels = urgency.split(',').map(Number).filter(n => n >= 1 && n <= 5);
      if (levels.length > 0) {
        params.push(levels);
        conditions.push(`c.urgency_level = ANY($${params.length}::int[])`);
      }
    }

    // Filter by tags
    if (tags) {
      const tagList = tags.split(',').map(t => t.trim()).filter(Boolean);
      if (tagList.length > 0) {
        params.push(tagList);
        conditions.push(`c.tags ?| $${params.length}::text[]`);
      }
    }

    // Determine ORDER BY. Mặc định: ca mới nhất lên đầu (ổn định qua các lần poll).
    let orderClause = 'c.created_at DESC';
    switch (sortBy) {
      case 'distance_asc':
        orderClause = 'distance_m ASC';   // TNV chủ động chọn "gần nhất trước"
        break;
      case 'distance_desc':
        orderClause = 'distance_m DESC';
        break;
      case 'newest':
        orderClause = 'c.created_at DESC';
        break;
      case 'oldest':
        orderClause = 'c.created_at ASC';
        break;
    }

    const whereSQL = conditions.join(' AND ');

    const query = `
      SELECT 
        c.id,
        c.urgency_level,
        c.tags,
        c.summary_1line,
        c.status,
        c.text_normalized,
        c.address_text,
        c.phone_hash,
        ST_X(c.coords::geometry) AS lon,
        ST_Y(c.coords::geometry) AS lat,
        c.created_at,
        ROUND(ST_Distance(
          c.coords::geography,
          ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography
        ))::int AS distance_m,
        EXTRACT(EPOCH FROM (NOW() - c.created_at)) / 60 AS time_ago_minutes,
        COALESCE(rc.cnt, 0) AS responder_count
      FROM cases c
      LEFT JOIN (
        SELECT case_id, COUNT(*) AS cnt
        FROM case_assignments
        WHERE revoked_at IS NULL AND completed_at IS NULL
        GROUP BY case_id
      ) rc ON rc.case_id = c.id
      WHERE ${whereSQL}
      ORDER BY ${orderClause}
      LIMIT 50
    `;

    const result = await db.query(query, params);

    // Map tags -> Vietnamese labels + mask phone
    const TAG_MAP = {
      y_te: 'Y tế',
      tre_em: 'Trẻ em',
      nguoi_gia: 'Người già',
      ngap_noc: 'Ngập nóc',
      phuong_tien: 'Cần thuyền',
    };

    const cases = result.rows.map(row => {
      const rawTags = typeof row.tags === 'string' ? JSON.parse(row.tags) : (row.tags || []);
      return {
        id: row.id,
        urgency_level: row.urgency_level,
        tags: rawTags,
        tags_vi: rawTags.map(t => TAG_MAP[t] || t),
        summary_1line: row.summary_1line,
        ai_summary: row.summary_1line,
        description: row.text_normalized,
        address: row.address_text,
        status: row.status,
        lat: row.lat,
        lon: row.lon,
        distance_m: row.distance_m,
        responder_count: parseInt(row.responder_count) || 0,
        created_at: row.created_at,
        time_ago_minutes: Math.round(parseFloat(row.time_ago_minutes) || 0),
      };
    });

    res.json(cases);
  } catch (err) {
    console.error('[sosController][getNearbyCases]', err.message);
    res.status(500).json({ error: 'Internal error' });
  }
}
/**
 * GET /api/case/:id/my-assignment?volunteerId=xxx
 * TNV kiểm tra xem mình đã được assign vào ca này chưa
 */
async function checkMyAssignment(req, res) {
  try {
    const { id } = req.params;
    const { volunteerId } = req.query;
    if (!volunteerId) {
      return res.status(400).json({ error: 'Missing volunteerId' });
    }

    const result = await db.query(
      `SELECT ca.id, ca.assigned_at, ca.warned_at, ca.confirmed_en_route, c.status
       FROM case_assignments ca
       JOIN cases c ON c.id = ca.case_id
       WHERE ca.case_id = $1 AND ca.volunteer_id = $2 AND ca.revoked_at IS NULL
       LIMIT 1`,
      [id, volunteerId]
    );

    if (result.rows.length > 0) {
      return res.json({
        isAssigned: true,
        caseStatus: result.rows[0].status,
        assignedAt: result.rows[0].assigned_at,
        warnedAt: result.rows[0].warned_at,         // null nếu chưa cảnh báo
        confirmedEnRoute: result.rows[0].confirmed_en_route, // false nếu đang chờ xác nhận
      });
    }

    // Check case status anyway
    const caseResult = await db.query(
      `SELECT status FROM cases WHERE id = $1`,
      [id]
    );

    return res.json({
      isAssigned: false,
      caseStatus: caseResult.rows[0]?.status || 'unknown',
    });
  } catch (err) {
    console.error('[sosController][checkMyAssignment]', err.message);
    res.status(500).json({ error: 'Internal error' });
  }
}

/**
 * POST /api/case/:id/revoke — TNV chủ động hủy nhiệm vụ
 * Body: { volunteerId }
 */
async function revokeCase(req, res) {
  try {
    const { id } = req.params;
    const { volunteerId } = req.body;

    if (!volunteerId) {
      return res.status(400).json({ error: 'Missing volunteerId' });
    }

    // Đánh dấu assignment là đã revoke
    const result = await db.query(
      `UPDATE case_assignments SET revoked_at = NOW()
       WHERE case_id = $1 AND volunteer_id = $2 AND revoked_at IS NULL AND completed_at IS NULL
       RETURNING id`,
      [id, volunteerId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Assignment not found' });
    }

    // Giải phóng TNV (đánh dấu available lại)
    await db.query(
      `UPDATE volunteers SET is_available = true WHERE id = $1`,
      [volunteerId]
    );

    // Đếm xem còn TNV nào đang active cho ca này không
    const remaining = await db.query(
      `SELECT COUNT(*) AS cnt FROM case_assignments
       WHERE case_id = $1 AND revoked_at IS NULL AND completed_at IS NULL`,
      [id]
    );
    const remainingCount = parseInt(remaining.rows[0].cnt, 10);

    if (remainingCount === 0) {
      // Không còn TNV nào → trả ca về pending để TNV khác nhận
      await db.query(
        `UPDATE cases SET status = 'pending' WHERE id = $1 AND status = 'responding'`,
        [id]
      );
      console.log(`[sosController] Case ${id} reverted to pending (no volunteers remaining)`);
    }

    console.log(`[sosController] TNV ${volunteerId} revoked assignment for case ${id}. Remaining: ${remainingCount}`);

    // Broadcast qua WebSocket để Nạn nhân biết TNV đã hủy
    broadcastToRoom(id, {
      type: 'case:revoked',
      volunteerId,
      remainingCount,
      caseId: id,
    });

    // Emit SSE cho Nạn nhân
    emitCaseEvent(id, 'case:revoked', {
      volunteerId,
      remainingCount,
      status: remainingCount > 0 ? 'responding' : 'pending',
    });

    res.json({ success: true, remainingCount });
  } catch (err) {
    console.error('[sosController][revokeCase]', err.message);
    res.status(500).json({ error: 'Internal error' });
  }
}

/**
 * GET /api/sos/history — Lịch sử tất cả ca SOS của user (theo phone)
 * Trả về danh sách ca SOS đã tạo, sắp xếp mới nhất trước.
 * Bao gồm thông tin TNV đã nhận ca (nếu có).
 */
async function getHistoryByPhone(req, res) {
  try {
    const phone = req.user?.phone_number || req.query.phone;
    if (!phone) {
      return res.status(400).json({ error: 'Missing phone' });
    }

    const phoneHash = hashPhone(phone);

    const result = await db.query(
      `SELECT 
        c.id,
        c.urgency_level,
        c.tags,
        c.summary_1line,
        c.text_normalized,
        c.address_text,
        c.status,
        ST_X(c.coords::geometry) AS lon,
        ST_Y(c.coords::geometry) AS lat,
        c.created_at,
        c.resolved_at,
        v.full_name AS volunteer_name,
        v.id AS volunteer_id
      FROM cases c
      LEFT JOIN case_assignments ca 
        ON ca.case_id = c.id 
        AND ca.revoked_at IS NULL
      LEFT JOIN volunteers v 
        ON v.id = ca.volunteer_id
      WHERE c.phone_hash = $1
      ORDER BY c.created_at DESC
      LIMIT 50`,
      [phoneHash]
    );

    const history = result.rows.map(row => {
      const rawTags = typeof row.tags === 'string' ? JSON.parse(row.tags) : (row.tags || []);
      return {
        id: row.id,
        urgency_level: row.urgency_level,
        tags: rawTags,
        summary: row.summary_1line,
        description: row.text_normalized,
        address: row.address_text,
        status: row.status,
        lat: row.lat,
        lon: row.lon,
        created_at: row.created_at,
        resolved_at: row.resolved_at,
        volunteer_name: row.volunteer_name,
        volunteer_id: row.volunteer_id,
      };
    });

    res.json(history);
  } catch (err) {
    console.error('[sosController][getHistoryByPhone]', err.message);
    res.status(500).json({ error: 'Internal error' });
  }
}

/**
 * POST /api/sos/cancel — Nạn nhân huỷ ca SOS của mình
 * Chỉ cho phép hủy khi ca đang ở trạng thái 'pending' (chưa có TNV nhận).
 * Nếu ca đã 'responding' (TNV đang trên đường), vẫn cho hủy nhưng cần xác nhận.
 */
async function cancelCase(req, res) {
  try {
    const phone = req.user?.phone_number;
    if (!phone) {
      return res.status(401).json({ error: 'Unauthorized — no phone' });
    }

    const phoneHash = hashPhone(phone);
    const { caseId, reason } = req.body;

    if (!caseId) {
      return res.status(400).json({ error: 'Missing caseId' });
    }

    // Verify case belongs to this user and is still active
    const caseRow = await db.query(
      `SELECT id, status, phone_hash FROM cases WHERE id = $1`,
      [caseId]
    );

    if (caseRow.rows.length === 0) {
      return res.status(404).json({ error: 'Case not found' });
    }

    const caseData = caseRow.rows[0];

    // Xác minh quyền: chỉ chủ ca mới được huỷ
    if (caseData.phone_hash !== phoneHash) {
      return res.status(403).json({ error: 'Forbidden — you are not the owner of this case' });
    }

    // Chỉ cho huỷ khi ca chưa resolved/cancelled
    if (caseData.status === 'resolved' || caseData.status === 'cancelled') {
      return res.status(409).json({ error: 'Case already closed' });
    }

    // Transaction: cập nhật status + revoke assignments cùng lúc
    const client = await db.getPool().connect();
    try {
      await client.query('BEGIN');
      
      // Cập nhật status → cancelled
      await client.query(
        `UPDATE cases SET status = 'cancelled', resolved_at = NOW() WHERE id = $1`,
        [caseId]
      );

      // Nếu có TNV đang nhận ca, revoke hết + giải phóng TNV
      if (caseData.status === 'responding') {
        // Giải phóng TNV (đánh dấu available lại) TRƯỚC KHI revoke
        await client.query(`
          UPDATE volunteers SET is_available = true
          WHERE id IN (
            SELECT volunteer_id FROM case_assignments
            WHERE case_id = $1 AND revoked_at IS NULL
          )
        `, [caseId]);

        await client.query(
          `UPDATE case_assignments SET revoked_at = NOW() WHERE case_id = $1 AND revoked_at IS NULL`,
          [caseId]
        );
      }

      // Xóa tin nhắn chat khi ca bị hủy
      await client.query(`DELETE FROM chat_messages WHERE case_id = $1`, [caseId]);

      await client.query('COMMIT');
    } catch (txErr) {
      await client.query('ROLLBACK');
      throw txErr;
    } finally {
      client.release();
    }

    // Broadcast SSE event để TNV biết ca đã bị huỷ
    try {
      emitCaseEvent(caseId, 'case:cancelled', { reason: reason || 'Nạn nhân đã hủy ca' });
      broadcastToRoom(caseId, { type: 'case:cancelled', caseId, reason: reason || 'Nạn nhân đã hủy ca' });
    } catch (broadcastErr) {
      console.warn('[sosController][cancelCase] broadcast error:', broadcastErr.message);
    }

    console.log(`[sosController] Case ${caseId} cancelled by victim. Reason: ${reason || 'N/A'}`);
    res.json({ success: true, message: 'Ca SOS đã được hủy thành công' });
  } catch (err) {
    console.error('[sosController][cancelCase]', err.message);
    res.status(500).json({ error: 'Internal error' });
  }
}

/**
 * GET /api/volunteers/:volunteerId/history — Lịch sử ca SOS mà TNV đã tham gia
 * Trả về stats tổng hợp + danh sách missions, sắp xếp mới nhất trước.
 * Khác getHistoryByPhone: đây là góc nhìn TNV (tôi đã giúp ai), không phải nạn nhân.
 */
async function getVolunteerHistory(req, res) {
  try {
    const { volunteerId } = req.params;
    if (!volunteerId) {
      return res.status(400).json({ error: 'Missing volunteerId' });
    }

    // 1) Lấy danh sách missions (assignments + case info)
    const result = await db.query(
      `SELECT 
        c.id AS case_id,
        c.status AS case_status,
        c.urgency_level,
        c.tags,
        c.summary_1line,
        c.text_normalized,
        c.address_text,
        ST_X(c.coords::geometry) AS lon,
        ST_Y(c.coords::geometry) AS lat,
        c.created_at AS case_created_at,
        c.resolved_at AS case_resolved_at,
        ca.assigned_at,
        ca.completed_at,
        ca.revoked_at,
        ca.initial_distance_m,
        EXTRACT(EPOCH FROM (ca.assigned_at - c.created_at)) / 60 AS response_time_min
      FROM case_assignments ca
      JOIN cases c ON c.id = ca.case_id
      WHERE ca.volunteer_id = $1
      ORDER BY ca.assigned_at DESC
      LIMIT 100`,
      [volunteerId]
    );

    // 2) Build missions list
    const missions = result.rows.map(row => {
      const rawTags = typeof row.tags === 'string' ? JSON.parse(row.tags) : (row.tags || []);
      const assignmentStatus = row.revoked_at ? 'revoked' : (row.completed_at ? 'completed' : 'active');
      return {
        case_id: row.case_id,
        case_status: row.case_status,
        assignment_status: assignmentStatus,
        urgency_level: row.urgency_level,
        tags: rawTags,
        summary: row.summary_1line,
        description: row.text_normalized,
        address: row.address_text,
        initial_distance_m: row.initial_distance_m,
        assigned_at: row.assigned_at,
        completed_at: row.completed_at,
        revoked_at: row.revoked_at,
        case_created_at: row.case_created_at,
        case_resolved_at: row.case_resolved_at,
        lat: row.lat,
        lon: row.lon,
        response_time_min: row.response_time_min != null ? Math.round(parseFloat(row.response_time_min)) : null,
      };
    });

    // 3) Tính stats tổng hợp
    const completed = missions.filter(m => m.assignment_status === 'completed').length;
    const revoked = missions.filter(m => m.assignment_status === 'revoked').length;
    const totalDistanceM = missions
      .filter(m => m.initial_distance_m != null)
      .reduce((sum, m) => sum + m.initial_distance_m, 0);
    const responseTimes = missions
      .filter(m => m.response_time_min != null && m.response_time_min >= 0)
      .map(m => m.response_time_min);
    const avgResponseTime = responseTimes.length > 0
      ? Math.round(responseTimes.reduce((a, b) => a + b, 0) / responseTimes.length)
      : 0;

    res.json({
      stats: {
        total_missions: missions.length,
        completed,
        revoked,
        total_distance_km: parseFloat((totalDistanceM / 1000).toFixed(1)),
        avg_response_time_min: avgResponseTime,
      },
      missions,
    });
  } catch (err) {
    console.error('[sosController][getVolunteerHistory]', err.message);
    res.status(500).json({ error: 'Internal error' });
  }
}

/**
 * GET /api/volunteers/:volunteerId/active-mission
 * Kiểm tra TNV có đang được assign vào ca nào đang active không.
 * Dùng để khôi phục trạng thái mission khi TNV tắt app rồi mở lại.
 * Trả về thông tin ca + assignment nếu có, hoặc { hasActiveMission: false }.
 */
async function getActiveAssignment(req, res) {
  try {
    const { volunteerId } = req.params;
    if (!volunteerId) {
      return res.status(400).json({ error: 'Missing volunteerId' });
    }

    const result = await db.query(
      `SELECT 
        c.id AS case_id,
        c.status AS case_status,
        c.urgency_level,
        c.tags,
        c.summary_1line,
        c.text_normalized,
        c.address_text,
        ST_X(c.coords::geometry) AS lon,
        ST_Y(c.coords::geometry) AS lat,
        ca.assigned_at
      FROM case_assignments ca
      JOIN cases c ON c.id = ca.case_id
      WHERE ca.volunteer_id = $1
        AND ca.revoked_at IS NULL
        AND ca.completed_at IS NULL
        AND c.status IN ('pending', 'responding', 'on_scene')
      ORDER BY ca.assigned_at DESC
      LIMIT 1`,
      [volunteerId]
    );

    if (result.rows.length === 0) {
      return res.json({ hasActiveMission: false });
    }

    const row = result.rows[0];
    res.json({
      hasActiveMission: true,
      caseId: row.case_id,
      caseStatus: row.case_status,
      urgencyLevel: row.urgency_level,
      tags: row.tags,
      summary: row.summary_1line,
      description: row.text_normalized,
      address: row.address_text,
      lat: row.lat,
      lon: row.lon,
      assignedAt: row.assigned_at,
    });
  } catch (err) {
    console.error('[sosController][getActiveAssignment]', err.message);
    res.status(500).json({ error: 'Internal error' });
  }
}

/**
 * POST /api/case/:id/confirm-route
 * TNV xác nhận vẫn đang trên đường cứu trợ (phản hồi cảnh báo đứng im).
 * Reset cờ confirmed_en_route = true, xóa warned_at để cronjob không hủy ca.
 */
async function confirmRoute(req, res) {
  try {
    const caseId = req.params.id;
    const { volunteerId } = req.body;

    if (!caseId || !volunteerId) {
      return res.status(400).json({ error: 'Missing caseId or volunteerId' });
    }

    const result = await db.query(
      `UPDATE case_assignments 
       SET confirmed_en_route = true, warned_at = NULL 
       WHERE case_id = $1 AND volunteer_id = $2 AND revoked_at IS NULL`,
      [caseId, volunteerId]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Assignment not found or already revoked' });
    }

    console.log(`[sosController][confirmRoute] TNV ${volunteerId} confirmed en route for case ${caseId}`);
    res.json({ success: true, message: 'Xác nhận hành trình thành công' });
  } catch (err) {
    console.error('[sosController][confirmRoute]', err.message);
    res.status(500).json({ error: 'Internal error' });
  }
}

module.exports = { createSos, getCaseById, getTnvLocation, acceptCase, resolveCase, revokeCase, getActiveByPhone, getNearbyCases, checkMyAssignment, getHistoryByPhone, cancelCase, getVolunteerHistory, getActiveAssignment, confirmRoute };
