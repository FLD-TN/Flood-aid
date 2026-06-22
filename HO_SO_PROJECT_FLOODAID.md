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
Mobile App (Flutter/Dart)  ←→  Backend (Node.js/Express)  ←→  PostgreSQL + PostGIS
       ↕ SSE, WebSocket              ↕ FCM                        ↕ Spatial Queries
Admin Web (React/Vite)     ←→  Backend (REST polling)      ←→  PostGIS (ST_DWithin)
```

Giao tiếp:
- REST API cho CRUD
- SSE (Server-Sent Events) cho push trạng thái ca SOS đến client
- WebSocket cho streaming GPS TNV thời gian thực đến Nạn nhân
- FCM (Firebase Cloud Messaging) cho Push Notification
- Fallback: WebSocket → REST polling khi mất kết nối

---

## 3. BA VAI TRÒ NGƯỜI DÙNG

### 3.1. Nạn nhân (Victim)
- Xác thực nhẹ qua OTP số điện thoại (Firebase Auth), đăng ký 1 lần trước mùa bão
- Nhấn SOS → Mở form: nhập text mô tả HOẶC nhấn giữ mic để dùng giọng nói (Speech-to-Text on-device) → Chọn vị trí GPS tự động hoặc kéo thả ghim thủ công → Gửi
- Chỉ text và metadata được gửi lên server, KHÔNG upload file audio
- Theo dõi ca trên bản đồ: Ping đỏ (vị trí mình) + Ping xanh (TNV đang đến, stream qua WebSocket)
- Trạng thái cập nhật liên tục: "Đang tìm..." → "Đã có người — cách 2.3km" → "Còn 300m, hãy ra hiệu!" → "Đã rất gần!"
- Đóng ca bằng nút "Tôi đã được giúp đỡ" hoặc hủy ca

### 3.2. Tình nguyện viên (TNV / Volunteer)
- Đăng ký eKYC: Chụp CCCD → FPT.AI nhận diện → Chụp selfie → FPT.AI FaceMatch (similarity ≥ 80%) → Chờ Admin duyệt
- Khai báo kỹ năng tùy chọn: CPR, y tá, bác sĩ (lưu trong JSONB `skills`)
- Nhận Push Notification (FCM) khi có ca SOS gần, nội dung đã được AI tóm tắt 1 dòng
- Xem bản đồ SOS tổng thể, lọc theo mức độ/khoảng cách/tags, sắp xếp gần→xa / mới→cũ
- Nhận ca → GPS tracking adaptive → Di chuyển đến nạn nhân → Hoàn thành
- Quản lý bán kính thông báo (Smart Notification Radius): NULL = bật, 0 = tắt, số km = giới hạn
- Liên lạc qua GSM (gọi điện trực tiếp), không có chat in-app

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
- VD: "mô" → "đâu", "rứa" → "vậy", "chi" → "gì", "nỏ" → "không", "bữa ni" → "hôm nay"
- Giữ nguyên viết hoa/thường gốc

**Speech-to-Text:** Android SpeechRecognizer (on-device, locale vi-VN), output text → Dialect Normalizer → gửi server

**Dự phòng mạng:**
- Mạng ổn: gửi full payload
- Mạng yếu: Split Payload — Gói Khẩn cấp (< 150 bytes: phone_hash + tọa độ + timestamp) gửi trước, Gói Bổ sung (text + metadata) gửi sau
- Mất mạng: Lưu SQLite → WorkManager tự sync khi có sóng. Hiển thị "Tín hiệu đã lưu an toàn"

**Anti-spam:** 1 SĐT chỉ có 1 ca active tại 1 thời điểm

### Module 2: Không gian & Phát sóng (Geo-Dispatch)

Dispatch FCM theo 4 phase:
- Phút 0: Gửi cho TNV có skill phù hợp (VD: ca tag y_te → TNV có CPR), TÔN TRỌNG radius cá nhân
- Phút 2: Broadcast toàn bộ TNV bật thông báo, TÔN TRỌNG radius cá nhân
- Phút 5: CƯỠNG CHẾ — BỎ QUA radius, gửi hết TNV trong 50km, title đặc biệt "⚠️ KHẨN CẤP"
- Phút 15: Alert Admin "Ca mồ côi", emit SSE `case:orphaned`

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

### Module 4: Tự động hóa (Automation & Resolution)

**Distance Tracker:** Mỗi khi nhận GPS update từ TNV qua WebSocket → server tính `ST_Distance(TNV, NạnNhân)` → gửi FCM theo ngưỡng:
- <300m: FCM "Cách 300m, hãy ra hiệu!" (chỉ 1 lần, flag `notif_sent_300m`)
- <100m: FCM "Đã rất gần!", cập nhật status → `on_scene` (flag `notif_sent_100m`)

**Stale Assignment Checker (cron mỗi 2 phút):** TNV nhận ca >10 phút mà GPS không di chuyển (current_distance ≥ 90% initial_distance) → FCM hỏi "Bạn còn đang trên đường?" → 5 phút không phản hồi → hủy assignment, mở lại ca

**Auto-Resolve:** Ca on_scene >60 phút + GPS TNV rời khu vực + nạn nhân không phản hồi → Alert Admin review

**Đóng ca (4 ưu tiên):**
1. Nạn nhân bấm "Tôi đã được giúp đỡ"
2. TNV bấm "Hoàn thành cứu hộ"
3. Admin đóng từ Dashboard
4. Auto-close (có điều kiện kép)

### Module 5: Admin Dashboard (React.js + Vite)

Components: TopBar, Sidebar, StatsPanel, LiveCommandMap (Leaflet), CaseList, CaseDetailPanel, VolunteerManagement, VolunteerPanel

---

## 5. CƠ SỞ DỮ LIỆU (PostgreSQL + PostGIS)

### 5 bảng chính:

**victims:** id (UUID PK), phone_hash (UNIQUE), firebase_uid, created_at

**volunteers:** id (UUID PK), phone_hash (UNIQUE), firebase_uid, full_name, cccd_verified (BOOLEAN), admin_approved (BOOLEAN), skills (JSONB), current_coords (GEOMETRY POINT 4326), last_seen_at, is_available (BOOLEAN), fcm_token, phone_encrypted, cccd_number_encrypted, notification_radius_km (INT, NULL=bật, 0=tắt), created_at, updated_at

**cases:** id (UUID PK), phone_hash (FK→victims), coords (GEOMETRY POINT 4326), text_raw, urgency_level (1-5), tags (JSONB), summary_1line, status (ENUM: pending/responding/on_scene/resolved/cancelled/orphaned), tnv_distance_m, ai_source ('gemini'/'rule_based'), created_at, updated_at, resolved_at

**case_assignments:** id (UUID PK), case_id (FK→cases), volunteer_id (FK→volunteers), initial_distance_m, assigned_at, warned_at, confirmed_en_route (BOOLEAN), arrived_at, completed_at, revoked_at, notif_sent_300m (BOOLEAN), notif_sent_100m (BOOLEAN), UNIQUE(case_id, volunteer_id)

**admins:** id (UUID PK), email (UNIQUE), firebase_uid, full_name, created_at

### Extensions: PostGIS, uuid-ossp
### Index: GiST spatial index trên coords, partial index trên status và is_available
### Views: v_active_cases (ca chưa resolved + responding_count), v_available_volunteers (TNV khả dụng + tọa độ)

---

## 6. DANH SÁCH API ENDPOINTS

### Auth & eKYC
- POST /api/auth/verify-phone (authMiddleware)
- POST /api/kyc/recognize-id (authMiddleware) — Proxy FPT.AI ID Recognition
- POST /api/kyc/check-face (authMiddleware) — Proxy FPT.AI FaceMatch

### SOS / Case
- POST /api/sos (authMiddleware) — Tạo ca SOS mới + AI Pipeline + Geo-Dispatch
- GET /api/sos/active (authMiddleware) — Kiểm tra ca active theo SĐT
- GET /api/sos/history (authMiddleware) — Lịch sử SOS nạn nhân
- POST /api/sos/cancel (authMiddleware) — Nạn nhân hủy ca
- GET /api/cases/nearby?lat=&lon=&maxDistance=&sortBy= — Danh sách ca gần TNV (có filter/sort)
- GET /api/case/:id — Thông tin ca SOS
- GET /api/case/:id/tnv-location — Nạn nhân polling vị trí TNV
- GET /api/case/:id/stream — SSE stream trạng thái ca
- GET /api/case/:id/my-assignment?volunteerId= — TNV kiểm tra assignment
- POST /api/case/:id/accept — TNV nhận ca
- POST /api/case/:id/resolve — Đóng ca
- POST /api/case/:id/revoke — TNV hủy nhiệm vụ

### Volunteer
- POST /api/volunteers/register (authMiddleware) — Đăng ký TNV
- GET /api/volunteers — Danh sách TNV
- GET /api/volunteers/locations — Tọa độ TNV (Admin map)
- PUT /api/volunteers/:id/approve — Admin duyệt
- PUT /api/volunteers/:id/availability — Bật/tắt trạng thái
- PUT /api/volunteers/:id/fcm-token — Cập nhật FCM token
- PUT /api/volunteers/:id/radius — Cập nhật bán kính thông báo
- GET /api/volunteers/:id/history — Lịch sử cứu hộ TNV
- GET /api/volunteers/:id/active-mission — Nhiệm vụ đang thực hiện

### Admin
- GET /api/admin/cases — Tất cả ca SOS
- GET /api/admin/stats — Thống kê dashboard
- GET /api/admin/case-clusters — Cụm ca SOS

### WebSocket
- ws://host/ws/gps?role=volunteer&caseId=xxx&volunteerId=yyy
- ws://host/ws/gps?role=victim&caseId=xxx
- Message: { type: 'gps_update', lat, lon, timestamp }

### SSE Events
- case:accepted, case:resolved, case:cancelled, case:revoked, case:orphaned, case:on_scene

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
│       ├── controllers/      # 7 controllers (sos, volunteer, admin, auth, kyc, location, sse)
│       ├── services/         # 5 services (aiPipeline, geoDispatch, fcmService, firebaseAdmin, wsServer)
│       ├── jobs/             # 3 background jobs (autoResolve, distanceTracker, staleAssignmentChecker)
│       ├── db/               # Database connection + migrations (8 migrations)
│       ├── middleware/       # Auth middleware (Firebase token verify)
│       ├── routes.js         # All API routes
│       └── server.js         # Entry point
│
├── mobile/                   # Flutter Mobile App
│   └── lib/
│       ├── screens/
│       │   ├── auth/         # phone_auth_screen, terms_screen
│       │   ├── victim/       # sos_screen, tracking_screen, location_picker, sos_history, otp_verification
│       │   └── volunteer/    # volunteer_home, active_mission, ekyc, face_verification, pending_approval, volunteer_history, volunteer_registration
│       ├── services/         # 10 services (api, auth, fcm, sse, ws_gps, dialect_normalizer, toast, event_bus, active_mission_manager, local_notification)
│       ├── widgets/          # Reusable widgets
│       └── theme/            # App theme
│
├── admin-web/                # React Admin Dashboard
│   └── src/
│       ├── components/       # 8 components (LiveCommandMap, CaseList, CaseDetailPanel, Sidebar, TopBar, StatsPanel, VolunteerManagement, VolunteerPanel)
│       ├── api/              # API client
│       └── hooks/            # Custom hooks
│
├── Y_tuong_KLTN.md           # Tài liệu ý tưởng chi tiết
└── ĐỀ CƯƠNG KHÓA LUẬN TỐT NGHIỆP.docx
```

