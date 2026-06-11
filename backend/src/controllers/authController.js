/**
 * Auth Controller
 * Xử lý xác thực & đăng nhập cho Tình nguyện viên
 */

const { db } = require('../db');
const crypto = require('crypto');

const SALT = process.env.PHONE_HASH_SALT || 'default_salt';

function hashPhone(phone) {
  return crypto.createHmac('sha256', SALT).update(phone).digest('hex');
}

/**
 * POST /api/auth/verify-phone
 * Sau khi OTP thành công, Mobile gọi endpoint này để xác định trạng thái TNV:
 *   - 200: TNV đã đăng ký & được Admin duyệt → Đăng nhập thành công
 *   - 403: TNV đã đăng ký nhưng chưa được Admin duyệt → Chờ phê duyệt
 *   - 404: SĐT chưa từng đăng ký → Cần đăng ký mới (chuyển sang form eKYC)
 */
async function verifyPhone(req, res) {
  try {
    const phone = req.user?.phone_number || req.body.phone;

    if (!phone) {
      return res.status(400).json({ error: 'Thiếu số điện thoại' });
    }

    const phoneHash = hashPhone(phone);

    const result = await db.query(
      'SELECT id, full_name, admin_approved, cccd_verified FROM volunteers WHERE phone_hash = $1',
      [phoneHash]
    );

    // TH 3: Chưa từng đăng ký
    if (result.rows.length === 0) {
      return res.status(404).json({
        status: 'NOT_REGISTERED',
        message: 'Số điện thoại chưa được đăng ký. Vui lòng đăng ký mới.',
      });
    }

    const volunteer = result.rows[0];

    // TH 2: Đã đăng ký nhưng chưa được duyệt
    if (!volunteer.admin_approved) {
      return res.status(403).json({
        status: 'PENDING_APPROVAL',
        volunteerId: volunteer.id,
        message: 'Hồ sơ của bạn đang chờ Ban Quản Trị phê duyệt.',
      });
    }

    // TH 1: Đã đăng ký & được duyệt → Đăng nhập thành công
    // Cập nhật trạng thái sẵn sàng khi đăng nhập
    await db.query(
      'UPDATE volunteers SET is_available = true WHERE id = $1',
      [volunteer.id]
    );

    return res.status(200).json({
      status: 'APPROVED',
      volunteerId: volunteer.id,
      fullName: volunteer.full_name,
      cccdVerified: volunteer.cccd_verified,
      message: 'Đăng nhập thành công.',
    });
  } catch (err) {
    console.error('[authController][verifyPhone]', err.message);
    res.status(500).json({ error: 'Internal error' });
  }
}

module.exports = { verifyPhone };
