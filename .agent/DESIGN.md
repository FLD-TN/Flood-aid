# DESIGN.md — Nền tảng Hỗ trợ Điều phối Cứu trợ Lũ lụt

> **Đây là tài liệu gốc cho AI Agent.** Đọc file này TRƯỚC KHI làm bất kỳ task nào. Không suy diễn ngoài phạm vi đã định nghĩa ở đây.

---

## 1. Tổng quan hệ thống

**Tên dự án:** FloodAid — Nền tảng điều phối cứu trợ lũ lụt Miền Trung Việt Nam  
**Loại:** Mobile App (Flutter/Android) + Web Dashboard  
**Đối tượng triển khai:** Cơ quan Nhà nước / Tổ chức cứu trợ  

### Ba Actor chính
| Actor | Xác thực | Thiết bị |
|-------|-----------|----------|
| **Nạn nhân (Victim)** | OTP SMS một lần trước mùa bão | Android app |
| **Tình nguyện viên (TNV / Volunteer)** | eKYC CCCD + duyệt Admin (trước mùa bão) | Android app |
| **Admin** | Tài khoản tổ chức | Web browser |

---

## 2. Kiến trúc hệ thống

```
┌──────────────────────────────────────────────────────────────────┐
│                        CLIENT LAYER                              │
│  Flutter Android App (Victim + TNV)  │  React.js Web (Admin)    │
└─────────────────────┬────────────────────────────────────────────┘
                      │ HTTPS / FCM
┌─────────────────────▼────────────────────────────────────────────┐
│                        BACKEND LAYER                             │
│   Node.js + Express API Server                                   │
│   ├── REST API (main)                                            │
│   ├── Background Jobs (Node-cron)                                │
│   └── FCM Dispatcher (Firebase Admin SDK)                        │
└─────────────────────┬────────────────────────────────────────────┘
                      │
┌─────────────────────▼────────────────────────────────────────────┐
│                        DATA & SERVICES LAYER                     │
│  PostgreSQL + PostGIS  │  Firebase Auth  │  Gemini API           │
│  FPT eKYC API          │  FCM            │  OpenStreetMap        │
└──────────────────────────────────────────────────────────────────┘
```

---

## 3. Năm Module Cốt lõi

### Module 1 — Core Ingestion & AI (Tiếp nhận & Xử lý AI)
**Trách nhiệm:** Nhận SOS từ Nạn nhân, xử lý GPS cold start, chạy AI pipeline
- **Input:** Text + GPS từ Flutter client
- **Output:** Ca SOS được lưu DB với `urgency_level`, `tags[]`, `summary_1line`
- **Critical path:** Parallel Race Pipeline (Gemini API race với Rule-based Regex)
- **Skill file:** `skills/skill-ai-pipeline.md`

### Module 2 — Geo-Spatial & Dispatch (Không gian & Phát sóng)
**Trách nhiệm:** Cluster các ca SOS, tìm TNV gần nhất, gửi FCM
- **Input:** Ca SOS đã lưu PostGIS
- **Output:** Push notification đến TNV phù hợp
- **Critical path:** ST_DWithin query → skill-match → FCM broadcast
- **Skill file:** `skills/skill-geospatial.md`

### Module 3 — Auth & Field Tracking (Xác thực & Theo dõi hiện trường)
**Trách nhiệm:** Firebase Auth (OTP/eKYC), Adaptive GPS tracking TNV
- **Input:** GPS updates từ TNV app (distance-based trigger ≥30m)
- **Output:** Vị trí TNV cập nhật real-time trên DB
- **Critical path:** Foreground Service → GPS stream → POST /api/location
- **Skill file:** `skills/skill-flutter-client.md`

### Module 4 — Automation & Resolution (Tự động hóa & Đóng ca)
**Trách nhiệm:** Background jobs: distance tracking, auto-close TTL, cảnh báo cờ
- **Input:** GPS stream từ TNV, tọa độ cờ cảnh báo từ Admin
- **Output:** FCM ngưỡng tiếp cận, tự động đóng ca, cảnh báo chướng ngại vật
- **Critical path:** Server-side distance calc (không dùng Android Geofencing)
- **Skill file:** `skills/skill-backend-api.md`

### Module 5 — Admin Dashboard (Điều phối & Giám sát)
**Trách nhiệm:** Live Command Map, timeout alerts, cắm cờ cảnh báo tuyến đường
- **Input:** Polling 15s từ REST API
- **Output:** Web dashboard với Mapbox/Leaflet
- **Skill file:** `skills/skill-admin-dashboard.md`

---

