const admin = require('firebase-admin');
const path = require('path');

let firebaseAdmin = null;

function initFirebaseAdmin() {
  if (firebaseAdmin) return firebaseAdmin;

  const serviceAccountPath = process.env.FIREBASE_ADMIN_SDK;
  if (!serviceAccountPath) {
    console.warn('[firebaseAdmin] FIREBASE_ADMIN_SDK not configured — Firebase features will be limited');
    return null;
  }

  try {
    const serviceAccount = require(path.resolve(serviceAccountPath));
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
    firebaseAdmin = admin;
    console.log('[firebaseAdmin] Initialized successfully');
    return admin;
  } catch (err) {
    console.warn('[firebaseAdmin] Init failed:', err.message);
    return null;
  }
}

function getAdmin() {
  return firebaseAdmin;
}

module.exports = { initFirebaseAdmin, getAdmin };
