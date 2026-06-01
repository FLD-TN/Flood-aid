/**
 * Volunteer Controller
 * Module 3: Auth & Field Tracking
 */

const { db } = require('../db');
const crypto = require('crypto');

const SALT = process.env.PHONE_HASH_SALT || 'default_salt';
const ENCRYPT_KEY = process.env.PHONE_ENCRYPT_KEY;

function hashPhone(phone) {
  return crypto.createHmac('sha256', SALT).update(phone).digest('hex');
}

/**
 * AES-256-GCM encrypt phone number
 */
function encryptPhone(phone) {
  if (!ENCRYPT_KEY || !phone) return null;
  const key = Buffer.from(ENCRYPT_KEY, 'hex');
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
  let encrypted = cipher.update(phone, 'utf8', 'hex');
  encrypted += cipher.final('hex');
  const authTag = cipher.getAuthTag().toString('hex');
  return iv.toString('hex') + ':' + encrypted + ':' + authTag;
}

/**
 * AES-256-GCM decrypt phone number
 */
function decryptPhone(encryptedStr) {
  if (!ENCRYPT_KEY || !encryptedStr) return null;
  try {
    const key = Buffer.from(ENCRYPT_KEY, 'hex');
    const parts = encryptedStr.split(':');
    const iv = Buffer.from(parts[0], 'hex');
    const encrypted = parts[1];
    const authTag = Buffer.from(parts[2], 'hex');
    const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv);
    decipher.setAuthTag(authTag);
    let decrypted = decipher.update(encrypted, 'hex', 'utf8');
    decrypted += decipher.final('utf8');
    return decrypted;
  } catch {
    return null;
  }
}

/**
 * POST /api/volunteers/register — Đăng ký TNV
 */
async function registerVolunteer(req, res) {
  try {
    const { fullName, skills } = req.body;
    const phone = req.user?.phone_number || req.body.phone;
    const firebaseUid = req.user?.uid;

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
      // Đảm bảo TNV cũ luôn được phê duyệt và sẵn sàng khi đăng nhập lại
      await db.query(
        'UPDATE volunteers SET admin_approved = true, is_available = true WHERE id = $1',
        [existing.rows[0].id]
      );
      return res.status(409).json({
        error: 'VOLUNTEER_EXISTS',
        volunteerId: existing.rows[0].id,
      });
    }

    const result = await db.query(
      `INSERT INTO volunteers (phone_hash, firebase_uid, full_name, skills, is_available, admin_approved, phone_encrypted)
       VALUES ($1, $2, $3, $4::jsonb, true, true, $5)
       RETURNING id, full_name, skills, is_available, admin_approved, created_at`,
      [phoneHash, firebaseUid || null, fullName || null, JSON.stringify(skills || []), encryptPhone(phone)]
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
             cccd_verified, phone_encrypted, created_at,
             ST_X(current_coords::geometry) AS lon,
             ST_Y(current_coords::geometry) AS lat,
             last_seen_at
      FROM volunteers
      ORDER BY created_at DESC
    `);

    // Decrypt phone cho Admin
    const rows = result.rows.map(row => ({
      ...row,
      phone: decryptPhone(row.phone_encrypted),
      phone_encrypted: undefined, // Không trả ciphertext ra client
    }));

    res.json(rows);
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

/**
 * PUT /api/volunteers/:id/fcm-token — Lưu/cập nhật FCM Token cho TNV
 */
async function updateFcmToken(req, res) {
  try {
    const { id } = req.params;
    const { fcmToken } = req.body;

    if (!fcmToken) {
      return res.status(400).json({ error: 'Missing fcmToken' });
    }

    await db.query(
      'UPDATE volunteers SET fcm_token = $1 WHERE id = $2',
      [fcmToken, id]
    );

    console.log(`[volunteerController] FCM token saved for volunteer ${id}`);
    res.json({ success: true });
  } catch (err) {
    console.error('[volunteerController][updateFcmToken]', err.message);
    res.status(500).json({ error: 'Internal error' });
  }
}

module.exports = {
  registerVolunteer,
  listVolunteers,
  getVolunteerLocations,
  approveVolunteer,
  setAvailability,
  updateFcmToken,
};
