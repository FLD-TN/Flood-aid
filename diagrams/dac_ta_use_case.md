# ĐẶC TẢ USE CASE — HỆ THỐNG FLOODAID

> Hệ thống Hỗ trợ Điều phối Cứu trợ Lũ lụt tại Miền Trung dựa trên AI NLP

---

## Tổng quan tác nhân và Use Case

| Tác nhân | Use Case |
|----------|----------|
| Nạn nhân | UC01, UC02, UC03, UC04, UC05, UC11 |
| Tình nguyện viên (TNV) | UC01, UC06, UC07, UC08, UC09, UC11, UC12 |
| Admin | UC00, UC10 |

---

## UC00 — Đăng nhập Admin

| Thuộc tính | Nội dung |
|---|---|
| **UseCase ID** | UC00 |
| **Tên UseCase** | Đăng nhập Admin |
| **Mô tả** | Admin đăng nhập hệ thống quản trị bằng email và mật khẩu được cấp. |
| **Tác nhân chính** | Admin |
| **Mức độ ưu tiên** | Cao |
| **Điều kiện kích hoạt** | Admin cần truy cập hệ thống để giám sát, xử lý ca SOS. |
| **Điều kiện tiền quyết** | Admin đã được cấp tài khoản. |
| **Điều kiện thành công** | Admin được xác thực và vào Dashboard. |
| **Luồng sự kiện chính** | 1. Admin mở Dashboard; hệ thống hiển thị form đăng nhập.<br>2. Admin nhập email, mật khẩu và nhấn "Đăng nhập".<br>3. Hệ thống kiểm tra thông tin và chuyển Admin vào Dashboard. |
| **Luồng thay thế** | Không có. |
| **Luồng ngoại lệ** | **3a** — Sai email hoặc mật khẩu: hiển thị "Email hoặc mật khẩu không đúng" (không nêu rõ trường sai), quay lại bước 2.<br>**3b** — Sai quá nhiều lần: tạm khóa đăng nhập, yêu cầu thử lại sau, kết thúc. |

---

## UC01 — Xác thực OTP

| Thuộc tính | Nội dung |
|---|---|
| **UseCase ID** | UC01 |
| **Tên UseCase** | Xác thực OTP |
| **Mô tả** | Người dùng xác thực danh tính qua OTP gửi về số điện thoại. Chỉ làm 1 lần, các lần sau tự nhận diện. |
| **Tác nhân chính** | Nạn nhân, Tình nguyện viên |
| **Mức độ ưu tiên** | Cao |
| **Điều kiện kích hoạt** | Người dùng mở app lần đầu hoặc phiên đã hết hạn. |
| **Điều kiện tiền quyết** | Đã cài app và có số điện thoại hợp lệ. |
| **Điều kiện thành công** | Xác thực thành công, app lưu phiên cho các lần sau. |
| **Luồng sự kiện chính** | 1. Người dùng mở app; hệ thống hiển thị màn hình chọn vai trò.<br>2. Người dùng chọn vai trò, nhập số điện thoại và nhấn "Gửi OTP".<br>3. Hệ thống gửi OTP về số điện thoại.<br>4. Người dùng nhập OTP; hệ thống xác thực và ghi nhận tài khoản.<br>5. Hệ thống điều hướng theo vai trò: nếu là Nạn nhân thì vào màn hình chính; nếu là TNV lần đầu thì chuyển sang đăng ký eKYC (UC06); nếu là TNV đang chờ duyệt thì hiển thị màn hình chờ; nếu là TNV đã được duyệt thì vào màn hình chính TNV. |
| **Luồng thay thế** | **3a** — Không nhận được OTP: người dùng nhấn "Gửi lại"; hệ thống gửi mã mới (tối đa 3 lần, cách nhau 60 giây); tiếp tục bước 4. |
| **Luồng ngoại lệ** | **2a** — Số điện thoại sai định dạng: báo lỗi tại ô nhập, quay lại bước 2.<br>**4a** — OTP sai: báo lỗi; chưa đủ 3 lần thì quay lại bước 4; quá 3 lần thì khóa 5 phút và kết thúc.<br>**4b** — OTP hết hạn (sau 60 giây): báo "Mã OTP đã hết hạn", quay về bước 3a. |

