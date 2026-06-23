# HỒ SƠ PROJECT FLOODAID — CONTEXT CHO VIẾT BÁO CÁO KLTN

> Hướng dẫn sử dụng: Copy TOÀN BỘ nội dung file này và paste vào đầu cuộc hội thoại với Claude trên Word.
> Sau đó yêu cầu Claude viết từng phần của báo cáo dựa trên context này.

---

## 1. THÔNG TIN ĐỀ TÀI

- **Tên đề tài:** Nghiên cứu và Xây dựng Nền tảng Hỗ trợ Điều phối Cứu trợ Lũ lụt tại Miền Trung dựa trên AI NLP
- **Chuyên ngành:** Công nghệ Phần mềm
- **Loại:** Khóa luận tốt nghiệp đại học
- **Phạm vi:** Ứng dụng Android (Flutter) cho Nạn nhân & TNV + Web Dashboard cho Admin + Backend Node.js

---

## 2. KIẾN TRÚC TỔNG THỂ

Hệ thống gồm 3 thành phần chính:

```
Mobile App (Flutter/Dart)  ──  Backend (Node.js/Express)  ──  PostgreSQL + PostGIS
       │ SSE, WebSocket              │ FCM                        │ Spatial Queries
Admin Web (React/Vite)     ──  Backend (REST polling)      ──  PostGIS (ST_DWithin)
```

Giao tiếp:
- REST API cho CRUD
- SSE (Server-Sent Events) cho push trạng thái ca SOS đến client
- WebSocket cho streaming GPS TNV thời gian thực đến Nạn nhân **VÀ** cho Chat In-App real-time
- FCM (Firebase Cloud Messaging) cho Push Notification
- Fallback: WebSocket → REST khi mất kết nối (áp dụng cho cả GPS lẫn Chat)

---

## 3. BA VAI TRÒ NGƯỜI DÙNG

### 3.1. Nạn nhân (Victim)
- Xác thực nhẹ qua OTP số điện thoại (Firebase Auth), đăng ký 1 lần trước mùa bão
- Nhấn SOS → Mở form: nhập text mô tả HOẶC nhấn giữ mic để dùng giọng nói (Speech-to-Text on-device) → Chọn vị trí GPS tự động hoặc kéo thả ghim thủ công → Gửi
- Chỉ text và metadata được gửi lên server, KHÔNG upload file audio
- Theo dõi ca trên bản đồ: Ping đỏ (vị trí mình) + Ping xanh (TNV đang đến, stream qua WebSocket)
- Trạng thái cập nhật liên tục: "Đang tìm..." → "Đã có người — cách 2.3km" → "Còn 300m, hãy ra hiệu!" → "Đã rất gần!"
- **Khi TNV đã nhận ca:** Hiển thị 2 nút liên lạc tròn bên dưới bản đồ:
  - **Nút xanh lá** (phone_in_talk): Gọi GSM trực tiếp đến TNV qua `tel://` scheme — số điện thoại TNV nhận từ SSE event `case:accepted` (field `volunteerPhone`)
  - **Nút xanh dương** (chat_bubble): Mở màn hình Chat In-App (ChatScreen) để nhắn tin với TNV
- Đóng ca bằng nút "Tôi đã được giúp đỡ" hoặc huỷ ca

### 3.2. Tình nguyện viên (TNV / Volunteer)
- Đăng ký eKYC: Chụp CCCD → FPT.AI nhận diện → Chụp selfie → FPT.AI FaceMatch (similarity ≥ 80%) → Chờ Admin duyệt
- Nhận Push Notification (FCM) khi có ca SOS gần, nội dung đã được AI tóm tắt 1 dòng
- Xem bản đồ SOS tổng thể, lọc theo mức độ/khoảng cách/tags, sắp xếp gần↔xa / mới↔cũ
- Nhận ca → GPS tracking adaptive → Di chuyển đến nạn nhân → Hoàn thành
- Quản lý bán kính thông báo (Smart Notification Radius): NULL = bật, 0 = tắt, số km = giới hạn
- **Khi đã nhận ca:** Hiển thị 3 nút liên lạc tròn trong mission board (DraggableScrollableSheet):
  - **Nút xanh lá** (phone_in_talk): Gọi GSM trực tiếp đến nạn nhân — số điện thoại nhận từ `result['victimPhone']` trong response của API `POST /case/:id/accept`
  - **Nút xanh dương** (chat_bubble): Mở màn hình Chat In-App (ChatScreen) để nhắn tin với nạn nhân
  - **Nút vàng** (directions): Mở Google Maps chỉ đường đến vị trí nạn nhân

