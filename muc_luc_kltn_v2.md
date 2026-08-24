# MỤC LỤC KHÓA LUẬN — BẢN ĐỐI CHIẾU, GHI CHÚ SỬA VÀ PHƯƠNG ÁN CẮT

> **Đề tài:** Nghiên cứu và Xây dựng Nền tảng Hỗ trợ Điều phối Cứu trợ Lũ lụt tại Miền Trung dựa trên AI NLP
> **Chuyên ngành:** Công nghệ Phần mềm




## PHẦN MỞ ĐẦU (không đánh số)

- LỜI CẢM ƠN
- LỜI CAM ĐOAN
- MỤC LỤC
- DANH MỤC TỪ VIẾT TẮT
- DANH MỤC BẢNG BIỂU
- DANH MỤC HÌNH ẢNH

> **✔ ĐÃ XONG — DANH MỤC BẢNG BIỂU**
> Bảy bảng Chương 4 (4.1 đến 4.7) đã có mặt, tên bảng đã khớp với thân bài. Chỉ còn phải thêm **Bảng 2.3 - Công nghệ sử dụng và lý do lựa chọn** sau khi nén mục 2.3.

> **✔ ĐÃ XONG — DANH MỤC TỪ VIẾT TẮT**
> Đã xóa CPR, đã thêm GiST. Không cần sửa gì thêm.

> **✔ ĐÃ XONG (phần chú thích) / ⚠ CÒN LẠI (phần hình vẽ) — DANH MỤC HÌNH ẢNH**
> Bốn chú thích hình Chương 4 đã đúng tên mới. **Nhưng cả bốn hình vẫn chưa có hình vẽ**, mới chỉ có dòng "(Sơ đồ Hình 4.x - sẽ được chèn)". Ưu tiên vẽ **Hình 4.3** trước vì nó thể hiện đóng góp chính.

> **⚠ CẦN SỬA — LỖI ĐÁNH SỐ HÌNH Ở CHƯƠNG 3 (mới phát hiện)**
> Danh mục hình ảnh **nhảy số**: sau Hình 3.3 là Hình 3.5 (thiếu **Hình 3.4**), và sau Hình 3.26 là Hình 3.28 (thiếu **Hình 3.27**). Hội đồng chấm hình thức sẽ trừ điểm chỗ này.
> Ngoài ra **Hình 3.2 dùng dấu hai chấm** thay vì gạch nối: *"Hình 3.2 : Biểu đồ tuần tự..."* - sửa thành *"Hình 3.2 - Biểu đồ tuần tự..."* cho đồng nhất với mọi hình khác.
> Cách sửa: chọn toàn bộ chú thích hình Chương 3, dùng Insert → Caption của Word để đánh số lại tự động, rồi Update Field toàn tài liệu.

> **⚠ CẦN SỬA — TRANG TRẮNG**
> Có một **trang trắng (trang 84)** nằm giữa mục 4.6 và Chương 5. Xóa page break thừa.

---

## CHƯƠNG 1: TỔNG QUAN ĐỀ TÀI

**1.1. Đặt vấn đề**

**1.2. Lý do chọn đề tài**

**1.3. Mục tiêu đề tài**

&nbsp;&nbsp;*1.3.1. Mục tiêu tổng quát*

&nbsp;&nbsp;*1.3.2. Mục tiêu cụ thể*

> **⚠ CẦN SỬA — 1.3.2**
> **(a) Thiếu một mục tiêu quan trọng.** Danh sách hiện chỉ nói "gửi SOS bằng văn bản hoặc từ giọng nói chuyển sang văn bản", **không nhắc chuẩn hóa phương ngữ** — trong khi đây là một trong hai đóng góp NLP chính (mục 4.2.2). Thêm gạch đầu dòng:
> *"Nghiên cứu và xây dựng bộ chuẩn hóa phương ngữ miền Trung chạy trên thiết bị, nhằm sửa sai lệch của bộ nhận dạng giọng nói trước khi đưa văn bản vào bước phân loại."*
>
> **(b) Sửa cách gọi cơ chế điều phối.** Cụm *"điều phối thông báo dựa trên vị trí (Geo-Dispatch)"* gây hiểu nhầm rằng thông báo được lọc theo bán kính. Thực tế (mục 4.3.1) bước phát sóng **không lọc bán kính**. Sửa thành: *"...cơ chế điều phối gồm phát sóng thông báo tới tình nguyện viên khả dụng và truy vấn không gian xếp hạng ca theo vị trí."*

**1.4. Đối tượng và phạm vi nghiên cứu**

&nbsp;&nbsp;*1.4.1. Đối tượng nghiên cứu*

> **⚠ CẦN SỬA — 1.4.1**
> Gạch đầu dòng thứ ba viết *"cơ chế phát sóng thông báo **dựa trên vị trí** của tình nguyện viên"* — cùng lỗi với 1.3.2. Sửa: phát sóng dựa trên **trạng thái khả dụng và tùy chọn nhận thông báo**; PostGIS dùng cho **truy vấn ca gần và theo dõi khoảng cách**.

&nbsp;&nbsp;*1.4.2. Phạm vi nghiên cứu*

**1.5. Phương pháp nghiên cứu**

> **⚠ CẦN SỬA — 1.5**
> Bổ sung **phương pháp thực nghiệm** (hiện chỉ có nghiên cứu tài liệu, phân tích yêu cầu, phát triển phần mềm), vì mục 4.5 đã có phần đánh giá định lượng.

**1.6. Đóng góp của khóa luận** — *(MỤC MỚI, cần viết)*

