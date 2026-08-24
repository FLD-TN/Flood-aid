# CHƯƠNG 5: KẾT LUẬN

## 5.1. Kết quả đạt được

Sau quá trình nghiên cứu và triển khai, đề tài đã đạt được những kết quả chính như sau:

**Về sản phẩm**

- Xây dựng hoàn chỉnh nền tảng FloodAid gồm ba thành phần vận hành được và tích hợp với nhau: ứng dụng di động, máy chủ nghiệp vụ và trang quản trị web.
- Ứng dụng di động cho phép nạn nhân gửi yêu cầu SOS bằng văn bản hoặc giọng nói, theo dõi vị trí tình nguyện viên theo thời gian thực, nhắn tin và gọi điện trong ca.
- Ứng dụng di động cho phép tình nguyện viên đăng ký qua định danh điện tử (eKYC), lọc và tiếp nhận ca cứu hộ, dẫn đường tới vị trí nạn nhân.
- Trang quản trị cung cấp bản đồ chỉ huy thời gian thực và duyệt hồ sơ tình nguyện viên.
- Hoàn thành toàn bộ mục tiêu cụ thể đã đặt ra ở mục 1.3.2.

**Về đóng góp kỹ thuật**

- Xây dựng bộ chuẩn hóa phương ngữ miền Trung chạy trên thiết bị, với từ điển hơn 26.000 mục được sinh tự động bằng cách áp tập luật biến âm lên corpus tiếng Việt chuẩn Viet74K, thay vì liệt kê thủ công.
- Chứng minh được bước chuẩn hóa vừa nâng đúng mức khẩn cấp của những ca bị dạng phương ngữ che khuất từ khóa, vừa là tiền đề để cơ chế xử lý phủ định hoạt động đúng (Bảng 4.5).
- Hiện thực cơ chế phân loại mức độ khẩn cấp kết hợp nhánh dò từ khóa cục bộ và nhánh mô hình ngôn ngữ lớn (Gemini), hợp nhất theo quy tắc sàn an toàn: mức khẩn cấp cuối không bao giờ thấp hơn mức mà từ khóa cảnh báo phát hiện.
- Đo được nhánh dò từ khóa hoàn tất trong dưới 0,1 ms và phân loại thành công 100% số ca ở mọi kịch bản, kể cả khi dịch vụ Gemini trả lỗi hoặc mất kết nối hoàn toàn (mục 4.5.1).
- Giảm độ trễ của nhánh mô hình ngôn ngữ bằng cách tắt chế độ suy luận nội tại của Gemini, nhờ đó độ trễ trung bình giảm hơn bốn lần và 95% số ca dùng được kết quả của mô hình ngay ở ngưỡng chờ 3 giây.
- Xác định ngưỡng thời gian chờ 3 giây của mô hình ngôn ngữ bằng số liệu đo được (Bảng 4.7), thay vì chọn theo cảm tính.
- Hiện thực cơ chế điều phối tự phục hồi: tự phát hiện ca không có người tiếp nhận, tự thu hồi phân công khi tình nguyện viên không tiến về phía nạn nhân và mở lại ca để điều phối cho người khác.
- Khắc phục được một lỗi độ tin cậy của thiết kế ban đầu: chuyển cơ chế phát hiện ca mồ côi từ bộ hẹn giờ trong bộ nhớ tiến trình sang tác vụ nền quét cơ sở dữ liệu, nhờ đó cảnh báo vẫn diễn ra đúng hạn qua các lần khởi động lại máy chủ.
- Thiết kế cơ chế liên lạc ba tầng dự phòng, gồm WebSocket, REST và gọi điện qua mạng GSM, cùng chiến lược theo dõi GPS thích nghi ba chế độ nhằm tiết kiệm pin thiết bị.
- Bảo vệ dữ liệu cá nhân bằng mã hóa AES-256-GCM cho số điện thoại và tự động xóa tin nhắn khi ca kết thúc.

**Về kiến thức và kỹ năng**

- Sử dụng được hệ quản trị PostgreSQL và phần mở rộng không gian PostGIS: thiết kế lược đồ quan hệ, viết truy vấn không gian (`ST_DWithin`, `ST_Distance`), tạo chỉ mục GiST và chỉ mục bộ phận.
- Xây dựng được ứng dụng di động đa màn hình bằng Flutter và ngôn ngữ Dart, tích hợp GPS, nhận dạng giọng nói, bản đồ và thông báo đẩy.
- Phân biệt và lựa chọn đúng ba kỹ thuật giao tiếp REST, Server-Sent Events và WebSocket theo đặc điểm của từng luồng dữ liệu, đồng thời thiết kế cơ chế dự phòng khi kết nối gián đoạn.
- Xây dựng máy chủ nghiệp vụ bằng Node.js và Express theo mô hình phân tách trách nhiệm, xử lý bất đồng bộ và lập lịch tác vụ nền bằng `node-cron`.
- Xây dựng trang quản trị bằng React kết hợp bản đồ Leaflet và OpenStreetMap.
- Tích hợp được các dịch vụ bên ngoài: mô hình ngôn ngữ lớn Google Gemini, xác thực và thông báo đẩy Firebase, định danh điện tử FPT.AI.
- Rèn được thói quen kiểm chứng bằng số liệu thay vì tin vào trực giác. Chính thói quen này đã giúp phát hiện ra rằng cấu hình mặc định của mô hình ngôn ngữ làm ngưỡng thời gian chờ mất tác dụng, một sai lệch mà quá trình phát triển không để lộ dấu hiệu nào.

