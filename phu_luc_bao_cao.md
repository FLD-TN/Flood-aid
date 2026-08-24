# PHỤ LỤC — KHÔNG DÙNG NỮA

> **⛔ QUYẾT ĐỊNH MỚI: báo cáo BỎ HẲN phần phụ lục.** File này giữ lại chỉ để tra cứu nội bộ
> (bảng từ khóa, luật biến âm, danh sách endpoint, tập test) — **KHÔNG dán vào báo cáo Word**.
> Báo cáo kết thúc ở TÀI LIỆU THAM KHẢO.

---

# PHỤ LỤC A — Mã nguồn các cơ chế cốt lõi

Phụ lục này tập hợp mã nguồn đầy đủ của các cơ chế được trình bày ở Chương 4. Bản in trong thân
Chương 4 đã lược bớt phần ghi nhật ký và xử lý lỗi để tập trung vào logic; bản dưới đây là mã nguồn
nguyên vẹn.

> **Cách làm:** mở từng file trong danh sách, copy toàn bộ nội dung, dán vào đây dưới đúng tiêu đề
> mục, định dạng bằng phông đơn cách (Consolas cỡ 9–10). Không cần sửa gì trong mã.

- **A.1** — Cơ chế phân loại mức độ khẩn cấp: `backend/src/services/aiPipeline.js`
- **A.2** — Bộ chuẩn hóa phương ngữ (thiết bị): `mobile/lib/services/dialect_normalizer.dart`
- **A.3** — Sinh từ điển phương ngữ: `backend/src/generateDialectDict.js`
- **A.4** — Phát hiện ca mồ côi: `backend/src/jobs/orphanCaseChecker.js`
- **A.5** — Tự thu hồi phân công: `backend/src/jobs/staleAssignmentChecker.js`
- **A.6** — Theo dõi khoảng cách tiếp cận: `backend/src/jobs/distanceTracker.js`
- **A.7** — Bộ điều khiển từ điển phương ngữ: `backend/src/controllers/dialectController.js`

---

# PHỤ LỤC B — Bảng từ khóa và tập luật biến âm đầy đủ

Chương 4 chỉ trích một phần các bảng này. Dưới đây là nội dung đầy đủ, đúng như trong mã nguồn.

## B.1. Bảng từ khóa xác định mức khẩn cấp (`URGENCY_KEYWORDS`)

Nguồn: `backend/src/services/aiPipeline.js`

| Mức | Từ khóa |
|---|---|
| 5 — Nguy hiểm tính mạng | máu, bất tỉnh, không thở, chết, chìm, đuối nước |
| 4 — Khẩn cấp cao | trẻ em, em bé, người già, ngập nóc, mái nhà, bị thương, gãy, cấp cứu |
| 3 — Khẩn cấp trung bình | ngập sâu, nước dâng, kẹt, không thoát được, mắc kẹt, cô lập |
| 2 — Khẩn cấp thấp | ngập, cần xuồng, cần giúp, nước lên, cần hỗ trợ |
| 1 — Mặc định | (không khớp từ khóa nào ở trên) |

## B.2. Bảng từ khóa gán nhãn phân loại (`TAG_KEYWORDS`)

Nguồn: `backend/src/services/aiPipeline.js`

| Nhãn | Ý nghĩa | Từ khóa |
|---|---|---|
| `y_te` | Cần hỗ trợ y tế | máu, bất tỉnh, chấn thương, bị thương, không thở, cấp cứu, gãy |
| `tre_em` | Có trẻ em | trẻ em, em bé, con nít, trẻ con, con nhỏ |
| `nguoi_gia` | Có người cao tuổi | người già, ông, bà, cụ, cao tuổi |
| `ngap_noc` | Ngập tới mái nhà | ngập nóc, nước đến nóc, ngập tới mái, nước ngập mái |
| `phuong_tien` | Cần phương tiện đường thủy | cần xuồng, cần thuyền, không có phương tiện, cần ghe |

## B.3. Danh sách từ phủ định và cụm loại trừ

Nguồn: `backend/src/services/aiPipeline.js`

- **Từ phủ định** (`NEGATION_WORDS`): không, chưa, chẳng, chả, khỏi, đừng
- **Cửa sổ phủ định**: 2 từ ngay trước từ khóa, trong cùng một mệnh đề
- **Cụm loại trừ** (`EXCLUSION_PHRASES`, xóa trước khi dò): "kẹt xe", "chết máy"

## B.4. Tập luật biến âm (`phoneticRules`)

