# GỠ MỤC 4.5 + 4.6 KHỎI BÁO CÁO — hướng dẫn cho Claude add-in Word

> Đã lưu backup ở `backup_muc_4.5_danh_gia_thuc_nghiem.md`.
> File này: (1) xóa 4.5 + 4.6, (2) sửa các tham chiếu bị gãy, (3) cập nhật mục lục/danh mục.
>
> QUY TẮC:
> - Nếu không khớp chính xác (do đã humanize hoặc dấu ngoặc cong/thẳng), khớp theo NỘI DUNG câu rồi thay/xóa.
> - Chỉ đụng đúng các chỗ nêu dưới. Báo lại chỗ nào đã làm, chỗ nào không tìm thấy.

---

# PHẦN 1 — XÓA KHỐI 4.5 VÀ 4.6

**XÓA toàn bộ** từ tiêu đề mục **"4.5. Đánh giá thực nghiệm"** cho tới **hết Chương 4** — tức tới câu cuối cùng *"…kèm hướng khắc phục ở mục 5.3."* (thuộc mục 4.6).

Khối cần xóa gồm: đoạn mở 4.5, mục **4.5.1** kèm **Bảng 4.6** và **Bảng 4.7**, mục **4.5.2**, và toàn bộ mục **4.6 Kết luận chương**.

Sau khi xóa, Chương 4 kết thúc ở mục **4.4.4. Xác thực và định danh**. Chương 5 bắt đầu ngay sau đó.

---

# PHẦN 2 — SỬA CÁC THAM CHIẾU BỊ GÃY (11 chỗ)

## 2.1 — Đầu Chương 4 (đoạn mở đầu chương)

TÌM: "…là chuẩn hóa phương ngữ, phân loại mức độ khẩn cấp và điều phối cứu trợ, kèm cơ sở của từng quyết định thiết kế và kết quả đo đạc."
THAY: "…là chuẩn hóa phương ngữ, phân loại mức độ khẩn cấp và điều phối cứu trợ, kèm cơ sở của từng quyết định thiết kế."

## 2.2 — Mục 1.5 (Phương pháp nghiên cứu): XÓA cả gạch đầu dòng

XÓA nguyên gạch đầu dòng: "Phương pháp thực nghiệm: xây dựng tập dữ liệu tin nhắn cầu cứu mô phỏng, đo độ trễ và tỉ lệ sử dụng của từng nhánh trong cơ chế phân loại, từ đó xác định ngưỡng thời gian chờ của mô hình ngôn ngữ bằng số liệu thay vì chọn theo cảm tính (mục 4.5)."

## 2.3 — Bảng 2.2 (So sánh phương pháp), dòng "Tốc độ xử lý": bỏ số liệu mất nguồn

Ô cột **Rule-based** — TÌM: "Rất nhanh (dưới 0,1 ms - xem mục 4.5.1)" → THAY: "Rất nhanh"

Ô cột **LLM (Gemini, GPT)** — TÌM: "Phụ thuộc mạng/API (đo được khoảng 1,2 giây trung bình - xem mục 4.5.1)" → THAY: "Phụ thuộc mạng/API"

## 2.4 — Mục 3.1.3 (Yêu cầu phi chức năng), gạch "Hiệu năng"

TÌM: "để luồng tạo ca không bị nghẽn (số đo ở mục 4.5.1). Độ trễ truyền vị trí GPS thấp."
THAY: "để luồng tạo ca không bị nghẽn. Độ trễ truyền vị trí GPS thấp."

## 2.5 — Mục 4.2.3.2 (Nhánh mô hình ngôn ngữ lớn), đoạn cuối về thinkingConfig

TÌM đoạn (bản hiện tại, bắt đầu bằng "Mục 4.5.1 đo tác động…" HOẶC "Tác động của tham số này được đo cụ thể ở mục 4.5.1…") tới "…vô hiệu hóa gần như toàn bộ nhánh mô hình ngôn ngữ."
THAY bằng:
Việc tắt chế độ suy luận nội tại giúp giảm đáng kể độ trễ sinh của mô hình, nhờ đó ngưỡng thời gian chờ mới có thể đặt ở mức 3 giây; nếu giữ chế độ mặc định, độ trễ tăng cao và phần lớn lời gọi sẽ không kịp trong ngưỡng này.

## 2.6 — Mục 4.2.3.3 (Quy tắc hợp nhất): hai chỗ

(a) XÓA hẳn câu cuối đoạn: "Mục 4.5.1 đo độ trễ và tỉ lệ sử dụng của từng nhánh." (bản gốc có thể là "Mục 4.5.1 đo định lượng độ trễ và tỉ lệ sử dụng của từng nhánh.")

