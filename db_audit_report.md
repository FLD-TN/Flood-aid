# 📋 Database Audit Report — FloodAid

> **Đánh giá bởi:** Database Architect (AI Agent)
> **Schema source:** [migrations.js](file:///c:/Users/Admin/Desktop/KLTN/backend/src/db/migrations.js)
> **Business context:** [Y_tuong_KLTN.md](file:///c:/Users/Admin/Desktop/KLTN/Y_tuong_KLTN.md)
> **Ngày:** 2026-05-29

---

## ✅ Điểm tốt (Đang làm đúng)

| # | Hạng mục | Chi tiết |
|---|---------|---------|
| 1 | **UUID Primary Key** | Tất cả bảng dùng `uuid_generate_v4()` — phù hợp hệ thống phân tán, tránh enumeration attack |
| 2 | **PostGIS Geometry** | `coords GEOMETRY(POINT, 4326)` dùng đúng SRID 4326 (WGS84), kết hợp GIST index cho truy vấn không gian |
| 3 | **Partial Indexes** | `idx_cases_status WHERE status != 'resolved'` và `idx_volunteers_available WHERE is_available = true` — giảm kích thước index, tăng tốc truy vấn active records |
| 4 | **Composite Unique** | `UNIQUE(case_id, volunteer_id)` trên `case_assignments` ngăn TNV nhận trùng ca |
| 5 | **CHECK Constraint** | `urgency_level BETWEEN 1 AND 5` enforce business rule cứng |
| 6 | **Enum types** | `case_status`, `flag_type`, `user_role` dùng PostgreSQL ENUM — type-safe, lưu trữ compact |
| 7 | **TIMESTAMPTZ** | Tất cả timestamp dùng `WITH TIME ZONE` — đúng best practice cho hệ thống multi-timezone |
| 8 | **Views cho Dashboard** | `v_active_cases`, `v_available_volunteers` encapsulate logic phức tạp, dễ bảo trì |
| 9 | **JSONB cho tags/skills** | Linh hoạt, hỗ trợ GIN index nếu cần query |
| 10 | **Idempotent migrations** | Dùng `IF NOT EXISTS`, `CREATE OR REPLACE` — chạy lại an toàn |

---

## 🔴 Critical Issues (Cần sửa ngay)

| # | Bảng / Cột | Vấn đề | Đề xuất sửa |
|---|-----------|--------|-------------|
| C1 | `cases.phone_hash` | ✅ **ĐÃ SỬA:** **Thiếu Foreign Key → `victims`**. Cột `phone_hash` không có ràng buộc FK nào trỏ về bảng `victims`. Nếu bảng `victims` bị xóa/sửa, `cases` vẫn trỏ vào "bóng ma". Tuy nhiên lưu ý: victim có thể tạo SOS trước khi row victim được insert (nếu chưa có Firebase UID) → cần upsert victim trước khi insert case. | Thêm FK `REFERENCES victims(phone_hash)` **SAU KHI** đảm bảo luồng code luôn upsert victims trước. Hoặc chấp nhận loose coupling ở đây vì `phone_hash` chỉ là identifier, không phải PK của victims. |
| C2 | `warning_flags` | ✅ **ĐÃ SỬA:** Đã xoá toàn bộ tính năng `warning_flags` khỏi hệ thống (bao gồm CSDL, API, mobile app, cron job, và tài liệu Y_tuong_KLTN.md) theo yêu cầu. | Xoá toàn bộ. |
| C3 | `cases` | ✅ **ĐÃ SỬA:** Đã xoá hoàn toàn các biến `adults`, `children`, `elderly` khỏi luồng SOS của app Flutter và tài liệu Y_tuong_KLTN.md vì không còn cần thiết. | Loại bỏ khỏi app và tài liệu. |
| C4 | `volunteers` | ✅ **ĐÃ SỬA:** **Thiếu cột `phone` (SĐT gốc)**. Chỉ lưu `phone_hash` — Admin và TNV khác **không thể gọi GSM trực tiếp** cho TNV khi cần điều phối ngoại tuyến. Y_tuong_KLTN nhấn mạnh: "GSM là Primary channel", "Admin luôn có SĐT thật". Tuy nhiên, lưu trữ SĐT thật tạo ra vấn đề PII — cân nhắc encrypt at rest. | Thêm cột `phone_encrypted TEXT` (encrypt bằng AES-256 với key từ env) hoặc chấp nhận tradeoff bảo mật bằng cách thêm `phone VARCHAR(15)` trực tiếp nếu hệ thống nội bộ tin cậy. |
| C5 | `migrations.js` dòng 8-10 | ✅ **ĐÃ SỬA:** **Thiếu SSL config cho Render**. Pool connection không có `ssl: { rejectUnauthorized: false }`. Khi chạy migration trên cloud sẽ bị lỗi `SSL/TLS required` (giống lỗi bạn gặp hôm qua ở `db/index.js`). | Thêm tham số SSL tương tự `db/index.js` đã sửa. |

---

## 🟡 Moderate Issues (Nên sửa)

| # | Bảng / Cột | Vấn đề | Đề xuất sửa |
|---|-----------|--------|-------------|
| M1 | `cases` | ✅ **ĐÃ SỬA:** **Thiếu `updated_at`**. Chỉ có `created_at` và `resolved_at`. Khi status chuyển `pending → responding → on_scene`, không track được thời điểm thay đổi. | Thêm `updated_at TIMESTAMPTZ DEFAULT NOW()` trong migration005. |
| M2 | `volunteers` | ✅ **ĐÃ SỬA:** **Thiếu `updated_at`**. Khi Admin phê duyệt, khi TNV đổi availability — không trace được thời gian. | Thêm `updated_at TIMESTAMPTZ DEFAULT NOW()` trong migration005. |
| M3 | `case_assignments` | ✅ **ĐÃ SỬA:** **Thiếu index trên `assigned_at`**. Background job `autoResolve` và `staleAssignmentChecker` query các assignment theo thời gian nhưng không có index trên cột timestamp. | `CREATE INDEX idx_assignments_active_time ON case_assignments (assigned_at) WHERE completed_at IS NULL AND revoked_at IS NULL;` trong migration005. |
| M4 | `user_role` ENUM | **Khai báo nhưng không bảng nào sử dụng**. ENUM `user_role ('victim', 'volunteer', 'admin')` được tạo nhưng không có cột nào dùng nó. Gây confusion. | Xóa nếu không dùng, hoặc thêm cột `role user_role` vào bảng phù hợp. |
| M5 | `volunteer_flag_alerts` | ✅ **ĐÃ XOÁ:** Bảng đã bị xoá cùng với tính năng `warning_flags` trong C2. | Đã xoá trong migration004. |
| M6 | `cases.ai_source` | ✅ **ĐÃ SỬA:** **Thiếu CHECK constraint**. Giá trị hợp lệ chỉ là `'gemini'` hoặc `'regex'` (từ AI Pipeline), nhưng hiện cho phép nhập bất kỳ chuỗi nào. | `ALTER TABLE cases ADD CONSTRAINT chk_ai_source CHECK (ai_source IN ('gemini', 'regex'));` trong migration005. |

---

## 🟢 Suggestions (Cải tiến tùy chọn)

| # | Hạng mục | Đề xuất |
|---|---------|---------|
| S1 | **Table Partitioning cho `cases`** | Khi hệ thống chạy qua nhiều mùa bão, bảng `cases` sẽ grow rất lớn. Cân nhắc partition theo `created_at` (range partitioning theo tháng/quý) để query active cases nhanh hơn. |
| S2 | **GIN Index cho `tags` JSONB** | Nếu TNV thường xuyên lọc theo tags (`WHERE tags ?| ARRAY['y_te', 'tre_em']`), thêm GIN index sẽ cải thiện hiệu suất: `CREATE INDEX idx_cases_tags ON cases USING GIN(tags);` |
| S3 | **Materialized View cho Dashboard Stats** | Nếu Admin Dashboard cần thống kê tổng hợp (tổng ca theo ngày, urgency distribution...), dùng Materialized View + refresh cron 5 phút sẽ nhẹ hơn query trực tiếp. |
| S4 | **Bảng `audit_log`** | Để trace "ai đã làm gì, lúc nào" (Admin approve/reject TNV, Admin đóng ca thủ công...), cân nhắc thêm bảng audit log: `(id, actor_id, action, entity_type, entity_id, details JSONB, created_at)`. |
| S5 | **Connection Pooling** | Khi traffic tăng (nhiều TNV + nạn nhân cùng lúc trong bão), PostgreSQL mặc định chỉ chấp nhận 100 connections. Cân nhắc dùng PgBouncer hoặc tăng `max` trong Pool config. |

---

## 📝 Migration Scripts (Đã áp dụng)

Tất cả migration scripts đã được tích hợp vào [migrations.js](file:///c:/Users/Admin/Desktop/KLTN/backend/src/db/migrations.js):

| Migration | Nội dung | Issues |
|-----------|---------|--------|
| `migration004` | FK `cases.phone_hash → victims`, cột `phone_encrypted`, DROP `warning_flags`/`volunteer_flag_alerts`/`flag_type` | C1, C2, C4, M5 |
| `migration005` | `updated_at` cho `cases` & `volunteers`, index `assigned_at`, CHECK `ai_source` | M1, M2, M3, M6 |
| SSL config | Thêm `ssl: { rejectUnauthorized: false }` cho Render vào Pool constructor | C5 |

### Đã xoá hoàn toàn khỏi codebase (C2, C3):
- Tính năng `warning_flags` (DB, API routes, controllers, background jobs, mobile app, tài liệu)
- Tham số `adults`/`children`/`elderly` (Flutter sendSos, sos_screen, tài liệu)

---

## 📌 Trạng thái tổng hợp

| # | Vấn đề | Trạng thái |
|---|--------|-----------|
| C1 | FK `cases.phone_hash → victims` | ✅ Đã sửa (migration004) |
| C2 | Xoá `warning_flags` | ✅ Đã xoá toàn bộ |
| C3 | Xoá `adults/children/elderly` | ✅ Đã xoá toàn bộ |
| C4 | Thêm `phone_encrypted` (AES-256-GCM) | ✅ Đã sửa (migration004 + volunteerController) |
| C5 | SSL trong migrations.js | ✅ Đã sửa |
| M1 | `updated_at` cho `cases` | ✅ Đã sửa (migration005) |
| M2 | `updated_at` cho `volunteers` | ✅ Đã sửa (migration005) |
| M3 | Index `assigned_at` | ✅ Đã sửa (migration005) |
| M4 | `user_role` ENUM | ✅ **ĐÃ XOÁ:** ENUM không sử dụng đã bị drop. | Đã xoá trong migration005. |
| M5 | `volunteer_flag_alerts` PK rộng | ✅ Đã xoá cùng C2 |
| M6 | CHECK `ai_source` | ✅ Đã sửa (migration005) |

---

## 🔎 Business Logic Gaps (So sánh Schema vs Y_tuong_KLTN)

| Feature trong Y_tuong_KLTN | Trạng thái Schema | Ghi chú |
|---|---|---|
| eKYC CCCD cho TNV | ⚠️ Có cột `cccd_verified` | Thiếu cột lưu ảnh/metadata CCCD |
| Mở rộng bán kính động (2km → 5km → 10km) | ⚠️ Logic ở code | Không cần thêm cột DB — xử lý ở query |
| FCM Notification | ✅ Có `fcm_token` | Đúng |
| Ca mồ côi alert | ⚠️ Logic ở code | View `v_active_cases` có `minutes_waiting` hỗ trợ |
| TNV không di chuyển → hủy ca | ✅ `warned_at`, `confirmed_en_route`, `revoked_at` | Đủ cột, logic ở background job |
| Kênh GSM (SĐT thật) | ✅ `phone_encrypted` (AES-256-GCM) | Đã sửa trong C4 |
| Crowd-swarming (nhiều TNV / ca) | ✅ `case_assignments` N-N | Đúng |
| Auto-resolve triple-AND | ⚠️ Logic ở `autoResolve.js` | Cần `arrived_at` (đã có), distance check (ở code) |

