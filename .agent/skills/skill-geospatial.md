# skill-geospatial.md — Module 2: Geo-Spatial & Dispatch

> Đọc file này khi làm task liên quan đến: PostGIS queries, ST_DWithin, clustering, FCM dispatch, bán kính mở rộng.

---

## Trách nhiệm

- Tìm TNV gần ca SOS trong bán kính (ST_DWithin)
- Cluster các ca gần nhau (ST_ClusterDBSCAN)
- Dispatch FCM theo thứ tự ưu tiên (skill-match trước, broadcast sau)
- Mở rộng bán kính tự động nếu không có TNV nhận

---

## Pattern: Geo Dispatch Service

```js
// services/geoDispatch.js

const { db } = require('../db');
const { sendFcmToVolunteer } = require('./fcmService');

const INITIAL_RADIUS_KM = 3;
const EXTENDED_RADIUS_KM = 10;
const SKILL_MATCH_WAIT_MS = 2 * 60 * 1000;   // 2 phút
const BROADCAST_WAIT_MS  = 5 * 60 * 1000;    // 5 phút
const ORPHAN_ALERT_MS    = 15 * 60 * 1000;   // 15 phút

/**
 * Main dispatch flow sau khi tạo ca SOS
 */
async function dispatchToNearbyVolunteers(caseId) {
  const caseRow = await db.query(
    'SELECT id, coords, urgency_level, tags, summary_1line FROM cases WHERE id = $1',
    [caseId]
  );
  if (!caseRow.rows.length) return;
  const sosCase = caseRow.rows[0];

  // Bước 1: Gửi cho TNV có skill phù hợp trước
  const skillMatchCount = await dispatchToSkillMatchedVolunteers(sosCase, INITIAL_RADIUS_KM);

  // Bước 2: Sau 2 phút, broadcast cho tất cả TNV trong bán kính
  setTimeout(async () => {
    const caseNow = await db.query('SELECT status FROM cases WHERE id = $1', [caseId]);
    if (caseNow.rows[0]?.status !== 'pending') return; // đã có người nhận
    await broadcastToAllVolunteers(sosCase, INITIAL_RADIUS_KM);
  }, SKILL_MATCH_WAIT_MS);

  // Bước 3: Sau 5 phút, mở rộng bán kính lên 10km
  setTimeout(async () => {
    const caseNow = await db.query('SELECT status FROM cases WHERE id = $1', [caseId]);
    if (caseNow.rows[0]?.status !== 'pending') return;
    await broadcastToAllVolunteers(sosCase, EXTENDED_RADIUS_KM);
  }, BROADCAST_WAIT_MS);

  // Bước 4: Sau 15 phút, alert "Ca mồ côi" cho Admin
  setTimeout(async () => {
    const caseNow = await db.query('SELECT status FROM cases WHERE id = $1', [caseId]);
    if (caseNow.rows[0]?.status !== 'pending') return;
    await alertAdminOrphanCase(caseId, sosCase.urgency_level);
  }, ORPHAN_ALERT_MS);
}

/**
 * Tìm TNV có skill khớp với tags của ca SOS
 */
async function dispatchToSkillMatchedVolunteers(sosCase, radiusKm) {
  const tags = JSON.parse(sosCase.tags || '[]');

  // Chỉ ưu tiên skill-match khi ca có tag y_te
  if (!tags.includes('y_te')) return 0;

  const result = await db.query(`
    SELECT v.id, v.fcm_token, v.skills
    FROM volunteers v
    WHERE v.is_available = true
      AND v.admin_approved = true
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
      AND ca.id IS NULL  -- chưa nhận notification về ca này
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
}

async function alertAdminOrphanCase(caseId, urgencyLevel) {
  // Gửi FCM cho tất cả admin tokens
  console.warn(`[geoDispatch] ORPHAN CASE: ${caseId}, urgency: ${urgencyLevel}`);
  // TODO: query admin FCM tokens và gửi alert
}

module.exports = { dispatchToNearbyVolunteers };
```

---

## Pattern: Clustering Query

```sql
-- Cluster các ca SOS pending gần nhau (bán kính 20m)
-- Dùng cho Admin Dashboard và Victim map

WITH clustered AS (
  SELECT 
    id,
    coords,
    summary_1line,
    urgency_level,
    status,
    ST_ClusterDBSCAN(coords, eps := 0.00018, minpoints := 1) 
      OVER () AS cluster_id
  FROM cases
  WHERE status = 'pending'
)
SELECT 
  cluster_id,
  COUNT(*) AS victim_count,
  MAX(urgency_level) AS max_urgency,
  ST_Centroid(ST_Collect(coords)) AS cluster_center,
  CASE 
    WHEN COUNT(*) = 1 THEN MAX(summary_1line)
    ELSE CONCAT('[KHẨN CẤP] Cụm nạn nhân: ~', COUNT(*), ' người tại khu vực này')
  END AS display_label
FROM clustered
GROUP BY cluster_id;
```

---

## Pattern: FCM Service

```js
// services/fcmService.js

const admin = require('firebase-admin');

const URGENCY_EMOJI = { 1: '🔵', 2: '🟡', 3: '🟠', 4: '🔴', 5: '🆘' };

async function sendFcmToVolunteer(fcmToken, sosCase) {
  if (!fcmToken) return;

  const emoji = URGENCY_EMOJI[sosCase.urgency_level] || '🔴';

  try {
    await admin.messaging().send({
      token: fcmToken,
      notification: {
        title: `${emoji} SOS Mức ${sosCase.urgency_level} — Cần cứu hộ ngay`,
        body: sosCase.summary_1line,
      },
      data: {
        caseId: String(sosCase.id),
        urgencyLevel: String(sosCase.urgency_level),
        // KHÔNG gửi coords trong FCM data — TNV xem từ app sau khi mở
        type: 'NEW_SOS',
      },
      android: {
        priority: sosCase.urgency_level >= 4 ? 'high' : 'normal',
        notification: {
          sound: sosCase.urgency_level >= 4 ? 'sos_alert' : 'default',
          channelId: 'sos_notifications',
        },
      },
    });
  } catch (err) {
    console.error('[fcmService] Send failed for token:', fcmToken.slice(0, 10), err.message);
    // Token invalid → mark volunteer fcm_token as null
    if (err.code === 'messaging/invalid-registration-token') {
      await require('../db').db.query(
        'UPDATE volunteers SET fcm_token = NULL WHERE fcm_token = $1',
        [fcmToken]
      );
    }
  }
}

module.exports = { sendFcmToVolunteer };
```

---

## Database Indexes bắt buộc

```sql
-- Chạy trong migration khi setup lần đầu
CREATE INDEX idx_cases_coords ON cases USING GIST(coords);
CREATE INDEX idx_cases_status ON cases (status) WHERE status != 'resolved';
CREATE INDEX idx_volunteers_coords ON volunteers USING GIST(current_coords);
CREATE INDEX idx_volunteers_available ON volunteers (is_available, admin_approved) 
  WHERE is_available = true AND admin_approved = true;
CREATE INDEX idx_warning_flags_coords ON warning_flags USING GIST(coords) 
  WHERE is_active = true;
```
