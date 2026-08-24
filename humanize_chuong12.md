# HUMANIZE CHƯƠNG 1 & 2 — Danh sách TÌM / THAY cho Claude add-in Word

> Chương 1 và 2 phần lớn đã tự nhiên (văn tả sự kiện có trích dẫn + định nghĩa lý thuyết).
> Chỉ chỉnh 6 chỗ có dấu hiệu "văn AI": câu meta, bộ-ba lặp nhịp, câu chốt lặp, gạch ngang thừa.
>
> QUY TẮC BẮT BUỘC:
> - CHỈ thay phần văn xuôi nêu dưới. KHÔNG đụng số liệu, trích dẫn [1]–[12], Bảng 2.1–2.3,
>   tên công nghệ/hàm/thuật ngữ.
> - Nếu không khớp 100% (ngoặc cong/thẳng khác nhau), khớp theo nội dung câu rồi thay.
>   Báo lại mục nào đã thay, mục nào không tìm thấy.
> - Không thêm in đậm nào.

---

## 1. Mục 1.2 — ba câu mở đầu lý do (bỏ kiểu câu cụt "Bắt đầu từ… / Tiếp theo… / Cuối cùng…")

TÌM "Bắt đầu từ nhu cầu thực tiễn."  → THAY "Lý do đầu tiên là nhu cầu thực tiễn."

TÌM "Tiếp theo xuất phát từ tính cần thiết về mặt thời gian."  → THAY "Lý do thứ hai là tính cấp thiết về mặt thời gian."

TÌM "Cuối cùng là cơ hội về mặt công nghệ."  → THAY "Lý do thứ ba là cơ hội về mặt công nghệ."

(Giữ nguyên phần còn lại của ba đoạn và câu "Từ ba lý do trên, đề tài…".)

---

## 2. Mục 2.1 — câu chốt cuối (tránh lặp với câu "Đây chính là vấn đề…" ở cuối 1.1)

TÌM "Đây chính là khoảng trống mà đề tài hướng tới."

THAY bằng:
Khoảng trống đó chính là điều đề tài nhắm giải quyết.

---

## 3. Mục 2.2.1.3 — bỏ gạch ngang chèn dài

TÌM "Trong bối cảnh thiên tai - nơi yêu cầu phản hồi gần như tức thời, hạ tầng mạng không ổn định và kết quả cần ổn định, dễ kiểm chứng - phương pháp Rule-based tỏ ra phù hợp nhất để làm lớp xử lý nền tảng nhờ tốc độ cực nhanh, hoạt động hoàn toàn ngoại tuyến và tính tất định."

THAY bằng:
Trong bối cảnh thiên tai, nơi yêu cầu phản hồi gần như tức thời, hạ tầng mạng không ổn định và kết quả cần ổn định, dễ kiểm chứng, phương pháp Rule-based tỏ ra phù hợp nhất để làm lớp xử lý nền tảng nhờ tốc độ cực nhanh, hoạt động hoàn toàn ngoại tuyến và tính tất định.

---

## 4. Mục 2.2.1.4 — câu đầu ("trật tự có chủ đích")

TÌM "tuy nhiên hai nhánh này không chạy đua song song mà nối tiếp nhau theo một trật tự có chủ đích."

THAY bằng:
tuy nhiên hai nhánh này không chạy song song mà nối tiếp nhau theo một trật tự định trước.

---

## 5. Mục 2.2.1.4 — đoạn 2 (bỏ "Giá trị thực sự của thiết kế nằm ở…" + câu chốt kịch tính)
> Đây là cùng cụm đã gỡ trong Chương 4; sửa để đồng bộ toàn báo cáo.

TÌM "Cơ chế này không nhằm làm cho hệ thống phản hồi nhanh hơn. Do nhánh mô hình ngôn ngữ lớn được chờ một cách tuần tự sau nhánh dò từ khóa… thay vì đánh giá thấp tình huống. Chi tiết hiện thực của cơ chế này được trình bày ở mục 4.2.3."

THAY bằng:
Thiết kế này không nhằm giúp hệ thống phản hồi nhanh hơn. Vì nhánh mô hình ngôn ngữ lớn được chờ tuần tự sau nhánh dò từ khóa, thời gian phản hồi tổng thể vẫn bị chặn dưới bởi độ trễ của mô hình và tối đa bằng ngưỡng thời gian chờ đã đặt (ba giây). Bù lại, nó đạt được độ sẵn sàng và tính an toàn: hệ thống luôn có sẵn một kết quả phân loại kể cả khi dịch vụ mô hình bên ngoài gặp sự cố hay mạng chập chờn, và quy tắc lấy mức khẩn cấp lớn hơn giữa hai nhánh khiến kết quả luôn nghiêng về phía an toàn của nạn nhân thay vì đánh giá thấp tình huống. Chi tiết hiện thực được trình bày ở mục 4.2.3.

---

## 6. Mục 2.3 — đoạn mở (bỏ "Điểm cần nhấn mạnh là" + bộ-ba "Thứ nhất/hai/ba" + gạch ngang chèn)

TÌM "Điểm cần nhấn mạnh là các công nghệ này không được chọn chỉ vì mức độ phổ biến, mà vì mức phù hợp với ba ràng buộc đặc thù của bối cảnh ứng phó thiên tai. Thứ nhất, hạ tầng mạng… Thứ hai, pin… Thứ ba, phần lớn nghiệp vụ của hệ thống - định vị nạn nhân, xếp hạng ca theo khoảng cách, theo dõi tiếp cận - đều xoay quanh dữ liệu không gian, nên nền tảng lưu trữ và truy vấn không gian giữ vai trò trung tâm. Bảng 2.3 tổng hợp các thành phần chính, công nghệ tương ứng và lý do lựa chọn xét theo ba ràng buộc đó."

THAY bằng:
Các công nghệ này không được chọn chỉ vì phổ biến, mà vì phù hợp với ba ràng buộc đặc thù của bối cảnh ứng phó thiên tai. Ràng buộc đầu tiên là hạ tầng mạng ở vùng chịu ảnh hưởng thường chập chờn hoặc gián đoạn, nên các thành phần phải hoạt động được ngay cả khi mất kết nối và tự đồng bộ khi mạng phục hồi. Kế đến, pin thiết bị là tài nguyên khan hiếm trong nhiều giờ đến nhiều ngày mất điện, đòi hỏi cơ chế theo dõi và truyền dữ liệu tiết kiệm năng lượng. Cuối cùng, phần lớn nghiệp vụ của hệ thống, từ định vị nạn nhân, xếp hạng ca theo khoảng cách đến theo dõi tiếp cận, đều xoay quanh dữ liệu không gian, nên nền tảng lưu trữ và truy vấn không gian giữ vai trò trung tâm. Bảng 2.3 tổng hợp các thành phần chính, công nghệ tương ứng và lý do lựa chọn theo ba ràng buộc đó.

---

# HẾT — 6 mục (1.2 gồm 3 câu nhỏ). Sau khi thay, rà lại Chương 1–2 không còn:
# "Điểm cần nhấn mạnh là", "Giá trị thực sự của thiết kế nằm ở", và không còn hai chương
# liền nhau dùng chung khuôn "Thứ nhất/Thứ hai/Thứ ba".