---

## UC02 — Gửi yêu cầu SOS

| Thuộc tính | Nội dung |
|---|---|
| **UseCase ID** | UC02 |
| **Tên UseCase** | Gửi yêu cầu SOS |
| **Mô tả** | Nạn nhân gửi tín hiệu cầu cứu kèm mô tả và vị trí. Hệ thống tự phân tích mức độ khẩn cấp bằng AI rồi phát sóng thông báo tới mọi TNV đang sẵn sàng và bật nhận thông báo. |
| **Tác nhân chính** | Nạn nhân |
| **Mức độ ưu tiên** | Rất cao — chức năng lõi |
| **Điều kiện kích hoạt** | Nạn nhân đang gặp nguy hiểm, cần cứu trợ. |
| **Điều kiện tiền quyết** | Đã xác thực OTP (UC01). Không có ca SOS nào đang hoạt động. |
| **Điều kiện thành công** | Ca SOS được tạo và lưu. Mọi TNV đang sẵn sàng và bật nhận thông báo đều nhận được thông báo. |
| **Luồng sự kiện chính** | 1. Nạn nhân nhấn nút SOS; hệ thống hiển thị form SOS (ô mô tả, nút ghi âm, bản đồ chọn vị trí).<br>2. Nạn nhân nhập mô tả tình trạng và chọn vị trí trên bản đồ (GPS tự động hoặc kéo thả ghim).<br>3. Nạn nhân nhấn "Gửi SOS".<br>4. Hệ thống kiểm tra người dùng có ca SOS đang hoạt động không (mỗi số chỉ 1 ca).<br>5. Hệ thống phân tích mô tả bằng AI (mức độ khẩn cấp 1–5, nhãn phân loại, tóm tắt 1 dòng) và lưu ca ở trạng thái "đang chờ".<br>6. Hệ thống phát sóng thông báo tới mọi TNV đang sẵn sàng và bật nhận thông báo, và chuyển nạn nhân sang màn hình theo dõi ca (UC03). |
| **Luồng thay thế** | **2a** — Nhập bằng giọng nói: nạn nhân nhấn giữ mic và nói; app chuyển giọng nói thành chữ, chuẩn hóa phương ngữ miền Trung và điền vào ô mô tả. |
| **Luồng ngoại lệ** | **2b** — Không lấy được GPS: báo lỗi; nạn nhân kéo thả ghim chọn vị trí thủ công.<br>**3a** — Mất mạng khi gửi: báo lỗi kết nối; khi có mạng, người dùng thử lại.<br>**4a** — Đã có ca SOS đang hoạt động: từ chối, báo "Bạn đang có ca SOS chưa kết thúc", kết thúc.<br>**5a** — AI không phản hồi kịp: hệ thống dùng kết quả phân tích dự phòng, tiếp tục bình thường. |

---

## UC03 — Theo dõi ca cứu hộ

