# Nghiên cứu và Xây dựng Nền tảng Hỗ trợ Điều phối Cứu trợ Lũ lụt tại Miền Trung dựa trên AI NLP.

> **Phạm vi nền tảng:** Ứng dụng Android (Flutter) cho Nạn nhân & TNV + Web Dashboard cho Admin.


## Role của hệ thống 

### 1. Nạn nhân (Victim)

- Là người gặp nạn và cần trợ giúp.
- **Xác thực nhẹ qua OTP số điện thoại** — không cần tạo mật khẩu, không cần điền thông tin cá nhân. Chỉ nhập SĐT → nhận mã OTP 6 số → vào thẳng màn hình SOS. Toàn bộ quá trình dưới 30 giây.
- App được cài đặt và đăng ký OTP **một lần trước mùa bão** trong điều kiện bình thường. Khi thiên tai xảy ra, Nạn nhân chỉ cần mở app và bấm SOS — không phải thực hiện bất kỳ bước đăng ký nào nữa. SĐT đã xác thực giúp TNV và Admin có thể gọi GSM trực tiếp khi mất 4G, và là cơ sở để hệ thống chống spam hiệu quả.

- **Hoạt động chính của Nạn nhân:**
Khi nạn nhân nhấn nút "Tạo SOS", một form điền thông tin sẽ hiện ra. Nạn nhân có thể kiểm tra vị trí hiện tại hoặc chọn vị trí thủ công trên bản đồ (có hỗ trợ tìm kiếm). Nạn nhân cũng có thể nhập một dòng text ngắn gọn hoặc nhấn giữ nút mic để nói — Android `SpeechRecognizer` (gói Flutter `speech_to_text`) nhận dạng giọng nói thành text ngay trên thiết bị và hiển thị vào ô nhập liệu. Nạn nhân xem lại, sửa nếu cần, rồi bấm Gửi SOS. **Chỉ có text và các siêu dữ liệu (tọa độ) được gửi lên server — không upload file audio.** AI sẽ tóm tắt nội dung text thành một dòng duy nhất hiển thị trên notification của TNV để giúp TNV ra quyết định nhanh mà không cần đọc text dài.

- **Màn hình bản đồ SOS dành cho Nạn nhân:**
Bản đồ SOS hiển thị **2 marker**:
  - 📍 **Ping đỏ** — vị trí của chính nạn nhân (cố định).
  - 🔵 **Ping xanh** — vị trí TNV đang di chuyển về phía nạn nhân. Chỉ xuất hiện khi **đã có TNV nhận ca**. Ứng dụng sử dụng **Server-Sent Events (SSE)** để lắng nghe trạng thái ca cứu hộ và **WebSocket** để stream vị trí GPS của TNV theo **thời gian thực** (độ trễ < 100ms) xuống cho nạn nhân. Nạn nhân sẽ thấy ping xanh nhích dần về phía mình một cách mượt mà. Khi mạng yếu hoặc mất kết nối WebSocket, hệ thống tự động fallback về cơ chế polling REST API mỗi 10 giây. Khi chưa có TNV nhận ca, ping xanh không hiển thị.

Nạn nhân **không thấy ping của nạn nhân khác** và **không thấy bản đồ SOS tổng thể** — nhằm tránh người không có kỹ năng tự ý đi cứu và trở thành nạn nhân tiếp theo.

Bên dưới bản đồ hiển thị **text trạng thái** cập nhật liên tục:
  - 🔴 *"Đang tìm người cứu hộ gần bạn..."* — trạng thái Pending
  - 🟡 *"Đã có người đang trên đường — cách bạn ~2.3km"* — trạng thái Responding
  - 🟠 *"Người cứu hộ còn cách bạn ~300m, hãy ra hiệu!"* — trạng thái Near (server tính distance < 300m)
  - 🟢 *"Người cứu hộ đã rất gần!"* — trạng thái On-scene (server tính distance < 100m)

- **Đóng ca chủ động:**
Nạn nhân có thể bấm nút **"Tôi đã được giúp đỡ"** bất cứ lúc nào để xóa điểm ping của mình khỏi bản đồ ngay lập tức, không cần đợi hệ thống tự đóng ca.

---

### 2. Tình nguyện viên cứu hộ (Volunteer / TNV)

- Là những người trực tiếp nhận nhiệm vụ và đi cứu hộ.
- **Bắt buộc đăng ký eKYC đầy đủ (CCCD + duyệt Admin) TRƯỚC mùa bão**, không thực hiện đăng ký trong lúc thiên tai đang xảy ra. Việc đăng ký trước giúp Admin có thời gian xem xét kỹ hồ sơ và đảm bảo pool TNV luôn sẵn sàng khi cần. Việc xác thực CCCD được thực hiện qua API eKYC của bên thứ ba.