### 3.3. Admin
- Web Dashboard (React + Leaflet/OpenStreetMap)
- Live Command Map: Hiển thị marker ca SOS + marker TNV, polling 15 giây
- Duyệt/từ chối hồ sơ TNV
- Cảnh báo ca mồ côi (15 phút không có TNV nhận, nhấp nháy đỏ)
- Thống kê tổng quan (stats panel)

---

## 4. NĂM MODULE HỆ THỐNG

### Module 1: Tiếp nhận & Xử lý AI (Core Ingestion & AI Pipeline)

**Parallel Race Pipeline** — xử lý text SOS:
- Nhánh A (Gemini 2.5 Flash API): Nhận text → trả JSON `{urgency_level: 1-5, tags: [], summary_1line}`. Timeout cứng 3 giây.
- Nhánh B (Rule-based Regex): Chạy song song, luôn có kết quả trong ~0.1ms. Quét từ khóa cứng:
  - URGENCY_KEYWORDS (5 cấp): Level 5 = ["máu", "bất tỉnh", "không thở", "chết", "chìm", "đuối nước"], Level 4 = ["trẻ em", "người già", "ngập nóc", "bị thương", "gãy", "cấp cứu"], Level 3 = ["ngập sâu", "kẹt", "mắc kẹt", "cô lập"], Level 2 = ["ngập", "cần xuồng", "cần giúp", "nước lên"]
  - TAG_KEYWORDS (5 nhóm): y_te, tre_em, nguoi_gia, ngap_noc, phuong_tien
- Merge: Dùng Gemini nếu có, Rule-based urgency làm baseline tối thiểu (Math.max), tags được union từ cả 2

**Dialect Normalizer** — chuẩn hóa phương ngữ miền Trung:
- Từ điển 26,000+ mục (`dialect_dict.json`), chạy trên client (Flutter/Dart)
- Thuật toán: Greedy longest-match (trigram → bigram → unigram)
- VD: "mô" → "đâu", "rứa" → "vậy", "chi" → "gì", "nờ" → "không", "bữa ni" → "hôm nay"
- Giữ nguyên viết hoa/thường gốc

**Speech-to-Text:** Android SpeechRecognizer (on-device, locale vi-VN), output text → Dialect Normalizer → gửi server

**Anti-spam:** 1 SĐT chỉ có 1 ca active tại 1 thời điểm

### Module 2: Không gian & Phát sóng (Geo-Dispatch)

Dispatch FCM theo 2 phase:
- **Phút 0 — Broadcast:** Gửi thông báo cho TẤT CẢ TNV đang bật thông báo (`notification_radius_km IS NULL`) và đang available (`is_available = true`, `admin_approved = true`, `current_coords IS NOT NULL`). Loại bỏ TNV đã được assign vào ca đó để tránh spam.
- **Phút 15 — Orphan Alert:** Nếu ca vẫn còn `pending` sau 15 phút → emit SSE `case:orphaned` đến nạn nhân + ghi log cảnh báo cho Admin.

> TNV tắt thông báo (`notification_radius_km = 0` hoặc khác NULL) sẽ không nhận FCM trong phase này.

Truy vấn không gian: `ST_DWithin(coords::geography, ..., radius_meters)` trên PostGIS

### Module 3: Xác thực & Theo dõi (Auth & Field Tracking)

**eKYC qua FPT.AI:**
- POST /api/kyc/recognize-id: Backend proxy ảnh CCCD (base64) → FPT.AI ID Recognition → trả số CCCD, họ tên, ngày sinh, giới tính, quê quán
- POST /api/kyc/check-face: Backend proxy cặp ảnh (CCCD + selfie) → FPT.AI FaceMatch → isMatch (≥80%), similarity (%)