> **⚠ CẦN VIẾT MỚI — 1.6**
> Chương 5 phải "đối chiếu lại các đóng góp", nhưng hiện **Chương 1 không phát biểu đóng góp ở đâu cả**. Viết nửa trang, liệt kê đúng ba đóng góp mà Chương 4 chứng minh:
> 1. Bộ chuẩn hóa phương ngữ miền Trung, từ điển **sinh tự động bằng luật biến âm**, tổ chức hai lớp, cập nhật nóng không cần phát hành lại ứng dụng.
> 2. Cơ chế phân loại mức độ khẩn cấp kết hợp dò từ khóa và mô hình ngôn ngữ lớn, có **ràng buộc sàn an toàn**.
> 3. Cơ chế điều phối **tự phục hồi**: phát hiện ca mồ côi bền vững qua khởi động lại máy chủ, tự thu hồi phân công khi tình nguyện viên không tiếp cận.

---

## CHƯƠNG 2: CƠ SỞ LÝ THUYẾT VÀ CÔNG NGHỆ LIÊN QUAN

**2.1. Các công trình liên quan**

> **⚠ CẦN SỬA — Bảng 2.1, dòng FloodAid (mới phát hiện)**
> Ô mô tả FloodAid ghi *"GIS điều phối **theo vị trí**"* - cùng lỗi Geo-Dispatch như mục 1.3.2 và 1.4.1. Sửa thành: *"GIS xếp hạng ca cứu hộ theo vị trí và theo dõi khoảng cách tiếp cận"*. Việc phát sóng thông báo thì **không lọc theo vị trí**.

**2.2. Cơ sở lý thuyết**

&nbsp;&nbsp;*2.2.1. Xử lý ngôn ngữ tự nhiên (NLP)*

&nbsp;&nbsp;&nbsp;&nbsp;2.2.1.1. Khái niệm NLP và các bài toán cơ bản

&nbsp;&nbsp;&nbsp;&nbsp;2.2.1.2. Các mô hình ngôn ngữ tiêu biểu

> **✂ NÉN — 2.2.1.2**
> Mục này dành gần **hai trang** cho Transformer, BERT và PhoBERT — ba mô hình đề tài **không hề sử dụng**. Chúng chỉ cần tồn tại đủ để làm nền cho lập luận "vì sao *không* chọn học sâu" ở Bảng 2.2. **Rút mỗi mô hình xuống 3–4 dòng**, giữ lại phần Rule-based và LLM (là hai thứ thực sự dùng). Tiết kiệm ~1,5 trang.

&nbsp;&nbsp;&nbsp;&nbsp;2.2.1.3. So sánh các phương pháp phân loại văn bản

> **✔ CẦN SỬA - Bảng 2.2 (giờ đã có số đo thật)**
> Ô *"Rule-based - Rất nhanh (~0,1 ms)"* trước đây là con số ước lượng. Phép đo ở mục 4.5.1 xác nhận: nhánh dò từ khóa chạy **dưới 0,1 ms**. Giữ nguyên ô này, chỉ dẫn thêm *"xem mục 4.5.1"*.
> Ô *"LLM - Phụ thuộc mạng/API"*: bổ sung số đo thật **khoảng 1,2 giây trung bình** để bảng có sức nặng.

&nbsp;&nbsp;&nbsp;&nbsp;2.2.1.4. Cơ chế phân loại mức độ khẩn cấp

> **⚠ CẦN SỬA — TÊN GỌI và NỘI DUNG. Chỗ nguy hiểm nhất trong Chương 2.**
> *(Số hiệu 2.2.1.4 trong bản hiện tại **đã đúng** — trước đây đánh nhầm là 2.1.2.4, nay đã sửa.)*
>
> **(a) Tên gọi.** *"Chiến lược Parallel Race Pipeline"* → **"Cơ chế phân loại mức độ khẩn cấp"**. Sau khi đổi, **tìm–thay toàn bộ** cụm "Parallel Race" còn sót: mục 2.3.4, mục 3.1.2.4, và phần Kết luận.
>
> **(b) Nội dung sai so với mã nguồn.** Bản hiện viết *"hệ thống **đồng thời kích hoạt hai nhánh xử lý**"*. Thực tế trong `aiPipeline.js`: nhánh dò từ khóa chạy **đồng bộ trước**, sau đó mới `await` Gemini; `Promise.race` chỉ nằm **bên trong** nhánh Gemini để chặn thời gian chờ. Viết lại:
>
> > *Khi tiếp nhận một tin nhắn cầu cứu, hệ thống chạy nhánh dò từ khóa cục bộ để có ngay một kết quả bảo đảm tối thiểu, sau đó gọi mô hình ngôn ngữ lớn với một giới hạn thời gian chờ cố định nhằm thu được kết quả hiểu ngữ cảnh tốt hơn. Nếu mô hình phản hồi kịp, kết quả của nó được dùng làm kết quả chính; nếu không, hệ thống dùng kết quả của nhánh dò từ khóa. Trong cả hai trường hợp, mức khẩn cấp cuối cùng được lấy là giá trị lớn hơn giữa hai nhánh (sàn an toàn), và tập nhãn được hợp từ cả hai nhánh.*
>
> **(c) Bỏ hàm ý sai về hiệu năng.** Không được ngụ ý cơ chế này giúp hệ thống **nhanh hơn**. Thời gian phản hồi vẫn bị chặn dưới bởi độ trễ của mô hình (tối đa **3 giây**). Giá trị của thiết kế là **độ sẵn sàng** và **an toàn**, **không phải tốc độ**. Nói thẳng điều này sẽ ăn điểm phản biện.
>
> **(d) Không viết lấn sang Chương 4.** Mục này chỉ nêu *nguyên lý* và *lý do*; phần hiện thực (mã, `Math.max`, bảng từ khóa) để nguyên ở 4.2.3.

&nbsp;&nbsp;*2.2.2. Nhận dạng giọng nói tự động (ASR)*

&nbsp;&nbsp;&nbsp;&nbsp;2.2.2.1. Tổng quan về ASR

&nbsp;&nbsp;&nbsp;&nbsp;2.2.2.2. ASR cho tiếng Việt

