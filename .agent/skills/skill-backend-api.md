# skill-backend-api.md — Module 4: Automation & Background Jobs

> Đọc file này khi làm task liên quan đến: background jobs, auto-close TTL, distance tracking server-side, cờ cảnh báo proximity alert, TNV không di chuyển.

---

## Trách nhiệm

- Server-side distance tracking (không dùng Android Geofencing)
- Auto-close TTL với điều kiện triple-AND
- Hủy assignment khi TNV không di chuyển
- FCM proximity alerts (< 300m, < 100m) — mỗi ngưỡng chỉ gửi 1 lần
- Warning flag proximity alert (TNV vào trong 200m của cờ)

---

## Pattern: Distance Tracking Job

```js
// jobs/distanceTracker.js
// Chạy mỗi khi server nhận GPS update từ TNV

const { db } = require('../db');
const { sendFcmToVolunteer, sendFcmToVictim } = require('../services/fcmService');
const cron = require('node-cron');

/**
 * Gọi sau mỗi lần nhận POST /api/location từ TNV
 * Không cần cron job — trigger theo event GPS update
 */
async function onVolunteerLocationUpdate(volunteerId, newCoords) {
  // Tìm tất cả ca mà TNV này đang nhận (status = responding/on_scene)
  const assignments = await db.query(`
    SELECT 
      ca.case_id,
      ca.notif_sent_300m,
      ca.notif_sent_100m,
      c.coords AS victim_coords,
      c.status AS case_status,
      ST_Distance(
        $1::geography,
        c.coords::geography
      ) AS distance_m,
      v_victim.fcm_token AS victim_fcm,
      vol.fcm_token AS tnv_fcm
    FROM case_assignments ca
    JOIN cases c ON c.id = ca.case_id
    LEFT JOIN victims v_victim ON v_victim.phone_hash = c.phone_hash
    JOIN volunteers vol ON vol.id = ca.volunteer_id
    WHERE ca.volunteer_id = $2
      AND c.status IN ('responding', 'on_scene')
  `, [newCoords, volunteerId]);

  for (const row of assignments.rows) {
    const distM = Math.round(row.distance_m);

    // Cập nhật status text cho Nạn nhân (qua REST polling)
    await updateCaseDistanceCache(row.case_id, distM);

    // FCM ngưỡng 300m — chỉ gửi 1 lần
    if (distM < 300 && !row.notif_sent_300m) {
      await sendFcmToVictim(row.victim_fcm, {
        title: '🟠 Người cứu hộ sắp đến!',
        body: `Người cứu hộ còn cách bạn ~${distM}m, hãy ra hiệu!`,
        type: 'NEAR_300',
      });
      await sendFcmToVolunteer(row.tnv_fcm, {
        title: '🟠 Bạn sắp tới nơi',
        body: 'Còn ~300m, chuẩn bị tiếp cận nạn nhân!',
        type: 'NEAR_300',
      });
      await db.query(
        'UPDATE case_assignments SET notif_sent_300m = true WHERE case_id = $1 AND volunteer_id = $2',
        [row.case_id, volunteerId]
      );
    }

    // FCM ngưỡng 100m — chỉ gửi 1 lần
    if (distM < 100 && !row.notif_sent_100m) {
      await sendFcmToVictim(row.victim_fcm, {
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
    }
  }

  // Kiểm tra cờ cảnh báo trong 200m
  await checkWarningFlagProximity(volunteerId, newCoords);
}

async function updateCaseDistanceCache(caseId, distanceM) {
  await db.query(
    'UPDATE cases SET tnv_distance_m = $1 WHERE id = $2',
    [distanceM, caseId]
  );
}

module.exports = { onVolunteerLocationUpdate };
```

---

## Pattern: Warning Flag Proximity Check

```js
// jobs/distanceTracker.js (tiếp)

async function checkWarningFlagProximity(volunteerId, tnvCoords) {
  const WARNING_RADIUS_M = 200;

  const flags = await db.query(`
    SELECT 
      wf.id,
      wf.type,
      ST_Distance($1::geography, wf.coords::geography) AS dist_m
    FROM warning_flags wf
    WHERE wf.is_active = true
      AND ST_DWithin(wf.coords::geography, $1::geography, $2)
  `, [tnvCoords, WARNING_RADIUS_M]);

  if (flags.rows.length === 0) return;

  const vol = await db.query(
    'SELECT fcm_token FROM volunteers WHERE id = $1',
    [volunteerId]
  );
  if (!vol.rows[0]?.fcm_token) return;

  const typeLabels = {
    tree_down: 'Cây đổ chắn đường',
    bridge_collapsed: 'Cầu sập',
    flooded_road: 'Đường ngập sâu',
  };

  for (const flag of flags.rows) {
    // Chỉ cảnh báo lần đầu tiên vào vùng 200m (tránh spam khi đứng yên)
    const alreadyAlerted = await db.query(
      `SELECT 1 FROM volunteer_flag_alerts 
       WHERE volunteer_id = $1 AND flag_id = $2 AND alerted_at > NOW() - INTERVAL '30 minutes'`,
      [volunteerId, flag.id]
    );
    if (alreadyAlerted.rows.length > 0) continue;

    await sendFcmToVolunteer(vol.rows[0].fcm_token, {
      title: '⚠️ Cảnh báo nguy hiểm phía trước!',
      body: `${typeLabels[flag.type] || 'Chướng ngại vật'} — cách bạn ~${Math.round(flag.dist_m)}m`,
      type: 'WARNING_FLAG',
    });

    await db.query(
      'INSERT INTO volunteer_flag_alerts (volunteer_id, flag_id, alerted_at) VALUES ($1, $2, NOW())',
      [volunteerId, flag.id]
    );
  }
}
```