| Thuộc tính | Nội dung |
|---|---|
| **UseCase ID** | UC03 |
| **Tên UseCase** | Theo dõi ca cứu hộ |
| **Mô tả** | Nạn nhân theo dõi trạng thái ca và vị trí TNV trên bản đồ theo thời gian thực; có thể liên lạc với TNV khi đã có người nhận ca. |
| **Tác nhân chính** | Nạn nhân |
| **Mức độ ưu tiên** | Cao |
| **Điều kiện kích hoạt** | Vừa gửi SOS thành công (UC02) hoặc mở lại app khi đang có ca. |
| **Điều kiện tiền quyết** | Ca SOS đã tạo (UC02), đang ở trạng thái chờ hoặc đang cứu hộ. |
| **Điều kiện thành công** | Nạn nhân nắm được tiến trình cứu hộ theo thời gian thực. |
| **Luồng sự kiện chính** | 1. Hệ thống hiển thị bản đồ vị trí nạn nhân và trạng thái ca "Đang tìm tình nguyện viên...".<br>2. Khi có TNV nhận ca, hệ thống hiển thị vị trí TNV cùng khoảng cách còn lại và cập nhật liên tục theo thời gian thực cho tới khi TNV đến nơi. |
| **Luồng thay thế** | **1a** — Sau 15 phút chưa có TNV nhận ca: báo "Chưa tìm được tình nguyện viên. Admin đã được thông báo"; tiếp tục chờ. |
| **Luồng ngoại lệ** | **2a** — Mất kết nối trực tiếp: chuyển chế độ dự phòng, cập nhật vị trí TNV định kỳ thay vì liên tục. |
| **Quy tắc nghiệp vụ** | Khi TNV đến gần (dưới 100m), hệ thống cập nhật trạng thái ca "Đã đến nơi" và thông báo cho nạn nhân. Việc gọi điện / nhắn tin với TNV thực hiện qua UC11. Diễn biến hành trình phía TNV xem UC12. |

---

## UC04 — Đóng / Hủy ca SOS

| Thuộc tính | Nội dung |
|---|---|
| **UseCase ID** | UC04 |
| **Tên UseCase** | Đóng / Hủy ca SOS |
| **Mô tả** | Nạn nhân đóng ca khi đã được cứu hộ, hoặc hủy ca khi không còn cần trợ giúp. |
| **Tác nhân chính** | Nạn nhân |
| **Mức độ ưu tiên** | Cao |
| **Điều kiện kích hoạt** | Nạn nhân đã được cứu hộ hoặc muốn hủy yêu cầu. |
| **Điều kiện tiền quyết** | Ca SOS đang hoạt động (chờ, đang cứu hộ hoặc TNV đã đến). |
| **Điều kiện thành công** | Ca chuyển sang "hoàn thành" hoặc "đã hủy". TNV trở lại sẵn sàng. Toàn bộ tin nhắn trong ca bị xóa. |
| **Luồng sự kiện chính** | 1. Nạn nhân nhấn "Tôi đã được giúp đỡ"; hệ thống hỏi xác nhận.<br>2. Nạn nhân xác nhận "Có".<br>3. Hệ thống đánh dấu ca hoàn thành, ghi thời điểm kết thúc và cập nhật TNV trở lại sẵn sàng.<br>4. Hệ thống xóa toàn bộ tin nhắn trong ca và thông báo các bên ca đã kết thúc. |
| **Luồng thay thế** | **1a** — Nạn nhân nhấn "Hủy ca": hệ thống hỏi xác nhận; nạn nhân xác nhận "Có"; hệ thống đánh dấu đã hủy và giải phóng TNV (nếu có); tiếp tục bước 4. |
| **Luồng ngoại lệ** | Không có. |

---

## UC05 — Xem lịch sử SOS

| Thuộc tính | Nội dung |
|---|---|
| **UseCase ID** | UC05 |
| **Tên UseCase** | Xem lịch sử SOS |
| **Mô tả** | Nạn nhân xem lại các ca SOS đã gửi: trạng thái, thời gian, kết quả. |
| **Tác nhân chính** | Nạn nhân |
| **Mức độ ưu tiên** | Trung bình |
| **Điều kiện kích hoạt** | Nạn nhân muốn xem lại các ca SOS đã gửi. |
| **Điều kiện tiền quyết** | Đã xác thực OTP (UC01). |
| **Điều kiện thành công** | Hệ thống hiển thị danh sách lịch sử SOS. |
| **Luồng sự kiện chính** | 1. Nạn nhân chọn "Lịch sử"; hệ thống lấy danh sách ca SOS.<br>2. Hệ thống hiển thị theo thứ tự mới nhất trước: thời gian, mô tả tóm tắt, trạng thái, mức độ khẩn cấp, nhãn phân loại và tên TNV phụ trách (nếu có). |
| **Luồng thay thế** | Không có. |
| **Luồng ngoại lệ** | **1a** — Chưa có ca SOS: hiển thị màn hình trống "Bạn chưa gửi yêu cầu SOS nào", kết thúc. |