**GPS Tracking Adaptive (3 chế độ):**
- Idle (chưa nhận ca): Tắt GPS hoàn toàn, dùng cached position
- Moving (đang đến nạn nhân): `distanceFilter: 30` (chỉ emit khi di chuyển >30m), `LocationAccuracy.balanced`, switch sang `high` khi <500m
- On-scene (<100m): `LocationAccuracy.low`, `distanceFilter: 100`

GPS stream qua WebSocket (`ws://host/ws/gps?role=volunteer&caseId=xxx&volunteerId=yyy`)
Android Foreground Service bắt buộc để GPS tracking không bị kill

### Module 4: Liên lạc Khẩn cấp (Emergency Communication) — Module mới

Được thêm vào nhằm giải quyết nhu cầu thực tế: GPS đến gần nạn nhân nhưng địa hình lũ lụt phức tạp khiến TNV không thể xác định vị trí chính xác — cần một kênh phối hợp nhanh.

**Chat In-App (WebSocket Real-time + REST Fallback):**
- Màn hình `ChatScreen` (Flutter, dùng chung cho cả 2 vai trò): constructor nhận `caseId`, `myRole` ('volunteer'|'victim'), `myId` (volunteerId nếu là TNV, null nếu là nạn nhân), `peerPhone`
- Kết nối WebSocket cùng endpoint GPS `/ws/gps` với query params `caseId`, `role`, `volunteerId`
- Message type `'chat'`: client gửi lên `{ type: 'chat', content: '...' }` → Server lưu vào bảng `chat_messages` → forward đến phía đối diện trong room → echo lại sender để confirm
- Optimistic UI: Tin nhắn hiển thị ngay khi gửi, không chờ server confirm, tránh duplicate khi nhận echo
- Fallback REST: Nếu WebSocket ngắt (`_wsConnected = false`) → tự động gọi `POST /api/case/:id/messages`
- Load lịch sử: `initState` gọi `GET /api/case/:id/messages` lấy 100 tin nhắn gần nhất
- Trạng thái kết nối hiển thị trong AppBar: chấm xanh "Real-time" / chấm xám "Offline"
- Bubble layout: tin của mình căn phải (màu primary xanh), tin đối phương căn trái (màu xám)
- Nút gọi điện nằm trong AppBar của ChatScreen nếu `peerPhone != null`
- **Xóa tin nhắn khi ca đóng:** Server gọi `DELETE FROM chat_messages WHERE case_id = $1` trong cả `resolveCase()` và `cancelCase()` — đảm bảo không tích lũy dữ liệu nhạy cảm sau khi ca kết thúc

**Gọi điện GSM (Direct Call):**
- Không dùng VoIP, không cần internet — mở ứng dụng điện thoại của thiết bị qua `url_launcher` với scheme `tel://`
- TNV gọi nạn nhân: SĐT lấy từ `result['victimPhone']` trong response `POST /case/:id/accept`
- Nạn nhân gọi TNV: SĐT lấy từ field `volunteerPhone` trong SSE event `case:accepted`
- Cả hai SĐT được mã hóa AES-256-GCM trong DB (`phone_encrypted`), chỉ giải mã tại thời điểm giao cho đúng người đúng ca

**Bảo mật SĐT:**
- SĐT lưu dạng hash (HMAC-SHA256, field `phone_hash`) cho mục đích tra cứu và anti-spam
- SĐT lưu dạng mã hóa AES-256-GCM (field `phone_encrypted`, key 32-byte từ env `PHONE_ENCRYPT_KEY`) cho mục đích gọi điện
- Utility `crypto.js` dùng chung: `encryptPhone()` và `decryptPhone()` — tránh duplicate code giữa volunteerController và sosController

### Module 5: Tự động hóa (Automation & Resolution)

**Distance Tracker:** Mỗi khi nhận GPS update từ TNV qua WebSocket → server tính `ST_Distance(TNV, NạnNhân)` → gửi FCM theo ngưỡng:
- <300m: FCM cho **TNV only** "Cách ~300m, chuẩn bị tiếp cận!" (chỉ 1 lần, flag `notif_sent_300m`)
- <100m: FCM cho **cả 2 bên** — TNV "Bạn đã đến nơi, hãy tìm nạn nhân" + nạn nhân "🟢 Người cứu hộ đã đến!" (flag `notif_sent_100m`); FCM token nạn nhân được query từ `victims.fcm_token` trước khi gửi; cập nhật status → `on_scene`

