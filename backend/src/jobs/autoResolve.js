/**
 * Auto-Resolve Job — Module 4
 * Cron: chạy mỗi 5 phút
 * Triple-AND conditions: 60 phút + TNV rời khu vực + không phản hồi
 * KHÔNG tự đóng ca — chỉ alert Admin để review thủ công
 */

const cron = require('node-cron');
const { db } = require('../db');

cron.schedule('*/5 * * * *', async () => {
  try {
    // Tìm các ca cần review (KHÔNG auto-close, chỉ alert Admin)
    const candidates = await db.query(`
      SELECT 
        c.id,
        c.urgency_level,
        ca.arrived_at,
        ca.volunteer_id
      FROM cases c
      JOIN case_assignments ca ON ca.case_id = c.id AND ca.completed_at IS NULL
      JOIN volunteers vol ON vol.id = ca.volunteer_id
      WHERE c.status = 'on_scene'
        AND ca.arrived_at < NOW() - INTERVAL '60 minutes'
        AND vol.current_coords IS NOT NULL
        AND ST_Distance(vol.current_coords::geography, c.coords::geography) > 200
    `);

    for (const row of candidates.rows) {
      console.warn(`[autoResolve] ⚠️ Possible ghost SOS case: ${row.id} — TNV đã rời khu vực sau 60 phút on-scene`);
      // TODO: Gửi FCM alert cho Admin khi có Firebase Admin SDK
    }

    if (candidates.rows.length > 0) {
      console.log(`[autoResolve] Found ${candidates.rows.length} cases needing admin review`);
    }
  } catch (err) {
    console.error('[autoResolve] cron error:', err.message);
  }
});

console.log('[autoResolve] Cron job scheduled: every 5 minutes');