&nbsp;&nbsp;*2.2.3. Phương ngữ miền Trung và chuẩn hóa ngôn ngữ*

&nbsp;&nbsp;&nbsp;&nbsp;2.2.3.1. Đặc điểm phương ngữ miền Trung

> **⚠ CẦN SỬA — 2.2.3.1**
> **(a) Thiếu phần biến âm.** Mục này hiện **chỉ nói về lớp từ vựng** ("mô", "rứa", "chi", "bữa ni") và nhắc biến âm một câu chung chung. Nhưng nền tảng lý thuyết của đóng góp Chương 4 lại nằm ở **hiện tượng biến âm có quy luật** (vần "am"→"ôm", "a"→"oa", "ăn"→"en", phụ âm đầu "v"→"d"). Bổ sung phần biến âm với ví dụ như Bảng 4.1 của Chương 4 (làm → lồm, nhà → nhoà, già → gioà), và nêu rõ **hai nhóm hiện tượng cần hai nguồn tri thức khác nhau**: biến âm mô hình hóa được bằng luật, từ vựng riêng thì không.
>
> **(b) Bổ sung lại từ "nỏ" (= "không") vào danh sách ví dụ.** Bản trước có từ này, bản hiện tại đã bỏ. **Phải đưa lại**, vì Bảng 4.5 của Chương 4 (câu 4 và câu 5) dùng đúng từ này để chứng minh một luận điểm quan trọng: *"nỏ" là một từ phủ định phương ngữ, và nếu không được chuẩn hóa về "không" thì cơ chế xử lý phủ định ở mục 4.2.3.1 sẽ không hoạt động, dẫn tới gán sai nhãn.* Thiếu "nỏ" ở Chương 2, lập luận đó ở Chương 4 mất nền.

&nbsp;&nbsp;&nbsp;&nbsp;2.2.3.2. Kỹ thuật chuẩn hóa phương ngữ

> **⚠ CẦN SỬA — 2.2.3.2 (thiếu lý thuyết, lại thừa hiện thực)**
> **(a) Thiếu cơ sở lý thuyết.** Mục này mới mô tả *kết quả* ("từ điển hơn 26.000 mục"), không phải *phương pháp*. Bổ sung:
> - Nêu hướng **sửa lỗi đầu ra của hệ nhận dạng giọng nói bằng lớp hậu xử lý** (*post-ASR error correction*), trích dẫn **[10], [11]**.
> - Nêu điểm khác biệt của đề tài: **sinh từ điển bằng luật biến âm từ corpus tiếng Việt chuẩn (Viet74K)**, thay vì huấn luyện trên dữ liệu song song (không sẵn có) hay liệt kê thủ công.
> - Nêu lý do **không huấn luyện lại mô hình ASR**: cần kho ngữ liệu giọng nói lớn, ngoài phạm vi khóa luận.
> - Nêu nhu cầu **cập nhật từ điển nóng giữa mùa lũ** → dẫn tới kiến trúc hai lớp ở 4.2.2.
>
> **(b) Thừa phần hiện thực — cắt bớt.** Mục này đang mô tả cả thuật toán khớp tham lam trigram/bigram/unigram, cả chuyện "nạp từ điển một lần khi khởi động". Đó là **hiện thực**, đã có ở 4.2.2.4. **Xóa khỏi Chương 2** để hết trùng lặp.

&nbsp;&nbsp;*2.2.4. Hệ thống thông tin địa lý (GIS) và cơ sở dữ liệu không gian*

&nbsp;&nbsp;*2.2.5. Kiến trúc hệ thống phân tán và giao tiếp thời gian thực*

&nbsp;&nbsp;*2.2.6. Xác thực và bảo mật*

**2.3. Công nghệ sử dụng**

> **✂ NÉN — toàn bộ mục 2.3 (bỏ 7 tiểu mục 2.3.1–2.3.7)**
> **Không xóa mục 2.3** — tên chương là *"Cơ sở lý thuyết **và công nghệ liên quan**"*, bỏ hẳn thì chương hụt mất một nửa tiêu đề. Vấn đề là **cách viết**: bảy tiểu mục hiện chỉ liệt kê tính năng thư viện ("Flutter cho phép xây dựng ứng dụng với hiệu năng gần như gốc…") — đó là quảng cáo sản phẩm, không phải lập luận lựa chọn.
>
> **Thay bằng:** một đoạn văn dẫn nhập (~10 dòng) + **Bảng 2.3 ba cột**, trong đó **cột thứ ba mới là thứ có giá trị học thuật**:
>
> | Thành phần | Công nghệ | **Lý do chọn cho bối cảnh thiên tai** |
> |---|---|---|
> | Ứng dụng di động | Flutter/Dart (Android) | Một mã nguồn, hiệu năng gần gốc; hệ sinh thái đủ thư viện cho GPS, nhận dạng giọng nói, WebSocket |
> | Máy chủ | Node.js + Express | Mô hình hướng sự kiện, vào/ra không chặn — phù hợp nhiều kết nối bền vững đồng thời (WebSocket, SSE) |
> | Cơ sở dữ liệu | PostgreSQL + PostGIS | Truy vấn không gian (`ST_DWithin`, `ST_Distance`) + chỉ mục GiST là nền tảng cho toàn bộ nghiệp vụ điều phối |
> | Mô hình ngôn ngữ | Google Gemini 2.5 Flash | Zero/few-shot, không cần huấn luyện; ép được đầu ra JSON có cấu trúc |
> | Xác thực & thông báo | Firebase Auth + FCM | OTP không cần mật khẩu (phù hợp người dân đăng ký gấp); thông báo đẩy tới thiết bị đang khóa màn hình |
> | Định danh | FPT.AI eKYC | Dịch vụ sẵn có cho CCCD Việt Nam; không thuộc đóng góp của đề tài |
> | Trang quản trị | React + Vite, Leaflet/OSM | Bản đồ mã nguồn mở, không phụ thuộc khóa API bản đồ trả phí |
>
> Tiết kiệm ~1,5 trang, và **quan trọng hơn là đổi được chất**: từ liệt kê sang lập luận.

