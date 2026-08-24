/**
 * Distance Tracker — Module 4
 * Chạy mỗi khi server nhận GPS update từ TNV
 * Server-side distance calc (không dùng Android Geofencing)
 */

const { db } = require('../db');
const { sendFcmToVolunteer, sendFcmToVictim } = require('../services/fcmService');
const { routeEta } = require('../services/vietmap');

// Throttle gọi Route v4 để không cháy transaction: chỉ tính lại quãng đường/ETA thật
// khi TNV đã di chuyển > NGƯỠNG mét kể từ lần tính trước, HOẶC quá NGƯỠNG giây.
const ROUTE_MIN_MOVE_M = 150;
const ROUTE_MAX_AGE_SEC = 30;

/**
 * Gọi sau mỗi lần nhận POST /api/location từ TNV
 */
async function onVolunteerLocationUpdate(volunteerId, newCoordsWkt) {
  try {
    // lon/lat của TNV lấy từ WKT 'SRID=4326;POINT(lon lat)'
    const m = /POINT\(([-\d.]+)\s+([-\d.]+)\)/.exec(newCoordsWkt);
    const volLon = m ? parseFloat(m[1]) : null;
    const volLat = m ? parseFloat(m[2]) : null;

    // Tìm tất cả ca mà TNV này đang nhận
    const assignments = await db.query(`
      SELECT
        ca.case_id,
        ca.notif_sent_300m,
        ca.notif_sent_100m,
        c.status AS case_status,
        c.phone_hash AS victim_phone_hash,
        ST_Y(c.coords::geometry) AS victim_lat,
        ST_X(c.coords::geometry) AS victim_lon,
        ST_Distance(
          ST_GeomFromEWKT($1)::geography,
          c.coords::geography
        ) AS distance_m,
        -- Cần gọi lại Route? khi chưa từng tính, quá cũ, hoặc TNV đã đi > ngưỡng
        (
          c.route_updated_at IS NULL
          OR c.route_anchor IS NULL
          OR NOW() - c.route_updated_at > ($3 || ' seconds')::interval
          OR ST_Distance(c.route_anchor::geography, ST_GeomFromEWKT($1)::geography) > $4
        ) AS route_stale
      FROM case_assignments ca
      JOIN cases c ON c.id = ca.case_id
      WHERE ca.volunteer_id = $2
        AND ca.revoked_at IS NULL
        AND ca.completed_at IS NULL
        AND c.status IN ('responding', 'on_scene')
    `, [newCoordsWkt, volunteerId, ROUTE_MAX_AGE_SEC, ROUTE_MIN_MOVE_M]);

    for (const row of assignments.rows) {
      const distM = Math.round(row.distance_m);

      // Cập nhật distance cache (đường chim bay) cho polling
      await db.query(
        'UPDATE cases SET tnv_distance_m = $1 WHERE id = $2',
        [distM, row.case_id]
      );

      // Quãng đường + ETA THẬT theo đường đi (Route v4) — có throttle chống cháy transaction
      if (row.route_stale && volLat != null && volLon != null) {
        const route = await routeEta(volLat, volLon, row.victim_lat, row.victim_lon);
        if (route) {
          await db.query(
            `UPDATE cases
             SET tnv_route_distance_m = $1, tnv_eta_sec = $2,
                 route_updated_at = NOW(), route_anchor = ST_GeomFromEWKT($3)
             WHERE id = $4`,
            [route.distanceM, route.etaSec, newCoordsWkt, row.case_id]
          );
        }
      }

      // Lấy FCM tokens
      const vol = await db.query('SELECT fcm_token FROM volunteers WHERE id = $1', [volunteerId]);
      const tnvFcm = vol.rows[0]?.fcm_token;

      // FCM ngưỡng 300m — chỉ gửi cho TNV
      if (distM < 300 && !row.notif_sent_300m) {
        await sendFcmToVolunteer(tnvFcm, {
          id: row.case_id,
          urgency_level: 3,
          summary_1line: `Bạn sắp tới nơi! Còn khoảng${distM}m, chuẩn bị tiếp cận!`,
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
