/**
 * FCM Service — Firebase Cloud Messaging
 * Khi chưa có Firebase Admin SDK, log notification thay vì gửi thật
 */

const URGENCY_EMOJI = { 1: '🔵', 2: '🟡', 3: '🟠', 4: '🔴', 5: '🆘' };

const { getAdmin } = require('./firebaseAdmin');

function initFirebaseAdmin() {
  return getAdmin();
}

/**
 * Gửi FCM notification cho TNV khi có ca SOS mới hoặc cảnh báo hệ thống
 * @param {string} fcmToken
 * @param {object} sosCase - { id, urgency_level, summary_1line }
 * @param {string} [type='NEW_SOS'] - Loại thông báo: 'NEW_SOS', 'STALE_WARNING', ...
 */
async function sendFcmToVolunteer(fcmToken, sosCase, type = 'NEW_SOS') {
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
      type: type,
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
