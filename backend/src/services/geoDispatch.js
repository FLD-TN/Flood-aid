/**
 * Geo-Dispatch Service — Module 2 (Smart Radius)
 * 
 * Luồng dispatch FCM khi có ca SOS mới:
 *   Phút 0  → dispatchToSkillMatchedVolunteers (chỉ gửi TNV bật thông báo)
 *   Phút 2  → broadcastToAllVolunteers (chỉ gửi TNV bật thông báo)
 *   Phút 5  → forceBroadcastOrphanCase (BỎ QUA toggle, gửi hết trong 50km)
 *   Phút 15 → alertAdminOrphanCase (thông báo Admin)
 */

const { db } = require('../db');
const { sendFcmToVolunteer } = require('./fcmService');
const { emitCaseEvent } = require('../controllers/sseController');

// Thời gian chờ giữa các phase (ms)
const SKILL_MATCH_WAIT_MS = parseInt(process.env.SKILL_MATCH_WAIT_MS) || 2 * 60 * 1000;
const BROADCAST_WAIT_MS = parseInt(process.env.BROADCAST_WAIT_MS) || 5 * 60 * 1000;
const ORPHAN_ALERT_MS = parseInt(process.env.ORPHAN_ALERT_MS) || 15 * 60 * 1000;

// Bán kính tối đa cho Phase cưỡng chế (km) — dùng khi không ai nhận ca
const FORCE_BROADCAST_RADIUS_KM = parseInt(process.env.FORCE_BROADCAST_RADIUS_KM) || 50;

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

    // ── Phase 1 (Phút 0): Gửi cho TNV có skill phù hợp — TÔN TRỌNG radius cá nhân ──
    const skillMatchCount = await dispatchToSkillMatchedVolunteers(sosCase);
    console.log(`[geoDispatch] Case ${caseId}: ${skillMatchCount} skill-matched TNV notified (personal radius)`);

    // ── Phase 2 (Phút 2): Broadcast cho tất cả TNV — TÔN TRỌNG radius cá nhân ──
    setTimeout(async () => {
      try {
        const caseNow = await db.query('SELECT status FROM cases WHERE id = $1', [caseId]);
        if (caseNow.rows[0]?.status !== 'pending') return;
        const broadcastCount = await broadcastToAllVolunteers(sosCase);
        console.log(`[geoDispatch] Case ${caseId}: broadcast to ${broadcastCount} TNV (personal radius)`);
      } catch (err) {
        console.error('[geoDispatch] Broadcast error:', err.message);
      }
    }, SKILL_MATCH_WAIT_MS);

    // ── Phase 3 (Phút 5): CƯỠNG CHẾ — BỎ QUA radius cá nhân, gửi hết trong 50km ──
    setTimeout(async () => {
      try {
        const caseNow = await db.query('SELECT status FROM cases WHERE id = $1', [caseId]);
        if (caseNow.rows[0]?.status !== 'pending') return;
        const forceCount = await forceBroadcastOrphanCase(sosCase);
        console.log(`[geoDispatch] ⚠️ Case ${caseId}: FORCE broadcast to ${forceCount} TNV (${FORCE_BROADCAST_RADIUS_KM}km, override)`);
      } catch (err) {
        console.error('[geoDispatch] Force broadcast error:', err.message);
      }
    }, BROADCAST_WAIT_MS);

    // ── Phase 4 (Phút 15): Alert Admin — ca mồ côi ──
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
 * Phase 1: Tìm TNV có skill khớp — CHỈ GỬI cho TNV đã BẬT thông báo
 * 
 * Điều kiện lọc:
 *   - notification_radius_km IS NULL → BẬT (nhận thông báo)
 *   - notification_radius_km = 0     → TẮT (không nhận)
 */
async function dispatchToSkillMatchedVolunteers(sosCase) {
  const tags = typeof sosCase.tags === 'string' ? JSON.parse(sosCase.tags) : (sosCase.tags || []);

  // Chỉ ưu tiên skill-match khi ca có tag y_te
  if (!tags.includes('y_te')) return 0;

  const result = await db.query(`
    SELECT v.id, v.fcm_token, v.skills,
           ROUND(ST_Distance(v.current_coords::geography, $1::geography))::int AS distance_m
    FROM volunteers v
    WHERE v.is_available = true
      AND v.admin_approved = true
      AND v.current_coords IS NOT NULL
      AND v.skills ?| ARRAY['cpr', 'y_ta', 'bac_si']
      AND v.notification_radius_km IS NULL
    ORDER BY ST_Distance(v.current_coords::geography, $1::geography)
    LIMIT 10
  `, [sosCase.coords]);

  for (const vol of result.rows) {
    await sendFcmToVolunteer(vol.fcm_token, sosCase);
    console.log(`[geoDispatch] Sent to skill-matched TNV ${vol.id} (${vol.distance_m}m away)`);
  }
  return result.rows.length;
}