- **Hoạt động chính của TNV:**
Nhận Push Notification tự động từ hệ thống khi có ca SOS trong bán kính gần. Nội dung notification đã được AI tóm tắt thành 1 dòng để TNV ra quyết định ngay lập tức. Có quyền tự do quyết định (họ có thể cứu trợ hoặc không, vì đó là quyền của họ) dựa trên đánh giá an toàn của bản thân. Hoặc họ có thể chủ động mở bản đồ SOS để xem các ca đang cần hỗ trợ, không nhất thiết phải đợi Notification.

- **Khai báo kỹ năng (tuỳ chọn):**
Trong quá trình đăng ký, TNV có thể khai báo kỹ năng chuyên môn (không bắt buộc): đang là bác sĩ, có kinh nghiệm y tá, có kinh nghiệm CPR... Thông tin này được AI Dispatch sử dụng để ưu tiên gửi thông báo đến TNV phù hợp khi ca SOS có tag y tế.

---

### 3. Admin

- Là đại diện của Cơ quan Nhà nước hoặc Tổ chức lớn đứng ra vận hành nền tảng (Bên thứ 3).

- **Hoạt động chính:**
  - Kiểm duyệt tính hợp pháp của Tình nguyện viên (Xem xét CCCD, phê duyệt hoặc từ chối hồ sơ đăng ký).
  - Giám sát an toàn hệ thống (Tiếp nhận Report từ Nạn nhân và khóa tài khoản vi phạm).
  - Có bản đồ toàn diện với dashboard để Điều phối & Giám sát toàn hệ thống.
  - Kế thừa giao diện và tính năng của TNV và Nạn nhân khi cần.

---

## Các Module của hệ thống

### 1. Module Tiếp nhận & Xử lý Cốt lõi (Core Ingestion & AI Module)

**Chức năng chính:**

**UI & Định vị:** Xử lý giao diện nút bấm SOS với form nhập liệu chi tiết. Nạn nhân có hai phương thức nhập text ghi chú: (1) nhập text thủ công — phương thức chính, (2) nhấn giữ nút mic → Android `SpeechRecognizer` chuyển giọng nói thành text ngay trên thiết bị (client-side STT, không upload audio lên server). Cung cấp tùy chọn mở bản đồ để kéo thả ghim tọa độ hoặc tìm kiếm địa chỉ thủ công để chống sai số GPS. Tuyệt đối không phó mặc 100% cho GPS tự động.

**Xử lý GPS Cold Start (3 lớp):** Android GPS cold start có thể mất 30–60 giây — nguy hiểm nếu user bấm SOS ngay khi mở app. Ba lớp kết hợp giải quyết vấn đề này:
- *Lớp 1 — Buffer tự nhiên:* Khi user đang gõ text hoặc nói vào mic (5–15 giây), GPS Fused Location Provider đã warm up song song trong nền và thường có fix từ cell tower/WiFi sau 3–8 giây. Đến lúc bấm "Gửi SOS", tọa độ đã sẵn sàng.
- *Lớp 2 — Khởi động GPS sớm:* Ngay khi user điều hướng đến màn hình SOS (không phải ngay khi app vào foreground) — gọi `Geolocator.getPositionStream()` với `LocationAccuracy.balanced` để warm up GPS. GPS có fix sau 3–5 giây, đến lúc user nhập xong text và bấm Gửi thì tọa độ đã sẵn sàng. Không warm up liên tục từ foreground để tiết kiệm pin.
- *Lớp 3 — `getLastKnownLocation()` làm placeholder:* Android luôn cache vị trí từ lần dùng trước. Gửi tọa độ cache đi ngay khi bấm SOS làm tọa độ tạm thời, sau đó overwrite bằng tọa độ GPS fresh khi về. TNV nhận tín hiệu ngay lập tức, tọa độ chính xác cập nhật sau vài giây.
- *Lưới an toàn:* Tùy chọn kéo thả ghim thủ công luôn có sẵn như phương án cuối cùng.

**Kiến trúc Dự phòng Mạng (2 Lớp):**

- **Lớp 1 — Tách gói tin (Split Payload):** Khi mạng yếu, hệ thống tự động tách payload thành 2 gói riêng biệt:
  - *Gói Khẩn cấp (Critical Payload, < 150 bytes):* Chỉ chứa `phone_hash` + tọa độ GPS + mức độ ưu tiên + timestamp. Gửi ngay lập tức — đây là thứ quan trọng nhất để TNV biết **ở đâu** và **mức độ nguy hiểm**.
  - *Gói Bổ sung (Enrichment Payload):* Chứa nội dung text đầy đủ, địa chỉ thủ công, tags AI. Gửi sau khi gói khẩn cấp thành công, hoặc lưu vào SQLite chờ mạng ổn định hơn.
  - Mục đích: Dù mạng chỉ đủ truyền 1 gói nhỏ, TNV vẫn nhận được tín hiệu SOS với tọa độ và mức độ nguy hiểm.

