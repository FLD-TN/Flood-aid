# Cập nhật báo cáo KLTN cho tích hợp VietMap

> Tài liệu này liệt kê **chính xác các chỗ cần sửa** trong báo cáo và cung cấp **đoạn văn viết sẵn theo văn phong khóa luận** để chép vào. Đọc kỹ Phần 0 trước khi sửa.

---

## Phần 0 — Phạm vi và lưu ý (đọc trước)

1. **VietMap được tích hợp ở: ứng dụng di động (Flutter) và backend.** Trang quản trị (React) **vẫn dùng Leaflet/OpenStreetMap — chưa thay**. Do đó các câu trong báo cáo nói *trang quản trị dùng Leaflet/OpenStreetMap* (Bảng 2.3, mục 5.1) **vẫn đúng — GIỮ NGUYÊN**, đừng sửa.
2. **Điều đã thay:** ứng dụng di động trước đây render bản đồ bằng `flutter_map` (bản Flutter của Leaflet) với tile **OpenStreetMap**, tìm địa chỉ bằng **Nominatim (OSM)**. Nay: tile nền đổi sang **VietMap**, và bổ sung các dịch vụ VietMap (Reverse, Autocomplete, Place) đi qua backend.
3. **Tính trung thực (Lời cam đoan):** phần tích hợp VietMap ở backend đã kiểm thử chạy thật; phần app đã biên dịch không lỗi nhưng **nên chạy thử trên máy/emulator Android để xác nhận trước khi mô tả là "đã hiện thực"** trong khóa luận.
4. **Về khoảng cách:** phần điều phối và xếp hạng ca trong Chương 4 vẫn dùng khoảng cách đường chim bay (`ST_Distance`); VietMap không thay đổi logic này. Nhờ vậy phần Hạn chế (5.2) và Hướng phát triển (5.3) nói về "đường chim bay" **vẫn đúng, giữ nguyên**.
5. **Không đề cập tính năng vẽ tuyến đường (VietMap Route).** Code có tích hợp Route để vẽ đường đi TNV↔nạn nhân, nhưng **không đưa vào bất kỳ bản báo cáo nào** theo yêu cầu. Mọi mô tả VietMap trong khoá luận chỉ gồm: tile nền, Reverse (toạ độ→địa chỉ), Autocomplete + Place (nhập địa chỉ có gợi ý).

---

## Phần 1 — Các chỗ SỬA (thay chữ)

### 1.1. Chương 1, mục 1.2 (Lý do chọn đề tài) — câu về công nghệ

**Hiện tại:**
> …các mô hình ngôn ngữ lớn (LLM) cùng với hệ thống thông tin địa lý mã nguồn mở (PostGIS, OpenStreetMap) đã tạo điều kiện thuận lợi để xây dựng một nền tảng cứu trợ thông minh với chi phí hợp lý.

**Sửa thành:**
> …các mô hình ngôn ngữ lớn (LLM) cùng với hệ thống thông tin địa lý (PostGIS cho lưu trữ và truy vấn không gian, dịch vụ bản đồ VietMap cung cấp dữ liệu địa lý Việt Nam) đã tạo điều kiện thuận lợi để xây dựng một nền tảng cứu trợ thông minh với chi phí hợp lý.

---

### 1.2. Chương 2, Bảng 2.3 (Công nghệ sử dụng) — thêm 1 dòng

**Giữ nguyên** dòng *Ứng dụng di động (Flutter/Dart)* và dòng *Trang quản trị (React + Vite, Leaflet/OpenStreetMap)*.

**Thêm một dòng mới** vào Bảng 2.3:

| Thành phần | Công nghệ | Lý do chọn cho bối cảnh thiên tai |
|---|---|---|
| Bản đồ & dịch vụ địa lý (ứng dụng di động) | VietMap (tile raster + Reverse/Autocomplete/Place v4) | Dữ liệu địa chỉ, đường phố, hẻm và POI tại Việt Nam đầy đủ và bằng tiếng Việt; khắc phục việc OpenStreetMap thưa dữ liệu ở nhiều khu vực trong nước. Có gói miễn phí, khóa API được giấu ở backend. |

