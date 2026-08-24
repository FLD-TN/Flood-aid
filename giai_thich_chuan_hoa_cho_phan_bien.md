# GIẢI THÍCH CƠ CHẾ CHUẨN HÓA PHƯƠNG NGỮ (cho người chưa biết đề tài)

> Mục tiêu: giảng cho giảng viên phản biện hiểu **chuẩn hóa là gì, tạo ra bằng cách nào,
> và chạy thế nào**, bằng ví dụ cụ thể từng bước. Đọc file này như một bài giảng có thể
> nói thành lời. (File `thuyet_trinh_phan_bien_chuan_hoa.md` là phần hỏi–đáp phòng thủ.)

---

## 1. VẤN ĐỀ — bắt đầu bằng một ví dụ để thầy thấy ngay

Người dân miền Trung gọi cứu hộ bằng giọng địa phương. Ứng dụng ghi âm rồi cho qua bộ
nhận dạng giọng nói để ra chữ. **Nhưng bộ nhận dạng được huấn luyện trên giọng chuẩn**,
nên khi nghe giọng miền Trung, nó **không hiểu người nói, mà chỉ phiên âm theo âm nghe được**:

| Người dân nói (ý muốn) | Máy ghi ra chữ | Vấn đề |
|---|---|---|
| nhà | **nhoà** | sai chính tả so với chuẩn |
| làm | **lồm** | |
| mái nhà | **mớ nhoà** | |

Hậu quả: câu SOS *"Nhoà tui ngập tới mớ nhoà rồi"* — hệ thống phía sau đọc chữ **"mớ nhoà"**
sẽ **không hiểu là "mái nhà"**, nên **không nhận ra đây là ca ngập tới mái (rất nguy hiểm)**
và xếp nhầm mức thấp.

**Nhiệm vụ của bước chuẩn hóa:** biến *"Nhoà tui ngập tới mớ nhoà rồi"* thành
*"Nhà tui ngập tới mái nhà rồi"* — tức **đổi chữ phương ngữ về chữ phổ thông**, để các bước
sau hiểu đúng.

---

## 2. Ý TƯỞNG CỐT LÕI (một câu)

Sai lệch của giọng miền Trung **không hỗn loạn mà có quy luật**. Ví dụ: hễ chữ nào có
nguyên âm "à" thì bị đọc thành "oà" (nhà→nhoà, già→gioà, cà→coà). **Đã có quy luật thì lập
được bảng sửa ngược.** Toàn bộ đề tài xoay quanh việc **mô hình hóa các quy luật này** và
dùng chúng để đổi ngược về chuẩn.

> Ẩn dụ dễ hiểu: giống như biết một người **luôn viết sai chính tả theo cùng một kiểu**,
> ta lập được bảng "thấy chữ này thì sửa thành chữ kia".

---

## 3. HAI LOẠI SAI — cần hai cách xử lý khác nhau

Khi phân tích phương ngữ, có **hai loại hiện tượng**, bản chất khác nhau:

**Loại A — Biến âm (đọc trại đi):** cùng một từ nhưng phát âm lệch.
`nhà→nhoà`, `làm→lồm`, `chặn→chẹn`, `vô→dô`. → Loại này **có công thức**, xử lý bằng **luật**.

**Loại B — Từ vựng riêng (dùng hẳn từ khác):** người miền Trung dùng một từ hoàn toàn khác.
`răng` = sao, `rứa` = thế, `mô` = đâu, `mi` = mày. → Không có công thức nào biến "răng" thành
"sao"; loại này **phải liệt kê tay**.

→ Vì hai loại khác bản chất nên hệ thống dùng **hai nguồn tri thức**: bộ luật (cho loại A) +
bảng liệt kê tay (cho loại B).

---

## 4. LÀM SAO TẠO RA TỪ ĐIỂN (đây là phần "làm ra sao để chuẩn hóa được")

Ý tưởng khéo: thay vì ngồi gõ tay hàng nghìn cặp từ, ta **sinh ngược tự động**.

**Nguyên liệu:** một danh sách **~74.000 từ tiếng Việt chuẩn** (bộ Viet74K, có sẵn, dùng
làm "nguồn sự thật" về từ chuẩn).

**Cách làm — với MỖI từ chuẩn, áp luật biến âm để đoán ra dạng phương ngữ của nó:**