- **Lớp 2 — Hàng đợi Ngoại tuyến (Offline Queue):** Khi mất mạng 100%, lưu toàn bộ payload vào SQLite nội bộ. App sử dụng Android `WorkManager` + `ConnectivityManager` để lắng nghe sự kiện mạng trở lại và tự động đồng bộ ngay khi thiết bị có kết nối. App thông báo trấn an: *"Tín hiệu đã lưu an toàn, sẽ tự động gửi khi có sóng"* — tuyệt đối không hiển thị lỗi "Gửi thất bại".

**Xử lý AI — Tóm tắt & Phân loại Song song (Parallel Race Pipeline):**

Thay vì gọi tuần tự (tổng timeout lên đến 5+ giây), hệ thống gọi **song song đồng thời** AI và Rule-based, lấy kết quả nào về trước:

- **Nhánh A — Primary AI (Gemini API):** Nhận text từ client, trả về: `summary_1line` (tóm tắt 1 dòng cho notification), `urgency_level` (1-5), `tags[]` (y_te, tre_em, nguoi_gia...). Timeout cứng: 3 giây.
- **Nhánh B — Rule-based Regex (Local, 0.1s):** Luôn chạy song song làm baseline. Quét từ khóa cứng ("máu", "trẻ em", "ngập nóc", "bất tỉnh") để trả về `urgency_level` tối thiểu. Được dùng ngay lập tức nếu Gemini chưa về kịp hoặc timeout, đảm bảo hệ thống không bao giờ bị block.

**AI Dispatch Tối ưu hóa:** Sau khi có tags, hệ thống ưu tiên gửi notification đến TNV có kỹ năng phù hợp (VD: ca có tag `y_te` → ưu tiên TNV khai báo có CPR/y tá) trước khi broadcast toàn bộ pool TNV trong bán kính.

**Chống spam SOS:** Mỗi SĐT đã xác thực OTP chỉ được có **1 ca SOS active** tại một thời điểm. Nếu cố tạo ca thứ 2 trong khi ca cũ chưa đóng, app hiển thị: *"Bạn đang có 1 ca đang được xử lý"* và dẫn về màn hình theo dõi ca hiện tại.

**Công nghệ:** Flutter (Android, SQLite, speech_to_text, connectivity_plus, WorkManager), Node.js, Gemini API.

---

### 2. Module Không gian & Phát sóng (Geo-Spatial & Dispatch Module)

**Chức năng chính:**



**Radar & Phát sóng có tối ưu:** Truy vấn `ST_DWithin` tìm TNV trong bán kính 2-5km. Ưu tiên gửi trước cho TNV có kỹ năng phù hợp với tags của ca SOS. Sau 2 phút không có TNV phù hợp nhận, broadcast đến toàn bộ TNV trong bán kính.

**Mở rộng bán kính theo thời gian chờ:** Nếu sau 5 phút không có TNV nào nhận ca, tự động mở rộng bán kính từ 2-5km lên 10km. Sau 15 phút vẫn không có TNV, Admin nhận cảnh báo "Ca mồ côi" để can thiệp ngoại tuyến.

**Push Notification Dispatcher:** Đóng gói thông báo với nội dung tóm tắt 1 dòng từ AI và đẩy qua Firebase Cloud Messaging (FCM).

**Công nghệ:** PostgreSQL + PostGIS (`ST_DWithin`, `ST_ClusterDBSCAN`), Firebase Cloud Messaging (FCM).

---

### 3. Module Xác thực & Theo dõi Hiện trường (Auth & Field Tracking Module)

*Module này quản lý danh tính và theo dõi vị trí TNV trong suốt quá trình cứu hộ.*

**Chức năng chính:**

**Xác thực danh tính (đã hoàn thành tại bước đăng ký):** Nạn nhân đã xác thực SĐT qua OTP. TNV đã xác thực SĐT + CCCD qua eKYC. Khi TNV bấm "Tôi sẽ đi cứu", hệ thống chỉ tra cứu phiên đăng nhập sẵn có — không cần bước xác thực bổ sung. SĐT của cả 2 bên đã lưu sẵn giúp Admin kết nối GSM khi mất 4G.

**Kênh liên lạc TNV ↔ Nạn nhân — GSM là Primary:** Toàn bộ giao tiếp giữa TNV, Nạn nhân và Admin đều qua **cuộc gọi điện thoại GSM trực tiếp** — không có chat in-app, không có kênh liên lạc số nào khác. Trong tình huống lũ lụt thực tế, nạn nhân không có thời gian ngồi chat app, và GSM là kênh đáng tin cậy nhất khi 4G chập chờn. Admin luôn có SĐT thật của cả 2 bên (từ OTP + eKYC) để kết nối trực tiếp khi cần.

**Tracking GPS Thích nghi (Adaptive GPS Strategy):**

Thay vì POST cứng mỗi 7 giây bất kể trạng thái, hệ thống chia làm 3 chế độ GPS theo giai đoạn để tối ưu pin — điều kiện thiên tai khi sạc điện không có sẵn đòi hỏi thiết bị phải hoạt động được 7–10 tiếng thay vì 3–4 tiếng. Đặc biệt, khi ca ở trạng thái đang xử lý (responding), vị trí GPS của TNV được stream qua **WebSocket** để cập nhật theo **thời gian thực** cho nạn nhân, tự động fallback về REST polling nếu mất kết nối.

