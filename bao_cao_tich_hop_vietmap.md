# Báo cáo tích hợp VietMap API vào FloodAid

> Phạm vi: các thay đổi thay thế nền bản đồ và dịch vụ địa lý cũ (Leaflet/OpenStreetMap) bằng VietMap.
> *(Không bao gồm phần khoảng cách/thời gian dự kiến tới — trình bày riêng.)*

---

## 1. Bối cảnh — hiện trạng trước khi tích hợp

Ứng dụng FloodAid (Flutter) ban đầu dùng bộ công cụ bản đồ mã nguồn mở:

| Thành phần | Công nghệ cũ | Hạn chế tại Việt Nam |
|-----------|--------------|----------------------|
| Thư viện bản đồ | `flutter_map` (bản Flutter của **Leaflet**) | (giữ nguyên) |
| Tile nền bản đồ | **OpenStreetMap** (`tile.openstreetmap.org`) | Dữ liệu VN sơ sài: nhiều đường không tên, thiếu số nhà, hẻm không đầy đủ, ít POI |
| Tìm kiếm địa điểm | **Nominatim** (geocoder của OSM) | Chỉ trả 1 kết quả, không gợi ý khi gõ, độ chính xác địa chỉ VN thấp |
| Toạ độ → địa chỉ | *(không có)* | Ca SOS chỉ lưu toạ độ thô (lat/lng), không có địa chỉ chữ |

**Quyết định kiến trúc:** giữ nguyên thư viện `flutter_map` (Leaflet), chỉ **thay nguồn tile** và **thay nhà cung cấp dịch vụ địa lý** sang VietMap. Cách này tránh viết lại toàn bộ phần bản đồ, đồng thời vẫn chạy được trên nền web (khác với việc dùng SDK bản đồ vector native của VietMap — xem mục 7).

---

## 2. Tổng quan các thay đổi

| # | Tính năng | Trước (Leaflet/OSM) | Sau (VietMap) |
|---|-----------|---------------------|---------------|
| A | Nền bản đồ | Tile OpenStreetMap | **Tile raster VietMap** (dữ liệu VN dày, nhãn tiếng Việt) |
| B | GPS → địa chỉ chữ | Không có | **Reverse Geocoding v4** |
| C | Nhập/tìm địa chỉ | Nominatim (1 kết quả) | **Autocomplete v4 + Place v4** (gợi ý khi gõ) |
| E | Màu ping nạn nhân | (một phần cố định) | **Đồng bộ theo mức khẩn cấp SOS** |
| F | Bảo mật API key | — | **Backend proxy** — key không lộ ra client |

> **Lưu ý:** code còn tích hợp VietMap Route (vẽ tuyến đường TNV↔nạn nhân), nhưng **không mô tả trong bất kỳ bản báo cáo/khoá luận nào** theo yêu cầu, nên đã lược khỏi tài liệu này.

---

## 3. Chi tiết từng thay đổi

### A. Nền bản đồ: OpenStreetMap → tile raster VietMap

**File:** `mobile/lib/widgets/map_widget.dart` (widget dùng chung `FloodAidMap`)

Thay `urlTemplate` của `TileLayer` từ OSM sang tile raster của VietMap:

| Kiểu | URL tile mới |
|------|--------------|
| Bản đồ đường phố | `https://maps.vietmap.vn/maps/tiles/tm/{z}/{x}/{y}@2x.png?apikey=…` |
| Tối (dark) | `https://maps.vietmap.vn/maps/tiles/dm/{z}/{x}/{y}@2x.png?apikey=…` |
| Vệ tinh | `https://maps.vietmap.vn/maps/tiles/st/{z}/{x}/{y}.png?apikey=…` |
| Địa hình | Giữ OpenTopoMap (VietMap không có kiểu này) |

- `@2x` = tile retina (512px) → hiển thị nét trên màn hình mật độ cao.
- Kết quả: bản đồ hiện đầy đủ **tên đường, hẻm, POI bằng tiếng Việt** — giải quyết đúng hạn chế lớn nhất của OSM tại VN.
- Áp dụng cho cả 3 màn có bản đồ: trang chủ TNV, màn nhiệm vụ (TNV), màn theo dõi (nạn nhân).

### B. GPS → địa chỉ chữ (Reverse Geocoding)

**Files:** `backend/src/services/vietmap.js` (`reverseGeocode`), `backend/src/controllers/sosController.js`, migration `cases.address_text`.

- Khi tạo ca SOS: ưu tiên địa chỉ người dùng tự nhập; nếu không có → **tự động chuyển toạ độ GPS thành địa chỉ** bằng VietMap Reverse v4 (chạy bất đồng bộ, không làm chậm thao tác gửi SOS khẩn cấp).
- Địa chỉ được lưu vào cột mới `cases.address_text` và trả ra ở các API xem ca → TNV và nạn nhân đều thấy **địa chỉ dạng chữ** thay vì chỉ có toạ độ.
- Ví dụ: `(10.759, 106.675)` → *"197 Trần Phú, Phường 4, Quận 5, Thành phố Hồ Chí Minh"*.

### C. Nhập/tìm địa chỉ có gợi ý: Nominatim → VietMap Autocomplete

**Files:** `mobile/lib/screens/victim/location_picker_screen.dart` (viết lại), `backend/src/controllers/geoController.js`.