Nguồn: `backend/src/generateDialectDict.js`. Áp theo đúng thứ tự này lên từng âm tiết của mỗi từ
chuẩn để sinh ngược dạng phương ngữ.

| # | Hiện tượng | Luật (chuẩn → phương ngữ) | Ví dụ |
|---|---|---|---|
| 1 | Vần "àm" | àm → ồm | làm → lồm |
| 2 | Vần "ám" | ám → ốm | |
| 3 | Vần "ạm" | ạm → ộm | |
| 4 | Vần "am" | am → ôm | |
| 5 | Nguyên âm "à" | à → oà | nhà → nhoà |
| 6 | Nguyên âm "á" | á → oá | |
| 7 | Nguyên âm "ạ" | ạ → oạ | |
| 8 | Vần "ăn" | ăn → en | chăn → chen |
| 9 | Vần "ắn" | ắn → én | |
| 10 | Vần "ặn" | ặn → ẹn | |
| 11 | Vần "ặng" | ặng → ẹng | |
| 12 | Phụ âm đầu "v" | ^v → d | vô → dô |

## B.5. Từ điển cứng (lớp từ vựng không suy ra được bằng luật)

Nguồn: `backend/src/generateDialectDict.js` (`hardcodedDict`). Đây là các mục được ghép thẳng vào
từ điển sinh ra, vì chúng không tuân theo luật biến âm nào.

| Phương ngữ | Nghĩa chuẩn | Phương ngữ | Nghĩa chuẩn |
|---|---|---|---|
| răng | sao | tau | tao |
| rứa | thế | mi | mày |
| mô | đâu | con trơ | con trai |
| tê | kia | thằng trơ | thằng trai |
| ni | này | con gớ | con gái |
| nớ | đó | mớ nhoà | mái nhà |
| chừ | giờ | chu cha | ôi trời |

## B.6. Danh sách chặn (`blacklist`)

Nguồn: `backend/src/generateDialectDict.js`. Các dạng sinh ra nằm trong danh sách này bị loại bỏ,
vì chúng trùng với một từ tiếng Việt chuẩn mang nghĩa khác.

oà, hòa, hà, dạ, dề, dợ, men, kén, dạng, dòng

---

# PHỤ LỤC C — Danh sách endpoint REST và định dạng gói tin WebSocket

Nguồn: `backend/src/routes.js` và `backend/src/services/wsServer.js`. Đây là danh sách đầy đủ mà
thân bài (mục 3.5) đã dẫn chiếu tới.

## C.1. Danh sách endpoint REST

**Nhóm Xác thực và eKYC**

| Phương thức | Đường dẫn | Chức năng |
|---|---|---|
| POST | `/api/auth/verify-phone` | Xác thực số điện thoại qua Firebase |
| POST | `/api/kyc/recognize-id` | Nhận dạng thông tin Căn cước công dân (proxy FPT.AI) |
| POST | `/api/kyc/check-face` | Đối sánh khuôn mặt với ảnh trên Căn cước công dân (proxy FPT.AI) |

**Nhóm SOS và ca cứu hộ**

| Phương thức | Đường dẫn | Chức năng |
|---|---|---|
| POST | `/api/sos` | Tạo ca SOS mới (kèm phân loại và điều phối) |
| GET | `/api/sos/active` | Lấy ca đang hoạt động của người dùng |
| GET | `/api/sos/history` | Lấy lịch sử ca SOS đã gửi |
| POST | `/api/sos/cancel` | Hủy ca SOS |
| GET | `/api/cases/nearby` | Danh sách ca gần tình nguyện viên (có lọc và xếp hạng) |
| GET | `/api/case/:id` | Chi tiết một ca |
| GET | `/api/case/:id/tnv-location` | Vị trí tình nguyện viên phụ trách ca |
| GET | `/api/case/:id/stream` | Kênh SSE cập nhật trạng thái ca |
| GET | `/api/case/:id/my-assignment` | Kiểm tra phân công của tình nguyện viên với ca |
| POST | `/api/case/:id/accept` | Nhận ca (trả về số điện thoại nạn nhân đã giải mã) |
| POST | `/api/case/:id/resolve` | Hoàn tất ca |
| POST | `/api/case/:id/revoke` | Thu hồi phân công |
| GET | `/api/case/:id/messages` | Tải lịch sử tin nhắn (dự phòng REST) |
| POST | `/api/case/:id/messages` | Gửi tin nhắn (dự phòng REST) |

**Nhóm Từ điển phương ngữ**