- **Chế độ 1 — TNV Idle (chưa nhận ca):** Tắt hoàn toàn GPS stream. Dùng `getLastKnownPosition()` cached sẵn để đăng ký vị trí tĩnh với server khi cần. Tiêu thụ GPS ≈ 0%.

- **Chế độ 2 — TNV đang di chuyển đến nạn nhân:** Thay vì timer cứng 7 giây, dùng **distance-based trigger** — chỉ POST khi đã di chuyển > 30m so với lần POST trước (`distanceFilter: 30` trong `LocationSettings`). Xuồng chạy 20 km/h ≈ 5.5 m/s → vẫn POST ~6 giây/lần khi đang chạy, nhưng **không POST khi đứng yên** (kẹt đường, chờ tín hiệu). Dùng `LocationAccuracy.balanced` (cell tower + WiFi, sai số ~100m) thay vì `high` (GPS chip full power) — tiết kiệm 60–70% điện, sai số 100m chấp nhận được ở hành trình 2–5km. Chỉ switch sang `LocationAccuracy.high` khi distance đến nạn nhân < 500m.

```dart
// Thay vì setInterval 7 giây:
Geolocator.getPositionStream(
  locationSettings: LocationSettings(
    accuracy: LocationAccuracy.balanced, // switch sang high khi < 500m
    distanceFilter: 30, // chỉ emit khi di chuyển > 30m
  ),
)
```

- **Chế độ 3 — TNV On-scene (distance < 100m):** Giảm xuống `LocationAccuracy.low`, tăng `distanceFilter` lên 100m. Lúc này không cần track mịn — chỉ cần xác nhận TNV vẫn còn tại khu vực để logic auto-close hoạt động đúng.

**Foreground Service bắt buộc:** Android 8+ kill background GPS sau 5–10 phút nếu không có Foreground Service. Khi TNV nhận ca, app bắt buộc khởi động Foreground Service với persistent notification: *"Đang cứu hộ — GPS đang hoạt động"*. Đây là điều kiện bắt buộc để GPS tracking hoạt động xuyên suốt ca cứu hộ — không làm vậy mọi tracking đều vô nghĩa sau vài phút background.

**Phía Nạn nhân:** Sau khi gửi SOS thành công, GPS của nạn nhân tắt hoàn toàn — tọa độ đã fixed, không cần cập nhật thêm. App sẽ tự động lắng nghe trạng thái ca cứu trợ qua **Server-Sent Events (SSE)**. Khi có TNV nhận ca, hệ thống mở kết nối **WebSocket** để nhận vị trí GPS của TNV theo thời gian thực và hiển thị lên bản đồ.


**Công nghệ:** Firebase Auth (OTP), FPT AI eKYC (cho TNV), HTTP POST (GPS tracking), Android Foreground Service.

---

### 4. Module Tự động hóa & Đóng ca (Automation & Resolution Module)

*Các tiến trình chạy ngầm (Background Jobs) trên Server để đóng ca, dọn rác và xử lý vi phạm.*

**Chức năng chính:**

**Ghi nhận Tiếp cận (Server-side Distance Tracking):**
Thay vì dùng Android Geo-fencing API phức tạp trên thiết bị, toàn bộ logic tính khoảng cách chạy **trên server** — không race condition, test được hoàn toàn bằng mock data, không phụ thuộc vào Android background service:

Mỗi khi server nhận GPS update từ TNV (mỗi 7 giây), background job tự động tính `distance(GPS_TNV, GPS_NạnNhân)` và xử lý theo ngưỡng:

- `distance < 500m` → cập nhật text trạng thái trên app nạn nhân: *"Người cứu hộ còn cách bạn ~500m"*
- `distance < 300m` → FCM cho nạn nhân: *"Người cứu hộ còn ~300m, hãy ra hiệu!"* + FCM cho TNV: *"Bạn sắp tới nơi, chuẩn bị tiếp cận!"* (mỗi ngưỡng chỉ gửi 1 lần)
- `distance < 100m` → text trạng thái trên app nạn nhân chuyển: *"🟢 Người cứu hộ đã rất gần!"*

Khi GPS lệch do bão (500m–1km), hệ quả chỉ là notification đến hơi sớm hoặc muộn — không crash logic, không đóng nhầm ca.

TNV luôn có thể bấm nút **"Tôi đã đến nơi"** thủ công bất kỳ lúc nào, không phụ thuộc GPS.

**Đóng ca tự động (Auto-Resolve TTL — Điều kiện kép):**
Auto-close chỉ kích hoạt khi **đồng thời** thỏa mãn cả 3 điều kiện, tránh đóng sai ca khi nạn nhân hết pin:
1. Đã qua 60 phút kể từ khi vào On-scene, **VÀ**
2. GPS của TNV đã rời khỏi khu vực (xác nhận TNV đã ra về), **VÀ**
3. Nạn nhân không phản hồi thông báo xác nhận.

