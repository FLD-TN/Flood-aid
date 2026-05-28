const { getAdmin } = require('../services/firebaseAdmin');

async function authMiddleware(req, res, next) {
  const admin = getAdmin();
  if (!admin) {
    // Nếu chưa cấu hình Firebase, log cảnh báo và bypass (dành cho môi trường dev/test)
    console.warn('[authMiddleware] Bypass auth since Firebase Admin is not initialized');
    // Fallback: Lấy phone từ body/query nếu có, nếu không thì dùng mặc định
    const fallbackPhone = req.body.phone || req.query.phone || '+84999999999';
    req.user = { uid: 'dev-uid', phone_number: fallbackPhone };
    return next();
  }

  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Unauthorized: Missing or invalid token' });
  }

  const token = authHeader.split('Bearer ')[1];
  try {
    const decodedToken = await admin.auth().verifyIdToken(token);
    req.user = {
      uid: decodedToken.uid,
      phone_number: decodedToken.phone_number,
    };
    next();
  } catch (error) {
    console.error('[authMiddleware] Invalid token:', error.message);
    return res.status(401).json({ error: 'Unauthorized: Invalid token' });
  }
}

module.exports = { authMiddleware };