(b) TÌM: "Trường ai_source ghi lại nguồn của kết quả cuối cùng, nhận giá trị gemini hoặc rule_based, phục vụ thống kê tỉ lệ dự phòng ở mục 4.5.1." (hoặc bản đã humanize: "…ghi nguồn của kết quả cuối (gemini hoặc rule_based), phục vụ thống kê tỉ lệ dự phòng ở mục 4.5.1.")
THAY: "Trường ai_source ghi lại nguồn của kết quả cuối cùng, nhận giá trị gemini hoặc rule_based."

## 2.7 — Chương 5.1, nhóm "Về đóng góp kỹ thuật": sửa 3 gạch đầu dòng dựa vào số đo

TÌM: "Đo được nhánh dò từ khóa hoàn tất trong dưới 0,1 ms và phân loại thành công 100% số ca ở mọi kịch bản, kể cả khi dịch vụ Gemini trả lỗi hoặc mất kết nối hoàn toàn (mục 4.5.1)."
THAY: "Bảo đảm hệ thống luôn có kết quả phân loại nhờ nhánh dò từ khóa cục bộ chạy hoàn toàn ngoại tuyến, kể cả khi dịch vụ Gemini lỗi hoặc mất kết nối."

TÌM: "Giảm độ trễ của nhánh mô hình ngôn ngữ bằng cách tắt chế độ suy luận nội tại của Gemini, nhờ đó độ trễ trung bình giảm hơn bốn lần và 95% số ca dùng được kết quả của mô hình ngay ở ngưỡng chờ 3 giây."
THAY: "Giảm độ trễ của nhánh mô hình ngôn ngữ bằng cách tắt chế độ suy luận nội tại của Gemini, giúp mô hình kịp trả kết quả trong ngưỡng thời gian chờ."

TÌM: "Xác định ngưỡng thời gian chờ 3 giây của mô hình ngôn ngữ bằng số liệu đo được (Bảng 4.7), thay vì chọn theo cảm tính."
THAY: "Đặt ngưỡng thời gian chờ 3 giây cho mô hình ngôn ngữ, kèm cơ chế dự phòng về nhánh dò từ khóa khi quá hạn."

## 2.8 — Chương 5.1, nhóm "Về kiến thức và kỹ năng": XÓA cả gạch đầu dòng

XÓA nguyên gạch đầu dòng bắt đầu bằng "Rèn được thói quen kiểm chứng bằng số liệu thay vì tin vào trực giác…" (dù bản gốc "Chính thói quen này đã giúp phát hiện…" hay bản đã sửa "nhờ vậy mới phát hiện…").

## 2.9 — Chương 5.2 (Hạn chế): sửa 3 chỗ

(a) XÓA nguyên gạch đầu dòng: "Phép đo mới thực hiện trên 40 tin nhắn mô phỏng do người viết tự xây dựng, cỡ mẫu còn nhỏ."

(b) TÌM: "Nhánh mô hình ngôn ngữ vẫn phụ thuộc vào một dịch vụ bên ngoài. Trong phép đo, 5% số lời gọi bị Gemini trả về lỗi 503 Service Unavailable và những ca này phải dùng kết quả của nhánh dò từ khóa."
THAY: "Nhánh mô hình ngôn ngữ vẫn phụ thuộc vào một dịch vụ bên ngoài; khi dịch vụ lỗi hoặc quá hạn, ca đó phải dùng kết quả của nhánh dò từ khóa."

(c) TÌM: "mới được chọn theo kinh nghiệm vận hành, chưa qua khảo sát định lượng. Chỉ riêng ngưỡng thời gian chờ của mô hình ngôn ngữ được xác định bằng thực nghiệm."
THAY: "mới được chọn theo kinh nghiệm vận hành, chưa qua khảo sát định lượng."

## 2.10 — Chương 5.3 (Hướng phát triển): bỏ tham chiếu tới cách đo

TÌM: "Hiệu chỉnh các tham số vận hành bằng dữ liệu thực địa, theo đúng cách đã làm với ngưỡng thời gian chờ."
THAY: "Hiệu chỉnh các tham số vận hành bằng dữ liệu thực địa."

---

# PHẦN 3 — CẬP NHẬT MỤC LỤC & DANH MỤC (làm cuối cùng)

- **Mục lục**: sẽ tự bỏ các mục 4.5, 4.5.1, 4.5.2, 4.6 sau khi xóa khối.
- **Danh mục bảng biểu**: sẽ tự bỏ Bảng 4.6 và Bảng 4.7 (đã xóa cùng khối 4.5).
- Chọn **toàn bộ tài liệu → Update Field** để cập nhật lại số trang và các danh mục.

---

# KIỂM TRA CUỐI (rà lại sau khi làm xong)

- Không còn chuỗi "**mục 4.5**", "**mục 4.5.1**", "**Bảng 4.6**", "**Bảng 4.7**", "**kết quả đo đạc**", "**phép đo**", "**thực nghiệm**" nào trong toàn tài liệu (dùng Find).
- Chương 4 kết thúc ở **4.4.4**; Chương 5 liền mạch.
- Mục lục và Danh mục bảng biểu không còn 4.5/4.6/Bảng 4.6/4.7.