---

## Phần 2 — Nội dung THÊM (chèn mới)

### 2.1. Chương 2 — bổ sung cuối mục 2.2.4 (GIS và cơ sở dữ liệu không gian)

*Chèn một đoạn ngắn ngay sau đoạn nói về SRID 4326 / GiST:*

> Cần phân biệt hai lớp dữ liệu địa lý trong hệ thống. Lớp thứ nhất là **lưu trữ và truy vấn không gian** ở phía máy chủ, do PostGIS đảm nhận (định vị nạn nhân, tìm tình nguyện viên trong bán kính, xếp hạng ca theo khoảng cách). Lớp thứ hai là **dữ liệu bản đồ hiển thị và dịch vụ địa chỉ** phía người dùng — hiển thị nền bản đồ, chuyển toạ độ thành địa chỉ, gợi ý địa chỉ khi gõ. Ở lớp thứ hai, ứng dụng di động sử dụng dịch vụ **VietMap** thay cho OpenStreetMap, do dữ liệu OpenStreetMap tại Việt Nam còn thưa (nhiều tuyến đường không có tên, thiếu số nhà, hẻm không đầy đủ), trong khi VietMap cung cấp bản đồ dày dữ liệu và nhãn tiếng Việt, phù hợp để tình nguyện viên định vị nạn nhân trên hiện trường.

---

### 2.2. Chương 3, mục 3.3.2 (Mô tả bảng cases) — thêm cột

*Trong đoạn mô tả bảng `cases`, thêm cột `address_text` vào danh sách:*

> …status (ENUM), tnv_distance_m, ai_source, **address_text** (TEXT, NULL nếu chưa có — địa chỉ dạng chữ của ca; lấy từ địa chỉ người dùng tự nhập/chọn khi gửi SOS, hoặc do máy chủ tự chuyển toạ độ GPS thành địa chỉ bằng dịch vụ Reverse của VietMap), orphan_alerted_at…

---

### 2.3. Chương 3, mục 3.4.1 (Thiết kế các endpoint) — thêm một nhóm

*Thêm nhóm endpoint mới (đặt sau Nhóm SOS / Ca cứu hộ):*

> **Nhóm Dịch vụ địa lý (proxy VietMap):**
> Các endpoint này đóng vai trò trung gian gọi API VietMap từ máy chủ nhằm **giấu khóa API** (không lộ ở phía ứng dụng), đồng thời chuẩn hoá dữ liệu trả về cho ứng dụng di động.
> - GET /api/geo/reverse — chuyển toạ độ (lat, lon) thành địa chỉ dạng chữ.
> - GET /api/geo/autocomplete — gợi ý địa chỉ theo văn bản người dùng đang gõ (có tham số vị trí để ưu tiên địa điểm gần).
> - GET /api/geo/place — chuyển mã địa điểm (ref_id từ Autocomplete) thành toạ độ và địa chỉ chi tiết.

---

### 2.4. Chương 4 — KHÔNG thêm gì

**QUYẾT ĐỊNH:** VietMap chỉ là tích hợp API bên thứ ba thay cho OpenStreetMap/Leaflet, ngang hàng với
FPT.AI eKYC, **không phải đóng góp kỹ thuật cá nhân**. Vì vậy **KHÔNG tạo tiểu mục 4.4.5** hay bất kỳ
mục nào ở Chương 4. Chương 4 chỉ dành cho ba cơ chế cốt lõi tự làm (chuẩn hoá phương ngữ, phân loại,
điều phối). Nội dung VietMap chỉ nhắc gọn ở Bảng 2.3, mục 2.2.4, bảng cases (3.3.2), nhóm endpoint
(3.4.1) và kết luận (5.1).

---

### 2.5. Chương 5, mục 5.1 — nhắc gọn (KHÔNG khung "đóng góp")

