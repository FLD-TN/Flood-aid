# RULES.md — Quy tắc bắt buộc cho AI Agent

> Đây là bộ quy tắc **bắt buộc** cho mọi task trong dự án FloodAid.
> Vi phạm bất kỳ quy tắc nào đều phải được xác nhận lại với developer trước khi tiếp tục.

---

## RULE-0: Đọc DESIGN.md trước

Trước khi làm bất kỳ task nào, AI Agent PHẢI:
1. Đọc `DESIGN.md` để hiểu kiến trúc tổng thể
2. Xác định task thuộc Module nào (1–5)
3. Đọc skill file tương ứng của Module đó
4. Chỉ sau đó mới bắt đầu viết code

---

## RULE-1: An toàn là ưu tiên số 1 (Safety-First)

```
TUYỆT ĐỐI KHÔNG:
  ✗ Hiển thị thông báo "Gửi thất bại" với Nạn nhân
  ✗ Tự động đóng ca mà không có xác nhận từ con người
  ✗ Bỏ qua offline queue — phải dùng WorkManager + SQLite
  ✗ Dùng GPS accuracy.high liên tục (hao pin)
  ✗ Broadcast FCM spam (mỗi ngưỡng distance chỉ gửi 1 lần)

LUÔN LUÔN:
  ✓ Hiển thị "Tín hiệu đã lưu, sẽ tự động gửi khi có sóng" khi mất mạng
  ✓ Có fallback Rule-based Regex khi Gemini API timeout
  ✓ Chạy Parallel Race Pipeline — không gọi Gemini tuần tự
  ✓ Đặt flag notifSent_300m và notifSent_100m để chống spam FCM
  ✓ Validate 1 SĐT = 1 SOS active tại server trước khi tạo ca mới
```

---

## RULE-2: Tech Stack — Không tự ý thay thế

### Backend (Node.js)
```
✓ Express.js — REST API framework
✓ pg + postgis — PostgreSQL client
✓ firebase-admin — FCM + Auth
✓ node-cron — Background jobs
✓ @google/generative-ai — Gemini SDK
✗ KHÔNG dùng Mongoose, KHÔNG dùng MySQL
✗ KHÔNG dùng socket.io — đã dùng polling + FCM
✗ KHÔNG dùng Android Geofencing — server-side distance only
```

### Flutter (Android only)
```
✓ speech_to_text — STT on-device
✓ geolocator — GPS
✓ connectivity_plus — Network detection
✓ workmanager — Background sync
✓ sqflite — Local SQLite queue
✓ firebase_messaging — FCM
✓ google_maps_flutter — Bản đồ
✗ KHÔNG upload audio file lên server
✗ KHÔNG có chat in-app
✗ KHÔNG build cho iOS trong dự án này
```

### Admin Dashboard (React)
```
✓ React.js + Vite
✓ Mapbox GL JS hoặc Leaflet + OpenStreetMap (FREE)
✓ Axios — HTTP client
✓ setInterval 15s — polling (không dùng WebSocket)
✗ KHÔNG dùng Google Maps (tốn phí)
```

---

## RULE-3: Naming Convention

### Database
```sql
-- Tên bảng: snake_case, số nhiều
cases, volunteers, case_assignments, warning_flags

-- Trạng thái case: lowercase enum string
'pending' | 'responding' | 'on_scene' | 'resolved'

-- Tag trong JSONB: snake_case tiếng Việt không dấu
'y_te' | 'tre_em' | 'nguoi_gia' | 'ngap_noc' | 'bat_tinh'
```

### API
```
-- RESTful, lowercase, dùng :id placeholder
POST /api/sos
GET  /api/case/:id/tnv-location
POST /api/case/:id/accept
POST /api/case/:id/resolve
POST /api/location
GET  /api/volunteers/locations
POST /api/flags
```

### Flutter / Dart
```dart
// Class: PascalCase
class SosPayloadModel {}
class AdaptiveGpsService {}

// File: snake_case
sos_screen.dart, adaptive_gps_service.dart

// Constant: SCREAMING_SNAKE
const CRITICAL_PAYLOAD_MAX_BYTES = 150;
const DISTANCE_FILTER_NORMAL_M = 30;
const DISTANCE_FILTER_ONSCENE_M = 100;
const GEOFENCE_NEAR_M = 300;
const GEOFENCE_ARRIVED_M = 100;
```

### Node.js
```js
// File: camelCase
sosController.js, geoDispatchService.js

// ENV: SCREAMING_SNAKE
GEMINI_TIMEOUT_MS, DATABASE_URL, FCM_SENDER_ID

// Function: camelCase
async function runParallelAiPipeline(text) {}
async function dispatchToNearbyVolunteers(caseId) {}
```

