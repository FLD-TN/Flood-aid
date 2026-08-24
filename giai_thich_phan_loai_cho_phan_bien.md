# GIẢI THÍCH CƠ CHẾ PHÂN LOẠI MỨC ĐỘ KHẨN CẤP (cho người chưa biết đề tài)

> Giảng cho giảng viên phản biện hiểu **phân loại là gì, hoạt động ra sao**, bằng ví dụ
> chạy từng bước. Bám sát Chương 4.2 báo cáo. (Cặp với file `giai_thich_chuan_hoa_cho_phan_bien.md`.)

---

## 1. VẤN ĐỀ — phải giải quyết ba yêu cầu MÂU THUẪN nhau

Sau khi có câu SOS (đã chuẩn hóa), hệ thống phải gán cho nó **một mức khẩn cấp (1–5)** và
**các nhãn** (y tế, trẻ em, người già, ngập nóc, cần phương tiện) để điều phối đúng thứ tự ưu tiên.

Nhưng bài toán có **ba yêu cầu xung khắc**:
1. **Luôn phải có kết quả** — kể cả khi mất mạng hoặc dịch vụ AI sập (đây là hệ cứu người).
2. **Cần hiểu ngữ cảnh** — "không có ai bị thương" khác hẳn "có người bị thương"; chỉ mô hình
   ngôn ngữ lớn (LLM) hiểu tốt, nhưng nó **chậm và phụ thuộc mạng**.
3. **Không được bỏ sót ca nguy kịch** — bỏ sót một ca đuối nước là hậu quả không đảo ngược.

Một cơ chế đơn lẻ không thỏa cả ba. Giải pháp: **kết hợp hai nhánh**.

---

## 2. Ý TƯỞNG CỐT LÕI — hai nhánh, một sàn an toàn

- **Nhánh 1 — Dò từ khóa (chạy trên máy chủ, cục bộ):** nhanh, tất định, **không bao giờ lỗi**.
  Vai trò: **lớp bảo đảm tối thiểu** — luôn có kết quả kể cả khi mất mạng.
- **Nhánh 2 — Mô hình ngôn ngữ lớn (Gemini):** hiểu ngữ cảnh. Vai trò: **lớp hiểu sâu**.
- **Hợp nhất theo nguyên tắc LẤY MỨC CAO HƠN** (sàn an toàn): thà đánh giá cao hơn thực tế
  còn hơn bỏ sót nguy hiểm.

> Một câu: *"Từ khóa giữ cho hệ không bao giờ 'mù'; mô hình lớn giúp hiểu đúng ngữ cảnh; và
> mức cuối luôn lấy cái cao hơn để không bỏ sót ca nguy kịch."*

---

## 3. NHÁNH 1 — DÒ TỪ KHÓA (chi tiết, có ví dụ chạy)

Ý tưởng gốc rất đơn giản: có **bảng từ khóa cho từng mức** và **bảng từ khóa cho từng nhãn**.
Thấy từ khóa mức nào thì gán mức đó; thấy từ khóa nhãn nào thì gắn nhãn đó.

**Bảng mức (rút gọn):**
| Mức | Từ khóa tiêu biểu |
|---|---|
| 5 – nguy hiểm tính mạng | máu, bất tỉnh, không thở, chết, chìm, đuối nước |
| 4 – khẩn cấp cao | trẻ em, người già, ngập nóc, mái nhà, bị thương, gãy, cấp cứu |
| 3 – trung bình | kẹt, mắc kẹt, cô lập, nước dâng, ngập sâu |
| 2 – thấp | ngập, nước lên, cần xuồng, cần giúp |
| 1 – mặc định | (không khớp gì) |

**Ví dụ chạy 1 — câu đơn giản:**
Câu: *"Ba tôi bị thương chảy máu nhiều, phải đưa đi cấp cứu"*
- Thấy "máu" → mức 5. Thấy "bị thương", "cấp cứu" → mức 4.
- Lấy **mức cao nhất = 5**. Nhãn: "máu/bị thương/cấp cứu" → nhãn **y_te**.
- Kết quả: **mức 5, nhãn [y_te]**.

Nhưng cách dò "ngây thơ" (chỉ tìm chuỗi con) sẽ **sai nặng**. Có **ba tinh chỉnh** quan trọng:

### 3a. So khớp theo BIÊN TỪ (không phải chuỗi con)
Tiếng Việt có nhiều từ **chứa nhau ở mức ký tự**: chữ **"không"** chứa **"ông"**, chữ **"bàn"**
chứa **"bà"**. Nếu tìm chuỗi con, mọi câu có "không" đều bị gán nhầm nhãn **người già** (vì
"ông" là từ khóa người già). Vì vậy hệ thống **tách câu thành từng từ** và một từ khóa chỉ tính
khi **trùng khớp trọn vẹn** một (hoặc một dãy) từ, không phải nằm lọt bên trong một từ khác.

