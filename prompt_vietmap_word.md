# PROMPT SỬA BÁO CÁO — PHẦN VIETMAP (chạy riêng, độc lập)

> **File này tách riêng** khỏi `prompt_sua_word.md` để bạn sửa mỗi phần VietMap khi cần.
> Mỗi khối `PROMPT` là một lệnh độc lập — dán vào add-in Claude trong Word, chờ sửa xong rồi sang prompt kế.

## Nguyên tắc (đọc trước)

1. **VietMap chỉ là API bên thứ ba thay cho OpenStreetMap/Leaflet** — ngang hàng với FPT.AI eKYC, **KHÔNG phải đóng góp kỹ thuật cá nhân**. Vì vậy: **KHÔNG tạo tiểu mục riêng ở Chương 4**, chỉ nhắc gọn ở nơi bắt buộc. Không viết dài dòng.
2. **Chỉ đổi ở ứng dụng di động.** Trang quản trị (React) **vẫn Leaflet/OpenStreetMap** — mọi câu nói admin dùng Leaflet/OSM (Bảng 2.3 dòng admin, mục 5.1) **giữ nguyên, đừng sửa**.
3. **Chỉ mô tả ba dịch vụ:** tile nền, Reverse (toạ độ→địa chỉ), Autocomplete + Place (nhập địa chỉ có gợi ý). **KHÔNG đề cập tính năng vẽ tuyến đường (VietMap Route)** — code có nhưng không đưa vào báo cáo.
4. **Không đụng khoảng cách đường chim bay.** Xếp hạng/điều phối vẫn dùng `ST_Distance`; VietMap không thay logic này. Hạn chế 5.2 và hướng phát triển 5.3 về "đường chim bay" giữ nguyên.

---

### PROMPT V1 — Chương 1, mục 1.2: sửa câu công nghệ

```
Trong Chương 1, mục "1.2. Lý do chọn đề tài", có câu nhắc tới hệ thống thông tin địa lý mã nguồn mở
kèm cụm "(PostGIS, OpenStreetMap)". Ứng dụng di động nay đã đổi từ OpenStreetMap sang dịch vụ bản đồ
VietMap, nên câu này cần sửa.

Tìm câu chứa "(PostGIS, OpenStreetMap)" và sửa cụm đó thành:
"(PostGIS cho lưu trữ và truy vấn không gian, dịch vụ bản đồ VietMap cung cấp dữ liệu địa lý Việt Nam)".

Giữ nguyên phần còn lại của câu.
```

---

### PROMPT V2 — Chương 2, Bảng 2.3: thêm một dòng

```
Trong Chương 2, mục 2.3 có "Bảng 2.3 - Công nghệ sử dụng và lý do lựa chọn".

GIỮ NGUYÊN dòng "Ứng dụng di động (Flutter/Dart)" và dòng "Trang quản trị (React + Vite,
Leaflet/OpenStreetMap)" — trang quản trị chưa đổi.

THÊM một dòng mới vào bảng (đặt sau dòng Ứng dụng di động):

| Bản đồ và dịch vụ địa lý (ứng dụng di động) | VietMap (tile raster + Reverse/Autocomplete/Place) | Dữ liệu địa chỉ, đường phố, hẻm và điểm quan tâm tại Việt Nam đầy đủ và bằng tiếng Việt, khắc phục việc OpenStreetMap thưa dữ liệu ở nhiều khu vực trong nước; có gói miễn phí, khóa API được giấu ở máy chủ |

Giữ đúng định dạng bảng như các dòng khác.
```

---

### PROMPT V3 — Chương 2, mục 2.2.4: thêm một câu phân biệt (ngắn)

```
Trong Chương 2, mục "2.2.4. Hệ thống thông tin địa lý (GIS) và cơ sở dữ liệu không gian", ngay sau
đoạn nói về hệ tọa độ SRID 4326 và chỉ mục GiST, thêm MỘT đoạn ngắn (2–3 câu, không dài dòng):

"Cần phân biệt hai lớp dữ liệu địa lý trong hệ thống: lớp lưu trữ và truy vấn không gian ở máy chủ
do PostGIS đảm nhận (định vị nạn nhân, tìm tình nguyện viên trong bán kính, xếp hạng ca theo khoảng
cách), và lớp dữ liệu bản đồ hiển thị cùng dịch vụ địa chỉ ở phía người dùng. Ở lớp thứ hai, ứng
dụng di động dùng dịch vụ VietMap thay cho OpenStreetMap, do dữ liệu OpenStreetMap tại Việt Nam còn
thưa (nhiều đường không tên, thiếu số nhà, hẻm không đầy đủ), trong khi VietMap cung cấp bản đồ dày
dữ liệu và nhãn tiếng Việt."

Không viết thêm gì về hiện thực kỹ thuật ở đây.
```