**Stale Assignment Checker (cron mỗi 2 phút):** TNV nhận ca >10 phút mà GPS không di chuyển (current_distance ≥ 90% initial_distance) → FCM hỏi "Bạn còn đang trên đường?" → 5 phút không phản hồi → huỷ assignment, mở lại ca

**Auto-Resolve:** Ca on_scene >60 phút + GPS TNV rời khu vực + nạn nhân không phản hồi → Alert Admin review

**Đóng ca (4 ưu tiên):**
1. Nạn nhân bấm "Tôi đã được giúp đỡ"
2. TNV bấm "Hoàn thành cứu hộ"
3. Admin đóng từ Dashboard
4. Auto-close (có điều kiện kép)

**Mission Recovery (khôi phục trạng thái khi mở lại app):**
Khi TNV mở app sau khi tắt giữa chừng, `volunteer_home_screen` gọi `GET /api/volunteers/:id/active-mission` → nếu còn ca đang `responding`/`on_scene` chưa hoàn thành → tự điều hướng về `ActiveMissionScreen` với đầy đủ thông tin ca. `ActiveMissionManager` (singleton) khôi phục trạng thái GPS tracking và WebSocket mà không cần accept lại.

**Lịch sử cứu hộ TNV:**
`GET /api/volunteers/:id/history` trả về 2 phần:
- `stats`: `{ total_missions, completed, revoked, total_distance_km, avg_response_time_min }` — thống kê tổng hợp toàn bộ lịch sử
- `missions`: danh sách 100 ca gần nhất, mỗi ca có `assignment_status` (completed/revoked/active), `initial_distance_m`, `response_time_min` (thời gian từ khi ca tạo đến khi TNV nhận)

**WebSocket Heartbeat:**
Server ping mỗi 30 giây đến tất cả client. Client phải pong lại; nếu không pong được trong chu kỳ tiếp theo → server terminate connection và dọn khỏi room. Đảm bảo room map không tích lũy socket chết.

### Module 6: Admin Dashboard (React.js + Vite)

Components: TopBar, Sidebar, StatsPanel, LiveCommandMap (Leaflet), CaseList, CaseDetailPanel, VolunteerManagement, VolunteerPanel

---

## 5. CƠ SỞ DỮ LIỆU (PostgreSQL + PostGIS)

### 6 bảng chính:

**victims:**
`id` (UUID PK), `phone_hash` (VARCHAR 64, UNIQUE), `firebase_uid` (VARCHAR 128, UNIQUE), `phone_encrypted` (TEXT), `fcm_token` (TEXT), `created_at` (TIMESTAMPTZ)

> `phone_encrypted`: SĐT mã hóa AES-256-GCM. Được upsert mỗi lần nạn nhân tạo SOS. Dùng để TNV đã được assign có thể gọi lại nạn nhân.
> `fcm_token`: FCM token của thiết bị nạn nhân. Được lưu khi nạn nhân gửi SOS (Flutter gọi `FirebaseMessaging.instance.getToken()` và truyền vào body). Dùng để server gửi push notification "Người cứu hộ đã đến!" khi TNV còn cách 100m.

**volunteers:**
`id` (UUID PK), `phone_hash` (UNIQUE), `firebase_uid` (UNIQUE), `full_name`, `cccd_verified` (BOOLEAN), `admin_approved` (BOOLEAN), `current_coords` (GEOMETRY POINT 4326), `last_seen_at` (TIMESTAMPTZ), `is_available` (BOOLEAN), `fcm_token` (TEXT), `phone_encrypted` (TEXT), `cccd_number_encrypted` (TEXT), `notification_radius_km` (INT), `created_at`, `updated_at`

> Lưu ý quan trọng: Cột `skills` (JSONB) và `flag_count` (INT) đã bị xóa hoàn toàn khỏi DB. Dispatch không còn phân loại theo skills. Tính năng cảnh báo flag TNV đã loại bỏ.