---

## RULE-4: Error Handling (Xử lý lỗi)

```js
// Backend: LUÔN có try-catch với logging rõ ràng
try {
  // ...
} catch (err) {
  console.error('[MODULE_NAME][FUNCTION_NAME]', err.message);
  // Không leak stack trace ra client trong production
  res.status(500).json({ error: 'Internal error' });
}

// Gemini timeout: LUÔN có Promise.race với fallback
const result = await Promise.race([
  callGeminiApi(text),
  new Promise((_, reject) =>
    setTimeout(() => reject(new Error('GEMINI_TIMEOUT')), 3000)
  )
]).catch(() => runRuleBasedFallback(text)); // fallback
```

---

## RULE-5: GPS & Location

```dart
// KHÔNG dùng LocationAccuracy.high trừ khi distance < 500m
// Thứ tự ưu tiên GPS accuracy:
// idle → cached | moving_far → balanced | near(<500m) → high

// LUÔN khởi động Foreground Service khi TNV nhận ca
// Không có Foreground Service = GPS chết sau 5 phút
AndroidForegroundServiceConfig(
  notificationChannelName: 'FloodAid Cứu hộ',
  notificationTitle: 'Đang cứu hộ — GPS đang hoạt động',
  notificationIcon: 'ic_rescue',
)
```

---

## RULE-6: Database & Spatial Queries

```sql
-- LUÔN dùng ST_DWithin thay vì tính distance thủ công
-- LUÔN index cột geometry
CREATE INDEX ON cases USING GIST(coords);
CREATE INDEX ON volunteers USING GIST(current_coords);

-- Clustering: dùng ST_ClusterDBSCAN
-- Radius 20m = 0.00018 degrees (approximate, đủ dùng)
SELECT ST_ClusterDBSCAN(coords, eps := 0.00018, minpoints := 1)
       OVER () AS cluster_id, *
FROM cases WHERE status = 'pending';

-- KHÔNG dùng lat/lon thô để tính distance trong Postgres
-- LUÔN dùng geography type hoặc ST_Distance
```

---

## RULE-7: FCM Notifications

```js
// Format notification cho TNV — AI summary làm body
{
  notification: {
    title: `[${urgencyEmoji}] SOS Mức ${urgencyLevel}`,
    body: summaryOneLine, // từ Gemini hoặc Rule-based
  },
  data: {
    caseId: case.id,
    urgencyLevel: String(case.urgency_level),
    lat: String(case.lat),
    lon: String(case.lon),
  },
  android: {
    priority: urgencyLevel >= 4 ? 'high' : 'normal',
  }
}

// CHỐNG SPAM: 1 TNV chỉ nhận 1 notification cho 1 ca
// Dùng bảng case_assignments.notif_sent để track
```

---

## RULE-8: Security

```
✓ Hash SĐT (SHA-256 + salt) trước khi lưu DB — không lưu SĐT thô
✓ Validate Firebase ID token ở mọi protected endpoint
✓ Rate limit POST /api/sos (max 1 active case / phone_hash)
✓ Admin endpoints phải check role = 'admin' trong JWT
✗ KHÔNG expose SĐT thô qua API (chỉ Admin mới xem được qua dashboard)
✗ KHÔNG log SĐT hoặc coords của nạn nhân vào console
```

---

## RULE-9: Testing

```
Với mỗi background job / service phức tạp, PHẢI viết unit test với mock data:
- Mock GPS coordinates cho TNV và Victim
- Mock Gemini response (timeout và success)
- Mock FCM send (verify đúng token, đúng payload)
- Test điều kiện triple-AND của auto-close TTL

Framework: Jest (Node.js), flutter_test (Dart)
```

---

## RULE-10: File Structure

```
backend/
├── src/
│   ├── controllers/      # Express route handlers
│   ├── services/         # Business logic
│   │   ├── aiPipeline.js
│   │   ├── geoDispatch.js
│   │   └── distanceTracker.js
│   ├── jobs/             # node-cron background jobs
│   │   ├── autoResolve.js
│   │   ├── orphanCaseAlert.js
│   │   └── flagProximityAlert.js
│   ├── middleware/        # auth, rate-limit
│   └── db/               # pg queries, migrations
└── tests/

mobile/                   # Flutter project
├── lib/
│   ├── screens/
│   ├── services/
│   │   ├── adaptive_gps_service.dart
│   │   ├── offline_queue_service.dart
│   │   └── foreground_service.dart
│   ├── models/
│   └── widgets/
└── test/

admin-web/                # React project
├── src/
│   ├── components/
│   │   ├── LiveCommandMap.jsx
│   │   └── CaseList.jsx
│   ├── hooks/
│   │   └── usePolling.js
│   └── api/
```
