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

      // FCM ngưỡng 300m — chỉ gửi 1 lần
      if (distM < 300 && !row.notif_sent_300m) {
        await sendFcmToVictim(null, {
          title: '🟠 Người cứu hộ sắp đến!',
          body: `Người cứu hộ còn cách bạn ~${distM}m, hãy ra hiệu!`,
          type: 'NEAR_300',
        });
        await sendFcmToVolunteer(tnvFcm, {
          id: row.case_id,
          urgency_level: 3,
          summary_1line: `Bạn sắp tới nơi — còn ~${distM}m, chuẩn bị tiếp cận!`,
        });
        await db.query(
          'UPDATE case_assignments SET notif_sent_300m = true WHERE case_id = $1 AND volunteer_id = $2',
          [row.case_id, volunteerId]
        );
        console.log(`[distanceTracker] Case ${row.case_id}: 300m notification sent`);
      }

      // FCM ngưỡng 100m — chỉ gửi 1 lần
      if (distM < 100 && !row.notif_sent_100m) {
        await sendFcmToVictim(null, {
          title: '🟢 Người cứu hộ đã rất gần!',
          body: 'Người cứu hộ đã đến khu vực của bạn!',
          type: 'NEAR_100',
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
        console.log(`[distanceTracker] Case ${row.case_id}: TNV on-scene (<100m)`);
      }
    }

    // Kiểm tra cờ cảnh báo trong 200m
    await checkWarningFlagProximity(volunteerId, newCoordsWkt);

  } catch (err) {
    console.error('[distanceTracker][onVolunteerLocationUpdate]', err.message);
  }
}

/**
 * Cảnh báo TNV khi tiến vào 200m từ cờ nguy hiểm
 */
async function checkWarningFlagProximity(volunteerId, tnvCoordsWkt) {
  const WARNING_RADIUS_M = 200;

  try {
    const flags = await db.query(`
      SELECT 
        wf.id,
        wf.type,
        ST_Distance(ST_GeomFromEWKT($1)::geography, wf.coords::geography) AS dist_m
      FROM warning_flags wf
      WHERE wf.is_active = true
        AND ST_DWithin(wf.coords::geography, ST_GeomFromEWKT($1)::geography, $2)
    `, [tnvCoordsWkt, WARNING_RADIUS_M]);

    if (flags.rows.length === 0) return;

    const vol = await db.query('SELECT fcm_token FROM volunteers WHERE id = $1', [volunteerId]);
    if (!vol.rows[0]?.fcm_token) return;

    const typeLabels = {
      tree_down: 'Cây đổ chắn đường',
      bridge_collapsed: 'Cầu sập',
      flooded_road: 'Đường ngập sâu',
    };

    for (const flag of flags.rows) {
      // Chống spam: chỉ cảnh báo 1 lần trong 30 phút
      const alreadyAlerted = await db.query(
        `SELECT 1 FROM volunteer_flag_alerts 
         WHERE volunteer_id = $1 AND flag_id = $2 AND alerted_at > NOW() - INTERVAL '30 minutes'`,
        [volunteerId, flag.id]
      );
      if (alreadyAlerted.rows.length > 0) continue;

      await sendFcmToVolunteer(vol.rows[0].fcm_token, {
        id: flag.id,
        urgency_level: 4,
        summary_1line: `⚠️ ${typeLabels[flag.type] || 'Chướng ngại vật'} — cách bạn ~${Math.round(flag.dist_m)}m`,
      });

      await db.query(
        'INSERT INTO volunteer_flag_alerts (volunteer_id, flag_id, alerted_at) VALUES ($1, $2, NOW())',
        [volunteerId, flag.id]
      );

      console.log(`[distanceTracker] Flag ${flag.id} proximity alert sent to TNV ${volunteerId}`);
    }
  } catch (err) {
    console.error('[distanceTracker][checkWarningFlagProximity]', err.message);
  }
}

module.exports = { onVolunteerLocationUpdate };
