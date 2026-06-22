/**
 * Stale Assignment Checker — Module 4
 * Cron: chạy mỗi 2 phút
 * Phát hiện TNV nhận ca nhưng không di chuyển > 10 phút
 */

const cron = require('node-cron');
const { db } = require('../db');
const { sendFcmToVolunteer } = require('../services/fcmService');

cron.schedule('*/2 * * * *', async () => {
  try {
    // TNV nhận ca > 10 phút mà GPS không di chuyển về phía nạn nhân
    const staleAssignments = await db.query(`
      SELECT 
        ca.volunteer_id,
        ca.case_id,
        vol.fcm_token,
        ca.assigned_at,
        ca.warned_at,
        ca.initial_distance_m,
        ST_Distance(vol.current_coords::geography, c.coords::geography) AS current_distance
      FROM case_assignments ca
      JOIN volunteers vol ON vol.id = ca.volunteer_id
      JOIN cases c ON c.id = ca.case_id
      WHERE c.status = 'responding'
        AND ca.assigned_at < NOW() - INTERVAL '10 minutes'
        AND ca.completed_at IS NULL
        AND ca.revoked_at IS NULL
        AND ca.warned_at IS NULL
        AND vol.current_coords IS NOT NULL
        AND ca.initial_distance_m IS NOT NULL
        AND ST_Distance(vol.current_coords::geography, c.coords::geography) >= ca.initial_distance_m * 0.9
    `);

    for (const row of staleAssignments.rows) {
      // Gửi FCM hỏi TNV
      if (row.fcm_token) {
        await sendFcmToVolunteer(row.fcm_token, {
          id: row.case_id,
          urgency_level: 2,
          summary_1line: '❓ Bạn có còn đang trên đường không? Nhấn để xác nhận.',
        });
      }

      // Mark đã cảnh báo
      await db.query(
        'UPDATE case_assignments SET warned_at = NOW(), confirmed_en_route = false WHERE case_id = $1 AND volunteer_id = $2',
        [row.case_id, row.volunteer_id]
      );

      console.log(`[staleAssignment] TNV ${row.volunteer_id} warned for case ${row.case_id}`);

      // Sau 5 phút không phản hồi → hủy assignment
      setTimeout(async () => {
        try {
          const stillPending = await db.query(
            `SELECT 1 FROM case_assignments 
             WHERE case_id = $1 AND volunteer_id = $2 AND confirmed_en_route = false AND revoked_at IS NULL`,
            [row.case_id, row.volunteer_id]
          );

          if (stillPending.rows.length > 0) {
            // Hủy assignment
            await db.query(
              `UPDATE case_assignments SET revoked_at = NOW() 
               WHERE case_id = $1 AND volunteer_id = $2`,
              [row.case_id, row.volunteer_id]
            );

            // Mở lại ca
            await db.query(
              `UPDATE cases SET status = 'pending' 
               WHERE id = $1 AND status = 'responding'`,
              [row.case_id]
            );

            console.warn(`[staleAssignment] ⚠️ TNV ${row.volunteer_id} revoked from case ${row.case_id} due to inactivity`);

            // Re-dispatch
            setImmediate(() => {
              require('../services/geoDispatch').dispatchToNearbyVolunteers(row.case_id);
            });
          }
        } catch (err) {
          console.error('[staleAssignment] Revoke error:', err.message);
        }
      }, 5 * 60 * 1000);
    }
  } catch (err) {
    console.error('[staleAssignment] cron error:', err.message);
  }
});

console.log('[staleAssignment] Cron job scheduled: every 2 minutes');