**cases:**
`id` (UUID PK), `phone_hash` (FK→victims.phone_hash), `coords` (GEOMETRY POINT 4326), `text_raw` (TEXT), `urgency_level` (SMALLINT 1-5), `tags` (JSONB), `summary_1line` (TEXT), `status` (ENUM: pending/responding/on_scene/resolved/cancelled/orphaned), `tnv_distance_m` (INT), `ai_source` (VARCHAR: 'gemini'/'rule_based'), `created_at`, `updated_at`, `resolved_at`

**case_assignments:**
`id` (UUID PK), `case_id` (FK→cases), `volunteer_id` (FK→volunteers), `initial_distance_m` (INT), `assigned_at`, `warned_at`, `confirmed_en_route` (BOOLEAN), `arrived_at`, `completed_at`, `revoked_at`, `notif_sent_300m` (BOOLEAN), `notif_sent_100m` (BOOLEAN), UNIQUE(case_id, volunteer_id)

**admins:**
`id` (UUID PK), `email` (UNIQUE), `firebase_uid` (UNIQUE), `full_name`, `created_at`

**chat_messages:** *(Bảng mới)*
`id` (UUID PK, DEFAULT uuid_generate_v4()), `case_id` (UUID, FK→cases.id ON DELETE CASCADE), `sender_role` (VARCHAR 10, CHECK IN ('volunteer','victim')), `sender_id` (UUID, nullable — volunteerId hoặc null nếu là nạn nhân), `content` (TEXT NOT NULL), `created_at` (TIMESTAMPTZ DEFAULT NOW())

> `chat_messages`: Lưu lịch sử tin nhắn chat trong một ca SOS. `ON DELETE CASCADE` đảm bảo tự xóa khi record `cases` bị xóa. Ngoài ra, code backend explicit `DELETE FROM chat_messages WHERE case_id = $1` trong `resolveCase()` và `cancelCase()` để dọn dẹp ngay lập tức khi ca đóng — không để lại dữ liệu nhạy cảm sau khi ca kết thúc.

### Extensions: PostGIS, uuid-ossp

### Indexes:
- GiST spatial index trên `cases.coords` và `volunteers.current_coords`
- Partial index trên `cases.status` WHERE status != 'resolved'
- Partial index trên `volunteers.is_available, admin_approved`
- Composite index `(case_id, created_at)` trên `chat_messages` — tối ưu truy vấn lịch sử chat theo thứ tự thời gian

### Views:
- `v_active_cases`: ca chưa resolved với `responding_count` (số TNV đang xử lý)
- `v_available_volunteers`: TNV khả dụng với tọa độ hiện tại (không có skills, không có flag_count)

---

## 6. DANH SÁCH API ENDPOINTS

### Auth & eKYC
- POST /api/auth/verify-phone (authMiddleware)
- POST /api/kyc/recognize-id (authMiddleware) → Proxy FPT.AI ID Recognition
- POST /api/kyc/check-face (authMiddleware) → Proxy FPT.AI FaceMatch

### SOS / Case
- POST /api/sos (authMiddleware) → Tạo ca SOS mới + AI Pipeline + Geo-Dispatch. Body: `{ text, lat, lon, phone, fcmToken? }`. Upsert `phone_encrypted` và `fcm_token` vào bảng `victims`
- GET /api/sos/active (authMiddleware) → Kiểm tra ca active theo SĐT
- GET /api/sos/history (authMiddleware) → Lịch sử SOS nạn nhân
- POST /api/sos/cancel (authMiddleware) → Nạn nhân huỷ ca + **xóa toàn bộ chat_messages của ca đó**
- GET /api/cases/nearby?lat=&lon=&maxDistance=&sortBy= → Danh sách ca gần TNV (có filter/sort)
- GET /api/case/:id → Thông tin ca SOS
- GET /api/case/:id/tnv-location → Nạn nhân polling vị trí TNV (fallback khi WebSocket chưa kết nối)
- GET /api/case/:id/stream → SSE stream trạng thái ca
- GET /api/case/:id/my-assignment?volunteerId= → TNV kiểm tra đã được assign chưa
- POST /api/case/:id/accept → TNV nhận ca → Response: `{ success, initialDistance, **victimPhone** }` (victimPhone là SĐT nạn nhân đã giải mã)
- POST /api/case/:id/resolve → Đóng ca + **xóa toàn bộ chat_messages của ca đó**
- POST /api/case/:id/revoke → TNV huỷ nhiệm vụ