---

## CHƯƠNG 3: PHÂN TÍCH VÀ THIẾT KẾ HỆ THỐNG

> **⚠ CẦN SỬA — ĐOẠN MỞ CHƯƠNG 3 (mới phát hiện)**
> Đoạn mở chương liệt kê nội dung sẽ trình bày, trong đó có *"thiết kế giao diện lập trình ứng dụng (API) và **thiết kế giao diện người dùng**"*. Nhưng chương **không hề có mục thiết kế giao diện người dùng**, và mục API thì sắp bị chuyển xuống Phụ lục C. Viết lại câu này cho khớp với các mục thực có: phân tích yêu cầu, mô hình hóa UML, thiết kế kiến trúc, thiết kế cơ sở dữ liệu.

**3.1. Phân tích yêu cầu**

&nbsp;&nbsp;*3.1.1. Xác định các tác nhân (Actors)*

> **⚠ CẦN SỬA — 3.1.1 (mới phát hiện)**
> Tác nhân *"Hệ thống AI"* được mô tả là *"đảm nhận phân loại mức độ khẩn cấp, chuẩn hóa phương ngữ và **điều phối thông báo theo vị trí**"*. Hai lỗi:
> - Cụm *"điều phối thông báo theo vị trí"* lặp lại lỗi Geo-Dispatch (phát sóng **không** lọc bán kính).
> - **Chuẩn hóa phương ngữ chạy trên thiết bị, không phải trên máy chủ**, nên không thuộc tác nhân "Hệ thống AI" phía backend. Đây là điểm Chương 4 mục 4.1 nói rất rõ (bước 2 nằm ở phía client).
>
> Sửa thành: *"Hệ thống AI: tác nhân tự động đảm nhận phân loại mức độ khẩn cấp và điều phối, gồm phát sóng thông báo tới tình nguyện viên khả dụng, phát hiện ca mồ côi và tự thu hồi phân công."*

&nbsp;&nbsp;*3.1.2. Yêu cầu chức năng*

&nbsp;&nbsp;&nbsp;&nbsp;3.1.2.1. Chức năng cho Nạn nhân

&nbsp;&nbsp;&nbsp;&nbsp;3.1.2.2. Chức năng cho Tình nguyện viên

> **⚠ CẦN SỬA — 3.1.2.2 (mới phát hiện)**
> Gạch đầu dòng *"Nhận thông báo đẩy khi có ca SOS **ở gần**"* - sai. Bước phát sóng gửi cho **mọi** tình nguyện viên đang rảnh và bật nhận thông báo, không lọc bán kính (mục 4.3.1). Sửa: *"Nhận thông báo đẩy khi có ca SOS mới được tạo, nếu đang ở trạng thái sẵn sàng và bật nhận thông báo."*
> Yếu tố khoảng cách chỉ xuất hiện ở gạch đầu dòng kế tiếp (lọc danh sách ca theo bán kính), chỗ đó đúng rồi.

&nbsp;&nbsp;&nbsp;&nbsp;3.1.2.3. Chức năng cho Admin

> **⚠ CẦN SỬA — 3.1.2.3**
> Bổ sung chức năng **quản lý từ điển phương ngữ** (thêm/sửa/xóa mục từ, làm tăng số phiên bản để ứng dụng đồng bộ). Chức năng này đã hiện thực và là chỗ dựa cho lập luận "cập nhật nóng giữa mùa lũ" ở 4.2.2.3, nhưng Chương 3 hoàn toàn không có. Thiếu nó, hội đồng sẽ hỏi: *"quản trị viên thêm từ mới bằng cách nào, use case nào mô tả?"*
>
> **Lưu ý:** mục 3.1.2.3 hiện còn ghi *"Đăng nhập vào trang quản trị bằng tài khoản nội bộ và **xác thực OTP**"* — nhưng UC00 và mục 3.4.2 (bảng `admins`, cột `password_hash` bcrypt) đều cho thấy Admin đăng nhập bằng **email + mật khẩu**, không có OTP. Bỏ cụm "và xác thực OTP".

&nbsp;&nbsp;&nbsp;&nbsp;3.1.2.4. Chức năng tự động của hệ thống

> **⚠ CẦN SỬA — 3.1.2.4**
> **(a)** *"Phân loại mức độ khẩn cấp theo cơ chế **Parallel Race Pipeline**"* → *"theo cơ chế phân loại mức độ khẩn cấp (kết hợp dò từ khóa và mô hình ngôn ngữ lớn, có sàn an toàn)"*.
> **(b)** *"...và **tự động đóng ca** theo điều kiện"* → **SAI so với mã nguồn**. Tác vụ `autoResolve` **không đóng ca**, chỉ **cảnh báo quản trị viên xem xét** (mục 4.3.3). Sửa: *"phát hiện ca nghi ngờ đã kết thúc và chuyển quản trị viên xem xét"*.
> **(c)** Bổ sung hai chức năng tự động đang thiếu: **phát hiện ca mồ côi** (tác vụ nền quét định kỳ) và **tự thu hồi phân công** khi tình nguyện viên không tiếp cận sau 10 phút.

&nbsp;&nbsp;*3.1.3. Yêu cầu phi chức năng*

