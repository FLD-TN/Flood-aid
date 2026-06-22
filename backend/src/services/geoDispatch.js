/**
 * Geo-Dispatch Service — Module 2 (Smart Radius)
 * 
 * Luồng dispatch FCM khi có ca SOS mới:
 *   Phút 0  → broadcastToAllVolunteers (gửi TẤT CẢ TNV đang bật thông báo, không giới hạn khoảng cách)
 *   Phút 15 → alertAdminOrphanCase (thông báo Admin ca mồ côi)
 */

const { db } = require('../db');
const { sendFcmToVolunteer } = require('./fcmService');
const { emitCaseEvent } = require('../controllers/sseController');

// Thời gian chờ giữa các phase (ms)
const ORPHAN_ALERT_MS = parseInt(process.env.ORPHAN_ALERT_MS) || 15 * 60 * 1000;

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

    // ── Phase 1 (Phút 0): Broadcast cho TẤT CẢ TNV — TÔN TRỌNG radius cá nhân (Không giới hạn khoảng cách) ──
    const broadcastCount = await broadcastToAllVolunteers(sosCase);
    console.log(`[geoDispatch] Case ${caseId}: broadcast to ${broadcastCount} TNV (personal radius)`);

    // ── Phase 2 (Phút 15): Alert Admin — ca mồ côi ──
    setTimeout(async () => {
      try {
        const caseNow = await db.query('SELECT status FROM cases WHERE id = $1', [caseId]);
        if (caseNow.rows[0]?.status !== 'pending') return;
        await alertAdminOrphanCase(caseId, sosCase.urgency_level);
      } catch (err) {
        console.error('[geoDispatch] Orphan alert error:', err.message);
      }
    }, ORPHAN_ALERT_MS);

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


async function alertAdminOrphanCase(caseId, urgencyLevel) {
  console.warn(`[geoDispatch] ORPHAN CASE: ${caseId}, urgency: ${urgencyLevel} — Admin cần can thiệp!`);

  // Emit SSE event to victim
  emitCaseEvent(caseId, 'case:orphaned', {
    caseId,
    urgencyLevel,
    status: 'orphaned',
  });

  // TODO: Gửi FCM cho Admin khi có Firebase Admin SDK
}

module.exports = { dispatchToNearbyVolunteers };