### Chat In-App *(Endpoints mới)*
- GET /api/case/:id/messages → Lấy tối đa 100 tin nhắn gần nhất, sắp xếp theo `created_at ASC`. Dùng khi `ChatScreen` khởi tạo để load lịch sử.
- POST /api/case/:id/messages → REST fallback gửi tin nhắn. Body: `{ senderRole, content, senderId? }`. Server lưu vào DB và broadcast qua WebSocket đến room tương ứng.

### Volunteer
- POST /api/volunteers/register (authMiddleware) → Đăng ký TNV + lưu `phone_encrypted`
- GET /api/volunteers → Danh sách TNV
- GET /api/volunteers/locations → Tọa độ TNV (Admin map)
- PUT /api/volunteers/:id/approve → Admin duyệt
- PUT /api/volunteers/:id/availability → Bật/tắt trạng thái
- PUT /api/volunteers/:id/fcm-token → Cập nhật FCM token
- PUT /api/volunteers/:id/radius → Cập nhật bán kính thông báo
- GET /api/volunteers/:id/history → Lịch sử cứu hộ TNV
- GET /api/volunteers/:id/active-mission → Nhiệm vụ đang thực hiện

### Admin
- GET /api/admin/cases → Tất cả ca SOS
- GET /api/admin/stats → Thống kê dashboard
- GET /api/admin/case-clusters → Cụm ca SOS

### WebSocket (ws://host/ws/gps)

**Kết nối GPS (role=volunteer):**
- URL: `?role=volunteer&caseId=xxx&volunteerId=yyy`
- Gửi lên: `{ type: 'gps_update', lat, lon, timestamp }`

**Nhận GPS (role=victim):**
- URL: `?role=victim&caseId=xxx`
- Nhận về: `{ type: 'gps_update', lat, lon, distance_m }`

**Chat In-App (cả 2 role — cùng connection WebSocket trên):**
- Gửi lên: `{ type: 'chat', content: '...' }`
- Nhận về: `{ type: 'chat', senderRole, content, createdAt }`
- Server lưu vào `chat_messages`, forward đến phía đối diện trong room (theo `caseId`), echo lại sender để client confirm
- Cùng một WebSocket connection phục vụ cả GPS tracking lẫn Chat — phân biệt bằng field `type`

### SSE Events (GET /api/case/:id/stream)
- `case:accepted` → `{ volunteerId, initialDistance, status: 'responding', **volunteerPhone** }`
  > `volunteerPhone`: SĐT TNV đã giải mã — nạn nhân nhận để có thể gọi GSM
- `case:resolved` → `{ resolvedBy, status }`
- `case:cancelled` → `{ status }`
- `case:revoked` → `{ remainingCount, status }`
- `case:orphaned` → `{ status }`
- `case:on_scene` → `{ distance_m }`

---

## 7. CÔNG NGHỆ SỬ DỤNG

### Mobile (Flutter/Dart)
flutter (SDK ^3.11.0), firebase_core, firebase_auth, firebase_messaging, http, geolocator, shared_preferences, google_fonts, flutter_map, latlong2, url_launcher, web_socket_channel, speech_to_text, flutter_local_notifications, connectivity_plus, shimmer, lucide_icons, flutter_screenutil, image_picker, lottie, camera

### Backend (Node.js)
express, pg (PostgreSQL), ws (WebSocket), firebase-admin, @google/generative-ai (Gemini), cors, dotenv, helmet, morgan, express-rate-limit, node-cron, nodemon (dev)

### Admin Web (React)
react 19, react-dom, vite 8, leaflet, react-leaflet, axios, tailwindcss, autoprefixer, postcss

### External APIs
- Firebase Authentication (OTP)
- Firebase Cloud Messaging (Push Notification)
- Google Gemini 2.5 Flash API (AI NLP)
- FPT.AI ID Recognition API (eKYC CCCD)
- FPT.AI FaceMatch API (Xác thực khuôn mặt)
- OpenStreetMap (Bản đồ mã nguồn mở)

---

## 8. CẤU TRÚC THƯ MỤC

