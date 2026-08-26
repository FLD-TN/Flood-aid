/**
 * Stale Assignment Checker — Module 4
 * Cron: chạy mỗi 2 phút
 *
 * Scan 1: Phát hiện TNV nhận ca nhưng không di chuyển > 10 phút → gửi cảnh báo
 * Scan 2: Phát hiện TNV đã cảnh báo nhưng không xác nhận trong 5 phút → hủy ca
 *         (dùng SQL thay vì setTimeout để không mất trạng thái khi server restart)
 */

const cron = require('node-cron');
const { db } = require('../db');
const { sendFcmToVolunteer } = require('../services/fcmService');
const { broadcastToRoom } = require('../services/wsServer');

cron.schedule('*/20 * * * * *', async () => {
  try {
    // ── Scan 1: Gửi cảnh báo đứng im ────────────────────────────────────────
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
        AND ca.assigned_at < NOW() - INTERVAL '30 seconds'
        AND ca.completed_at IS NULL
        AND ca.revoked_at IS NULL
        AND ca.warned_at IS NULL
        AND vol.current_coords IS NOT NULL
        AND ca.initial_distance_m IS NOT NULL
        AND ST_Distance(vol.current_coords::geography, c.coords::geography) >= ca.initial_distance_m * 0.9
    `);

    for (const row of staleAssignments.rows) {
      // Gửi FCM cảnh báo đứng im cho TNV (type = STALE_WARNING)
      if (row.fcm_token) {
        await sendFcmToVolunteer(row.fcm_token, {
          id: row.case_id,
          urgency_level: 2,
          summary_1line: '⚠️ Bạn có còn đang trên đường không? Nhấn để xác nhận.',
        }, 'STALE_WARNING');
      }

      // Phát sự kiện WebSocket để app hiện hộp thoại đếm ngược tức thì
      try {
        broadcastToRoom(row.case_id, {
          type: 'stale_warning',
          caseId: row.case_id,
          volunteerId: row.volunteer_id,
        });
      } catch (wsErr) {
        console.warn('[staleAssignment] WebSocket broadcast error:', wsErr.message);
      }

      // Mark đã cảnh báo
      await db.query(
        'UPDATE case_assignments SET warned_at = NOW(), confirmed_en_route = false WHERE case_id = $1 AND volunteer_id = $2',
        [row.case_id, row.volunteer_id]
      );

      console.log(`[staleAssignment] TNV ${row.volunteer_id} warned for case ${row.case_id}`);
    }

    // ── Scan 2: Hủy ca nếu TNV không phản hồi sau 5 phút kể từ warned_at ───
    const timedOutAssignments = await db.query(`
      SELECT ca.volunteer_id, ca.case_id, vol.fcm_token
      FROM case_assignments ca
      JOIN volunteers vol ON vol.id = ca.volunteer_id
      JOIN cases c ON c.id = ca.case_id
      WHERE ca.warned_at IS NOT NULL
        AND ca.warned_at < NOW() - INTERVAL '20 seconds'
        AND ca.confirmed_en_route = false
        AND ca.revoked_at IS NULL
        AND ca.completed_at IS NULL
        AND c.status = 'responding'
    `);

    for (const row of timedOutAssignments.rows) {
      // Hủy assignment
      await db.query(
        `UPDATE case_assignments SET revoked_at = NOW()
         WHERE case_id = $1 AND volunteer_id = $2`,
        [row.case_id, row.volunteer_id]
      );

      // Giải phóng TNV (đánh dấu available lại)
      await db.query(
        `UPDATE volunteers SET is_available = true WHERE id = $1`,
        [row.volunteer_id]
      );

      // Đếm xem còn TNV nào đang active cho ca này không
      const remaining = await db.query(
        `SELECT COUNT(*) AS cnt FROM case_assignments
         WHERE case_id = $1 AND revoked_at IS NULL AND completed_at IS NULL`,
        [row.case_id]
      );
      const remainingCount = parseInt(remaining.rows[0].cnt, 10);

      if (remainingCount === 0) {
        // Mở lại ca về pending vì không còn ai
        await db.query(
          `UPDATE cases SET status = 'pending'
           WHERE id = $1 AND status = 'responding'`,
          [row.case_id]
        );
      }

      console.warn(`[staleAssignment] ⚠️ TNV ${row.volunteer_id} auto-revoked from case ${row.case_id} (no response in 5 min). Remaining: ${remainingCount}`);

      // Broadcast qua WebSocket để Nạn nhân biết TNV đã bị hủy (ĐỒNG BỘ MÀN HÌNH NẠN NHÂN)
      try {
        broadcastToRoom(row.case_id, {
          type: 'case:revoked',
          volunteerId: row.volunteer_id,
          remainingCount,
          caseId: row.case_id,
        });
      } catch (wsErr) {
        console.warn('[staleAssignment] WebSocket case:revoked broadcast error:', wsErr.message);
      }

      // Re-dispatch
      setImmediate(() => {
        require('../services/geoDispatch').dispatchToNearbyVolunteers(row.case_id);
      });
    }

  } catch (err) {
    console.error('[staleAssignment] cron error:', err.message);
  }
});

console.log('[staleAssignment] Cron job scheduled: every 2 minutes');
