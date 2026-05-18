# QUICKSTART.md — Hướng dẫn dùng AI Agent cho dự án FloodAid

## Cấu trúc file

```
flood-relief-agent/
├── DESIGN.md          ← Kiến trúc tổng thể — đọc TRƯỚC TIÊN
├── RULES.md           ← Quy tắc bắt buộc — AI Agent phải tuân theo
├── CONTEXT.md         ← Bối cảnh domain — lý do đằng sau các quyết định
├── QUICKSTART.md      ← File này
├── docs/
│   └── SCHEMA.md      ← SQL migrations đầy đủ
└── skills/
    ├── skill-ai-pipeline.md        ← Module 1: Gemini API, Rule-based, Offline Queue
    ├── skill-geospatial.md         ← Module 2: PostGIS, ST_DWithin, FCM Dispatch
    ├── skill-flutter-client.md     ← Module 3: Flutter, Adaptive GPS, Foreground Service
    ├── skill-backend-api.md        ← Module 4: Background Jobs, Auto-close, Distance Tracking
    └── skill-admin-dashboard.md    ← Module 5: React, Mapbox, Polling, Warning Flags
```

---

## Cách dùng với AI Agent (Cursor / Windsurf / Cline)

### Bước 1: Đặt file vào project

```
project-root/
├── .agent/               ← Tạo thư mục này
│   ├── DESIGN.md
│   ├── RULES.md
│   ├── CONTEXT.md
│   ├── docs/SCHEMA.md
│   └── skills/
│       ├── skill-ai-pipeline.md
│       ├── skill-geospatial.md
│       ├── skill-flutter-client.md
│       ├── skill-backend-api.md
│       └── skill-admin-dashboard.md
├── backend/
├── mobile/
└── admin-web/
```

### Bước 2: Cấu hình AI Agent

**Với Cursor** — tạo `.cursorrules` ở root:
```
Trước khi làm bất kỳ task nào trong dự án này:
1. Đọc .agent/DESIGN.md để hiểu kiến trúc
2. Đọc .agent/RULES.md để biết quy tắc bắt buộc
3. Xác định task thuộc Module nào, đọc skill file tương ứng trong .agent/skills/
4. Tuân thủ naming convention và tech stack đã định nghĩa
5. KHÔNG tự ý dùng tech ngoài danh sách trong RULES.md
```

**Với Windsurf** — tạo `.windsurfrules` tương tự nội dung trên.

**Với Cline** — thêm vào Custom Instructions trong settings.

**Với Claude Projects** — dán toàn bộ nội dung DESIGN.md + RULES.md vào Project Instructions.

### Bước 3: Prompt mẫu theo từng task

---

## Prompt Templates theo Module

### Module 1 — AI Pipeline

```
Task: Implement POST /api/sos endpoint

Context: Đọc .agent/skills/skill-ai-pipeline.md
Yêu cầu:
- Chạy Parallel Race Pipeline: Gemini API (timeout 3s) race với Rule-based Regex
- Gemini timeout → tự động fallback sang Rule-based, không throw error
- Anti-spam: từ chối nếu phone_hash đã có 1 ca active
- Sau khi lưu DB → trigger geoDispatch async (không block response)
- Response: { caseId, status: 'pending', aiSource: 'gemini'|'rule_based' }
```

### Module 2 — Geo Dispatch

```
Task: Implement geo dispatch sau khi tạo ca SOS

Context: Đọc .agent/skills/skill-geospatial.md
Yêu cầu:
- ST_DWithin bán kính 3km (không hardcode, lấy từ config)
- Ưu tiên gửi FCM cho TNV có skill khớp tags (y_te → CPR/y_ta/bac_si)
- Sau 2 phút không có người nhận → broadcast tất cả TNV trong bán kính
- Sau 5 phút → mở rộng lên 10km
- Sau 15 phút → alert Admin "ca mồ côi"
- Tất cả setTimeout chạy async, không block main flow
```

### Module 3 — Flutter GPS

```
Task: Implement AdaptiveGpsService cho TNV

Context: Đọc .agent/skills/skill-flutter-client.md
Yêu cầu:
- Chế độ Idle: tắt GPS stream, dùng getLastKnownPosition
- Chế độ Moving: distanceFilter=30m, accuracy=balanced (switch sang high khi <500m)
- Chế độ OnScene: distanceFilter=100m, accuracy=low
- Bắt buộc khởi động Foreground Service khi TNV nhận ca
- Không GPS accuracy.high liên tục (hao pin)
```

### Module 4 — Background Jobs

```
Task: Implement distance tracking và warning flag proximity

Context: Đọc .agent/skills/skill-backend-api.md
Yêu cầu:
- Trigger sau mỗi POST /api/location (không cần cron)
- FCM ngưỡng 300m và 100m: mỗi ngưỡng chỉ gửi 1 lần (notifSent flag)
- Warning flag: FCM khi TNV vào trong 200m, chống spam bằng volunteer_flag_alerts
- Auto-close: KHÔNG tự đóng, chỉ alert Admin để review thủ công
```

### Module 5 — Admin Dashboard

```
Task: Implement Live Command Map với Mapbox

Context: Đọc .agent/skills/skill-admin-dashboard.md
Yêu cầu:
- Polling 15s cho volunteer locations và case clusters
- Case cluster dùng ST_ClusterDBSCAN (bán kính 20m)
- Orphan case (>15 phút, 0 TNV): marker nhấp nháy đỏ
- Click marker TNV → popup có link "tel:" để gọi GSM trực tiếp
- Cắm cờ: click toolbar → click map → POST /api/flags
```

---

## Các lỗi phổ biến AI Agent hay mắc phải

| Lỗi | Đúng phải là |
|-----|-------------|
| Dùng WebSocket cho real-time | Dùng polling 15s + FCM |
| Upload audio lên server | Chỉ gửi text (client-side STT) |
| Android Geofencing API | Server-side distance calc |
| GPS accuracy.high liên tục | Adaptive: balanced → high chỉ khi <500m |
| Auto-close ca khi 60 phút | Chỉ alert Admin, không tự đóng |
| Chat in-app TNV↔Victim | GSM call (số điện thoại) |
| Socket.io realtime map | setInterval polling |
| Hiển thị "Gửi thất bại" | "Đã lưu, sẽ gửi khi có sóng" |
| Gọi Gemini tuần tự | Parallel.race với Rule-based |

---

## Thứ tự implement khuyến nghị

```
Sprint 1 (Core):
  1. DB migrations (SCHEMA.md)
  2. POST /api/sos + AI Pipeline (Module 1)
  3. Geo Dispatch + FCM (Module 2)

Sprint 2 (Mobile):
  4. Flutter SOS Screen + Offline Queue (Module 3)
  5. Adaptive GPS + Foreground Service (Module 3)
  6. Flutter Tracking Screen (Module 3)

Sprint 3 (Automation):
  7. Distance Tracking Job (Module 4)
  8. Auto-resolve TTL + Stale Assignment (Module 4)
  9. Warning Flag Proximity Alert (Module 4)

Sprint 4 (Admin):
  10. Live Command Map (Module 5)
  11. Orphan case alerts (Module 5)
  12. Warning flag UI (Module 5)
```