## 5.2. Hạn chế

- Hệ thống vẫn phụ thuộc vào hạ tầng mạng và nguồn điện. Trong lũ, mất điện kéo theo mất sóng và cạn pin, đúng lúc hệ thống cần hoạt động nhất.
- Khoảng cách được tính theo đường chim bay, không phải quãng đường di chuyển thật; tình nguyện viên phải đi vòng có thể bị kết luận nhầm là bế tắc và bị thu hồi ca.
- Nhánh mô hình ngôn ngữ vẫn phụ thuộc vào một dịch vụ bên ngoài. Trong phép đo, 5% số lời gọi bị Gemini trả về lỗi 503 Service Unavailable và những ca này phải dùng kết quả của nhánh dò từ khóa.
- Nhánh dò từ khóa phụ thuộc bảng từ khóa cố định, không hiểu ngữ cảnh; cơ chế xử lý phủ định chỉ quét cửa sổ hai từ nên bỏ sót các cấu trúc phủ định phức tạp.
- Tập luật biến âm được soạn thủ công, chưa bao phủ hết khác biệt giữa các địa phương trong khu vực miền Trung.
- Từ điển sinh tự động còn chứa các mục thừa; tỉ lệ mục hợp lệ và tỉ lệ thay thế sai trên văn bản phổ thông đều chưa được đo.
- Từ điển phương ngữ hiện được đóng gói tĩnh trong ứng dụng; muốn thêm hoặc sửa từ địa phương mới phải biên dịch và phát hành lại ứng dụng, chưa cập nhật được linh hoạt trong lúc vận hành.
- Chiến lược phát sóng rộng chưa phải thuật toán điều phối tối ưu; ở quy mô lớn sẽ gây nhiễu thông báo cho tình nguyện viên.
- Phần lớn các tham số ngưỡng của hệ thống, gồm ngưỡng cảnh báo ca mồ côi, ngưỡng phát hiện đình trệ, các mốc tiếp cận và độ rộng vành đai xếp hạng, mới được chọn theo kinh nghiệm vận hành, chưa qua khảo sát định lượng. Chỉ riêng ngưỡng thời gian chờ của mô hình ngôn ngữ được xác định bằng thực nghiệm.
- Chưa kiểm chứng được khả năng nhánh mô hình ngôn ngữ tự hiểu phương ngữ mà không cần bước chuẩn hóa; giá trị đã xác lập của bộ chuẩn hóa vì vậy chỉ giới hạn ở nhánh dò từ khóa.
- Phép đo mới thực hiện trên 40 tin nhắn mô phỏng do người viết tự xây dựng, cỡ mẫu còn nhỏ.
- Hệ thống mới ở mức nguyên mẫu trên Android, chưa thử nghiệm với người dùng thật trong điều kiện thiên tai.

## 5.3. Hướng phát triển

Trong tương lai, đề tài có thể được mở rộng theo các hướng sau:

- Thay khoảng cách đường chim bay bằng khoảng cách theo tuyến đường, hoặc xét xu hướng giảm của khoảng cách qua nhiều mẫu GPS liên tiếp thay vì so với một mốc duy nhất.
- Cải tiến điều phối theo vòng mở rộng dần: gửi thông báo cho nhóm tình nguyện viên gần nhất trước, chỉ mở rộng bán kính khi không ai tiếp nhận.
- Xây dựng tập dữ liệu câu phương ngữ có gán nhãn để kiểm chứng đóng góp của bộ chuẩn hóa đối với nhánh mô hình ngôn ngữ lớn.
- Định lượng chất lượng từ điển: đo tỉ lệ mục hợp lệ và tỉ lệ thay thế sai trên văn bản phổ thông.
- Hiệu chỉnh các tham số vận hành bằng dữ liệu thực địa, theo đúng cách đã làm với ngưỡng thời gian chờ.
- Bổ sung kênh dự phòng qua SMS hoặc USSD cho khu vực chỉ còn sóng thoại.
- Mở rộng năng lực xử lý đa phương thức: cho phép gửi kèm ảnh, video từ hiện trường và dùng mô hình thị giác máy tính để đánh giá mức ngập.
- Phát triển ứng dụng cho iOS và phiên bản web; tích hợp bản đồ ngập lụt thời gian thực.
- Hợp tác với cơ quan phòng chống thiên tai để triển khai thử nghiệm có kiểm soát trong một mùa mưa bão thực tế.
- Bổ sung cơ chế khuyến khích tình nguyện viên và phân tích dữ liệu sau thiên tai, chẳng hạn bản đồ nhiệt các vùng thường xuyên cần cứu trợ.