> **⚠ CẦN SỬA — 3.1.3**
> **(a) Hiệu năng.** Con số **3 giây giữ nguyên** (sau khi tắt chế độ suy luận nội tại của Gemini, phép đo cho thấy ngưỡng này phủ được 95% số ca — xem mục 4.5.1). Chỉ cần sửa **cách diễn đạt** cho chặt: *"thời gian phản hồi yêu cầu SOS dưới 3 giây"* → *"bước phân loại có thời gian chờ bị chặn cứng ở 3 giây; quá ngưỡng, hệ thống dùng ngay kết quả của nhánh dò từ khóa"*. Dẫn tới số đo thực ở mục 4.5.1.
> **(b) Khả năng mở rộng.** *"Backend **không lưu trạng thái (stateless)**"* không đúng: máy chủ WebSocket giữ danh sách phòng theo `caseId` **trong bộ nhớ tiến trình**. Sửa: *"tầng REST không lưu trạng thái; tầng WebSocket có trạng thái phiên trong bộ nhớ, còn mọi trạng thái nghiệp vụ cần bền vững đều nằm trong cơ sở dữ liệu"* — cách phát biểu này vừa đúng, vừa dẫn thẳng vào lập luận ở 4.3.1.

**3.2. Mô hình hóa hệ thống (UML)** — *(tạm gác, quyết định sau)*

> **⚠ CẦN SỬA — đoạn mở mục 3.2 (mới phát hiện, sửa được ngay dù chưa quyết định về UML)**
> Câu cuối đoạn mở ghi: *"Phần này trình bày biểu đồ Use Case tổng quát, đặc tả chi tiết các Use Case chính **và mô tả vòng đời trạng thái của ca cứu hộ**."* Nhưng **biểu đồ trạng thái đã bị bỏ** khỏi báo cáo (mục 3.2.5 cũ). Xóa vế cuối, thay bằng: *"...đặc tả chi tiết các Use Case, biểu đồ tuần tự và biểu đồ hoạt động."*

> **⚠ CẦN SỬA — Bảng 3.3 (UC02 - Gửi yêu cầu SOS) (mới phát hiện)**
> Ba chỗ trong UC02 mô tả sai cơ chế phát sóng:
> - Ô **Mô tả**: *"rồi thông báo cho TNV phù hợp **gần nhất**"*
> - Ô **Điều kiện thành công**: *"TNV phù hợp **gần nhất** nhận thông báo"*
> - **Luồng sự kiện chính, bước 6**: *"Hệ thống tìm TNV sẵn sàng **gần nạn nhân**, gửi thông báo"*
>
> Cả ba đều sai: hệ thống phát sóng cho **mọi** tình nguyện viên khả dụng, không chọn người gần nhất. Sửa thành *"phát thông báo tới mọi tình nguyện viên đang sẵn sàng"*. Đây là use case lõi, hội đồng chắc chắn đọc kỹ.

**3.3. Thiết kế kiến trúc hệ thống**

> **Giữ nguyên mục này — bắt buộc.** Một khóa luận Công nghệ phần mềm không có mục kiến trúc là thiếu đúng phần cốt lõi của ngành; hội đồng sẽ hỏi ngay câu đầu tiên *"kiến trúc hệ thống của em là gì?"*. Chỉ tỉa như ghi chú bên dưới.

&nbsp;&nbsp;*3.3.1. Kiến trúc tổng thể*

&nbsp;&nbsp;*3.3.2. Kiến trúc module hệ thống*

> **✂ NÉN + ⚠ CẦN SỬA — 3.3.2**
> **Nén:** danh sách sáu module gần như trùng với cấu trúc Chương 4 → rút xuống **một đoạn văn hoặc một hình khối**, không liệt kê dài.
> **Sửa nội dung:**
> - **Module 2** (Không gian và Phát sóng): ghi rõ bước phát sóng **không lọc bán kính** (lọc theo `is_available`, `admin_approved`, `notification_radius_km IS NULL`); `ST_DWithin` chỉ dùng ở chức năng "ca gần".
> - **Module 5** (Tự động hóa và **Đóng ca**): đổi tên thành **"Tự động hóa và giám sát vòng đời ca"** — module này **không đóng ca**.

&nbsp;&nbsp;*3.3.3. Kiến trúc giao tiếp thời gian thực* — *(gộp thêm nội dung 3.5.2 vào đây)*

> **✂ GỘP — 3.3.3**
> Đưa phần **giao thức WebSocket** (vốn ở 3.5.2) vào đây, vì việc *dùng chung một kết nối cho GPS và Chat, phân biệt bằng trường `type`* là một **quyết định kiến trúc có lý do**, đáng nằm trong thân bài. Định dạng gói tin chi tiết thì để Phụ lục.
> **Sửa lỗi trình bày:** câu *"với tình nguyện **viêlà dạng** ws://host/ws/gps?role=volunteer&..."* bị lỗi đánh máy — viết lại, trình bày hai đường kết nối thành một bảng nhỏ hai dòng (vai trò tình nguyện viên / vai trò nạn nhân).

&nbsp;&nbsp;*3.3.4. ★ Kiến trúc liên lạc đa kênh trong ca*

> **✂ TỈA — 3.3.4**
> Giữ phần **thiết kế** (vì sao ba tầng dự phòng WS → REST → gọi GSM; vì sao mã hóa số điện thoại; vì sao tự xóa tin nhắn). **Bỏ phần hiện thực** (đã trình bày ở 4.4.2) để hết trùng lặp.
>
> **⚠ MÂU THUẪN VỚI CHƯƠNG 4 (mới phát hiện).** Câu mở mục 3.3.4 viết *"hệ thống cung cấp **hai kênh** liên lạc song song"*, trong khi Chương 4 mục 4.4.2 nói rõ là **ba tầng dự phòng** (WebSocket, rồi REST khi WebSocket đứt, rồi gọi GSM). Sửa Chương 3 thành *"ba tầng liên lạc theo thứ tự dự phòng"* cho khớp. Nếu để nguyên, hội đồng đọc hai chương sẽ thấy đếm không giống nhau.

**3.4. Thiết kế cơ sở dữ liệu**

> **⚠ CẦN SỬA — câu mở mục 3.4 (mới phát hiện)**
> Câu mở ghi *"gồm **sáu bảng chính**"*. Sau khi bổ sung `dialect_terms` và `dialect_meta` (xem ghi chú 3.4.1 và 3.4.2 bên dưới), con số này phải đổi thành **tám bảng**. Đây là chỗ rất dễ quên vì nó nằm ở câu dẫn, không nằm trong danh sách.