---

## UC06 — Đăng ký TNV với eKYC

| Thuộc tính | Nội dung |
|---|---|
| **UseCase ID** | UC06 |
| **Tên UseCase** | Đăng ký TNV với eKYC |
| **Mô tả** | TNV đăng ký bằng cách xác minh danh tính qua eKYC: chụp CCCD để nhận diện thông tin, chụp selfie để đối chiếu khuôn mặt. Sau đó chờ Admin phê duyệt. |
| **Tác nhân chính** | Tình nguyện viên |
| **Mức độ ưu tiên** | Cao |
| **Điều kiện kích hoạt** | TNV muốn đăng ký tham gia hệ thống. |
| **Điều kiện tiền quyết** | Đã xác thực OTP (UC01). Chưa có tài khoản TNV. |
| **Điều kiện thành công** | Hồ sơ TNV được tạo ở trạng thái "chờ phê duyệt". |
| **Luồng sự kiện chính** | 1. TNV chọn vai trò "Tình nguyện viên"; hệ thống hiển thị form đăng ký (họ tên, số điện thoại).<br>2. TNV nhập thông tin, nhấn "Tiếp tục" và chụp mặt trước CCCD theo hướng dẫn.<br>3. Hệ thống nhận diện và trích xuất thông tin CCCD (số CCCD, họ tên, ngày sinh, giới tính, quê quán).<br>4. TNV chụp selfie theo hướng dẫn.<br>5. Hệ thống đối chiếu khuôn mặt selfie với ảnh CCCD (yêu cầu tương đồng tối thiểu 80%).<br>6. Hệ thống tạo hồ sơ TNV ở trạng thái "chờ phê duyệt" và hiển thị "Đăng ký thành công! Vui lòng chờ Admin xét duyệt". |
| **Luồng thay thế** | Không có. |
| **Luồng ngoại lệ** | **3a** — Ảnh CCCD không rõ (mờ, thiếu sáng): báo "Ảnh không đủ rõ, vui lòng chụp lại", quay lại bước 2.<br>**5a** — Khuôn mặt không khớp (dưới 80%): báo "Khuôn mặt không khớp với CCCD", cho chụp lại selfie, quay lại bước 4.<br>**\*a** — Lỗi kết nối dịch vụ nhận diện (bước 3 hoặc 5): báo lỗi; TNV nhấn "Thử lại", quay lại bước bị gián đoạn. |

---

## UC07 — Lọc danh sách ca SOS

| Thuộc tính | Nội dung |
|---|---|
| **UseCase ID** | UC07 |
| **Tên UseCase** | Lọc danh sách ca SOS |
| **Mô tả** | TNV lọc và sắp xếp danh sách ca SOS theo mức độ khẩn cấp, khoảng cách, nhãn phân loại để tìm ca phù hợp cần ưu tiên. |
| **Tác nhân chính** | Tình nguyện viên |
| **Mức độ ưu tiên** | Cao |
| **Điều kiện kích hoạt** | TNV muốn thu hẹp danh sách ca SOS theo nhu cầu. |
| **Điều kiện tiền quyết** | TNV đã được duyệt và đang ở trạng thái sẵn sàng. |
| **Điều kiện thành công** | Danh sách được lọc và sắp xếp đúng theo tiêu chí đã chọn. |
| **Luồng sự kiện chính** | 1. TNV nhấn biểu tượng Lọc; hệ thống hiển thị bảng lọc (mức độ khẩn cấp 1–5, khoảng cách tối đa, nhãn phân loại).<br>2. TNV chọn tiêu chí lọc và nhấn "Áp dụng".<br>3. Hệ thống lọc và cập nhật danh sách.<br>4. TNV chọn tiêu chí sắp xếp (gần trước / xa trước / mới trước / cũ trước); hệ thống sắp xếp lại danh sách.<br>5. TNV chọn 1 ca; hệ thống hiển thị chi tiết: mô tả, vị trí trên bản đồ, mức độ khẩn cấp, nhãn phân loại, thời gian gửi. |
| **Luồng thay thế** | **2a** — TNV nhấn "Đặt lại bộ lọc": xóa toàn bộ tiêu chí, hiển thị lại danh sách đầy đủ. |
| **Luồng ngoại lệ** | **1a** — Không có ca SOS nào: báo "Hiện không có ca SOS nào đang chờ cứu hộ", kết thúc.<br>**3a** — Không có ca khớp bộ lọc: báo "Không có ca phù hợp" và gợi ý mở rộng tiêu chí; TNV chỉnh lại từ bước 2. |