/**
 * Phase 2: Broadcast tất cả TNV — CHỈ GỬI cho TNV đã BẬT thông báo
 * Loại bỏ TNV đã nhận ca (case_assignments) để không spam trùng
 */
async function broadcastToAllVolunteers(sosCase) {
  const result = await db.query(`
    SELECT v.id, v.fcm_token,
           ROUND(ST_Distance(v.current_coords::geography, $2::geography))::int AS distance_m
    FROM volunteers v
    LEFT JOIN case_assignments ca ON ca.volunteer_id = v.id AND ca.case_id = $1
    WHERE v.is_available = true
      AND v.admin_approved = true
      AND v.current_coords IS NOT NULL
      AND ca.id IS NULL
      AND v.notification_radius_km IS NULL
    ORDER BY ST_Distance(v.current_coords::geography, $2::geography)
    LIMIT 50
  `, [sosCase.id, sosCase.coords]);

  for (const vol of result.rows) {
    await sendFcmToVolunteer(vol.fcm_token, sosCase);
  }
  return result.rows.length;
}

/**
 * Phase 3 (CƯỠNG CHẾ): Gửi cho TẤT CẢ TNV trong bán kính 50km
 * BỎ QUA hoàn toàn toggle thông báo — ca SOS đã 5 phút chưa ai nhận
 * 
 * FCM payload có title đặc biệt để TNV biết đây là ca khẩn cấp
 */
async function forceBroadcastOrphanCase(sosCase) {
  const result = await db.query(`
    SELECT v.id, v.fcm_token,
           ROUND(ST_Distance(v.current_coords::geography, $2::geography))::int AS distance_m
    FROM volunteers v
    LEFT JOIN case_assignments ca ON ca.volunteer_id = v.id AND ca.case_id = $1
    WHERE v.is_available = true
      AND v.admin_approved = true
      AND v.current_coords IS NOT NULL
      AND ca.id IS NULL
      AND ST_DWithin(
        v.current_coords::geography,
        $2::geography,
        $3
      )
    ORDER BY ST_Distance(v.current_coords::geography, $2::geography)
    LIMIT 50
  `, [sosCase.id, sosCase.coords, FORCE_BROADCAST_RADIUS_KM * 1000]);

  // Tạo payload đặc biệt cho ca cưỡng chế
  const URGENCY_EMOJI = { 1: '🔵', 2: '🟡', 3: '🟠', 4: '🔴', 5: '🆘' };
  const emoji = URGENCY_EMOJI[sosCase.urgency_level] || '🔴';

  for (const vol of result.rows) {
    const distText = vol.distance_m > 1000
      ? `${(vol.distance_m / 1000).toFixed(1)}km`
      : `${vol.distance_m}m`;

    // Override sosCase tạm để fcmService gửi title khẩn cấp
    const urgentCase = {
      ...sosCase,
      summary_1line: `⚠️ KHẨN CẤP: Nạn nhân cách bạn ${distText} chưa có ai cứu — đã ${Math.round(BROADCAST_WAIT_MS / 60000)} phút! ${sosCase.summary_1line}`,
    };
    await sendFcmToVolunteer(vol.fcm_token, urgentCase);
  }
  return result.rows.length;
}

async function alertAdminOrphanCase(caseId, urgencyLevel) {
  console.warn(`[geoDispatch] ⚠️ ORPHAN CASE: ${caseId}, urgency: ${urgencyLevel} — Admin cần can thiệp!`);
  
  // Emit SSE event to victim
  emitCaseEvent(caseId, 'case:orphaned', {
    caseId,
    urgencyLevel,
    status: 'orphaned',
  });
  
  // TODO: Gửi FCM cho Admin khi có Firebase Admin SDK
}

module.exports = { dispatchToNearbyVolunteers };