&nbsp;&nbsp;*3.4.1. Biểu đồ thực thể – quan hệ (ERD)*

> **⚠ CẦN SỬA — Hình ERD**
> **(a)** Vẽ lại bảng `cases`: thay `text_raw` bằng **`text_normalized`** và **`text_original`**; bổ sung cột **`orphan_alerted_at`**.
>
> **(b)** Bổ sung **hai bảng mới** phục vụ quản lý từ điển phương ngữ (migration014, đã hiện thực):
> - **`dialect_terms`** — lưu các mục từ phương ngữ do admin thêm/sửa (lớp bổ sung, chồng lên bộ 26k gốc trong bundle app).
> - **`dialect_meta`** — bảng đơn hàng (single-row) chứa bộ đếm `version`, tăng đơn điệu mỗi lần admin thay đổi từ điển → app so sánh version để biết khi nào cần đồng bộ lại.
>
> Hai bảng này là nền tảng cho cơ chế "cập nhật từ điển nóng giữa mùa lũ" ở mục 4.2.2.3. **Nếu thiếu trong ERD, hội đồng sẽ hỏi: từ admin thêm lưu ở đâu, app biết lúc nào cần tải lại bằng cách nào?**

&nbsp;&nbsp;*3.4.2. Mô tả chi tiết các bảng dữ liệu*

> **⚠ CẦN SỬA — bảng `cases`, `volunteers`, và hai bảng mới `dialect_terms` + `dialect_meta`**
> **(a)** Cột `text_raw` **không còn tồn tại**. Thay bằng hai cột, kèm giải thích lý do tách (mục 4.2.1):
> - `text_normalized` — văn bản đã chuẩn hóa phương ngữ, dùng để phân loại và hiển thị;
> - `text_original` — văn bản gốc do nhận dạng giọng nói sinh ra, trước chuẩn hóa (rỗng nếu gõ tay). Cặp hai cột này là dữ liệu để đánh giá và cải thiện bộ chuẩn hóa.
>
> **(b)** Bổ sung cột **`orphan_alerted_at`** (thời điểm phát cảnh báo ca mồ côi; `NULL` = chưa từng cảnh báo — đóng vai trò cờ chống cảnh báo lặp).
>
> **(c)** Bảng `volunteers`, cột `notification_radius_km`: ghi rõ ba ngữ nghĩa `NULL` = bật nhận thông báo mọi ca / `0` = tắt / số dương = giới hạn bán kính, **và** ghi chú rằng bước phát sóng hiện chỉ gửi cho nhóm `NULL`.
>
> **(d) Bổ sung mô tả hai bảng mới — `dialect_terms` và `dialect_meta`** (migration014, đã hiện thực trong `backend/src/db/migrations.js`):
>
> | Bảng | Cột | Kiểu | Mô tả |
> |---|---|---|---|
> | **`dialect_terms`** | `dialect` *(PK)* | `TEXT` | Cách nói phương ngữ (đã lowercase) |
> | | `standard` | `TEXT NOT NULL` | Nghĩa phổ thông tương ứng |
> | | `updated_at` | `TIMESTAMPTZ` | Thời điểm tạo/sửa, mặc định `NOW()` |
> | **`dialect_meta`** | `id` *(PK)* | `INT` | Luôn = 1 (bảng đơn hàng, xem ràng buộc ở 3.4.4) |
> | | `version` | `INT NOT NULL` | Bộ đếm đơn điệu, +1 mỗi lần admin thêm/sửa/xóa từ |
>
> **Lý do thiết kế:**
> - Chỉ lưu phần admin thêm/sửa (lớp bổ sung); **không** nhân bản 26.000 mục gốc vào DB — app đã có sẵn trong bundle và merge chồng lên.
> - Dùng bộ đếm `version` riêng thay vì suy ra từ `MAX(updated_at)` vì thao tác `DELETE` sẽ làm mất dòng → không thể phát hiện xóa bằng timestamp.
> - Hai bảng này là hạ tầng cho cơ chế cập nhật từ điển nóng (mục 4.2.2.3) và nhóm endpoint `/api/dialect-dict` (Phụ lục C).

&nbsp;&nbsp;*3.4.3. Các View và chỉ mục (Index)*

> **⚠ CẦN SỬA — 3.4.3**
> Bổ sung **chỉ mục bộ phận phục vụ tác vụ quét ca mồ côi**: `(status, orphan_alerted_at, created_at)` với điều kiện `WHERE status = 'pending' AND orphan_alerted_at IS NULL`. Tác vụ chạy mỗi phút nên truy vấn của nó cần được lập chỉ mục, nếu không hội đồng có thể hỏi về chi phí quét định kỳ.

&nbsp;&nbsp;*3.4.4. Kiểu liệt kê (Enum) và ràng buộc*