Nếu GPS TNV vẫn còn trong khu vực → không đóng ca, vì nhiều khả năng vẫn đang xử lý. Nếu TNV đã rời đi mà nạn nhân không xác nhận → Admin nhận cảnh báo để review thủ công thay vì auto-close.

**Đóng ca chủ động bởi Nạn nhân:** Nạn nhân có thể bấm **"Tôi đã được giúp đỡ"** bất cứ lúc nào để đóng ca tức thì.

**Hủy ca tự động khi TNV không di chuyển:** Nếu TNV bấm nhận ca nhưng sau 10 phút GPS không ghi nhận di chuyển về phía nạn nhân, hệ thống gửi notification hỏi: *"Bạn có còn đang trên đường đến không?"*. Nếu TNV không phản hồi thêm 5 phút → hủy trạng thái "đang đến", mở lại ca cho TNV khác. TNV vi phạm nhiều lần bị gắn cờ để Admin xem xét.

**Công nghệ:** Node.js (Background Jobs, Cron).

---

### 5. Module Điều phối & Giám sát (Admin Dashboard Module)

*Nền tảng Web dành riêng cho Ban chỉ đạo, đóng vai trò "Lưới an toàn" giám sát toàn hệ thống.*

**Chức năng chính:**

**Live Command Map:** Bản đồ hiển thị cụm SOS, chấm GPS của TNV đang di chuyển. Dashboard chạy `setInterval` 15 giây gọi `GET /api/volunteers/locations` để cập nhật marker trên bản đồ — độ trễ 15 giây chấp nhận được vì xuồng chạy 20 km/h chỉ di chuyển ~80m trong khoảng thời gian đó. Trạng thái ca SOS cũng được đọc qua polling 15 giây từ REST API.

**Giám sát Điểm mù (Timeout Alerts):** Đánh dấu đỏ nhấp nháy đối với các ca SOS Mức 3-5 bị treo quá 15 phút mà biến đếm "người đang đến" vẫn là 0.

**Điều phối Can thiệp:** Admin click vào chấm TNV rảnh rỗi gần nhất để lấy SĐT gọi trực tiếp, hoặc dùng bộ đàm vô tuyến/Zalo điều động lực lượng chức năng đến tọa độ cần thiết.

**Cắm cờ cảnh báo tuyến đường:** Khi TNV gọi điện báo cáo chướng ngại vật (cây đổ, cầu sập, đường ngập), Admin click 1 chạm lên bản đồ tại tọa độ tương ứng để cắm cờ cảnh báo. Cờ này hiển thị ngay trên Bản đồ An toàn của tất cả Nạn nhân. Background job trên server tự động so sánh GPS của các TNV đang di chuyển với tọa độ cờ — nếu TNV nào tiến vào trong vòng 200m thì bắn FCM cảnh báo ngay lập tức.

**Công nghệ:** React.js, Mapbox GL JS / Leaflet, OpenStreetMap, HTTP polling (`setInterval`).

---

## Luồng của hệ thống

### GIAI ĐOẠN 1: TIẾP NHẬN ĐA PHƯƠNG THỨC & XỬ LÝ DỰ PHÒNG

**1. Mô tả luồng:**

Nạn nhân mở App — session OTP đã lưu từ trước, không cần đăng nhập lại.
  
Khi bấm nút tạo SOS, App mở ra một form nhập liệu và hiển thị vị trí (đồng thời chộp tọa độ GPS hiện tại - xem phần GPS Cold Start). Nạn nhân có thể chọn tọa độ thủ công trên bản đồ nếu muốn. Sau đó nhập text thủ công hoặc nhấn giữ nút mic → Android `SpeechRecognizer` chuyển giọng nói thành text ngay trên thiết bị → text hiện ra trong ô ghi chú → nạn nhân xem và sửa nếu cần → bấm Gửi. **Chỉ text và siêu dữ liệu được gửi lên server.**

App kiểm tra chất lượng mạng ngay lập tức để quyết định chiến lược gửi:
- Mạng ổn: gửi full payload (text + GPS + metadata).
- Mạng yếu: tách và gửi Gói Khẩn cấp trước, Gói Bổ sung sau.
- Mất mạng: lưu SQLite, WorkManager tự đồng bộ khi có sóng.

Backend nhận payload và khởi chạy **Parallel Race Pipeline**:
- Gọi Gemini API, đồng thời chạy Rule-based Regex làm baseline ngay lập tức.
- Nếu Gemini về trong 3 giây → dùng kết quả Gemini.
- Nếu Gemini timeout → Rule-based Regex đảm bảo hệ thống không bị block.

Ca SOS được lưu vào PostGIS với trạng thái `pending`, kèm: tọa độ, `urgency_level`, `tags[]`, `summary_1line`.

