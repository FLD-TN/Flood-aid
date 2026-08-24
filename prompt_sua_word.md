# BỘ PROMPT SỬA BÁO CÁO WORD — CÒN LẠI (đã lược các prompt đã hoàn tất)

> **Đã đối chiếu với PDF báo cáo mới nhất.** Các prompt đã áp dụng xong đã được GỠ khỏi file:
> 2.0, 2.2, 3.12, 3.13, 4.1 (Chương 4 dán lại qua 7 phần `ch4_parts/`), và toàn bộ VietMap V1–V6.
> Bên dưới **chỉ còn: PROMPT 6.2 và LOẠT 7 (hình thức).**
>
> **Cách dùng.** Dán nguyên khối vào add-in, chờ sửa xong, kiểm tra mắt, rồi sang prompt kế.
> Sao lưu `Report_KLTN.docx` trước khi bắt đầu.
>
> **Thứ tự còn lại:** 6.2 → 7.1 → 7.2 → 7.3 (7.3 CHẠY CUỐI CÙNG).

---

### PROMPT 6.2 — Dọn tham chiếu "Phụ lục" còn sót ở Chương 3  *(chỉ còn mục 3)*

> Mục 1 và 2 (Chương 4) ĐÃ tự khỏi khi dán lại Chương 4. **Chỉ còn mục 3 dưới đây là chắc chắn phải sửa**
> — PDF hiện vẫn còn "Phụ lục C" ở mục 3.4.

```
Tài liệu KHÔNG có phần Phụ lục. Trong Chương 3, mục "3.4. Thiết kế giao diện lập trình ứng dụng (API)",
đoạn mở đầu hiện còn câu: "...danh sách đầy đủ kèm phương thức, tham số và phản hồi được trình bày
trong Phụ lục C."

Sửa cụm "; danh sách đầy đủ kèm phương thức, tham số và phản hồi được trình bày trong Phụ lục C."
thành: "; các endpoint chính được liệt kê dưới đây theo nhóm chức năng."
(Giữ nguyên toàn bộ danh sách endpoint tại chỗ trong mục 3.4.1.)

Sau đó rà toàn tài liệu (kể cả mục lục) xác nhận không còn chữ "Phụ lục" nào. Báo lại các chỗ đã sửa.
```

---

# LOẠT 7 — Hình thức (CHẠY CUỐI CÙNG, sau khi 6.2 đã chốt)

---

### PROMPT 7.1 — Sửa lỗi đánh số hình ở Chương 3  *(PDF còn nhảy số 3.4, 3.27, còn "Hình 3.2 :")*

```
Danh mục hình ảnh của tài liệu bị NHẢY SỐ ở Chương 3.

Các lỗi cần sửa:
(a) Sau "Hình 3.3" nhảy thẳng sang "Hình 3.5" — thiếu Hình 3.4.
(b) Sau "Hình 3.26" nhảy thẳng sang "Hình 3.28" — thiếu Hình 3.27.
(c) "Hình 3.2 : Biểu đồ tuần tự SD-UC00..." dùng DẤU HAI CHẤM, trong khi mọi hình khác dùng gạch
    nối. Sửa thành "Hình 3.2 - Biểu đồ tuần tự SD-UC00...".

Hãy đánh số lại LIÊN TỤC toàn bộ chú thích hình của Chương 3, từ Hình 3.1 trở đi, không nhảy số.
Sau đó cập nhật mọi tham chiếu chéo trong thân bài trỏ tới các hình này. Giữ nguyên đánh số hình
Chương 4 (Hình 4.1 đến 4.4).
```

---

### PROMPT 7.2 — Xoá trang trắng

```
Kiểm tra tài liệu có trang trắng nào không (thường xuất hiện ở ranh giới giữa các chương, do page
break thừa), đặc biệt ở ranh giới cuối Chương 4 và tiêu đề "CHƯƠNG 5: KẾT LUẬN". Tìm và xóa các
page break thừa để không còn trang trắng.
```

---

### PROMPT 7.3 — Cập nhật lại ba danh mục đầu tài liệu  *(BẮT BUỘC — sửa "Error! Bookmark not defined.")*

> Sau khi dán lại Chương 4, MỤC LỤC + DANH MỤC BẢNG BIỂU + DANH MỤC HÌNH ẢNH đang hiển thị
> "Error! Bookmark not defined." ở toàn bộ mục Chương 4. Bước Update Field bên dưới sẽ sửa hết.

```
Sau khi mọi nội dung đã chốt, cập nhật lại ba danh mục ở đầu tài liệu.

(a) DANH MỤC BẢNG BIỂU: Chương 2 có Bảng 2.1–2.3; Chương 3 có Bảng 3.1–3.13; Chương 4 có Bảng
    4.1–4.7. Kiểm tra tên bảng trong danh mục khớp chú thích trong thân bài (không còn "Error!
    Bookmark not defined.").

(b) DANH MỤC HÌNH ẢNH: đánh số liên tục, không nhảy số. Chương 4 có đủ bốn hình 4.1–4.4 (không còn
    "Error! Bookmark not defined.").

(c) MỤC LỤC. Cập nhật toàn bộ, phải phản ánh:
    - Chương 4 với cấu trúc mới (4.1 đến 4.6 — có mục 4.6 Kết luận chương) và số trang đúng, không
      còn "Error! Bookmark not defined.".
    - KHÔNG có phần Phụ lục nào — tài liệu kết thúc ở TÀI LIỆU THAM KHẢO.

(d) DANH MỤC TỪ VIẾT TẮT: kiểm tra đã có GiST.

Cuối cùng, chọn toàn bộ tài liệu và Update Field để mọi số trang và tham chiếu chéo được tính lại.
```

---

# VIỆC TÔI PHẢI TỰ LÀM (add-in không làm được)

| Việc | Ghi chú |
|---|---|
| **Vẽ Hình 4.1, 4.2, 4.3, 4.4** | Đã có file .puml + .png trong `diagrams/`. Chèn ảnh vào 4 chỗ "(Sơ đồ Hình 4.x - sẽ được chèn)". |
| **Vẽ lại Hình 3.28 (ERD)** | Là ảnh. Cần khớp mô tả mới: `text_normalized` + `text_original` (thay `text_raw`), `address_text`, `orphan_alerted_at`, và hai bảng `dialect_terms`, `dialect_meta`. |
| **Đọc lại [10] và [11]** | Không được trích dẫn tài liệu chưa đọc. Kiểm tên tác giả/năm của [12] trên GitHub. |
