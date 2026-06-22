/**
 * Volunteer Controller
 * Module 3: Auth & Field Tracking
 */

const { db } = require('../db');
const crypto = require('crypto');
const { encryptPhone, decryptPhone } = require('../utils/crypto');

const SALT = process.env.PHONE_HASH_SALT || 'default_salt';

function hashPhone(phone) {
  return crypto.createHmac('sha256', SALT).update(phone).digest('hex');
}

/**
 * POST /api/volunteers/register — Đăng ký TNV mới
 * Chỉ dùng cho đăng ký mới (sau khi eKYC xong).
 * admin_approved mặc định = false → Chờ Admin duyệt.
 */
async function registerVolunteer(req, res) {
  try {
    const { fullName, cccdNumber } = req.body;
    const phone = req.user?.phone_number || req.body.phone;
    const firebaseUid = req.user?.uid;

    if (!phone) {
      return res.status(400).json({ error: 'Thiếu số điện thoại' });
    }

    if (!fullName || !fullName.trim()) {
      return res.status(400).json({ error: 'Thiếu họ và tên' });
    }

    const phoneHash = hashPhone(phone);

    // Kiểm tra đã tồn tại → Không cho đăng ký lại
    const existing = await db.query(
      'SELECT id, admin_approved FROM volunteers WHERE phone_hash = $1',
      [phoneHash]
    );
    if (existing.rows.length > 0) {
      const vol = existing.rows[0];
      if (vol.admin_approved) {
        return res.status(409).json({
          status: 'ALREADY_APPROVED',
          volunteerId: vol.id,
          message: 'Tài khoản đã được phê duyệt. Vui lòng đăng nhập.',
        });
      }
      return res.status(409).json({
        status: 'PENDING_APPROVAL',
        volunteerId: vol.id,
        message: 'Hồ sơ đã được gửi trước đó. Vui lòng chờ Admin phê duyệt.',
      });
    }

    const result = await db.query(
      `INSERT INTO volunteers (phone_hash, firebase_uid, full_name, is_available, admin_approved, cccd_verified, phone_encrypted, cccd_number_encrypted)
       VALUES ($1, $2, $3, false, false, $4, $5, $6)
       RETURNING id, full_name, is_available, admin_approved, cccd_verified, created_at`,
      [
        phoneHash,
        firebaseUid || null,
        fullName.trim(),
        !!cccdNumber,
        encryptPhone(phone),
        cccdNumber ? encryptPhone(cccdNumber) : null,
      ]
    );

    console.log(`[volunteerController][register] New volunteer registered: ${result.rows[0].id} (pending approval)`);
    res.status(201).json({
      status: 'REGISTERED',
      volunteerId: result.rows[0].id,
      message: 'Đăng ký thành công. Hồ sơ đang chờ Admin phê duyệt.',
      ...result.rows[0],
    });
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
      SELECT id, full_name, is_available, admin_approved, 
             cccd_verified, phone_encrypted, notification_radius_km, created_at,
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

/**
 * PUT /api/volunteers/:id/radius — TNV bật/tắt nhận thông báo SOS
 * Body: { enabled: boolean }
 *   - true  → notification_radius_km = NULL (nhận mọi thông báo)
 *   - false → notification_radius_km = 0    (tắt thông báo)
 */
async function updateNotificationRadius(req, res) {
  try {
    const { id } = req.params;
    const { enabled, radiusKm } = req.body;

    // Backward-compat: nếu client cũ gửi radiusKm thì map sang enabled
    let value;
    if (enabled !== undefined) {
      value = enabled ? null : 0;
    } else {
      // Legacy: radiusKm null/0 = ON, >0 giữ nguyên nhưng không dùng nữa
      value = (radiusKm === null || radiusKm === undefined || radiusKm === 0) ? null : 0;
    }

    await db.query(
      'UPDATE volunteers SET notification_radius_km = $1 WHERE id = $2',
      [value, id]
    );

    const isEnabled = value === null;
    console.log(`[volunteerController] Notifications ${isEnabled ? 'ON' : 'OFF'} for volunteer ${id}`);
    res.json({ success: true, notifications_enabled: isEnabled });
  } catch (err) {
    console.error('[volunteerController][updateNotificationRadius]', err.message);
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
  updateNotificationRadius,
};
