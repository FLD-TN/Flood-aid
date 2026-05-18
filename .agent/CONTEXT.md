# CONTEXT.md — Domain Knowledge & Bối cảnh dự án

> File này giúp AI Agent hiểu ngữ cảnh thực tế của dự án.
> Đọc khi cần hiểu WHY đằng sau các quyết định thiết kế.

---

## 1. Bối cảnh thực tế

- **Địa bàn:** Miền Trung Việt Nam — vùng hay xảy ra lũ lụt nghiêm trọng hàng năm
- **Điều kiện sử dụng:** Giữa cơn bão, mạng 4G chập chờn hoặc sập, nguồn điện mất, người dùng căng thẳng
- **Người dùng cuối:** Dân địa phương (ít tech-savvy), tình nguyện viên (đa dạng kỹ năng)
- **Thời điểm thiết kế:** Đăng ký và chuẩn bị TRƯỚC mùa bão; kích hoạt TRONG thiên tai

## 2. Tại sao các quyết định quan trọng được đưa ra

### Tại sao chỉ gửi TEXT, không upload audio?
→ Trong bão, mạng chỉ đủ gửi vài KB. Audio file = vài MB = timeout. Text < 500 bytes luôn gửi được.

### Tại sao dùng GSM thay vì chat in-app?
→ Khi 4G sập, GSM qua mạng điện thoại vẫn hoạt động (2G fallback). Chat in-app = cần 4G = vô dụng khi cần nhất.

### Tại sao cần Foreground Service?
→ Android 8+ (Oreo+) tự động kill background process để tiết kiệm pin. Nếu không có Foreground Service, GPS của TNV sẽ tắt sau 5–10 phút, bản đồ Admin mất tín hiệu hoàn toàn.

### Tại sao server-side distance thay vì Android Geofencing?
→ Android Geofencing không đáng tin trong điều kiện GPS lệch. Server-side = có thể mock test hoàn toàn, không phụ thuộc phần cứng, không race condition giữa app và server.

### Tại sao Parallel Race Pipeline thay vì gọi tuần tự?
→ Nếu gọi tuần tự: Gemini timeout 3s + Regex 0.1s = 3.1s minimum. Parallel: max(Gemini, Regex) = ~0.1s nếu Gemini sập. Trong thiên tai, 3 giây delay = có thể là sự khác biệt sống còn.

### Tại sao cluster bán kính 20m?
→ Trong 1 căn nhà lũ ngập, có thể 5 người cùng bấm SOS. Không cluster → bản đồ Admin rối với 5 chấm đỏ chồng lên nhau, tạo ảo giác "cứu xong rồi" cho TNV khác bỏ qua.

### Tại sao Split Payload (< 150 bytes critical)?
→ Trong mạng yếu (EDGE/2G), MTU thấp. Gói nhỏ < 150 bytes có xác suất gửi thành công cao hơn rất nhiều so với gói 2KB. Chỉ cần tọa độ + urgency level là đủ để TNV phản ứng ngay.

---

## 3. Các tình huống thực tế cần xử lý đặc biệt

### Tình huống A: 5G người trong 1 nhà cùng bấm SOS
```
Xử lý: PostGIS ST_ClusterDBSCAN(radius=20m) gộp thành 1 cluster
Hiển thị: "[KHẨN CẤP] Cụm nạn nhân: ~5 người tại khu vực này"
```

### Tình huống B: TNV bấm nhận ca nhưng không di chuyển
```
Phát hiện: Server check GPS movement sau 10 phút nhận ca
Action 1: FCM hỏi "Bạn có còn đang trên đường đến không?"
Action 2: +5 phút không phản hồi → hủy assignment, mở lại ca
Action 3: Gắn flag vi phạm → Admin xem xét revoke eKYC
```

### Tình huống C: Gemini API down giữa đêm bão lớn
```
Xử lý: Rule-based Regex đã chạy song song, có kết quả ngay lập tức
Keyword triggers: "máu" | "bất tỉnh" → urgency 5
                  "trẻ em" | "người già" → urgency 4 + tag tre_em/nguoi_gia
                  "ngập nóc" | "mái nhà" → urgency 4
                  "cần xuồng" → tag phương tiện
```

### Tình huống D: GPS nạn nhân lệch 500m do bão làm sập BTS
```
Xử lý: UI bắt buộc có ô nhập địa chỉ thủ công + kéo ghim bản đồ
        Notification ngưỡng chỉ là gợi ý, không trigger đóng ca
        Đóng ca thật sự = con người xác nhận (nạn nhân, TNV, hoặc Admin)
```

### Tình huống E: Vùng không có TNV (orphan case)
```
Threshold: Mức 3-5, > 15 phút, 0 người đang đến
Action: Admin nhận alert tự động
Response: Admin gọi GSM cho TNV rảnh gần nhất,
          hoặc điều động Quân đội/Hội Chữ thập đỏ qua bộ đàm
```

---

## 4. UX/UI Guidelines cho Nạn nhân

```
Nguyên tắc: UX trong trạng thái hoảng loạn, tay ướt, màn hình mưa
  - Nút SOS: TO, màu đỏ, không có confirm dialog phức tạp
  - Text status: màu đơn, dễ đọc trong ánh sáng xấu
  - KHÔNG có toast "lỗi mạng" → chỉ "đang lưu, sẽ gửi khi có sóng"
  - KHÔNG yêu cầu nhập thông tin phức tạp khi panic

Màu trạng thái:
  🔴 Pending: "Đang tìm người cứu hộ gần bạn..."
  🟡 Responding: "Đã có người đang trên đường — cách bạn ~Xkm"
  🟠 Near (<300m): "Người cứu hộ còn cách bạn ~300m, hãy ra hiệu!"
  🟢 On-scene (<100m): "Người cứu hộ đã rất gần!"
```

---

## 5. Các từ khóa domain quan trọng

| Từ khóa | Nghĩa trong hệ thống |
|---------|---------------------|
| Ca SOS / Case | Một yêu cầu cứu trợ đang active |
| TNV | Tình nguyện viên cứu hộ (Volunteer) |
| Nạn nhân | Victim — người cần cứu hộ |
| eKYC | Xác thực danh tính điện tử qua CCCD (FPT AI API) |
| Ca mồ côi | Orphan case — ca không có TNV nhận sau 15 phút |
| Ghost SOS | Ca cứu xong nhưng không ai bấm đóng |
| Cờ cảnh báo | Warning flag — điểm nguy hiểm trên bản đồ |
| Bán kính | Search radius cho ST_DWithin query |
| Cluster | Nhóm các ca SOS gần nhau (< 20m) |
| Cold start | GPS chưa có fix khi mới mở app |

---

## 6. Giới hạn & Không phải scope của dự án

```
NGOÀI SCOPE (không implement):
  ✗ iOS app
  ✗ Chat in-app giữa TNV và Nạn nhân  
  ✗ Payment / donation system
  ✗ AI tự động điều phối hoàn toàn (AI hỗ trợ, con người quyết định cuối)
  ✗ Tích hợp dữ liệu thời tiết real-time
  ✗ Multi-language (chỉ tiếng Việt)
  ✗ Bản đồ vệ tinh cập nhật real-time

TRONG SCOPE:
  ✓ Android app (Flutter)
  ✓ Web admin dashboard
  ✓ AI tóm tắt + phân loại SOS (Gemini API)
  ✓ Geospatial dispatch (PostGIS)
  ✓ FCM push notification
  ✓ GPS tracking + adaptive battery
  ✓ eKYC tích hợp FPT AI
  ✓ Offline resilience (SQLite + WorkManager)
```