Ví dụ chạy từng bước với từ **"làm"**:
1. Lấy từ chuẩn: `làm`.
2. Áp luật biến âm. Có luật: "vần **àm** đọc thành **ồm**". → `làm` biến thành `lồm`.
3. Ghi vào từ điển cặp: **`"lồm" → "làm"`** (thấy "lồm" thì sửa về "làm").

Làm y hệt cho cả 74.000 từ:
- `nhà` → (luật à→oà) → `nhoà` ⇒ lưu `"nhoà" → "nhà"`
- `già` → `gioà` ⇒ lưu `"gioà" → "già"`
- `chặn` → (luật ặn→ẹn) → `chẹn` ⇒ lưu `"chẹn" → "chặn"`
- `vô` → (luật v→d) → `dô` ⇒ lưu `"dô" → "vô"`

**Nhưng không phải dạng nào sinh ra cũng được giữ.** Có **ba điều kiện an toàn**, một mục
chỉ được lưu khi thỏa cả ba:
1. Dạng sinh ra **khác** từ gốc (nếu luật không đổi gì thì lưu vô ích).
2. **Không** nằm trong danh sách chặn (blacklist — một ít trường hợp cá biệt).
3. **Không trùng một từ chuẩn đã có** — **đây là điều kiện quan trọng nhất.**

Vì sao điều kiện 3 quan trọng nhất? Ví dụ: giả sử luật sinh ra chữ **"hoà"**. Nhưng "hoà"
**đã là một từ chuẩn** (hoà bình). Nếu ta lưu `"hoà" → ...`, thì **mọi câu phổ thông có chữ
"hoà" sẽ bị sửa sai nghĩa**. Nên hễ dạng sinh ra trùng một từ chuẩn đang tồn tại → **bỏ, không
lưu**. Điều kiện này giữ cho bộ chuẩn hóa **không phá văn bản bình thường**.

**Bước cuối:** gộp thêm **bảng từ vựng riêng gõ tay** (loại B: răng→sao, rứa→thế, mô→đâu...).

**Kết quả:** một tệp từ điển **hơn 26.000 mục**. Điểm cần nhấn: **chỉ vài chục mục là gõ tay
(loại B); hơn 26.000 mục còn lại do luật tự sinh (loại A).** Tệp này được **đóng gói sẵn trong
ứng dụng** và nạp vào bộ nhớ khi mở app.

---

## 5. LÀM SAO DÙNG TỪ ĐIỂN ĐỂ CHUẨN HÓA MỘT CÂU (đây là phần "chuẩn hóa hoạt động thế nào")

Có từ điển rồi, khi nạn nhân nhập một câu, thuật toán làm như sau: **duyệt câu từ trái sang
phải, tại mỗi vị trí thử khớp cụm 3 từ trước, rồi 2 từ, rồi 1 từ**; khớp ở mức nào thì thay và
nhảy qua đúng số từ đó.

**Chạy từng bước với câu:** `Nhoà tui ngập tới mớ nhoà rồi`

Tách thành các từ: `[Nhoà] [tui] [ngập] [tới] [mớ] [nhoà] [rồi]`

| Vị trí | Thử khớp | Kết quả |
|---|---|---|
| "Nhoà" | cụm 3 "nhoà tui ngập"? không. cụm 2 "nhoà tui"? không. **từ đơn "nhoà" → "nhà"** | ghi **"Nhà"** (giữ hoa), nhảy 1 |
| "tui" | không có trong từ điển | **giữ nguyên "tui"**, nhảy 1 |
| "ngập" | là từ chuẩn, không có trong dict | **giữ "ngập"**, nhảy 1 |
| "tới" | không có | **giữ "tới"**, nhảy 1 |
| "mớ" | cụm 3 "mớ nhoà rồi"? không. **cụm 2 "mớ nhoà" → "mái nhà"!** | ghi **"mái nhà"**, **nhảy 2** |
| "rồi" | không có | **giữ "rồi"**, nhảy 1 → hết câu |

Ghép lại: **`Nhà tui ngập tới mái nhà rồi`**. Chuẩn hóa xong.

**Chi tiết cần giảng kỹ — vì sao phải thử CỤM DÀI TRƯỚC?**
Nhìn chữ "mớ nhoà". Nếu thuật toán xử lý **từng từ đơn**:
- "mớ" → không có trong dict → giữ nguyên;
- "nhoà" → sửa thành "nhà";
- ⇒ ra **"mớ nhà"** — SAI.