```
KLTN/
├── backend/                  # Node.js Backend
│   └── src/
│       ├── controllers/      # sosController, volunteerController, adminController,
│       │                     # authController, kycController, locationController,
│       │                     # chatController (mới — GET/POST /case/:id/messages)
│       ├── services/         # aiPipeline, geoDispatch, fcmService, firebaseAdmin, wsServer
│       │                     # wsServer xử lý cả GPS lẫn chat trong cùng WebSocket room
│       ├── jobs/             # autoResolve, distanceTracker, staleAssignmentChecker
│       ├── db/               # Database connection + migrations (12 migrations)
│       ├── middleware/       # Auth middleware (Firebase token verify)
│       ├── utils/            # crypto.js — AES-256-GCM encrypt/decrypt SĐT (dùng chung)
│       └── routes.js         # All API routes
│
├── mobile/                   # Flutter Mobile App
│   └── lib/
│       ├── screens/
│       │   ├── auth/         # phone_auth_screen, terms_screen
│       │   ├── victim/       # sos_screen, tracking_screen (có nút Chat + Gọi), location_picker,
│       │   │                 # sos_history, otp_verification
│       │   ├── volunteer/    # volunteer_home, active_mission_screen (có nút Chat + Gọi + Chỉ đường),
│       │   │                 # ekyc, face_verification, pending_approval, volunteer_history,
│       │   │                 # volunteer_registration
│       │   └── chat/         # chat_screen.dart — dùng chung cho cả TNV lẫn nạn nhân
│       ├── services/         # api_service (getChatMessages, sendChatMessage, acceptCase trả Map),
│       │                     # auth_service, fcm_service, sse_service, ws_gps_service,
│       │                     # dialect_normalizer, toast_service, event_bus,
│       │                     # active_mission_manager, local_notification
│       ├── widgets/          # map_widget, sos_legend_widget, slide_to_confirm
│       └── theme/            # AppColors, AppTypography
│
└── admin-web/                # React Admin Dashboard
    └── src/
        ├── components/       # LiveCommandMap, CaseList, CaseDetailPanel, Sidebar,
        │                     # TopBar, StatsPanel, VolunteerManagement, VolunteerPanel
        ├── api/              # API client
        └── hooks/            # Custom hooks
```

---

## 9. LUỒNG CHÍNH CỦA HỆ THỐNG

**Giai đoạn 1 — Tiếp nhận SOS:**
Nạn nhân mở app → OTP đã lưu, không cần đăng nhập → Nhấn SOS → Form: nhập text (hoặc giọng nói → STT → Dialect Normalizer) + chọn vị trí GPS → Gửi → Backend: hashPhone → anti-spam → Parallel Race Pipeline (Gemini ‖ Rule-based) → Lưu PostGIS (status: pending) + upsert `phone_encrypted` vào bảng `victims`

**Giai đoạn 2 — Điều phối:**
Geo-Dispatch: Broadcast FCM ngay (Phút 0) đến tất cả TNV đang available và bật thông báo → Nếu 15 phút không có TNV nhận → emit SSE `case:orphaned`

**Giai đoạn 3 — Cứu hộ:**
TNV nhận notification → Xem bản đồ → "Tôi sẽ đi cứu" → Case: pending→responding → GPS tracking (WebSocket stream) → Server giải mã `victims.phone_encrypted` → Response `acceptCase` trả `victimPhone` cho TNV → SSE `case:accepted` mang `volunteerPhone` đến nạn nhân → Nạn nhân thấy ping xanh di chuyển → Distance Tracker: 300m FCM cho TNV only, 100m FCM cho cả 2 (nạn nhân nhận "Người cứu hộ đã đến!") → TNV đến nơi, status → `on_scene`

**Giai đoạn 4 — Liên lạc trong ca:**
Sau khi ca ở trạng thái `responding`, cả hai bên đều thấy 2 nút liên lạc:
- **Chat:** Bấm nút xanh dương → ChatScreen kết nối WebSocket cùng room (caseId) → Nhắn tin real-time. Nếu mất WS → tự chuyển sang REST fallback. Lịch sử chat được load từ DB khi mở màn hình.
- **Gọi điện:** Bấm nút xanh lá → Mở app điện thoại với số đối phương → Gọi GSM trực tiếp, không cần internet.

