# 🗄️ DB Review — PostgreSQL Database Audit Prompt

> **Cách dùng:** Đặt file này vào project, khi cần review database thì mention file này kèm schema (hoặc để AI Agent tự đọc schema từ context project).

---

## 📌 Mục tiêu

Bạn là một **Database Architect chuyên PostgreSQL**. Nhiệm vụ của bạn là **đọc toàn bộ schema hiện tại** của hệ thống (từ file context, migration files, hoặc schema được cung cấp), sau đó thực hiện **audit toàn diện** và đưa ra báo cáo cải tiến cụ thể.

---

## 🔍 Bước 1 — Đọc & Hiểu Context Hệ Thống

Trước khi review, hãy đọc:
- File context hệ thống (`Y_tuong_KLTN.md` hoặc tương đương)
- Toàn bộ schema hiện tại (migration files, `schema.prisma`, hoặc SQL dump)
- Các model/entity trong code nếu có

**Mục tiêu:** Hiểu rõ **business logic** của hệ thống trước khi đánh giá schema.

---

## 🧪 Bước 2 — Checklist Audit

Thực hiện kiểm tra theo từng hạng mục sau:

### 2.1 Naming Convention
- [ ] Tên bảng có dùng `snake_case` nhất quán không? (PostgreSQL convention)
- [ ] Tên bảng có dùng số nhiều hay số ít? (chọn 1 và nhất quán toàn bộ)
- [ ] Tên cột có mô tả rõ ý nghĩa không? (tránh `data`, `info`, `val`, `tmp`)
- [ ] Primary key có tên nhất quán không? (khuyến nghị: `id` hoặc `{table_name}_id`)
- [ ] Foreign key có tên theo pattern `{referenced_table}_id` không?
- [ ] Boolean columns có prefix `is_`, `has_`, `can_` không?
- [ ] Timestamp columns có dùng `created_at`, `updated_at`, `deleted_at` không?

### 2.2 Data Types
- [ ] Có dùng `VARCHAR` thay vì `TEXT` không cần thiết không? (PostgreSQL `TEXT` thường tốt hơn)
- [ ] Có dùng `CHAR(n)` sai mục đích không?
- [ ] Cột tiền/số thập phân có dùng `NUMERIC`/`DECIMAL` thay vì `FLOAT`/`REAL` không?
- [ ] ID có nên dùng `UUID` hay `BIGSERIAL` tùy use case không?
- [ ] Timestamp có dùng `TIMESTAMPTZ` (with timezone) không?
- [ ] Có nên dùng `JSONB` thay `JSON` cho các cột JSON không?
- [ ] Enum values có nên tách thành bảng lookup riêng không?

### 2.3 Constraints & Integrity
- [ ] Tất cả foreign keys có được khai báo tường minh không?
- [ ] Có thiếu `NOT NULL` ở các cột bắt buộc không?
- [ ] Có thiếu `UNIQUE` constraint ở các cột cần unique không? (email, phone, username...)
- [ ] `CHECK` constraints có đủ cho các rule business logic không? (vd: `price > 0`, `quantity >= 0`)
- [ ] Có cột nào nên có `DEFAULT` value không?
- [ ] ON DELETE / ON UPDATE policy có hợp lý không? (`CASCADE`, `SET NULL`, `RESTRICT`)

### 2.4 Normalization
- [ ] Có vi phạm 1NF không? (multi-value trong 1 cột, lưu list dưới dạng string)
- [ ] Có vi phạm 2NF không? (partial dependency với composite PK)
- [ ] Có vi phạm 3NF không? (transitive dependency)
- [ ] Có dữ liệu bị duplicate không cần thiết giữa các bảng không?
- [ ] Có bảng nào nên được tách ra không? Hay bảng nào nên merge lại?

### 2.5 Indexes
- [ ] Primary key đã có index tự động — OK
- [ ] Các foreign key column có index không? (PostgreSQL **không tự tạo** index cho FK)
- [ ] Các cột thường xuyên dùng trong `WHERE`, `ORDER BY`, `GROUP BY` có index không?
- [ ] Có index nào dư thừa (duplicate hoặc ít dùng) gây tốn storage/write performance không?
- [ ] Có nên dùng **Partial Index** cho các query pattern đặc biệt không? (vd: `WHERE deleted_at IS NULL`)
- [ ] Có nên dùng **Composite Index** thay nhiều single index không?
- [ ] Có cột `email`, `phone`, `username` cần `UNIQUE INDEX` chưa?

### 2.6 Soft Delete & Audit Trail
- [ ] Hệ thống có dùng soft delete không? Nếu có, `deleted_at TIMESTAMPTZ` đã có chưa?
- [ ] Có cần bảng audit log để track thay đổi dữ liệu không?
- [ ] `created_at`, `updated_at` đã có ở tất cả bảng cần thiết chưa?
- [ ] `created_by`, `updated_by` có cần thiết không?

### 2.7 Performance & Scalability
- [ ] Bảng nào có thể sẽ grow rất lớn? Có cần **Table Partitioning** không?
- [ ] Có query nào sẽ cần **Materialized View** không?
- [ ] Có cần tách **read replica** hay không?
- [ ] JSONB columns có được index bằng **GIN index** không?
- [ ] Có nên dùng **Connection Pooling** (PgBouncer) không?

### 2.8 Security
- [ ] Password/secret có đang lưu plain text không? (chỉ lưu hash)
- [ ] PII data (tên, email, SĐT, CCCD...) có cần encryption at rest không?
- [ ] Row-level security (RLS) có cần thiết cho use case này không?
- [ ] Database user/role có đang dùng least privilege không?

### 2.9 Business Logic Alignment
- [ ] Mỗi bảng có thực sự phản ánh đúng entity trong domain không?
- [ ] Relationship giữa các bảng có đúng với business rule không? (1-1, 1-N, N-N)
- [ ] Có bảng nào thiếu mà business logic cần không?
- [ ] Có bảng nào thừa hoặc không còn dùng nữa không?
- [ ] Các status/state column có đủ các giá trị cần thiết không?

---

## 📊 Bước 3 — Output Report

Sau khi audit, xuất báo cáo theo cấu trúc sau:

```
## 📋 Database Audit Report

### ✅ Điểm tốt
[Liệt kê những gì đang làm đúng]

### 🔴 Critical Issues (cần sửa ngay)
| # | Bảng / Cột | Vấn đề | Đề xuất sửa |
|---|-----------|--------|-------------|
| 1 | ...       | ...    | ...         |

### 🟡 Moderate Issues (nên sửa)
| # | Bảng / Cột | Vấn đề | Đề xuất sửa |
|---|-----------|--------|-------------|

### 🟢 Suggestions (cải tiến tùy chọn)
| # | Hạng mục | Đề xuất |
|---|---------|---------|

### 📝 Migration Scripts
[Cung cấp SQL migration script cho từng Critical Issue]

\```sql
-- Migration: fix_{issue_name}
-- Description: ...

ALTER TABLE ...;
CREATE INDEX ...;
\```

### 📌 Priority Order
1. [Issue quan trọng nhất cần làm trước]
2. ...
```

---