> **⚠ CẦN SỬA — 3.4.4 (lỗi thiết kế ≠ hiện thực còn sót + thiếu ràng buộc bảng mới)**
>
> **(a) Enum `orphaned`.**
> Bản hiện tại **đã bỏ biểu đồ trạng thái** (mục 3.2.5 cũ), nhưng enum thì vẫn còn: `case_status` liệt kê `pending, responding, on_scene, resolved, cancelled, **orphaned**` — trong khi giá trị **`orphaned` không bao giờ được gán**. Trong `orphanCaseChecker.js`, tác vụ nền **không đổi trạng thái ca**; ca vẫn giữ `pending` để tình nguyện viên còn thấy và tiếp nhận được. "Mồ côi" là một **sự kiện cảnh báo** (`case:orphaned` phát qua SSE + đánh dấu cột `orphan_alerted_at`), **không phải một trạng thái**. Chọn một trong hai cách:
> - **Cách 1 (khuyến nghị):** bỏ `orphaned` khỏi enum, thêm migration tương ứng; cảnh báo mồ côi biểu diễn bằng cột `orphan_alerted_at`.
> - **Cách 2:** giữ trong enum nhưng **ghi chú rõ** đây là giá trị dự trữ, hiện chưa dùng.
>
> **Tuyệt đối không** để enum có `orphaned` mà thân bài lại nói ca chuyển sang trạng thái đó.
>
> **(b) Ràng buộc bảng `dialect_meta` (bổ sung mới).**
> Bảng `dialect_meta` sử dụng ràng buộc `CHECK (id = 1)` để đảm bảo **chỉ tồn tại đúng một hàng** — đây là mẫu thiết kế *single-row config table* dùng cho bộ đếm phiên bản. Cần ghi rõ ràng buộc này trong mục 3.4.4 cùng với lý do: tránh chèn trùng khi migration chạy lại (`ON CONFLICT DO NOTHING`), và đảm bảo mọi endpoint đều đọc/ghi cùng một giá trị version.

**~~3.5. Thiết kế giao diện lập trình ứng dụng (API)~~** — **✂ BỎ MỤC NÀY**

> **✂ CẮT — toàn bộ mục 3.5**
> **3.5.1 (danh sách endpoint):** đây là **tài liệu tra cứu**, không phải nội dung luận văn — không chứa lập luận, không chứa quyết định thiết kế nào để bảo vệ. **Chuyển toàn bộ xuống Phụ lục C** (thân bài vốn đã hứa *"danh sách đầy đủ được trình bày trong Phụ lục C"* — vậy thì đừng liệt kê hai lần).
> **3.5.2 (giao thức WebSocket):** **gộp vào 3.3.3** (xem ghi chú ở trên). Sau khi cắt, Chương 3 kết thúc ở mục thiết kế cơ sở dữ liệu.
>
> **⚠ Trước khi chuyển xuống Phụ lục, bổ sung nhóm endpoint đang thiếu:** **Nhóm Từ điển phương ngữ** — `GET /api/dialect-dict/version` (hỏi số phiên bản), `GET /api/dialect-dict` (tải mục từ bổ sung), `POST /api/dialect-dict` và `DELETE /api/dialect-dict/:term` (quản trị viên thêm/xóa, mỗi thao tác tăng số phiên bản). Thiếu nhóm này thì cơ chế "cập nhật từ điển nóng" ở 4.2.2.3 trở thành chức năng chưa từng được thiết kế.

---

## CHƯƠNG 4: HIỆN THỰC CÁC CƠ CHẾ CỐT LÕI CỦA HỆ THỐNG

> Đã viết lại hoàn chỉnh trong `bao_cao_chuong_4.md`. **Thay thế toàn bộ Chương 4 cũ** trong file Word, gồm việc xóa các mục "cấu trúc thư mục dự án", "mô tả từng màn hình", "TopBar/Sidebar".

**4.1. Tổng quan hiện thực** — *(không có tiểu mục; gồm sáu bước xử lý một yêu cầu SOS và Hình 4.1)*

**4.2. ★ Phân loại ca SOS từ ngôn ngữ tự nhiên**

&nbsp;&nbsp;*4.2.1. Điểm tiếp nhận: bộ điều khiển tạo ca*

&nbsp;&nbsp;*4.2.2. ★ Xử lý ngôn ngữ địa phương: chuẩn hóa phương ngữ miền Trung* — *(Bảng 4.1, Bảng 4.2, Hình 4.2, Thuật toán 4.1)*

&nbsp;&nbsp;&nbsp;&nbsp;4.2.2.1. Kiến trúc từ điển hai lớp

&nbsp;&nbsp;&nbsp;&nbsp;4.2.2.2. Sinh lớp gốc bằng luật biến âm

&nbsp;&nbsp;&nbsp;&nbsp;4.2.2.3. Cập nhật lớp bổ sung theo số phiên bản

&nbsp;&nbsp;&nbsp;&nbsp;4.2.2.4. Thuật toán chuẩn hóa khi tạo yêu cầu SOS

&nbsp;&nbsp;*4.2.3. ★ Cơ chế phân loại mức độ khẩn cấp* — *(Hình 4.3, Bảng 4.3, Bảng 4.4)*

&nbsp;&nbsp;&nbsp;&nbsp;4.2.3.1. Nhánh dò từ khóa

&nbsp;&nbsp;&nbsp;&nbsp;4.2.3.2. Nhánh mô hình ngôn ngữ lớn

&nbsp;&nbsp;&nbsp;&nbsp;4.2.3.3. Quy tắc hợp nhất và sàn an toàn

&nbsp;&nbsp;*4.2.4. Minh họa tác động của chuẩn hóa lên kết quả phân loại* — *(Bảng 4.5)*

**4.3. ★ Điều phối cứu trợ**

&nbsp;&nbsp;*4.3.1. Chiến lược phát sóng hai giai đoạn*

&nbsp;&nbsp;*4.3.2. Xếp hạng ca gần theo vị trí*

&nbsp;&nbsp;*4.3.3. Theo sát tiếp cận và tự phục hồi phân công* — *(Hình 4.4)*

**4.4. Hạ tầng thời gian thực và các thành phần vận hành**

&nbsp;&nbsp;*4.4.1. Kênh truyền thời gian thực*

&nbsp;&nbsp;*4.4.2. Liên lạc đa kênh trong ca và bảo vệ dữ liệu cá nhân*

&nbsp;&nbsp;*4.4.3. Theo dõi vị trí tiết kiệm pin*

&nbsp;&nbsp;*4.4.4. Xác thực và định danh*

**4.5. Đánh giá thực nghiệm**

&nbsp;&nbsp;*4.5.1. Độ trễ và độ sẵn sàng của cơ chế phân loại* — *(Bảng 4.6, Bảng 4.7)* — **ĐÃ ĐO XONG, số liệu đã điền**