---

## UC08 — Nhận ca cứu hộ

| Thuộc tính | Nội dung |
|---|---|
| **UseCase ID** | UC08 |
| **Tên UseCase** | Nhận ca cứu hộ |
| **Mô tả** | TNV nhận một ca SOS để cứu hộ. Hệ thống cập nhật trạng thái, báo cho nạn nhân và cung cấp số điện thoại hai bên để liên lạc. |
| **Tác nhân chính** | Tình nguyện viên |
| **Mức độ ưu tiên** | Rất cao |
| **Điều kiện kích hoạt** | TNV nhận thông báo có ca SOS mới hoặc tự tìm thấy ca (UC07). |
| **Điều kiện tiền quyết** | TNV đã được duyệt, đang sẵn sàng, chưa có nhiệm vụ. Ca SOS đang ở trạng thái chờ. |
| **Điều kiện thành công** | Ca chuyển sang "đang cứu hộ". Phân công được tạo. Hai bên nhận được số điện thoại của nhau. |
| **Luồng sự kiện chính** | 1. TNV nhận thông báo có ca SOS mới hoặc chọn ca từ danh sách (UC07).<br>2. Hệ thống hiển thị chi tiết ca: mô tả, mức độ khẩn cấp, vị trí, khoảng cách.<br>3. TNV nhấn "Tôi sẽ đi cứu".<br>4. Hệ thống ghi nhận phân công, lưu khoảng cách ban đầu, cập nhật ca sang "đang cứu hộ" và TNV sang "đang thực hiện nhiệm vụ".<br>5. Hệ thống cung cấp số điện thoại cho cả hai bên, báo nạn nhân có TNV đang đến, và chuyển TNV sang màn hình theo dõi cứu hộ. |
| **Luồng thay thế** | Không có. |
| **Luồng ngoại lệ** | **3a** — Ca đã có TNV khác nhận: báo "Ca này đã có người nhận", quay về danh sách (mỗi ca chỉ 1 TNV).<br>**3b** — TNV đang có nhiệm vụ chưa xong: từ chối, báo "Bạn đang có nhiệm vụ chưa kết thúc", kết thúc. |

---

## UC09 — Xem lịch sử cứu hộ

| Thuộc tính | Nội dung |
|---|---|
| **UseCase ID** | UC09 |
| **Tên UseCase** | Xem lịch sử cứu hộ |
| **Mô tả** | TNV xem lại các ca đã tham gia cùng bảng thống kê hoạt động cá nhân. |
| **Tác nhân chính** | Tình nguyện viên |
| **Mức độ ưu tiên** | Trung bình |
| **Điều kiện kích hoạt** | TNV muốn xem lịch sử và thống kê cá nhân. |
| **Điều kiện tiền quyết** | TNV đã đăng ký và xác thực OTP (UC01). |
| **Điều kiện thành công** | Hệ thống hiển thị lịch sử và thống kê cứu hộ. |
| **Luồng sự kiện chính** | 1. TNV chọn "Lịch sử cứu hộ"; hệ thống lấy dữ liệu lịch sử và thống kê.<br>2. Hệ thống hiển thị thống kê: tổng số ca, số ca hoàn thành, số ca đã từ bỏ, tổng quãng đường (km), thời gian phản hồi trung bình.<br>3. Hệ thống hiển thị 100 ca gần nhất: thời gian, mô tả ngắn, kết quả, khoảng cách ban đầu.<br>4. TNV chọn 1 ca; hệ thống hiển thị thời gian nhận ca và thời gian hoàn thành. |
| **Luồng thay thế** | Không có. |
| **Luồng ngoại lệ** | **1a** — Chưa có lịch sử cứu hộ: hiển thị thống kê toàn 0 và danh sách trống, kết thúc. |