| Phương thức | Đường dẫn | Chức năng |
|---|---|---|
| GET | `/api/dialect-dict/version` | Hỏi số phiên bản hiện tại của từ điển |
| GET | `/api/dialect-dict` | Tải toàn bộ mục từ thuộc lớp bổ sung |
| POST | `/api/dialect-dict` | Quản trị viên thêm hoặc sửa một mục từ (tăng số phiên bản) |
| DELETE | `/api/dialect-dict` | Quản trị viên xóa một mục từ (tăng số phiên bản) |

**Nhóm Tình nguyện viên**

| Phương thức | Đường dẫn | Chức năng |
|---|---|---|
| POST | `/api/volunteers/register` | Đăng ký tình nguyện viên |
| GET | `/api/volunteers` | Danh sách tình nguyện viên |
| GET | `/api/volunteers/locations` | Vị trí các tình nguyện viên |
| PUT | `/api/volunteers/:id/approve` | Duyệt hồ sơ |
| PUT | `/api/volunteers/:id/availability` | Đặt trạng thái sẵn sàng |
| PUT | `/api/volunteers/:id/fcm-token` | Cập nhật token thông báo đẩy |
| PUT | `/api/volunteers/:id/radius` | Cập nhật bán kính nhận thông báo |
| GET | `/api/volunteers/:id/history` | Lịch sử cứu hộ |
| GET | `/api/volunteers/:id/active-mission` | Nhiệm vụ đang thực hiện |
| POST | `/api/location` | Cập nhật vị trí tình nguyện viên |

**Nhóm Quản trị viên**

| Phương thức | Đường dẫn | Chức năng |
|---|---|---|
| POST | `/api/admin/login` | Đăng nhập bằng email và mật khẩu |
| GET | `/api/admin/cases` | Toàn bộ ca cứu hộ |
| GET | `/api/admin/case-clusters` | Gom cụm ca theo khu vực cho bản đồ chỉ huy |
| GET | `/api/admin/stats` | Thống kê tổng quan |

## C.2. Định dạng gói tin WebSocket

Kênh WebSocket dùng chung một kết nối cho cả luồng GPS và luồng chat, phân biệt bằng trường `type`.

**Đường kết nối**

| Vai trò | Đường kết nối |
|---|---|
| Tình nguyện viên | `ws://host/ws/gps?role=volunteer&caseId=...&volunteerId=...` |
| Nạn nhân | `ws://host/ws/gps?role=victim&caseId=...` |

**Định dạng gói tin**

- Cập nhật vị trí (chỉ tình nguyện viên gửi): `{ type: 'gps_update', lat, lon, timestamp }`
- Gửi tin nhắn: `{ type: 'chat', content }`
- Nhận tin nhắn: `{ type: 'chat', senderRole, content, createdAt }`

**Sự kiện SSE (một chiều, máy chủ đẩy xuống)**

`case:accepted` (kèm số điện thoại tình nguyện viên để nạn nhân gọi), `case:resolved`,
`case:cancelled`, `case:revoked`, `case:orphaned`, `case:on_scene`.

---

# PHỤ LỤC D — Tập dữ liệu thử nghiệm

## D.1. Tập tin nhắn SOS mô phỏng (dùng cho mục 4.5.1)

40 tin nhắn cầu cứu mô phỏng, phân bố đều trên 5 mức khẩn cấp, dùng để đo độ trễ và tỉ lệ sử dụng
của hai nhánh phân loại. Cột "Mức đúng" là mức khẩn cấp do người viết xác định thủ công, dùng để
đối chiếu. Nguồn: `backend/scripts/sos_test_set.json`.

