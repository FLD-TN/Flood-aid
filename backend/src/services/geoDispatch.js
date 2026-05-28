/**
 * Geo-Dispatch Service — Module 2
 * Tìm TNV gần nhất, dispatch FCM theo thứ tự ưu tiên skill-match
 */

const { db } = require('../db');
const { sendFcmToVolunteer } = require('./fcmService');
const { emitCaseEvent } = require('../controllers/sseController');

const INITIAL_RADIUS_KM = parseInt(process.env.INITIAL_RADIUS_KM) || 3;
const EXTENDED_RADIUS_KM = parseInt(process.env.EXTENDED_RADIUS_KM) || 10;
const SKILL_MATCH_WAIT_MS = parseInt(process.env.SKILL_MATCH_WAIT_MS) || 2 * 60 * 1000;
const BROADCAST_WAIT_MS = parseInt(process.env.BROADCAST_WAIT_MS) || 5 * 60 * 1000;
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

    // Bước 1: Gửi cho TNV có skill phù hợp trước
    const skillMatchCount = await dispatchToSkillMatchedVolunteers(sosCase, INITIAL_RADIUS_KM);
    console.log(`[geoDispatch] Case ${caseId}: ${skillMatchCount} skill-matched TNV notified`);

    // Bước 2: Sau 2 phút, broadcast cho tất cả TNV trong bán kính
    setTimeout(async () => {
      try {
        const caseNow = await db.query('SELECT status FROM cases WHERE id = $1', [caseId]);
        if (caseNow.rows[0]?.status !== 'pending') return;
        const broadcastCount = await broadcastToAllVolunteers(sosCase, INITIAL_RADIUS_KM);
        console.log(`[geoDispatch] Case ${caseId}: broadcast to ${broadcastCount} TNV (${INITIAL_RADIUS_KM}km)`);
      } catch (err) {
        console.error('[geoDispatch] Broadcast error:', err.message);
      }
    }, SKILL_MATCH_WAIT_MS);

    // Bước 3: Sau 5 phút, mở rộng bán kính lên 10km
    setTimeout(async () => {
      try {
        const caseNow = await db.query('SELECT status FROM cases WHERE id = $1', [caseId]);
        if (caseNow.rows[0]?.status !== 'pending') return;
        const extCount = await broadcastToAllVolunteers(sosCase, EXTENDED_RADIUS_KM);
        console.log(`[geoDispatch] Case ${caseId}: extended broadcast to ${extCount} TNV (${EXTENDED_RADIUS_KM}km)`);
      } catch (err) {
        console.error('[geoDispatch] Extended broadcast error:', err.message);
      }
    }, BROADCAST_WAIT_MS);

    // Bước 4: Sau 15 phút, alert "Ca mồ côi" cho Admin
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
 * Tìm TNV có skill khớp với tags của ca SOS
 */
async function dispatchToSkillMatchedVolunteers(sosCase, radiusKm) {
  const tags = typeof sosCase.tags === 'string' ? JSON.parse(sosCase.tags) : (sosCase.tags || []);

  // Chỉ ưu tiên skill-match khi ca có tag y_te
  if (!tags.includes('y_te')) return 0;

  const result = await db.query(`
    SELECT v.id, v.fcm_token, v.skills
    FROM volunteers v
    WHERE v.is_available = true
      AND v.admin_approved = true
      AND v.current_coords IS NOT NULL
      AND ST_DWithin(
        v.current_coords::geography,
        $1::geography,
        $2
      )
      AND v.skills ?| ARRAY['cpr', 'y_ta', 'bac_si']
    ORDER BY ST_Distance(v.current_coords::geography, $1::geography)
    LIMIT 10
  `, [sosCase.coords, radiusKm * 1000]);

  for (const vol of result.rows) {
    await sendFcmToVolunteer(vol.fcm_token, sosCase);
  }
  return result.rows.length;
}

/**
 * Broadcast toàn bộ TNV trong bán kính (không filter skill)
 */
async function broadcastToAllVolunteers(sosCase, radiusKm) {
  const result = await db.query(`
    SELECT v.id, v.fcm_token
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
  `, [sosCase.id, sosCase.coords, radiusKm * 1000]);

  for (const vol of result.rows) {
    await sendFcmToVolunteer(vol.fcm_token, sosCase);
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