---

## UC10 — Duyệt hồ sơ TNV

| Thuộc tính | Nội dung |
|---|---|
| **UseCase ID** | UC10 |
| **Tên UseCase** | Duyệt hồ sơ TNV |
| **Mô tả** | Admin phê duyệt hoặc từ chối hồ sơ TNV sau khi eKYC đã xác minh danh tính. |
| **Tác nhân chính** | Admin |
| **Mức độ ưu tiên** | Cao |
| **Điều kiện kích hoạt** | Có hồ sơ TNV mới hoàn thành eKYC, đang chờ duyệt. |
| **Điều kiện tiền quyết** | Admin đã đăng nhập (UC00). Có ít nhất 1 hồ sơ chờ duyệt. |
| **Điều kiện thành công** | Hồ sơ được duyệt (TNV có thể nhận ca) hoặc bị từ chối (TNV không được hoạt động). |
| **Luồng sự kiện chính** | 1. Admin mở trang "Quản lý Tình nguyện viên"; hệ thống hiển thị danh sách TNV chờ duyệt (họ tên, số điện thoại, trạng thái xác minh CCCD).<br>2. Admin chọn 1 hồ sơ để xem chi tiết.<br>3. Hệ thống hiển thị chi tiết hồ sơ: họ tên, số điện thoại, trạng thái eKYC.<br>4. Admin nhấn "Phê duyệt" hoặc "Từ chối"; hệ thống cập nhật trạng thái hồ sơ. |
| **Luồng thay thế** | Không có. |
| **Luồng ngoại lệ** | Không có. |

---

## UC11 — Liên lạc trong ca

| Thuộc tính | Nội dung |
|---|---|
| **UseCase ID** | UC11 |
| **Tên UseCase** | Liên lạc trong ca |
| **Mô tả** | Nạn nhân và TNV nhắn tin thời gian thực qua màn hình chat trong app; có thể gọi điện trực tiếp. Tin nhắn tự xóa khi ca kết thúc để bảo vệ thông tin cá nhân. |
| **Tác nhân chính** | Nạn nhân, Tình nguyện viên |
| **Mức độ ưu tiên** | Cao |
| **Điều kiện kích hoạt** | Nạn nhân hoặc TNV muốn nhắn tin trong quá trình cứu hộ. |
| **Điều kiện tiền quyết** | Ca đang ở trạng thái "đang cứu hộ". Hai bên đã có số điện thoại của nhau (UC08). |
| **Điều kiện thành công** | Hai bên trao đổi được thông tin để phối hợp cứu hộ. |
| **Luồng sự kiện chính** | 1. Người dùng nhấn "Nhắn tin"; hệ thống mở màn hình chat và tải lịch sử (tối đa 100 tin gần nhất).<br>2. Người dùng nhập nội dung và nhấn Gửi.<br>3. Hệ thống gửi tin đến đối phương, lưu lại và hiển thị ngay ở cả hai bên.<br>4. Người dùng đóng chat; hệ thống giữ kết nối nền và hiện badge tin chưa đọc. |
| **Luồng thay thế** | **1a** — Mở lại chat sau khi đóng: hệ thống tải lại lịch sử và đồng bộ tin mới; tiếp tục bước 2. |
| **Luồng ngoại lệ** | **\*a** — Mất mạng khi đang nhắn tin (bước 3–4): trạng thái chuyển "Ngoại tuyến"; tin nhắn được gửi qua kênh dự phòng và vẫn đến đối phương; người dùng không thấy thông báo lỗi, tiếp tục bình thường khi có mạng. |

