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
| C1 | `cases.phone_hash` | **Thiếu Foreign Key → `victims`**. Cột `phone_hash` không có ràng buộc FK nào trỏ về bảng `victims`. Nếu bảng `victims` bị xóa/sửa, `cases` vẫn trỏ vào "bóng ma". Tuy nhiên lưu ý: victim có thể tạo SOS trước khi row victim được insert (nếu chưa có Firebase UID) → cần upsert victim trước khi insert case. | Thêm FK `REFERENCES victims(phone_hash)` **SAU KHI** đảm bảo luồng code luôn upsert victims trước. Hoặc chấp nhận loose coupling ở đây vì `phone_hash` chỉ là identifier, không phải PK của victims. |
| C2 | `warning_flags.created_by` | **FK treo — không rõ REFERENCES bảng nào**. Cột `created_by UUID NOT NULL` không có REFERENCES. Theo Y_tuong_KLTN, cờ cảnh báo do Admin tạo → nên FK đến `admins(id)`. Hiện tại, bất kỳ UUID giả nào cũng được chấp nhận. | `ALTER TABLE warning_flags ADD CONSTRAINT fk_flags_admin FOREIGN KEY (created_by) REFERENCES admins(id);` |
| C3 | `cases` | **Thiếu cột `adults`, `children`, `elderly`**. Theo Y_tuong_KLTN: "Nạn nhân nhập số lượng người (người lớn, trẻ em, người già)". Hiện tại migrations KHÔNG có 3 cột này. API `sendSos` trong app Flutter gửi `adults`, `children`, `elderly` lên server, nhưng backend `sosController.js` không đọc và không lưu chúng → **dữ liệu bị mất hoàn toàn**. | Thêm 3 cột: `adults SMALLINT DEFAULT 0`, `children SMALLINT DEFAULT 0`, `elderly SMALLINT DEFAULT 0`. Cập nhật sosController để INSERT 3 giá trị này. |
| C4 | `volunteers` | **Thiếu cột `phone` (SĐT gốc)**. Chỉ lưu `phone_hash` — Admin và TNV khác **không thể gọi GSM trực tiếp** cho TNV khi cần điều phối ngoại tuyến. Y_tuong_KLTN nhấn mạnh: "GSM là Primary channel", "Admin luôn có SĐT thật". Tuy nhiên, lưu trữ SĐT thật tạo ra vấn đề PII — cân nhắc encrypt at rest. | Thêm cột `phone_encrypted TEXT` (encrypt bằng AES-256 với key từ env) hoặc chấp nhận tradeoff bảo mật bằng cách thêm `phone VARCHAR(15)` trực tiếp nếu hệ thống nội bộ tin cậy. |
| C5 | `migrations.js` dòng 8-10 | **Thiếu SSL config cho Render**. Pool connection không có `ssl: { rejectUnauthorized: false }`. Khi chạy migration trên cloud sẽ bị lỗi `SSL/TLS required` (giống lỗi bạn gặp hôm qua ở `db/index.js`). | Thêm tham số SSL tương tự `db/index.js` đã sửa. |

---

## 🟡 Moderate Issues (Nên sửa)

| # | Bảng / Cột | Vấn đề | Đề xuất sửa |
|---|-----------|--------|-------------|
| M1 | `cases` | **Thiếu `updated_at`**. Chỉ có `created_at` và `resolved_at`. Khi status chuyển `pending → responding → on_scene`, không track được thời điểm thay đổi. | Thêm `updated_at TIMESTAMPTZ DEFAULT NOW()` + trigger hoặc update thủ công khi đổi status. |
| M2 | `volunteers` | **Thiếu `updated_at`**. Khi Admin phê duyệt, khi TNV đổi availability — không trace được thời gian. | Thêm `updated_at TIMESTAMPTZ DEFAULT NOW()`. |
| M3 | `case_assignments` | **Thiếu index trên `assigned_at`**. Background job `autoResolve` và `staleAssignmentChecker` query các assignment theo thời gian nhưng không có index trên cột timestamp. | `CREATE INDEX idx_assignments_assigned_at ON case_assignments (assigned_at) WHERE completed_at IS NULL AND revoked_at IS NULL;` |
| M4 | `user_role` ENUM | **Khai báo nhưng không bảng nào sử dụng**. ENUM `user_role ('victim', 'volunteer', 'admin')` được tạo nhưng không có cột nào dùng nó. Gây confusion. | Xóa nếu không dùng, hoặc thêm cột `role user_role` vào bảng phù hợp. |
| M5 | `volunteer_flag_alerts` | **PK quá rộng** — `PRIMARY KEY (volunteer_id, flag_id, alerted_at)`. `alerted_at` là `TIMESTAMPTZ DEFAULT NOW()` — 2 alert cho cùng 1 cờ trong cùng 1 giây sẽ bị trùng PK, nhưng khác giây thì tạo được nhiều row trùng lặp. | Đổi sang `UNIQUE(volunteer_id, flag_id)` nếu logic chỉ cần 1 alert / cờ / TNV, hoặc thêm cột `id UUID PK` riêng. |
| M6 | `cases.ai_source` | **Thiếu CHECK constraint**. Giá trị hợp lệ chỉ là `'gemini'` hoặc `'regex'` (từ AI Pipeline), nhưng hiện cho phép nhập bất kỳ chuỗi nào. | `ALTER TABLE cases ADD CONSTRAINT chk_ai_source CHECK (ai_source IN ('gemini', 'regex'));` |

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