---

### PROMPT V4 — Chương 3, mục 3.3.2: thêm cột `address_text` vào bảng cases

```
Trong Chương 3, mục "3.3.2. Mô tả chi tiết các bảng dữ liệu", ở đoạn mô tả "Bảng cases (ca SOS)",
danh sách cột hiện có: ...status (ENUM), tnv_distance_m, ai_source, orphan_alerted_at...

Thêm cột address_text vào danh sách, đặt ngay sau ai_source:

"address_text (TEXT, NULL nếu chưa có — địa chỉ dạng chữ của ca, lấy từ địa chỉ người dùng tự nhập
khi gửi SOS, hoặc do máy chủ tự chuyển tọa độ GPS thành địa chỉ bằng dịch vụ Reverse của VietMap)"

Giữ nguyên các cột còn lại.
```

---

### PROMPT V5 — Chương 3, mục 3.4.1: thêm nhóm endpoint dịch vụ địa lý

```
Trong Chương 3, mục "3.4.1. Thiết kế các endpoint", thêm một nhóm mới đặt SAU nhóm "SOS / Ca cứu hộ":

"Nhóm Dịch vụ địa lý (proxy VietMap):
Các endpoint này đóng vai trò trung gian gọi API VietMap từ máy chủ nhằm giấu khóa API (không lộ ở
phía ứng dụng), đồng thời chuẩn hóa dữ liệu trả về cho ứng dụng di động.
- GET /api/geo/reverse — chuyển tọa độ (lat, lon) thành địa chỉ dạng chữ.
- GET /api/geo/autocomplete — gợi ý địa chỉ theo văn bản người dùng đang gõ (có tham số vị trí để
  ưu tiên địa điểm gần).
- GET /api/geo/place — chuyển mã địa điểm (ref_id từ Autocomplete) thành tọa độ và địa chỉ chi tiết."

CHỈ ba endpoint trên. KHÔNG thêm endpoint route/tuyến đường.
```

---

### PROMPT V6 — Chương 5, mục 5.1: thêm nhắc gọn (không phải đóng góp)

```
Trong Chương 5, mục "5.1. Kết quả đạt được":

(a) Ở nhóm "Về sản phẩm", thêm một gạch đầu dòng:
"- Ứng dụng di động dùng bản đồ VietMap dày dữ liệu Việt Nam bằng tiếng Việt; mỗi ca SOS có địa chỉ
   dạng chữ và cho phép nhập địa chỉ có gợi ý khi gõ."

(b) Ở nhóm "Về kiến thức và kỹ năng", tìm gạch đầu dòng đang liệt kê các dịch vụ bên ngoài (Google
   Gemini, Firebase, FPT.AI) và THÊM VietMap vào cùng danh sách đó — không tạo gạch đầu dòng riêng,
   vì đây là tích hợp dịch vụ bên thứ ba chứ không phải đóng góp kỹ thuật. Ví dụ sửa thành:
   "...mô hình ngôn ngữ lớn Google Gemini, xác thực và thông báo đẩy Firebase, định danh điện tử
   FPT.AI, dịch vụ bản đồ VietMap."

KHÔNG sửa gạch đầu dòng "Xây dựng trang quản trị bằng React kết hợp bản đồ Leaflet và OpenStreetMap"
— trang quản trị chưa đổi.
```

---

## VIỆC TỰ LÀM (add-in không làm được)

| Việc | Ghi chú |
|---|---|
| **Vẽ lại Hình 3.28 (ERD)** | Thêm cột `address_text` vào bảng `cases` nếu muốn kỹ. Không bắt buộc — chỉ thêm một cột. |
| **Chạy thử app trên Android** | Xác nhận tile VietMap hiện đúng + màn nhập địa chỉ gợi ý chạy được, TRƯỚC khi mô tả là "đã hiện thực" (Lời cam đoan). |

## KHÔNG làm

- **KHÔNG tạo tiểu mục 4.4.5 hay bất kỳ mục nào ở Chương 4 cho VietMap.** Chương 4 chỉ dành cho ba cơ chế cốt lõi tự làm.
- **KHÔNG nhắc tính năng vẽ tuyến đường (Route)** ở bất kỳ đâu.
- **KHÔNG sửa** các câu nói trang quản trị dùng Leaflet/OpenStreetMap.
