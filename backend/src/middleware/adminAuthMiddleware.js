/**
 * Admin Auth Middleware
 * Bảo vệ các route admin — yêu cầu JWT hợp lệ
 */

const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET || 'floodaid_admin_secret_key';

function adminAuthMiddleware(req, res, next) {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Unauthorized: Missing admin token' });
  }

  const token = authHeader.split('Bearer ')[1];

  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    req.admin = { id: decoded.adminId, email: decoded.email };
    next();
  } catch (err) {
    return res.status(401).json({ error: 'Unauthorized: Invalid or expired admin token' });
  }
}

module.exports = { adminAuthMiddleware };