## 4. Luồng dữ liệu chính (Happy Path)

```
1. Nạn nhân bấm SOS
      │
      ▼
2. Flutter: GPS warm-up (3 lớp) + nhập text/voice → text only lên server
      │
      ▼
3. Backend: Parallel Race Pipeline
   ├── Nhánh A: Gemini API (timeout 3s) → summary_1line, urgency, tags
   └── Nhánh B: Rule-based Regex (0.1s, luôn chạy làm baseline)
      │ (dùng kết quả nào về trước)
      ▼
4. Lưu PostGIS: SOS case { coords, urgency_level, tags[], summary_1line }
      │
      ▼
5. Geo-Dispatch: ST_DWithin(2-5km) → filter TNV có skill phù hợp → FCM
      │
      ▼
6. TNV nhận notification → bấm "Tôi sẽ đi cứu" → Foreground Service GPS ON
      │
      ▼
7. Server: mỗi GPS update → tính distance(TNV, Victim)
   ├── < 500m → update status text
   ├── < 300m → FCM cảnh báo
   └── < 100m → status "Rất gần"
      │
      ▼
8. Đóng ca: Victim bấm "Đã được giúp" | TNV bấm "Hoàn thành" | Auto-TTL
```

---

## 5. Database Schema (Các bảng chính)

```sql
-- Bảng cases (ca SOS)
cases {
  id, phone_hash, coords GEOMETRY(POINT,4326),
  urgency_level INT(1-5), tags JSONB, summary_1line TEXT,
  status ENUM(pending|responding|on_scene|resolved),
  created_at, resolved_at
}

-- Bảng volunteers
volunteers {
  id, phone_hash, cccd_verified BOOL, admin_approved BOOL,
  skills JSONB, -- ["cpr","y_ta","bac_si"]
  current_coords GEOMETRY(POINT,4326), last_seen_at,
  is_available BOOL, flag_count INT
}

-- Bảng case_assignments
case_assignments {
  case_id, volunteer_id,
  assigned_at, arrived_at, completed_at,
  notif_sent_300m BOOL, notif_sent_100m BOOL -- chống spam FCM
}

-- Bảng warning_flags (cờ cảnh báo tuyến đường)
warning_flags {
  id, coords GEOMETRY(POINT,4326),
  type ENUM(tree_down|bridge_collapsed|flooded_road),
  created_by_admin_id, is_active BOOL, created_at
}
```

---

## 6. API Endpoints Chính

```
POST /api/sos                    # Gửi SOS (Module 1)
GET  /api/case/:id/tnv-location  # Nạn nhân polling vị trí TNV (15s)
POST /api/case/:id/accept        # TNV nhận ca
POST /api/case/:id/resolve       # Đóng ca (victim/tnv/admin)
POST /api/location               # TNV POST GPS update
GET  /api/volunteers/locations   # Admin dashboard polling (15s)
POST /api/flags                  # Admin cắm cờ cảnh báo
GET  /api/flags                  # Lấy tất cả cờ (Bản đồ An toàn)
```

---

## 7. Quyết định kỹ thuật quan trọng (Không được thay đổi)

| # | Quyết định | Lý do |
|---|-----------|-------|
| 1 | Chỉ gửi TEXT lên server, không upload audio | Giảm bandwidth trong điều kiện mạng yếu |
| 2 | GSM là kênh liên lạc TNV↔Victim, không có chat in-app | GSM tin cậy hơn 4G khi thiên tai |
| 3 | Server-side distance calc, không dùng Android Geofencing | Testable, không race condition |
| 4 | Foreground Service bắt buộc khi TNV nhận ca | Android 8+ kill background GPS |
| 5 | Parallel Race Pipeline (AI + Regex đồng thời) | AI không bao giờ block hệ thống |
| 6 | Split Payload (< 150 bytes critical, enrichment sau) | Đảm bảo tọa độ gửi được khi mạng yếu |
| 7 | Mỗi SĐT chỉ có 1 SOS active | Anti-spam |
| 8 | Cluster bán kính 20m → 1 chấm bản đồ | Tránh nhiễu khi nhiều người cùng kêu cứu |

---

## 8. Môi trường & Cấu hình

```env
# Backend
NODE_ENV=production
DATABASE_URL=postgresql://...
GEMINI_API_KEY=...
FIREBASE_ADMIN_SDK=./firebase-service-account.json
FPT_EKYC_API_KEY=...
GEMINI_TIMEOUT_MS=3000

# Flutter
GOOGLE_MAPS_API_KEY=...
FCM_SENDER_ID=...
```