Chỉ khi thử **cụm 2 từ "mớ nhoà"** (đã có sẵn một mục trong từ điển) thì mới ra đúng **"mái
nhà"**. Vì có những cụm mang nghĩa nguyên khối như vậy, thuật toán **bắt buộc thử cụm dài
trước, ngắn sau**.

**Hai nguyên tắc an toàn của bước chạy:**
- **Giữ nguyên viết hoa:** "Lồm" đầu câu → "Làm" (không phá đầu câu / tên riêng).
- **Từ lạ giữ nguyên:** từ nào không có trong từ điển thì để y như cũ → bộ chuẩn hóa **không
  bao giờ làm hỏng** phần văn bản nó không chắc.

---

## 6. NÓ CHẠY Ở ĐÂU, KHI NÀO

- **Chạy ngay trên điện thoại**, tại thời điểm nạn nhân nhập/đọc mô tả SOS.
- **Không cần mạng** — từ điển đã nạp sẵn trong bộ nhớ. Đây là điều quan trọng với **vùng lũ
  mạng chập chờn**: bước làm sạch chữ không được phụ thuộc Internet.
- Sau khi chuẩn hóa, câu đã sạch mới được đưa vào bước phân loại mức khẩn cấp và gửi lên máy
  chủ. Hệ thống **giữ cả bản gốc lẫn bản đã chuẩn hóa** để đối chiếu về sau.

---

## 7. TÓM TẮT MỘT SƠ ĐỒ (vẽ lên bảng nếu cần)

```
   Người dân nói giọng miền Trung
              │
              ▼
   Nhận dạng giọng nói  →  ra chữ phương ngữ:  "Nhoà tui ngập tới mớ nhoà rồi"
              │
              ▼
   ┌─────────────── BƯỚC CHUẨN HÓA (offline, trên máy) ───────────────┐
   │  Tra TỪ ĐIỂN đã dựng sẵn (>26.000 mục):                          │
   │   • hơn 26.000 mục do LUẬT biến âm tự sinh (nhoà→nhà, lồm→làm)   │
   │   • vài chục mục GÕ TAY cho từ vựng riêng (răng→sao, rứa→thế)    │
   │  Thuật toán: khớp cụm 3→2→1 từ, giữ hoa, giữ từ lạ.              │
   └──────────────────────────────────────────────────────────────────┘
              │
              ▼
   Chữ phổ thông:  "Nhà tui ngập tới mái nhà rồi"
              │
              ▼
   Phân loại mức khẩn cấp  →  hiểu đúng "mái nhà" → nâng đúng mức
```

---

## 8. CÁCH XÂY DỰNG TỪ ĐIỂN — nói gọn trong 4 câu (nếu thầy hỏi "làm bằng cách nào")

1. Lấy ~74.000 từ tiếng Việt chuẩn làm nguồn.
2. Với mỗi từ, áp bộ **luật biến âm** để sinh ngược ra dạng phương ngữ (làm→lồm), lưu cặp
   "phương ngữ → chuẩn".
3. **Lọc bỏ** những dạng trùng từ chuẩn (chống làm sai nghĩa) và vài trường hợp cá biệt.
4. Gộp thêm bảng **từ vựng riêng** gõ tay → được tệp hơn 26.000 mục, đóng gói trong app.

## 9. CÁCH CHUẨN HÓA MỘT CÂU — nói gọn trong 3 câu

1. Tách câu thành các từ.
2. Duyệt trái→phải, tại mỗi chỗ **thử khớp cụm dài trước (3 rồi 2 rồi 1 từ)**; khớp thì thay,
   không thì giữ nguyên.
3. Giữ nguyên viết hoa và giữ nguyên từ không có trong từ điển.

---

## THÔNG ĐIỆP KẾT (nói khi khép lại phần này)

> "Nói ngắn gọn: em quan sát thấy giọng miền Trung bị nhận dạng sai **theo quy luật**, nên em
> **mô hình hóa các quy luật đó thành luật biến âm**, rồi **áp lên 74.000 từ chuẩn để sinh tự
> động một từ điển ánh xạ hơn 26.000 mục**. Khi có câu SOS, thuật toán **tra từ điển này ngay
> trên máy, không cần mạng**, đổi chữ phương ngữ về chữ phổ thông để các bước sau hiểu đúng.
> Phần lớn từ điển là **tự sinh từ luật**, chỉ một phần nhỏ là gõ tay cho những từ vựng đặc
> thù không suy ra được bằng luật."