---

## 9. LUỒNG CHÍNH CỦA HỆ THỐNG

**Giai đoạn 1 — Tiếp nhận SOS:**
Nạn nhân mở app → OTP đã lưu, không cần đăng nhập → Nhấn SOS → Form: nhập text (hoặc giọng nói → STT → Dialect Normalizer) + chọn vị trí GPS → Gửi → Backend: hashPhone → anti-spam → Parallel Race Pipeline (Gemini || Rule-based) → Lưu PostGIS (status: pending)

**Giai đoạn 2 — Điều phối:**
Geo-Dispatch: ST_DWithin tìm TNV → Phase 1 skill-match → Phase 2 broadcast → Phase 3 force 50km → Phase 4 orphan alert

**Giai đoạn 3 — Cứu hộ:**
TNV nhận notification → Xem bản đồ → "Tôi sẽ đi cứu" → Case: pending→responding → GPS tracking (WebSocket stream) → Nạn nhân thấy ping xanh di chuyển → Distance Tracker: FCM 300m, 100m → TNV đến nơi

**Giai đoạn 4 — Kết thúc:**
Nạn nhân/TNV/Admin đóng ca → Case: resolved → Ping biến khỏi bản đồ → TNV giải phóng (is_available = true)

---

## 10. GHI CHÚ QUAN TRỌNG CHO VIẾT BÁO CÁO