*Trong "Về sản phẩm", thêm một gạch đầu dòng:*
> - Ứng dụng di động dùng bản đồ VietMap dày dữ liệu Việt Nam bằng tiếng Việt; mỗi ca SOS có địa chỉ dạng chữ và cho phép nhập địa chỉ có gợi ý khi gõ.

*Trong "Về kiến thức và kỹ năng", KHÔNG tạo gạch đầu dòng riêng — chỉ THÊM VietMap vào gạch đầu dòng đang liệt kê dịch vụ bên ngoài (Gemini, Firebase, FPT.AI), vì đây là tích hợp bên thứ ba chứ không phải đóng góp:*
> …mô hình ngôn ngữ lớn Google Gemini, xác thực và thông báo đẩy Firebase, định danh điện tử FPT.AI, **dịch vụ bản đồ VietMap**.

*Lưu ý: gạch đầu dòng "Xây dựng trang quản trị bằng React kết hợp bản đồ Leaflet và OpenStreetMap" — **GIỮ NGUYÊN** (trang quản trị chưa đổi).*

---

### 2.6. Chương 5, mục 5.3 (Hướng phát triển) — GIỮ NGUYÊN

Gạch đầu dòng "Thay khoảng cách đường chim bay bằng khoảng cách theo tuyến đường…" **giữ nguyên như cũ**, KHÔNG thêm ghi chú gì về VietMap Route (không đề cập tính năng vẽ tuyến trong báo cáo).

---

## Phần 3 — Dẫn chiếu mã nguồn (cho Phụ lục A nếu cần)

> Chỉ liệt kê phần được nhắc trong báo cáo. `vietmap.js` có cả hàm route trong mã nguồn nhưng **không mô tả trong khoá luận**, nên nếu trích Phụ lục A thì lược bỏ phần route.

- `backend/src/services/vietmap.js` — gọi VietMap: reverse, autocomplete, place (lược phần route khi trích).
- `backend/src/controllers/geoController.js` — các endpoint `/api/geo/*`.
- `backend/src/controllers/sosController.js` — lưu và trả `address_text`.
- `backend/src/db/migrations.js` — thêm cột `cases.address_text`.
- `mobile/lib/widgets/map_widget.dart` — đổi nguồn tile sang VietMap.
- `mobile/lib/config/vietmap_config.dart` — khóa tile + URL style VietMap.
- `mobile/lib/screens/victim/location_picker_screen.dart` — màn chọn địa chỉ có gợi ý.
- `mobile/lib/services/api_service.dart` — các hàm gọi `/api/geo/*`.

---

## Tóm tắt việc cần làm trong báo cáo

| # | Vị trí | Việc |
|---|--------|------|
| 1 | Ch1 §1.2 | Sửa câu "(PostGIS, OpenStreetMap)" |
| 2 | Ch2 Bảng 2.3 | Thêm 1 dòng VietMap (giữ dòng admin) |
| 3 | Ch2 §2.2.4 | Thêm đoạn phân biệt 2 lớp GIS |
| 4 | Ch3 §3.3.2 | Thêm cột `address_text` vào bảng cases |
| 5 | Ch3 §3.4.1 | Thêm nhóm endpoint `/api/geo/*` (3 cái: reverse, autocomplete, place) |
| 6 | Ch5 §5.1 | 1 gạch đầu dòng "Về sản phẩm" + thêm VietMap vào gạch đầu dòng dịch vụ bên ngoài |
| — | Phụ lục C | Thêm nhóm endpoint địa lý (3 cái) |

**Không làm:** KHÔNG tạo mục Chương 4 cho VietMap (bên thứ ba, không phải đóng góp).
**Không sửa:** các câu nói *trang quản trị dùng Leaflet/OpenStreetMap* (Bảng 2.3, §5.1) — vẫn đúng.
**Không đề cập:** tính năng vẽ tuyến đường (VietMap Route) — code có nhưng không đưa vào báo cáo.

> **Prompt cho add-in Word:** dùng file riêng `prompt_vietmap_word.md` (7 prompt V1–V7). File `cap_nhat` này là bản kế hoạch/đối chiếu.