### 3b. Xử lý PHỦ ĐỊNH (điểm tinh tế nhất)
Có từ khóa **chưa chắc** mang nghĩa khẩn cấp. Câu *"May quá **không** ai bị thương"* chứa từ
khóa "bị thương" (mức 4) nhưng thực ra là **báo an toàn**. Nên: một từ khóa bị **bỏ qua** nếu
**ngay trước nó, trong cùng mệnh đề, trong khoảng 2 từ**, có từ phủ định (không, chưa, chẳng,
khỏi, đừng...).

**Ví dụ chạy 2 — phủ định:**
Câu: *"May quá không ai bị thương"* → thấy "bị thương", nhưng cách 2 từ phía trước có "không"
→ **vô hiệu hóa** → **không** gán mức 4. Kết quả đúng: mức thấp.

Ba lựa chọn thiết kế của cơ chế phủ định (đều có lý do cứu hộ):
- **Dấu câu làm ranh giới mệnh đề:** để phủ định ở vế trước không "với" sang vế sau. Câu *"nước
  không rút, nhà ngập nóc"* — "ngập nóc" (vế sau) **vẫn phải tính**, không bị "không" ở vế trước triệt tiêu.
- **Cửa sổ chỉ 2 từ (hẹp):** vì **chặn nhầm một từ khóa thật (âm tính giả) nguy hiểm hơn nhiều**
  so với một báo động giả. Cửa sổ càng rộng càng dễ chặn nhầm → cố ý để hẹp.
- **Từ khóa tự mở đầu bằng phủ định thì KHÔNG xét phủ định:** ví dụ "**không thở**" — bản thân nó
  đã chứa "không" và là **dấu hiệu nguy kịch nhất**; nếu xét phủ định sẽ tự loại chính nó.

### 3c. Loại các CỤM CỐ ĐỊNH đánh lừa
Vài cụm chứa từ khóa nhưng không mang nghĩa cứu hộ: **"kẹt xe"**, **"xe chết máy"**. Chúng chứa
"kẹt" (mức 3) và "chết" (mức 5) nhưng vô nghĩa với lũ. Hệ thống **xóa các cụm này khỏi câu**
trước khi dò.

**Ví dụ chạy 3 — cụm loại trừ:**
Câu: *"đường kẹt xe không đi được"* → cụm "kẹt xe" bị xóa trước → "kẹt" không còn → **không** bị
đẩy lên mức 3 vì lý do sai.

> Nhánh này chạy **đồng bộ, không bao giờ ném lỗi** → luôn cho ra một kết quả trong tức khắc.

---

## 4. NHÁNH 2 — MÔ HÌNH NGÔN NGỮ LỚN (Gemini)

Nhánh này gửi câu cho mô hình **Gemini 2.5 Flash** kèm một **câu nhắc (prompt)** thiết kế cẩn thận:
- Định nghĩa thang mức 1–5 và tập nhãn hợp lệ.
- Kèm **vài ví dụ mẫu** (few-shot) để định hướng đầu ra.
- Ép trả về **JSON** (`responseMimeType: application/json`) và **temperature = 0,1** (giảm ngẫu
  nhiên — bài phân loại cần cùng đầu vào cho cùng đầu ra).

Ba điểm kỹ thuật đáng nói:
1. **Kiểm tra lược đồ:** kết quả phải đủ ba trường và mức phải trong [1,5]; sai định dạng → coi
   là **lỗi có kiểm soát**, nhánh này thất bại êm chứ không làm sập hệ.
2. **Giới hạn thời gian chờ cứng (~3 giây):** dùng `Promise.race` giữa lời gọi mô hình và một bộ
   đếm giờ; hết 3 giây mà chưa trả lời thì bỏ, quay về dùng nhánh từ khóa.
3. **Tắt "suy luận nội tại" (`thinkingBudget: 0`):** Gemini 2.5 Flash mặc định tự sinh một chuỗi
   lập luận trung gian trước khi trả lời. Với bài **gán một nhãn cho câu ngắn**, chuỗi này **không
   cải thiện chất lượng** nhưng **chiếm phần lớn thời gian**. Tắt nó → giảm mạnh độ trễ → nhờ đó
   ngưỡng 3 giây mới khả thi.

---

## 5. HỢP NHẤT HAI NHÁNH — sàn an toàn (điểm cốt lõi)

Trình tự thực thi (quan trọng — hay bị hỏi):
1. Chạy **nhánh từ khóa trước** (đồng bộ, tức thì, chắc chắn có kết quả).
2. Rồi mới **chờ nhánh Gemini** (có giới hạn thời gian).
3. **Hai nhánh KHÔNG chạy đua nhau** — `Promise.race` chỉ nằm bên trong nhánh Gemini để chặn
   thời gian chờ. Nhánh từ khóa **không** rút ngắn thời gian phản hồi; vai trò của nó là **bảo hiểm**.

