<img width="300" height="200"  style="display: block; margin-left: auto; margin-right: auto;" alt="Logo ĐH Ngoại Ngữ - Tin Học - HUFLIT" src="https://github.com/user-attachments/assets/c9365500-f365-4262-bf2a-317bc5141475" />

  # Nghiên cứu và xây dựng Nền tảng Hỗ trợ Điều phối Cứu trợ Lũ lụt tại Miền Trung dựa trên AI NLP
  
  **Khóa luận Tốt nghiệp - Khoa Công nghệ Thông tin, Đại học Ngoại ngữ - Tin học TP.HCM (HUFLIT)**<br>
  *Sinh viên: Trần Anh Duy | Giảng viên hướng dẫn: ThS. Lê Thị Minh Nguyện*

  [![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev/)
  [![Node.js](https://img.shields.io/badge/Node.js-43853D?style=for-the-badge&logo=node.js&logoColor=white)](https://nodejs.org/)
  [![PostgreSQL](https://img.shields.io/badge/PostGIS-316192?style=for-the-badge&logo=postgresql&logoColor=white)](https://postgis.net/)
  [![React](https://img.shields.io/badge/React-20232A?style=for-the-badge&logo=react&logoColor=61DAFB)](https://reactjs.org/)
  ![Google Gemini](https://img.shields.io/badge/google%20gemini-%238E75B2.svg?style=for-the-badge&logo=google%20gemini&logoColor=white)
</div>

---

## 📖 Giới thiệu Dự án

**FloodAid** là hệ thống điều phối cứu trợ khẩn cấp theo thời gian thực (Real-time), thiết kế riêng cho vùng lũ lụt Miền Trung. Hệ thống giải quyết bài toán tiếp nhận thông tin kêu cứu, tự động chuẩn hóa phương ngữ, đánh giá mức độ khẩn cấp bằng Trí tuệ Nhân tạo (AI NLP) và điều phối lực lượng Tình nguyện viên (TNV) dựa trên vị trí địa lý (GIS).

Dự án được phát triển nhằm rút ngắn tối đa thời gian từ lúc nạn nhân phát tín hiệu (SOS) đến khi lực lượng cứu hộ tiếp cận, hoạt động ổn định ngay cả trong điều kiện mạng viễn thông chập chờn của mùa bão lũ.

## 🚀 Kiến trúc & Công nghệ (Tech Stack & Architecture)

Hệ thống được thiết kế theo kiến trúc Client-Server với các module chuyên biệt:

### 1. Backend & Database (Node.js/Express)
- **Cơ sở dữ liệu:** PostgreSQL + **PostGIS** để lưu trữ tọa độ (SRID 4326) và thực hiện truy vấn không gian (`ST_DWithin`, `ST_Distance`) tối ưu bằng chỉ mục `GiST`.
- **Giao tiếp Real-time:** Phân tách luồng dữ liệu thông minh:
  - **Server-Sent Events (SSE):** Đẩy thông báo trạng thái ca siêu nhẹ, tiết kiệm pin.
  - **WebSocket:** Streaming tọa độ GPS của TNV thời gian thực & Chat In-app.
  - **Fallback:** Tự động chuyển qua REST polling khi đứt kết nối WebSocket (Offline-first approach).

### 2. FrontEnd & Mobile App
- **Mobile App (Nạn nhân & TNV):** Phát triển bằng Flutter/Dart. Tích hợp bản đồ **VietMap** (dữ liệu hẻm, phố Việt Nam chính xác hơn OpenStreetMap).
- **Admin Dashboard:** React + Vite + Leaflet, cung cấp "Live Command Map" giám sát toàn cảnh.

### 3. AI Pipeline & Định danh
- **Parallel Race Pipeline:** Kết hợp dò từ khóa (Rule-based) và Mô hình ngôn ngữ lớn (**Gemini 2.5 Flash** dạng few-shot learning). Luôn lấy mức khẩn cấp (1-5) cao hơn giữa 2 nhánh để làm "sàn an toàn", đảm bảo không bao giờ bỏ sót ca nguy kịch kể cả khi API AI bị lỗi (timeout cứng 3s).
- **Dialect Normalizer (On-device):** Thuật toán chuẩn hóa phương ngữ Miền Trung (tham chiếu từ điển *Viet74K*) chạy cục bộ trên Android bằng thuật toán *Greedy longest-match*, giúp sửa lỗi nhận dạng giọng nói (ví dụ: *"nước lên răng mà nhanh rứa"* ➔ *"nước lên sao mà nhanh thế"*).
- **eKYC:** Tích hợp **FPT.AI** (OCR & FaceMatch >= 80%) để xác minh danh tính Tình nguyện viên qua Căn cước công dân.

---

## 💡 Điểm nhấn Kỹ thuật (Technical Highlights)

- ⚡ **Xử lý bất đồng bộ & Tác vụ nền (Cron Jobs):** 
  - Tự động phát hiện **"Ca mồ côi"** (Orphan Cases) sau 15 phút không có TNV nhận, cảnh báo trực tiếp cho Admin.
  - Tự động **Thu hồi phân công** nếu TNV đã nhận ca nhưng 10 phút không di chuyển về phía nạn nhân (thuật toán dựa trên quãng đường chim bay).
- 🔐 **Bảo mật & Quyền riêng tư:** Xác thực OTP qua Firebase Auth. Mã hóa AES-256-GCM số điện thoại và CCCD trong database. Số điện thoại chỉ được cấp cho 2 bên khi TNV đã nhận ca. Hỗ trợ nhắn tin In-app an toàn (tự động xóa lịch sử khi đóng ca).
- 📍 **Smart Notification Radius (Geo-Dispatch):** Phát sóng Push Notification (FCM) linh hoạt cho các TNV đang khả dụng, hạn chế việc bỏ sót nạn nhân.

---

## 📸 Screenshots / Demo

| Nạn nhân tạo 1 ca SOS | Theo dõi ca cứu hộ | Nhắn tin thời gian thực |
| :---: | :---: | :---: |
|<img width="320" height="640" alt="image" src="https://github.com/user-attachments/assets/cd6b337f-c9d2-44be-8baa-fb84650f6876" />|<img width="320" height="640" alt="image" src="https://github.com/user-attachments/assets/35ca7d48-4bdb-4824-acd4-ce61e7537b58" />|<img width="320" height="640" alt="image" src="https://github.com/user-attachments/assets/1aff837a-f743-4f54-97ec-b17be7e3b830" />

---

## ⚙️ Cài đặt & Khởi chạy (Local Setup)

```bash
# 1. Clone repository
git clone https://github.com/your-username/FloodAid.git

# 2. Cấu hình Database & Backend
# Yêu cầu cài đặt PostgreSQL và extension PostGIS
cd FloodAid/backend
npm install
# Sửa file .env với thông tin DB, Firebase, Gemini API, VietMap API
npm run dev

# 3. Chạy Mobile App
cd ../mobile
flutter pub get
flutter run

# 4. Chạy Web Admin Dashboard
cd ../admin-web
npm install
npm run dev
```

---
