/**
 * FCM Service — Firebase Cloud Messaging
 * Khi chưa có Firebase Admin SDK, log notification thay vì gửi thật
 */

const URGENCY_EMOJI = { 1: '🔵', 2: '🟡', 3: '🟠', 4: '🔴', 5: '🆘' };

let firebaseAdmin = null;

function initFirebaseAdmin() {
  if (firebaseAdmin) return firebaseAdmin;

  const serviceAccountPath = process.env.FIREBASE_ADMIN_SDK;
  if (!serviceAccountPath) {
    console.warn('[fcmService] FIREBASE_ADMIN_SDK not configured — notifications will be logged only');
    return null;
  }

  try {
    const admin = require('firebase-admin');
    const serviceAccount = require(require('path').resolve(serviceAccountPath));
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
    firebaseAdmin = admin;
    return admin;
  } catch (err) {
    console.warn('[fcmService] Firebase Admin init failed:', err.message);
    return null;
  }
}

/**
 * Gửi FCM notification cho TNV khi có ca SOS mới
 */
async function sendFcmToVolunteer(fcmToken, sosCase) {
  if (!fcmToken) return;

  const emoji = URGENCY_EMOJI[sosCase.urgency_level] || '🔴';
  const payload = {
    notification: {
      title: `${emoji} SOS Mức ${sosCase.urgency_level} — Cần cứu hộ ngay`,
      body: sosCase.summary_1line,
    },
    data: {
      caseId: String(sosCase.id),
      urgencyLevel: String(sosCase.urgency_level),
      type: 'NEW_SOS',
    },
    android: {
      priority: sosCase.urgency_level >= 4 ? 'high' : 'normal',
      notification: {
        sound: sosCase.urgency_level >= 4 ? 'sos_alert' : 'default',
        channelId: 'sos_notifications',
      },
    },
  };

  const admin = initFirebaseAdmin();
  if (!admin) {
    // Dev mode: log thay vì gửi thật
    console.log('[fcmService][DEV] Would send to TNV:', {
      token: fcmToken.slice(0, 10) + '...',
      title: payload.notification.title,
      body: payload.notification.body,
    });
    return;
  }

  try {
    await admin.messaging().send({ token: fcmToken, ...payload });
  } catch (err) {
    console.error('[fcmService] Send failed for token:', fcmToken.slice(0, 10), err.message);
    // Token invalid → mark volunteer fcm_token as null
    if (err.code === 'messaging/invalid-registration-token') {
      const { db } = require('../db');
      await db.query('UPDATE volunteers SET fcm_token = NULL WHERE fcm_token = $1', [fcmToken]);
    }
  }
}

/**
 * Gửi FCM notification cho Nạn nhân (proximity alerts)
 */
async function sendFcmToVictim(fcmToken, notification) {
  if (!fcmToken) return;

  const admin = initFirebaseAdmin();
  if (!admin) {
    console.log('[fcmService][DEV] Would send to Victim:', notification);
    return;
  }

  try {
    await admin.messaging().send({
      token: fcmToken,
      notification: {
        title: notification.title,
        body: notification.body,
      },
      data: { type: notification.type },
      android: { priority: 'high' },
    });
  } catch (err) {
    console.error('[fcmService] Victim FCM failed:', err.message);
  }
}

module.exports = { sendFcmToVolunteer, sendFcmToVictim, URGENCY_EMOJI };