Sau khi gửi SOS thành công, Nạn nhân được chuyển đến màn hình theo dõi ca của bản thân.

**2. Lưu ý / Lỗ hổng:**

- *Lỗ hổng 1 — Viễn thông:* Mạng 4G/5G có nguy cơ sập hoặc chập chờn trong bão.
- *Lỗ hổng 2 — API:* Gemini API có thể timeout hoặc sập.
- *Lỗ hổng 3 — GPS trôi:* Bão lớn, trạm BTS sập làm GPS lệch 500m-1km.

**3. Giải pháp / Cách khắc phục:**

- **Mạng yếu:** Kiến trúc Split Payload đảm bảo tọa độ + mức độ nguy hiểm được gửi trước trong gói < 150 bytes, bất kể mạng tệ đến đâu.
- **Mất mạng:** Android WorkManager + SQLite offline queue, tự động sync khi có sóng. Không bao giờ hiển thị lỗi "Gửi thất bại" với nạn nhân.
- **API sập:** Parallel Race Pipeline đảm bảo Rule-based Regex luôn là lưới an toàn cuối cùng, phản hồi trong 0.1 giây.
- **GPS trôi:** Giao diện bắt buộc có tùy chọn "Kéo thả ghim trên bản đồ" hoặc ô nhập địa chỉ thủ công (VD: *"Ngã 3 cây xăng X, cuối hẻm 47"*).

---

### GIAI ĐOẠN 2: QUÉT RADAR & PHÁT SÓNG TỐI ƯU

**1. Mô tả luồng:**

Ngay khi có SOS, Backend (PostGIS) quét các ca SOS nằm gần nhau trong bán kính 20m
Truy vấn `ST_DWithin` tìm tất cả TNV đã eKYC trong bán kính 2-5km.

Hệ thống phát sóng theo thứ tự ưu tiên:
1. TNV có kỹ năng phù hợp tags của ca SOS (VD: tag `y_te` → TNV có CPR).
2. Nếu sau 2 phút không có TNV phù hợp nhận → broadcast toàn bộ TNV trong bán kính.
3. Nếu sau 5 phút không ai nhận → mở rộng bán kính lên 10km.
4. Sau 15 phút vẫn không có TNV → Admin nhận cảnh báo "Ca mồ côi".

**2. Lưu ý / Lỗ hổng:**

- *Lỗ hổng 1 — Nhiều người cùng kêu cứu:* 5 người trong cùng 1 nhà sinh ra 5 ca SOS đè lên nhau gây rối bản đồ.
- *Lỗ hổng 2 — Thiếu TNV:* Vùng sâu hoặc đầu mùa bão, pool TNV trong bán kính 2-5km có thể không đủ.

**3. Giải pháp / Cách khắc phục:**


- **Thiếu TNV:** Mở rộng bán kính động + cảnh báo "Ca mồ côi" cho Admin can thiệp ngoại tuyến. Về lâu dài, Admin cần phối hợp với Hội Chữ thập đỏ và tổ chức địa phương để vận động đăng ký TNV trong mùa khô.

---

### GIAI ĐOẠN 3: TIẾP ỨNG & GIAO TIẾP HIỆN TRƯỜNG

**1. Mô tả luồng:**

TNV nhận notification (nội dung đã được AI tóm tắt thành 1 dòng), xem bản đồ và bấm **"Tôi sẽ đi cứu"**. Hệ thống xác nhận ngay lập tức dựa trên session đã xác thực sẵn.

Bản đồ hiển thị trạng thái *"Đã có 1 người đang đến"* (Crowd-swarming — cho phép nhiều TNV cùng nhận 1 ca để dự phòng). Ca chuyển sang màu vàng (Responding).

TNV di chuyển đến điểm SOS. Liên lạc giữa TNV và Nạn nhân qua **GSM (gọi điện trực tiếp)** — Admin có SĐT thật của cả 2 bên từ OTP/eKYC để kết nối khi cần. Không có chat in-app.

**2. Lưu ý / Lỗ hổng:**

- *Lỗ hổng — Truy vết GSM:* Khi mất 4G, cần gọi điện trực tiếp. Cần SĐT thật của cả 2 bên.
- *Lỗ hổng — Hao pin TNV:* GPS tracking liên tục trong bão (không có sạc) có thể làm thiết bị cạn pin trước khi hoàn thành ca cứu hộ.

**3. Giải pháp / Cách khắc phục:**

- **Truy vết GSM:** Nạn nhân đã xác thực OTP, TNV đã xác thực eKYC — Admin luôn có SĐT thật của cả 2 bên để kết nối trực tiếp khi sập 4G.
- **Hao pin:** Áp dụng Adaptive GPS Strategy (mô tả chi tiết tại Module 3) — chuyển từ POST cứng 7 giây sang distance-based trigger 30m, dùng `LocationAccuracy.balanced` thay vì `high` trong phần lớn hành trình, tắt GPS hoàn toàn khi idle. Kết quả: pin ước tính từ ~3–4 tiếng lên ~7–10 tiếng.