- Màn "Chọn vị trí" trước dùng Nominatim (gõ xong bấm tìm, ra 1 kết quả). Nay dùng **VietMap Autocomplete v4**: gõ tới đâu **gợi ý địa chỉ hiện xuống tới đó** (giống ô tìm địa chỉ của Google Maps/Grab).
- Khi chọn 1 gợi ý → gọi **Place v4** để lấy toạ độ chính xác.
- Tối ưu chi phí: gõ được **debounce 300ms**, chỉ gọi Place khi người dùng thực sự chọn.
- Ưu tiên gợi ý gần vị trí hiện tại (tham số `focus` = GPS người dùng).

### E. Màu ping nạn nhân theo mức độ khẩn cấp

**File:** `mobile/lib/screens/volunteer/active_mission_screen.dart`

- Trước: ping nạn nhân ở màn nhiệm vụ **luôn màu đỏ**, không phản ánh mức SOS.
- Nay: tô theo mức khẩn cấp (mức 5 đỏ đậm → mức thấp vàng…), **đồng bộ với màu ở màn danh sách**.
- Ping TNV giữ **màu xanh biển** để phân biệt rõ hai bên.

### F. Kiến trúc bảo mật — Backend proxy

**File:** `backend/src/controllers/geoController.js`, `backend/src/routes.js`

- Các API cần bảo mật key (reverse, autocomplete, place) **không gọi thẳng từ app** mà đi qua backend:
  - `GET /api/geo/reverse` · `GET /api/geo/autocomplete` · `GET /api/geo/place`
- API key đặt trong biến môi trường backend (`VIETMAP_API_KEY`), **không lộ trong mã client**.
- Riêng key hiển thị bản đồ (tile) buộc phải nhúng ở client (bản chất của tile map), đặt trong `mobile/lib/config/vietmap_config.dart`; được bảo vệ bằng giới hạn domain/IP ở VietMap Console.

---

## 4. Danh sách file thay đổi chính

**Backend (Node.js/Express):**
- `src/services/vietmap.js` *(mới)* — gọi VietMap: reverse, autocomplete, place
- `src/controllers/geoController.js` *(mới)* — proxy các endpoint `/api/geo/*`
- `src/routes.js` — khai báo route `/geo/*`
- `src/controllers/sosController.js` — lưu + trả `address_text`
- `src/db/migrations.js` — thêm cột `cases.address_text`
- `.env.example` — thêm `VIETMAP_API_KEY`, `VIETMAP_MAP_KEY`

**Mobile (Flutter):**
- `lib/widgets/map_widget.dart` — đổi tile OSM → VietMap
- `lib/config/vietmap_config.dart` *(mới)* — key tile + URL style
- `lib/screens/victim/location_picker_screen.dart` — viết lại: Nominatim → Autocomplete/Place
- `lib/services/api_service.dart` — thêm `geoAutocomplete`, `geoPlace`, `geoReverse`
- `lib/screens/volunteer/active_mission_screen.dart` — màu ping nạn nhân theo mức khẩn cấp

---

## 5. Nhóm API VietMap đã sử dụng

| API VietMap | Dùng cho | Thay thế cho |
|-------------|----------|--------------|
| **Tilemap (raster tm/dm/st)** | Nền bản đồ | Tile OpenStreetMap |
| **Reverse v4** | GPS → địa chỉ | (chưa có) |
| **Autocomplete v4** | Gợi ý địa chỉ khi gõ | Nominatim |
| **Place v4** | ref_id → toạ độ | (đi kèm Autocomplete) |

---

## 6. Kết quả

- Bản đồ hiển thị **dữ liệu Việt Nam đầy đủ, tiếng Việt** thay cho OSM sơ sài.
- Ca SOS có **địa chỉ dạng chữ** — TNV định vị dễ hơn, không phải đọc toạ độ.
- Nhập địa chỉ có **gợi ý thông minh** thay vì tìm thủ công.
- Vẫn **chạy được trên nền web** (giữ `flutter_map`).

---

## 7. Ghi chú kỹ thuật — vì sao không dùng SDK bản đồ vector native của VietMap

VietMap có SDK bản đồ vector (`vietmap_flutter_gl`) cho hiệu ứng đẹp hơn (xoay/nghiêng 3D). Tuy nhiên đã cân nhắc và **không dùng** vì:
- Gói con cho web của SDK này lỗi biên dịch trên Flutter mới → **mất khả năng chạy web**.
- Là SDK native, cần cấu hình phức tạp và không thử nghiệm được trên trình duyệt.

→ Dùng **tile raster VietMap trên flutter_map** đạt được đúng mục tiêu (dữ liệu VN dày) mà vẫn giữ web, ít rủi ro. Hiệu ứng vector 3D không cần thiết cho ứng dụng cứu hộ.

---

## 8. Hướng phát triển tiếp (chưa triển khai)

- **Lớp "đường ngập"**: VietMap (và mọi bản đồ thương mại) **không có dữ liệu ngập nước**. Có thể để TNV/nạn nhân báo đoạn đường ngập → đối chiếu với tuyến đường để cảnh báo/tránh. Đây là giá trị riêng của một app cứu hộ lũ.
- **Matrix API**: chọn TNV tới nhanh nhất khi điều phối.
- **Static Map (PNG)**: đính ảnh vị trí vào thông báo đẩy (FCM).