&nbsp;&nbsp;*4.5.2. Kiểm chứng các cơ chế điều phối*

> **✔ ĐÃ HOÀN THÀNH — 4.5.1**
> Phép đo chạy trên 40 tin nhắn mô phỏng (`backend/scripts/measureAiPipeline.js`, tập dữ liệu ở `sos_test_set.json`). Kết quả đã điền vào Bảng 4.6 và Bảng 4.7. Dữ liệu thô ở `backend/scripts/output/do_tre_phan_loai.csv` → nộp kèm **Phụ lục D**.
>
> **Phép đo đã phát hiện và khắc phục một nút thắt hiệu năng:** Gemini 2.5 Flash bật chế độ suy luận nội tại mặc định, khiến độ trễ trung bình lên tới khoảng 5,6 giây - với ngưỡng 3 giây thì rất ít ca dùng được mô hình, tức cơ chế lai gần như không vận hành. Sau khi **tắt chế độ suy luận** (`thinkingConfig: { thinkingBudget: 0 }`), độ trễ giảm còn khoảng 1,2 giây và ngưỡng 3 giây phủ được **95%** số ca. Con số 3 giây trong Chương 2-3 vì vậy **không cần đổi**.
>
> **⚠ VIỆC CÒN LẠI — 4.5.2**
> Ba kịch bản kiểm chứng điều phối (ca mồ côi, thu hồi phân công, mốc tiếp cận) cần chạy thử và ghi lại kết quả quan sát được. Đây là những thứ em đã làm trong lúc phát triển, chỉ cần viết lại thành ba đoạn mô tả.
>
> Bốn hình 4.1–4.4 mới có chú thích, chưa có hình vẽ — ưu tiên vẽ **Hình 4.3** trước vì nó thể hiện đóng góp chính.

**4.6. Kết luận chương**

---

## CHƯƠNG 5: KẾT LUẬN

> Đã viết hoàn chỉnh trong `bao_cao_chuong_5.md`. **Thay thế toàn bộ phần "KẾT LUẬN VÀ HƯỚNG PHÁT TRIỂN" cũ** trong file Word.

**5.1. Kết quả đạt được** — *(ba nhóm gạch đầu dòng: Về sản phẩm / Về đóng góp kỹ thuật / Về kiến thức và kỹ năng)*

> **✔ HOÀN CHỈNH — 5.1**
> Đối chiếu trực tiếp với ba đóng góp phát biểu ở mục 1.6, số đo đã điền đầy đủ (dưới 0,1 ms cho nhánh dò từ khóa; 100% số ca được phân loại ở mọi kịch bản; 95% số ca dùng được mô hình ngôn ngữ ở ngưỡng 3 giây sau khi tắt chế độ suy luận nội tại). Không còn chỗ trống nào.

**5.2. Hạn chế** — *(không có tiểu mục; 11 gạch đầu dòng)*

> Mục này thừa nhận rằng Bảng 4.5 **chỉ khảo sát tác động của bộ chuẩn hóa lên nhánh dò từ khóa**, còn khả năng mô hình ngôn ngữ lớn tự hiểu phương ngữ thì chưa kiểm chứng. Chương 4 (mục 4.2.4, đoạn cuối về phạm vi của minh họa) đã được viết để phát biểu đúng phạm vi hẹp đó, nên hai chương không mâu thuẫn. Đây là mục có giá trị phản biện cao nhất của cả chương.
>
> **Lưu ý về tham chiếu chéo:** Chương 4 dẫn tới **mục 5.2** (không còn 5.2.1 / 5.2.2 / 5.2.3 như bản trước). Kiểm tra lại sau khi dán vào Word.

**5.3. Hướng phát triển** — *(10 gạch đầu dòng)*

> Bốn hướng đầu **khắc phục trực tiếp** các hạn chế ở 5.2 (khoảng cách theo tuyến đường, phát sóng theo vòng mở rộng dần, định lượng chất lượng từ điển, kiểm chứng đóng góp của mô hình ngôn ngữ), sau đó mới tới các hướng mở rộng. Hướng phát triển phải là **lời đáp cho hạn chế**, không phải một danh sách ước muốn rời rạc.

---

## TÀI LIỆU THAM KHẢO

> **⚠ CẦN SỬA — bổ sung ba tài liệu cho mục 2.2.3.2 và 4.2.2**
> Chương 4 đang trích dẫn **[10]**, **[11]** và **[12]**, nhưng danh mục hiện chỉ có tới **[9]**. Bổ sung (và **tự đọc lại nguyên văn trước khi đưa vào**):
> - **[10]** J. Guo, T. N. Sainath, R. J. Weiss, "A spelling correction model for end-to-end speech recognition," in *Proc. ICASSP*, 2019.
> - **[11]** R. Errattahi, A. El Hannani, H. Ouahmane, "Automatic speech recognition errors detection and correction: A review," *Procedia Computer Science*, vol. 128, pp. 32–37, 2018.
> - **[12]** Nguồn của **corpus Viet74K** (~74.000 mục từ vựng tiếng Việt), dùng ở mục 4.2.2.2 để sinh từ điển phương ngữ. Em tự tra lại đúng nguồn mình đã tải về và ghi theo chuẩn IEEE.

---

## PHỤ LỤC

- **Phụ lục A** — Mã nguồn các cơ chế cốt lõi (aiPipeline, dialect_normalizer, generateDialectDict, orphanCaseChecker, staleAssignmentChecker).
- **Phụ lục B** — Bảng từ khóa và tập luật biến âm đầy đủ.
- **Phụ lục C** — Danh sách endpoint REST đầy đủ *(chuyển từ mục 3.5.1)* và định dạng gói tin WebSocket.
- **Phụ lục D** — Tập dữ liệu thử nghiệm dùng cho mục 4.5 (tin nhắn SOS mô phỏng, câu phương ngữ kèm đáp án chuẩn).