1. **Tên đề tài có "AI NLP" nhưng project chủ yếu dùng Rule-based.** Cách trình bày: Chương 2 khảo sát lý thuyết các mô hình NLP (Transformer, BERT, PhoBERT, LLM), sau đó lập luận tại sao chọn Rule-based cho bối cảnh thiên tai (nhanh, offline, deterministic). Gemini API là nhánh AI nâng cao khi có mạng.

2. **Speech-to-Text chạy on-device** (Android SpeechRecognizer), không upload audio. Dialect Normalizer chuẩn hóa phương ngữ miền Trung trước khi gửi text lên server.

3. **Giao tiếp GSM** (gọi điện thoại trực tiếp) giữa TNV và Nạn nhân, không có chat in-app. Lý do: trong bão, nạn nhân không có thời gian chat, GSM tin cậy hơn khi 4G chập chờn.

4. **Adaptive GPS Strategy** tiết kiệm pin: từ ~3-4 tiếng lên ~7-10 tiếng hoạt động liên tục.

5. **PostGIS** được dùng cho toàn bộ spatial queries (ST_DWithin, ST_Distance), GiST index cho hiệu năng.

6. **Kiến trúc dự phòng mạng** là điểm mạnh: Split Payload + Offline Queue + WorkManager, không bao giờ hiển thị "Gửi thất bại".
