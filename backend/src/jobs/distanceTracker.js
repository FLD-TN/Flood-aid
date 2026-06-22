/**
 * Distance Tracker — Module 4
 * Chạy mỗi khi server nhận GPS update từ TNV
 * Server-side distance calc (không dùng Android Geofencing)
 */

const { db } = require('../db');
const { sendFcmToVolunteer, sendFcmToVictim } = require('../services/fcmService');

/**
 * Gọi sau mỗi lần nhận POST /api/location từ TNV
 */
async function onVolunteerLocationUpdate(volunteerId, newCoordsWkt) {
  try {
    // Tìm tất cả ca mà TNV này đang nhận
    const assignments = await db.query(`
      SELECT 
        ca.case_id,
        ca.notif_sent_300m,
        ca.notif_sent_100m,
        c.status AS case_status,
        c.phone_hash AS victim_phone_hash,
        ST_Distance(
          ST_GeomFromEWKT($1)::geography,
          c.coords::geography
        ) AS distance_m
      FROM case_assignments ca
      JOIN cases c ON c.id = ca.case_id
      WHERE ca.volunteer_id = $2
        AND ca.revoked_at IS NULL
        AND ca.completed_at IS NULL
        AND c.status IN ('responding', 'on_scene')
    `, [newCoordsWkt, volunteerId]);

    for (const row of assignments.rows) {
      const distM = Math.round(row.distance_m);

      // Cập nhật distance cache cho polling
      await db.query(
        'UPDATE cases SET tnv_distance_m = $1 WHERE id = $2',
        [distM, row.case_id]
      );

      // Lấy FCM tokens
      const vol = await db.query('SELECT fcm_token FROM volunteers WHERE id = $1', [volunteerId]);
      const tnvFcm = vol.rows[0]?.fcm_token;

      // FCM ngưỡng 300m — chỉ gửi cho TNV
      if (distM < 300 && !row.notif_sent_300m) {
        await sendFcmToVolunteer(tnvFcm, {
          id: row.case_id,
          urgency_level: 3,
          summary_1line: `Bạn sắp tới nơi — còn ~${distM}m, chuẩn bị tiếp cận!`,
        });
        await db.query(
          'UPDATE case_assignments SET notif_sent_300m = true WHERE case_id = $1 AND volunteer_id = $2',
          [row.case_id, volunteerId]
        );
        console.log(`[distanceTracker] Case ${row.case_id}: 300m notification sent to volunteer`);
      }

      // FCM ngưỡng 100m — gửi cho cả nạn nhân lẫn TNV, chỉ 1 lần
      if (distM < 100 && !row.notif_sent_100m) {
        // Lấy FCM token nạn nhân từ DB
        const victimRow = await db.query(
          `SELECT vi.fcm_token FROM victims vi
           JOIN cases c ON c.phone_hash = vi.phone_hash
           WHERE c.id = $1`,
          [row.case_id]
        );
        const victimFcm = victimRow.rows[0]?.fcm_token || null;

        await sendFcmToVictim(victimFcm, {
          title: '🟢 Người cứu hộ đã đến!',
          body: 'Đội cứu hộ đã đến khu vực của bạn!',
          type: 'NEAR_100',
        });
        await sendFcmToVolunteer(tnvFcm, {
          id: row.case_id,
          urgency_level: 3,
          summary_1line: 'Bạn đã đến nơi — hãy tìm nạn nhân trong khu vực!',
        });
        await db.query(
          `UPDATE case_assignments
           SET notif_sent_100m = true, arrived_at = NOW()
           WHERE case_id = $1 AND volunteer_id = $2`,
          [row.case_id, volunteerId]
        );
        await db.query(
          `UPDATE cases SET status = 'on_scene' WHERE id = $1 AND status = 'responding'`,
          [row.case_id]
        );
        console.log(`[distanceTracker] Case ${row.case_id}: 100m — both sides notified, status → on_scene`);
      }
    }

  } catch (err) {
    console.error('[distanceTracker][onVolunteerLocationUpdate]', err.message);
  }
}

module.exports = { onVolunteerLocationUpdate };
