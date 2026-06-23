/**
 * Admin Auth Controller
 * Đăng ký và đăng nhập cho Admin web dashboard
 */

const { db } = require('../db');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET || 'floodaid_admin_secret_key';
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '8h';

/**
 * POST /api/admin/register
 * Tạo tài khoản admin mới (email + password + full_name)
 */
async function register(req, res) {
  try {
    const { email, password, fullName } = req.body;

    if (!email || !password || !fullName) {
      return res.status(400).json({ error: 'Thiếu email, password hoặc họ tên' });
    }

    if (password.length < 6) {
      return res.status(400).json({ error: 'Mật khẩu tối thiểu 6 ký tự' });
    }

    const existing = await db.query('SELECT id FROM admins WHERE email = $1', [email]);
    if (existing.rows.length > 0) {
      return res.status(409).json({ error: 'Email đã được sử dụng' });
    }

    const passwordHash = await bcrypt.hash(password, 10);

    const result = await db.query(
      `INSERT INTO admins (email, full_name, password_hash)
       VALUES ($1, $2, $3)
       RETURNING id, email, full_name, created_at`,
      [email, fullName, passwordHash]
    );

    const admin = result.rows[0];
    const token = jwt.sign({ adminId: admin.id, email: admin.email }, JWT_SECRET, { expiresIn: JWT_EXPIRES_IN });

    return res.status(201).json({
      token,
      admin: { id: admin.id, email: admin.email, fullName: admin.full_name },
    });
  } catch (err) {
    console.error('[adminAuthController][register]', err.message);
    res.status(500).json({ error: 'Internal error' });
  }
}

/**
 * POST /api/admin/login
 * Đăng nhập bằng email + password → trả JWT
 */
async function login(req, res) {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ error: 'Thiếu email hoặc password' });
    }

    const result = await db.query(
      'SELECT id, email, full_name, password_hash FROM admins WHERE email = $1',
      [email]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Email hoặc mật khẩu không đúng' });
    }

    const admin = result.rows[0];

    if (!admin.password_hash) {
      return res.status(401).json({ error: 'Tài khoản chưa được cấu hình mật khẩu' });
    }

    const isMatch = await bcrypt.compare(password, admin.password_hash);
    if (!isMatch) {
      return res.status(401).json({ error: 'Email hoặc mật khẩu không đúng' });
    }

    const token = jwt.sign({ adminId: admin.id, email: admin.email }, JWT_SECRET, { expiresIn: JWT_EXPIRES_IN });

    return res.json({
      token,
      admin: { id: admin.id, email: admin.email, fullName: admin.full_name },
    });
  } catch (err) {
    console.error('[adminAuthController][login]', err.message);
    res.status(500).json({ error: 'Internal error' });
  }
}

module.exports = { register, login };