**Giai đoạn 5 — Kết thúc:**
Nạn nhân/TNV/Admin đóng ca → Server: xóa `chat_messages` của ca đó → TNV giải phóng (is_available = true) → SSE thông báo tất cả bên liên quan → Ping biến khỏi bản đồ

---

## 10. GHI CHÚ QUAN TRỌNG CHO VIẾT BÁO CÁO

1. **Tên đề tài có "AI NLP" nhưng project chủ yếu dùng Rule-based.** Cách trình bày: Chương 2 khảo sát lý thuyết các mô hình NLP (Transformer, BERT, PhoBERT, LLM), sau đó lập luận tại sao chọn Rule-based cho bối cảnh thiên tai (nhanh, offline, deterministic). Gemini API là nhánh AI nâng cao khi có mạng.

2. **Speech-to-Text chạy on-device** (Android SpeechRecognizer), không upload audio. Dialect Normalizer chuẩn hóa phương ngữ miền Trung trước khi gửi text lên server.

3. **Hai kênh liên lạc song song — thiết kế có chủ đích:**
   - **Chat In-App (WebSocket):** Phối hợp chi tiết, điều phối vị trí, liên lạc không đồng bộ. Lịch sử lưu DB trong thời gian ca diễn ra, tự động xóa khi ca đóng.
   - **Gọi điện GSM:** Dự phòng khi 4G chập chờn, tình huống khẩn cấp cần liên lạc ngay, không phụ thuộc internet. Mở trực tiếp qua `tel://` scheme.
   - Lý do giữ cả hai: trong lũ lụt, mạng không ổn định. Chat cần 4G ổn định, GSM hoạt động ngay cả khi chỉ có sóng 2G.

4. **Adaptive GPS Strategy** tiết kiệm pin: từ ~3-4 tiếng lên ~7-10 tiếng hoạt động liên tục.

5. **PostGIS** được dùng cho toàn bộ spatial queries (ST_DWithin, ST_Distance), GiST index cho hiệu năng.

6. **REST fallback cho Chat** là điểm mạnh về độ tin cậy: nếu WebSocket ngắt, `ChatScreen` tự chuyển sang gọi `POST /api/case/:id/messages` — người dùng không thấy "Gửi thất bại".

7. **Geo-Dispatch đơn giản nhưng đủ dùng:** Chỉ 2 phase (Phút 0 broadcast, Phút 15 orphan alert) thay vì hệ thống phức tạp nhiều phase. Lý do: sau khi loại bỏ cột `skills`, không còn cơ sở để phân loại TNV theo kỹ năng; broadcast phẳng đến toàn bộ TNV khả dụng là đủ nhanh và đơn giản hơn để vận hành thực tế trong thiên tai.

8. **Migration idempotent (12 migrations):** Toàn bộ chạy lại an toàn mỗi lần server khởi động. Các view dùng `DROP VIEW IF EXISTS` + `CREATE VIEW` (không dùng `CREATE OR REPLACE`) do PostgreSQL không cho phép xóa cột khỏi view qua `CREATE OR REPLACE`. Mỗi migration phản ánh trạng thái schema cuối cùng — không tham chiếu cột đã bị migration sau xóa. Migration 012 thêm cột `fcm_token` vào bảng `victims`.

9. **Mã hóa SĐT (AES-256-GCM):** Cả volunteers và victims đều có `phone_encrypted`. Utility `crypto.js` dùng chung tránh duplicate code. SĐT chỉ được giải mã tại thời điểm cần giao cho đúng người đúng ca — không expose trong danh sách, không lưu trong log.

10. **ActiveMissionManager (Singleton Flutter):** TNV có thể pop khỏi màn hình ActiveMission mà GPS vẫn chạy ngầm qua Android Foreground Service — tương tự cơ chế Grab/Gojek. Khi navigate vào lại, màn hình khôi phục trạng thái từ Manager mà không cần gọi API.

11. **WebSocket room architecture:** Một room = một `caseId`. Room chứa tối đa 1 victim-socket + N volunteer-sockets. Cả GPS update lẫn Chat đều đi qua cùng WebSocket connection — phân biệt bằng field `type` trong JSON payload (`gps_update` / `chat` / `connected`). Server `chatController` và `wsServer` được tách biệt để tránh circular dependency khi lưu DB từ WebSocket handler.