---

## Pattern: Auto-Close TTL (Điều kiện triple-AND)

```js
// jobs/autoResolve.js
// Cron: chạy mỗi 5 phút

const cron = require('node-cron');
const { db } = require('../db');

// Triple-AND conditions:
// 1. Đã qua 60 phút kể từ on_scene
// 2. TNV đã rời khỏi khu vực (GPS ra ngoài 200m)
// 3. Không có phản hồi từ cả 2 bên

cron.schedule('*/5 * * * *', async () => {
  try {
    // Tìm các ca cần review (không auto-close, chỉ alert Admin)
    const candidates = await db.query(`
      SELECT 
        c.id,
        c.urgency_level,
        ca.arrived_at,
        ST_Distance(vol.current_coords::geography, c.coords::geography) AS tnv_dist_m
      FROM cases c
      JOIN case_assignments ca ON ca.case_id = c.id AND ca.completed_at IS NULL
      JOIN volunteers vol ON vol.id = ca.volunteer_id
      WHERE c.status = 'on_scene'
        AND ca.arrived_at < NOW() - INTERVAL '60 minutes'
        AND ST_Distance(vol.current_coords::geography, c.coords::geography) > 200
      -- Điều kiện 2: TNV đã rời khu vực
    `);

    for (const row of candidates.rows) {
      // Không tự động đóng — alert Admin để review thủ công
      console.log(`[autoResolve] Orphan on_scene case: ${row.id}, alerting admin`);
      await alertAdminForReview(row.id, 'POSSIBLE_GHOST_SOS');
    }
  } catch (err) {
    console.error('[autoResolve] cron error:', err.message);
  }
});
```

---

## Pattern: TNV Không Di Chuyển Detection

```js
// jobs/staleAssignmentChecker.js
// Cron: chạy mỗi 2 phút

cron.schedule('*/2 * * * *', async () => {
  // TNV nhận ca > 10 phút mà GPS không di chuyển về phía nạn nhân
  const staleAssignments = await db.query(`
    SELECT 
      ca.volunteer_id,
      ca.case_id,
      vol.fcm_token,
      vol.current_coords,
      c.coords AS victim_coords,
      ca.assigned_at,
      ca.warned_at
    FROM case_assignments ca
    JOIN volunteers vol ON vol.id = ca.volunteer_id
    JOIN cases c ON c.id = ca.case_id
    WHERE c.status = 'responding'
      AND ca.assigned_at < NOW() - INTERVAL '10 minutes'
      AND ca.completed_at IS NULL
      AND ca.warned_at IS NULL
      -- TNV chưa di chuyển (GPS không gần hơn so với lúc nhận ca)
      AND ST_Distance(vol.current_coords::geography, c.coords::geography)
          >= ca.initial_distance_m * 0.9  -- vẫn còn >= 90% khoảng cách ban đầu
  `);

  for (const row of staleAssignments.rows) {
    // Gửi FCM hỏi TNV
    await sendFcmToVolunteer(row.fcm_token, {
      title: '❓ Bạn có còn đang trên đường không?',
      body: 'Nhấn để xác nhận bạn đang di chuyển đến nơi cứu hộ',
      type: 'CONFIRM_EN_ROUTE',
      data: { caseId: String(row.case_id) },
    });

    // Mark đã cảnh báo
    await db.query(
      'UPDATE case_assignments SET warned_at = NOW() WHERE case_id = $1 AND volunteer_id = $2',
      [row.case_id, row.volunteer_id]
    );

    // Sau 5 phút không phản hồi → hủy assignment
    setTimeout(async () => {
      const stillPending = await db.query(
        `SELECT 1 FROM case_assignments 
         WHERE case_id = $1 AND volunteer_id = $2 AND confirmed_en_route = false`,
        [row.case_id, row.volunteer_id]
      );
      if (stillPending.rows.length > 0) {
        await revokeAssignment(row.case_id, row.volunteer_id);
        await incrementFlagCount(row.volunteer_id);
      }
    }, 5 * 60 * 1000);
  }
});

async function revokeAssignment(caseId, volunteerId) {
  await db.query(
    `UPDATE case_assignments SET revoked_at = NOW() 
     WHERE case_id = $1 AND volunteer_id = $2`,
    [caseId, volunteerId]
  );
  await db.query(
    `UPDATE cases SET status = 'pending' 
     WHERE id = $1 AND status = 'responding'`,
    [caseId]
  );
  // Re-dispatch
  await require('../services/geoDispatch').dispatchToNearbyVolunteers(caseId);
}

async function incrementFlagCount(volunteerId) {
  await db.query(
    'UPDATE volunteers SET flag_count = flag_count + 1 WHERE id = $1',
    [volunteerId]
  );
}
```

---

## API Endpoint: POST /api/location

```js
// controllers/locationController.js

async function updateVolunteerLocation(req, res) {
  try {
    const { lat, lon } = req.body;
    const volunteerId = req.user.id; // từ Firebase Auth middleware

    const newCoords = `ST_SetSRID(ST_MakePoint(${lon}, ${lat}), 4326)`;

    await db.query(
      `UPDATE volunteers 
       SET current_coords = ${newCoords}, last_seen_at = NOW()
       WHERE id = $1`,
      [volunteerId]
    );

    // Trigger distance check (async — không block response)
    setImmediate(() =>
      require('../jobs/distanceTracker').onVolunteerLocationUpdate(
        volunteerId,
        `POINT(${lon} ${lat})`
      )
    );

    res.status(200).json({ ok: true });
  } catch (err) {
    console.error('[locationController]', err.message);
    res.status(500).json({ error: 'Internal error' });
  }
}
```
