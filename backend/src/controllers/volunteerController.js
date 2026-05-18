/**
 * Volunteer Controller
 * Module 3: Auth & Field Tracking
 */

const { db } = require('../db');
const crypto = require('crypto');

const SALT = process.env.PHONE_HASH_SALT || 'default_salt';

function hashPhone(phone) {
  return crypto.createHmac('sha256', SALT).update(phone).digest('hex');
}

/**
 * POST /api/volunteers/register — Đăng ký TNV
 */
async function registerVolunteer(req, res) {
  try {
    const { phone, fullName, skills } = req.body;

    if (!phone) {
      return res.status(400).json({ error: 'Missing phone number' });
    }

    const phoneHash = hashPhone(phone);

    // Kiểm tra đã tồn tại
    const existing = await db.query(
      'SELECT id FROM volunteers WHERE phone_hash = $1',
      [phoneHash]
    );
    if (existing.rows.length > 0) {
      return res.status(409).json({
        error: 'VOLUNTEER_EXISTS',
        volunteerId: existing.rows[0].id,
      });
    }

    const result = await db.query(
      `INSERT INTO volunteers (phone_hash, full_name, skills, is_available)
       VALUES ($1, $2, $3::jsonb, true)
       RETURNING id, full_name, skills, is_available, admin_approved, created_at`,
      [phoneHash, fullName || null, JSON.stringify(skills || [])]
    );

    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('[volunteerController][register]', err.message);
    res.status(500).json({ error: 'Internal error' });
  }
}

/**
 * GET /api/volunteers — Liệt kê tất cả TNV (Admin)
 */
async function listVolunteers(req, res) {
  try {
    const result = await db.query(`
      SELECT id, full_name, skills, is_available, admin_approved, 
             cccd_verified, flag_count, created_at,
             ST_X(current_coords::geometry) AS lon,
             ST_Y(current_coords::geometry) AS lat,
             last_seen_at
      FROM volunteers
      ORDER BY created_at DESC
    `);

    res.json(result.rows);
  } catch (err) {
    console.error('[volunteerController][list]', err.message);
    res.status(500).json({ error: 'Internal error' });
  }
}

/**
 * GET /api/volunteers/locations — Vị trí tất cả TNV (Admin dashboard polling 15s)
 */
async function getVolunteerLocations(req, res) {
  try {
    const result = await db.query(`
      SELECT * FROM v_available_volunteers
      ORDER BY minutes_since_update ASC NULLS LAST
    `);

    res.json(result.rows);
  } catch (err) {
    console.error('[volunteerController][locations]', err.message);
    res.status(500).json({ error: 'Internal error' });
  }
}

/**
 * PUT /api/volunteers/:id/approve — Admin phê duyệt TNV
 */
async function approveVolunteer(req, res) {
  try {
    const { id } = req.params;
    const { approved } = req.body;

    await db.query(
      'UPDATE volunteers SET admin_approved = $1 WHERE id = $2',
      [approved !== false, id]
    );

    res.json({ success: true });
  } catch (err) {
    console.error('[volunteerController][approve]', err.message);
    res.status(500).json({ error: 'Internal error' });
  }
}

/**
 * PUT /api/volunteers/:id/availability — TNV toggle available
 */
async function setAvailability(req, res) {
  try {
    const { id } = req.params;
    const { available } = req.body;

    await db.query(
      'UPDATE volunteers SET is_available = $1 WHERE id = $2',
      [available, id]
    );

    res.json({ success: true, is_available: available });
  } catch (err) {
    console.error('[volunteerController][setAvailability]', err.message);
    res.status(500).json({ error: 'Internal error' });
  }
}

module.exports = {
  registerVolunteer,
  listVolunteers,
  getVolunteerLocations,
  approveVolunteer,
  setAvailability,
};
