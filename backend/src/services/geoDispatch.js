/**
 * Geo-Dispatch Service — Module 2 (Smart Radius)
 *
 * Giai đoạn 1 (phút 0): broadcastToAllVolunteers — gửi thông báo cho TẤT CẢ TNV
 * đang bật nhận báo (không giới hạn khoảng cách; xem lý giải trong báo cáo).
 *
 * Giai đoạn 2 (ca mồ côi) KHÔNG còn nằm ở đây. Trước đây nó dùng setTimeout, tức
 * bộ hẹn giờ trong bộ nhớ tiến trình — mất trắng khi máy chủ khởi động lại. Nay
 * việc phát hiện ca mồ côi do jobs/orphanCaseChecker.js đảm nhiệm: quét CSDL định
 * kỳ theo cases.created_at và đánh dấu cases.orphan_alerted_at.
 */

const { db } = require('../db');
const { sendFcmToVolunteer } = require('./fcmService');

/**
 * Main dispatch flow sau khi tạo ca SOS
 */
async function dispatchToNearbyVolunteers(caseId) {
  try {
    const caseRow = await db.query(
      'SELECT id, coords, urgency_level, tags, summary_1line FROM cases WHERE id = $1',
      [caseId]
    );
    if (!caseRow.rows.length) return;
    const sosCase = caseRow.rows[0];

    // ── Giai đoạn 1 (phút 0): Broadcast cho TNV đang bật nhận thông báo ──
    const broadcastCount = await broadcastToAllVolunteers(sosCase);
    console.log(`[geoDispatch] Case ${caseId}: broadcast to ${broadcastCount} TNV (personal radius)`);

    // ── Giai đoạn 2 (ca mồ côi): do jobs/orphanCaseChecker.js quét định kỳ từ CSDL ──

  } catch (err) {
    console.error('[geoDispatch][dispatchToNearbyVolunteers]', err.message);
  }
}

/**
 * Phase 1: Broadcast tất cả TNV — CHỈ GỬI cho TNV đã BẬT thông báo
 * Loại bỏ TNV đã nhận ca (case_assignments) để không spam trùng
 */
async function broadcastToAllVolunteers(sosCase) {
  const result = await db.query(`
    SELECT v.id, v.fcm_token
    FROM volunteers v
    LEFT JOIN case_assignments ca ON ca.volunteer_id = v.id AND ca.case_id = $1
    WHERE v.is_available = true
      AND v.admin_approved = true
      AND v.current_coords IS NOT NULL
      AND ca.id IS NULL
      AND v.notification_radius_km IS NULL
  `, [sosCase.id]);

  for (const vol of result.rows) {
    await sendFcmToVolunteer(vol.fcm_token, sosCase);
  }
  return result.rows.length;
}


module.exports = { dispatchToNearbyVolunteers };