Quy tắc hợp nhất:
- **Mức cuối = LẤY CAO HƠN** giữa hai nhánh (`Math.max`). Đây là **sàn an toàn**.
- **Nhãn = HỢP** nhãn của cả hai nhánh (gộp, bỏ trùng).
- Ghi lại **nguồn kết quả** (`ai_source`: gemini hay rule_based) để đối chiếu.

**Ví dụ chạy 4 — sàn an toàn cứu một ca:**
Câu: *"nước cuốn trôi, có người bị đuối nước"*
- Nhánh từ khóa: thấy "đuối nước" → **mức 5**.
- Giả sử Gemini hiểu nhầm ngữ cảnh, trả về **mức 2**.
- `Math.max(2, 5)` = **5**. → Ca nguy kịch **không bị hạ oan**.

**Ví dụ chạy 5 — dự phòng khi mất mạng:**
Câu bất kỳ, nhưng Gemini **timeout/mất mạng** → nhánh Gemini thất bại êm → hệ **dùng kết quả
nhánh từ khóa**. → Luồng tạo ca **không bị nghẽn**, vẫn có mức để điều phối.

**Vì sao lấy cao hơn chứ không lấy trung bình / không tin hẳn Gemini?**
Trong cứu hộ, **bỏ sót một ca nguy kịch để lại hậu quả không đảo ngược**, còn **một báo động giả
chỉ tốn công**. Nên hệ thống **cố ý nghiêng về phía an toàn** — thà cao hơn thực tế còn hơn để lọt
dấu hiệu nguy hiểm. Đây là **đánh đổi có chủ đích**, phù hợp đặc thù bài toán sinh mạng.

---

## 6. NÓ CHẠY Ở ĐÂU, KHI NÀO

- Chạy **trên máy chủ**, ngay khi nhận câu SOS đã chuẩn hóa từ thiết bị (bộ điều khiển `createSos`).
- Kết quả (mức + nhãn) được lưu cùng ca vào cơ sở dữ liệu, rồi ca được điều phối theo mức ưu tiên.
- **Chuẩn hóa (4.1) là điều kiện để nhánh từ khóa chạy đúng:** nhánh này khớp theo mặt chữ, nên
  nếu câu còn ở dạng phương ngữ ("mớ nhoà") thì nó không thấy từ khóa "mái nhà" → xếp nhầm mức.

---

## 7. SƠ ĐỒ (vẽ lên bảng nếu cần)

```
                 Câu SOS đã chuẩn hóa
                        │
          ┌─────────────┴─────────────┐
          ▼                           ▼
  NHÁNH TỪ KHÓA                 NHÁNH GEMINI (LLM)
  (cục bộ, tức thì,             (hiểu ngữ cảnh, ~3s,
   không bao giờ lỗi)            có thể timeout/lỗi)
          │                           │
          └─────────────┬─────────────┘
                        ▼
          HỢP NHẤT:  mức = MAX(hai nhánh)   ← sàn an toàn
                     nhãn = HỢP hai nhánh
                        │
                        ▼
             Mức khẩn cấp + Nhãn  →  Điều phối
```

---

## 8. TÓM TẮT NHANH (đọc 5 phút cuối)
- **Hai nhánh:** dò từ khóa (bảo hiểm, offline được, luôn có kết quả) + Gemini (hiểu ngữ cảnh).
- Nhánh từ khóa có **3 tinh chỉnh:** khớp theo biên từ, xử lý phủ định (cửa sổ 2 từ), loại cụm
  đánh lừa (kẹt xe, chết máy).
- Gemini: prompt few-shot, JSON, temperature 0,1, **timeout 3s**, **tắt thinking** để đủ nhanh.
- **Hợp nhất bằng MAX** = sàn an toàn: thà cao hơn còn hơn bỏ sót ca nguy kịch.
- Chuẩn hóa (4.1) là điều kiện để nhánh từ khóa không đánh giá sai với người nói phương ngữ.

## THÔNG ĐIỆP KẾT (nói khi khép lại)
> "Phân loại của em không dựa vào một cơ chế duy nhất. Nhánh dò từ khóa là lớp bảo hiểm — luôn
> cho kết quả kể cả khi mất mạng — với các tinh chỉnh để không nhận nhầm (khớp theo biên từ, xử lý
> phủ định, loại cụm đánh lừa). Nhánh mô hình ngôn ngữ lớn hiểu ngữ cảnh sâu hơn. Cuối cùng, mức
> khẩn cấp luôn lấy giá trị cao hơn giữa hai nhánh — một sàn an toàn có chủ đích, vì trong cứu hộ,
> bỏ sót một ca nguy kịch nguy hiểm hơn nhiều so với một báo động giả."