## 📝 Migration Scripts

### C2 — Fix FK `warning_flags.created_by`
```sql
-- Migration: fix_flags_fk
-- Description: Thêm FK cho created_by trỏ về admins(id)

ALTER TABLE warning_flags 
  ADD CONSTRAINT fk_flags_admin 
  FOREIGN KEY (created_by) REFERENCES admins(id);
```

### C3 — Thêm cột thống kê nhân khẩu cho `cases`
```sql
-- Migration: add_case_demographics
-- Description: Lưu số lượng người lớn/trẻ em/người già mà nạn nhân khai báo

ALTER TABLE cases ADD COLUMN IF NOT EXISTS adults SMALLINT DEFAULT 0;
ALTER TABLE cases ADD COLUMN IF NOT EXISTS children SMALLINT DEFAULT 0;
ALTER TABLE cases ADD COLUMN IF NOT EXISTS elderly SMALLINT DEFAULT 0;
```

### M1 + M2 — Thêm `updated_at` cho cases và volunteers
```sql
-- Migration: add_updated_at
-- Description: Track thời điểm thay đổi dữ liệu gần nhất

ALTER TABLE cases ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE volunteers ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
```

### M3 — Index cho assignment timestamp
```sql
-- Migration: add_assignment_timestamp_index
-- Description: Tăng tốc query background job (autoResolve, staleChecker)

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_assignments_active_time 
  ON case_assignments (assigned_at) 
  WHERE completed_at IS NULL AND revoked_at IS NULL;
```

### M6 — CHECK constraint cho ai_source
```sql
-- Migration: add_ai_source_check
-- Description: Enforce giá trị hợp lệ cho cột ai_source

ALTER TABLE cases ADD CONSTRAINT chk_ai_source 
  CHECK (ai_source IN ('gemini', 'regex'));
```

### C5 — Fix SSL trong migrations.js
```diff
 const pool = new Pool({
   connectionString: process.env.DATABASE_URL,
+  ssl: process.env.DATABASE_URL?.includes('render.com')
+    ? { rejectUnauthorized: false }
+    : undefined,
 });
```

---

## 📌 Priority Order

1. **C3** — Thêm `adults`, `children`, `elderly` vào `cases` (dữ liệu đang bị mất hoàn toàn mỗi khi tạo SOS)
2. **C5** — Fix SSL trong `migrations.js` (không chạy được migration trên cloud)
3. **C4** — Quyết định chiến lược lưu SĐT thật (ảnh hưởng core flow "Admin gọi GSM")
4. **C2** — FK cho `warning_flags.created_by` (bảo toàn tính toàn vẹn dữ liệu)
5. **C1** — Cân nhắc FK `cases.phone_hash → victims.phone_hash` (tùy mức độ coupling mong muốn)
6. **M1-M6** — Các moderate issues có thể gộp vào 1 migration chạy cùng lúc

---

## 🔎 Business Logic Gaps (So sánh Schema vs Y_tuong_KLTN)

| Feature trong Y_tuong_KLTN | Trạng thái Schema | Ghi chú |
|---|---|---|
| Số lượng người (adults/children/elderly) | ❌ **Thiếu hoàn toàn** | App gửi lên nhưng DB không lưu |
| eKYC CCCD cho TNV | ⚠️ Có cột `cccd_verified` | Thiếu cột lưu ảnh/metadata CCCD |
| Mở rộng bán kính động (2km → 5km → 10km) | ⚠️ Logic ở code | Không cần thêm cột DB — xử lý ở query |
| FCM Notification | ✅ Có `fcm_token` | Đúng |
| Ca mồ côi alert | ⚠️ Logic ở code | View `v_active_cases` có `minutes_waiting` hỗ trợ |
| TNV không di chuyển → hủy ca | ✅ `warned_at`, `confirmed_en_route`, `revoked_at` | Đủ cột, logic ở background job |
| Kênh GSM (SĐT thật) | ❌ **Chỉ có hash** | Không thể gọi GSM nếu chỉ có hash |
| Bản đồ An toàn (cờ cảnh báo) | ✅ `warning_flags` | Đúng |
| Crowd-swarming (nhiều TNV / ca) | ✅ `case_assignments` N-N | Đúng |
| Auto-resolve triple-AND | ⚠️ Logic ở `autoResolve.js` | Cần `arrived_at` (đã có), distance check (ở code) |