---

### GIAI ĐOẠN 4: LƯỚI AN TOÀN ĐIỀU PHỐI NGOẠI TUYẾN

**1. Mô tả luồng:**

Admin (Cơ quan nhà nước/Ban điều phối) quan sát Web Dashboard giám sát toàn hệ thống.

Nếu ca Mức 3-5 nhấp nháy đỏ quá 15 phút mà biến đếm vẫn là "0 người đang đến" → Admin nhận cảnh báo tự động.

**2. Lưu ý / Lỗ hổng:**

*Lỗ hổng "Ca mồ côi":* Khu vực không có TNV, hoặc TNV nhận nhưng hủy giữa chừng. AI và phần mềm không thể tự sinh ra người cứu hộ.

**3. Giải pháp / Cách khắc phục:**

**Can thiệp Ngoại tuyến:** Admin click vào chấm TNV rảnh rỗi gần nhất để lấy SĐT gọi trực tiếp, hoặc dùng bộ đàm vô tuyến/Zalo điều động Quân đội, Lực lượng vũ trang đến tọa độ cần thiết. Admin cũng có thể cập nhật thủ công trạng thái *"Đã có lực lượng tiếp cận"* trên Dashboard sau khi điều phối xong.

---

### GIAI ĐOẠN 5: KẾT THÚC CHUYẾN CỨU TRỢ

**1. Mô tả luồng:**

Trong suốt quá trình TNV di chuyển, server liên tục tính khoảng cách từ GPS TNV đến tọa độ nạn nhân mỗi 7 giây (dùng lại GPS update đã có sẵn từ Module 3 — không cần thêm request). Khi khoảng cách thu hẹp dần, app nạn nhân cập nhật text trạng thái và nhận FCM notification theo các ngưỡng đã mô tả ở Module 4.

Khi TNV cập bến và tiếp cận được nạn nhân, ca kết thúc theo thứ tự ưu tiên sau:

- **Ưu tiên 1 — Nạn nhân bấm "Tôi đã được giúp đỡ"** → Resolved ngay lập tức. Ping đỏ biến khỏi bản đồ.
- **Ưu tiên 2 — TNV bấm "Tôi đã hoàn thành cứu hộ"** → Resolved ngay lập tức.
- **Ưu tiên 3 — Admin đóng ca từ Dashboard** → Admin quan sát GPS TNV đứng yên tại tọa độ nạn nhân > 10 phút trên Live Command Map, xác nhận qua GSM rồi đóng ca thủ công.
- **Ưu tiên 4 — Auto-close** → Sau 60 phút kể từ khi `distance < 100m` lần đầu mà không có tương tác nào từ cả 2 bên → Admin nhận alert để review thủ công thay vì tự động đóng.

Sau khi ca `resolved`: ping xanh và ping đỏ biến khỏi bản đồ, ca SOS được archive vào DB, nguồn lực TNV được giải phóng.

**2. Lưu ý / Lỗ hổng:**

- *Lỗ hổng 1 — Ghost SOS (Quên đóng ca):* Cứu xong cả 2 bên đều bận, không ai bấm "Hoàn thành". Bản đồ tồn tại ca "Đang cứu" vĩnh viễn.
- *Lỗ hổng 2 — TNV nhận ca rồi không đến:* TNV bấm nhận nhưng không di chuyển, chiếm ca khiến TNV khác bỏ qua. Rủi ro này đã được giảm thiểu nhờ eKYC — kẻ xấu phải dùng CCCD thật, tạo rào cản pháp lý rõ ràng.
- *Lỗ hổng 3 — GPS lệch trong bão:* Notification ngưỡng có thể đến sớm hoặc muộn hơn thực tế vài trăm mét.

**3. Giải pháp / Cách khắc phục:**

**Ghost SOS:** Auto-close sau 60 phút kể từ `distance < 100m` lần đầu + GPS TNV đã rời khu vực → Admin nhận alert review thủ công. Không tự động đóng nếu GPS TNV vẫn còn tại chỗ (có thể vẫn đang xử lý tình huống phức tạp).

**TNV không di chuyển:** Giữ nguyên logic — sau 10 phút nhận ca mà GPS TNV không ghi nhận di chuyển về phía nạn nhân, server gửi FCM hỏi: *"Bạn có còn đang trên đường đến không?"*. Sau 5 phút không phản hồi → hủy trạng thái "đang đến", mở lại ca cho TNV khác. TNV vi phạm nhiều lần bị gắn cờ để Admin xem xét.

**GPS lệch:** Notification chỉ là gợi ý, không phải trigger đóng ca — nên dù lệch cũng không gây hậu quả nghiêm trọng. Đóng ca thật sự luôn do con người xác nhận (nạn nhân, TNV, hoặc Admin).

---

### PHỤ LỤC: CẬP NHẬT GIAO DIỆN & TÍNH NĂNG MỚI CHO TNV