| # | Mức đúng | Nội dung tin nhắn |
|---|---|---|
| 1 | 5 | Cứu với! Con tôi bị đuối nước, nước cuốn đi rồi, cứu nhanh lên |
| 2 | 5 | Chồng tôi bất tỉnh không thở được, nước ngập tới cổ rồi |
| 3 | 5 | Có người bị nước cuốn chìm dưới cầu, cần cứu ngay lập tức |
| 4 | 5 | Mẹ tôi chảy máu nhiều lắm, ngất đi rồi, nhà đang ngập |
| 5 | 5 | Ba tôi ngã đập đầu, máu ra nhiều, không tỉnh lại, cần cấp cứu gấp |
| 6 | 5 | Nhà bị sập, có người kẹt bên trong, nước dâng nhanh, sợ chết đuối |
| 7 | 5 | Em bé rơi xuống nước, vớt lên rồi nhưng không thở, cứu với |
| 8 | 5 | Có hai người bị chìm khi qua sông, mất tích chưa tìm thấy |
| 9 | 4 | Nhà tôi có ba đứa trẻ nhỏ, nước đã ngập tới nóc, cần cứu gấp |
| 10 | 4 | Bà tôi 85 tuổi bị gãy chân, không di chuyển được, nước đang lên |
| 11 | 4 | Có người già và trẻ em trên gác mái, nước ngập tới mái nhà rồi |
| 12 | 4 | Vợ tôi bị thương ở chân, chảy máu, cần đưa đi cấp cứu |
| 13 | 4 | Trong nhà có cụ già nằm liệt giường, nước ngập nóc, không tự di tản được |
| 14 | 4 | Hai em bé đang sốt cao, nhà ngập sâu, cần đưa ra ngoài |
| 15 | 4 | Cần cấp cứu, có người bị mảnh tôn cắt vào tay, máu chảy nhiều |
| 16 | 4 | Nhà có con nhỏ mới sinh, nước lên tới mái, xin cứu trợ khẩn |
| 17 | 3 | Nhà tôi bị cô lập, nước ngập sâu quá đầu người, không ra ngoài được |
| 18 | 3 | Cả xóm bị mắc kẹt, nước dâng cao, đường vào đã ngập hết |
| 19 | 3 | Gia đình bốn người kẹt trên tầng hai, nước vẫn đang dâng |
| 20 | 3 | Chúng tôi bị cô lập hai ngày rồi, hết đồ ăn, nước ngập sâu |
| 21 | 3 | Nước dâng nhanh quá, không thoát được ra khỏi nhà |
| 22 | 3 | Mắc kẹt ở trạm xá, nước ngập sâu, có mấy người cần di tản |
| 23 | 3 | Nhà nằm sát bờ sông, nước dâng cao, sợ sạt lở, chưa ra được |
| 24 | 3 | Đường bị ngập sâu, xe không qua được, cả nhà đang kẹt lại |
| 25 | 2 | Nhà tôi bị ngập, cần xuồng để di chuyển ra ngoài |
| 26 | 2 | Nước lên tới đầu gối rồi, cần người giúp chuyển đồ lên cao |
| 27 | 2 | Cần hỗ trợ di dời, nhà đã bị ngập nửa mét |
| 28 | 2 | Xin cần ghe qua chở giúp mấy người sang bờ bên kia |
| 29 | 2 | Nước lên nhanh, cần giúp đưa gia súc và đồ đạc lên chỗ cao |
| 30 | 2 | Nhà bị ngập, không có phương tiện nào để đi lại |
| 31 | 2 | Cần xuồng để đưa mấy người trong xóm ra khu vực an toàn |
| 32 | 2 | Nước đang lên dần, cần hỗ trợ trước khi ngập sâu hơn |
| 33 | 1 | Nhà tôi hết lương thực, xin hỗ trợ mì và nước uống |
| 34 | 1 | Xin hỗ trợ nước sạch, cả xóm dùng hết nước rồi |
| 35 | 1 | Gia đình cần thêm chăn màn, đêm lạnh quá |
| 36 | 1 | Nhà không còn gạo, xin cứu trợ lương thực khi nào tiện |
| 37 | 1 | Xin hỗ trợ thuốc men thông thường, không có ai bị thương nặng |
| 38 | 1 | Mất điện mấy ngày rồi, xin hỗ trợ đèn pin và pin dự phòng |
| 39 | 4 | May quá không ai bị thương, nhưng nhà có người già, nước đã ngập tới mái |
| 40 | 2 | Xe bị kẹt xe rồi chết máy giữa đường ngập, cần người giúp đẩy |

> Hai tin cuối (39 và 40) được đưa vào có chủ đích để kiểm chứng cơ chế xử lý phủ định và cụm loại
> trừ ở mục 4.2.3.1: tin 39 chứa từ khóa "bị thương" nhưng đứng sau "không", nên không được tính là
> mức 4 vì y tế mà là mức 4 vì "ngập tới mái"; tin 40 chứa "kẹt" và "chết" nhưng nằm trong các cụm
> loại trừ "kẹt xe" và "chết máy", nên được đánh đúng mức 2.

## D.2. Tập câu phương ngữ (dùng cho Bảng 4.5)

Bảy câu cầu cứu mang đặc trưng phương ngữ, kèm dạng chuẩn sau chuẩn hóa, dùng để minh họa tác động
của bộ chuẩn hóa lên kết quả phân loại. Nội dung đầy đủ đã trình bày trong Bảng 4.5 của Chương 4.