---

## UC12 — Theo dõi hành trình cứu hộ

| Thuộc tính | Nội dung |
|---|---|
| **UseCase ID** | UC12 |
| **Tên UseCase** | Theo dõi hành trình cứu hộ |
| **Mô tả** | TNV theo dõi vị trí nạn nhân trên bản đồ và di chuyển đến nơi; hệ thống cập nhật trạng thái tiếp cận theo thời gian thực. Có thể liên lạc với nạn nhân khi cần. |
| **Tác nhân chính** | Tình nguyện viên |
| **Mức độ ưu tiên** | Cao |
| **Điều kiện kích hoạt** | TNV vừa nhận ca (UC08) hoặc mở lại app khi đang thực hiện nhiệm vụ. |
| **Điều kiện tiền quyết** | Ca đang ở trạng thái "đang cứu hộ" và TNV là người phụ trách. |
| **Điều kiện thành công** | TNV đến được vị trí nạn nhân; trạng thái ca cập nhật "Đã đến nơi". |
| **Luồng sự kiện chính** | 1. TNV mở màn hình theo dõi hành trình; hệ thống hiển thị bản đồ vị trí nạn nhân và TNV cùng số điện thoại nạn nhân.<br>2. TNV di chuyển đến vị trí nạn nhân; hệ thống cập nhật vị trí liên tục theo thời gian thực.<br>3. Khi TNV đến gần, hệ thống cập nhật trạng thái tiếp cận; TNV có thể tùy chọn liên lạc nạn nhân (**1a**).<br>4. Khi TNV đến nơi, hệ thống cập nhật trạng thái ca "Đã đến nơi" và thông báo cho cả hai bên. |
| **Luồng thay thế** | **1a** — Liên lạc nạn nhân (tùy chọn, trong khi di chuyển): TNV chọn gọi điện hoặc nhắn tin với nạn nhân; mở UC11; sau đó tiếp tục luồng chính.<br>**1b** — Từ bỏ nhiệm vụ (trước khi di chuyển): TNV nhấn "Từ bỏ nhiệm vụ" và xác nhận; hệ thống trả ca về trạng thái chờ, cập nhật TNV về sẵn sàng; kết thúc. |
| **Luồng ngoại lệ** | **2a** — Mất kết nối trực tiếp: chuyển chế độ dự phòng, cập nhật vị trí định kỳ thay vì liên tục. |

---

## Bảng tổng hợp quan hệ «extend»

| UC nguồn | Loại | UC đích | Mô tả |
|----------|------|---------|-------|
| UC11 Liên lạc trong ca | «extend» | UC03 Theo dõi ca | Sau khi có TNV nhận ca, nạn nhân có thể nhắn tin hoặc gọi điện |
| UC11 Liên lạc trong ca | «extend» | UC12 Theo dõi hành trình | Khi đang di chuyển, TNV có thể nhắn tin hoặc gọi nạn nhân |

---

## Ma trận Actor — Use Case

| Use Case | Nạn nhân | TNV | Admin |
|----------|:--------:|:---:|:-----:|
| UC00: Đăng nhập Admin | | | ✓ |
| UC01: Xác thực OTP | ✓ | ✓ | |
| UC02: Gửi yêu cầu SOS | ✓ | | |
| UC03: Theo dõi ca cứu hộ | ✓ | | |
| UC04: Đóng / Hủy ca SOS | ✓ | | |
| UC05: Xem lịch sử SOS | ✓ | | |
| UC06: Đăng ký eKYC | | ✓ | |
| UC07: Lọc danh sách ca SOS | | ✓ | |
| UC08: Nhận ca cứu hộ | | ✓ | |
| UC09: Xem lịch sử cứu hộ | | ✓ | |
| UC10: Duyệt hồ sơ TNV | | | ✓ |
| UC11: Liên lạc trong ca | ✓ | ✓ | |
| UC12: Theo dõi hành trình cứu hộ | | ✓ | |