**3. Xem nhanh vị trí (Quick View):**
Ở mỗi thẻ ca SOS của TNV, cung cấp nút **"Xem vị trí"**. Khi bấm, bản đồ sẽ lập tức di chuyển camera (fly-to) đến đúng tọa độ của nạn nhân, giúp TNV không cần phải lướt map thủ công để tìm kiếm vị trí của ca đó.

**4. Bộ lọc thông minh (Smart Filter Bottom Sheet):**
TNV có khả năng thu hẹp danh sách tìm kiếm thông qua màn hình bộ lọc:
- Lọc theo **Mức độ khẩn cấp** (Từ 1 đến 5).
- Lọc theo **Khoảng cách** (giới hạn bán kính tối đa lên đến 10km qua thanh trượt Slider).
- Sắp xếp ưu tiên: **Gần đến xa / Xa đến gần** và **Mới nhất / Đợi lâu nhất**.
- Lọc theo **Tags đặc biệt** (Trẻ em, Người già, Y tế, Ngập nóc, Cần thuyền).
Tất cả các tuỳ chọn lọc này gọi trực tiếp xuống database qua API để trả về kết quả thời gian thực.

**5. Trải nghiệm người dùng theo thời gian thực (Real-time UX) và Optimistic UI:**
- **Optimistic UI:** Mọi thao tác quan trọng (Nhận ca, Đóng ca, Xác nhận An toàn) đều cập nhật giao diện ngay lập tức (instant feedback) mà không cần đợi API phản hồi. Nếu có lỗi mạng, hệ thống tự động rollback trạng thái và hiển thị thông báo lỗi. Điều này giúp loại bỏ hoàn toàn cảm giác "app bị đơ" khi sử dụng ở vùng sóng yếu.
- **Push-based Communication:** Loại bỏ hoàn toàn cơ chế polling chậm trễ. Trạng thái ca cứu hộ được push từ server xuống client thông qua **Server-Sent Events (SSE)**. Vị trí GPS của TNV được stream trực tiếp qua **WebSocket** với độ trễ dưới 100ms, giúp nạn nhân thấy rõ hành trình cứu hộ trên bản đồ theo thời gian thực. Hệ thống có cơ chế tự động fallback về polling nếu mất kết nối WebSocket.


- POST /api/volunteers/register 409 918.438 ms - 81 , lúc xác thực otp 

- bắt đầu ấn nhận ca :
[geoDispatch] Case 1332ede6-a0eb-43e6-aae5-408e1c425865: broadcast to 0 TNV (3km)
[sosController] TNV 573b9773-6b3c-4dda-88f3-90d1ae956297 accepted case 1332ede6-a0eb-43e6-aae5-408e1c425865, distance: nullm
[SSE] Emitted "case:accepted" to 1 client(s) for case 1332ede6-a0eb-43e6-aae5-408e1c425865
POST /api/case/1332ede6-a0eb-43e6-aae5-408e1c425865/accept 200 930.530 ms - 39
GET /api/case/1332ede6-a0eb-43e6-aae5-408e1c425865/stream 200 0.117 ms - -
[SSE] Client disconnected from case 1332ede6-a0eb-43e6-aae5-408e1c425865 (0 remaining)
[WS] volunteer joined room 1332ede6-a0eb-43e6-aae5-408e1c425865 (V:1 / N:0)
GET /api/cases/nearby?lat=10.6352058&lon=107.0471772&maxDistance=10.0&sortBy=distance_asc 200 136.251 ms - 415
[WS] DB save error: invalid input syntax for type uuid: "tnv-local"
GET /api/cases/nearby?lat=10.6352387&lon=107.0471809&maxDistance=10.0&sortBy=distance_asc 200 5.856 ms - 415
[WS] DB save error: invalid input syntax for type uuid: "tnv-local"
GET /api/cases/nearby?lat=10.6352387&lon=107.0471809&maxDistance=10.0&sortBy=distance_asc 200 11.624 ms - 415
[WS] DB save error: invalid input syntax for type uuid: "tnv-local"
[WS] DB save error: invalid input syntax for type uuid: "tnv-local"
GET /api/cases/nearby?lat=10.6352387&lon=107.0471809&maxDistance=10.0&sortBy=distance_asc 200 5.486 ms - 415
[WS] DB save error: invalid input syntax for type uuid: "tnv-local"
GET /api/cases/nearby?lat=10.635256&lon=107.0472065&maxDistance=10.0&sortBy=distance_asc 200 7.920 ms - 415
[WS] DB save error: invalid input syntax for type uuid: "tnv-local"
[WS] DB save error: invalid input syntax for type uuid: "tnv-local"
GET /api/cases/nearby?lat=10.6352102&lon=107.0470794&maxDistance=10.0&sortBy=distance_asc 200 1058.174 ms - 416
[WS] DB save error: invalid input syntax for type uuid: "tnv-local"

- liên tục spam

