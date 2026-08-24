# SLIDE + KỊCH BẢN NÓI — PHÂN LOẠI MỨC ĐỘ KHẨN CẤP

> Cặp với `slide_kich_ban_chuan_hoa.md`. Cùng phong cách để hai bộ slide đồng bộ.
> PHẦN 1: kịch bản nói theo từng slide. PHẦN 2: prompt dán cho Claude add-in PowerPoint.
> Bộ gồm 8 slide, nói khoảng 4–5 phút.

---

# PHẦN 1 — KỊCH BẢN NÓI THEO TỪNG SLIDE

## Slide 1 — Tiêu đề
**Trên slide:** "Phân loại mức độ khẩn cấp" — phụ đề "Gán mức 1–5 và nhãn cho mỗi ca SOS để điều phối đúng ưu tiên".

**Lời nói:**
"Thưa thầy, phần này là cơ chế phân loại. Sau khi câu SOS được chuẩn hóa, hệ thống phải gán cho nó một mức khẩn cấp từ 1 đến 5 và các nhãn — như y tế, trẻ em, người già — để điều phối cứu hộ đúng thứ tự ưu tiên."

## Slide 2 — Vấn đề: ba yêu cầu mâu thuẫn
**Trên slide:** ba ô ngang: "Luôn phải có kết quả (kể cả mất mạng / AI sập)"; "Cần hiểu ngữ cảnh ('không bị thương' ≠ 'bị thương')"; "Không được bỏ sót ca nguy kịch". Dưới cùng: "Một cơ chế đơn lẻ không thỏa cả ba".

**Lời nói:**
"Bài toán có ba yêu cầu xung khắc nhau. Một, luôn phải có kết quả kể cả khi mất mạng — vì đây là hệ cứu người. Hai, phải hiểu ngữ cảnh: câu 'không có ai bị thương' khác hẳn 'có người bị thương', mà chỉ mô hình ngôn ngữ lớn hiểu tốt, nhưng nó chậm và cần mạng. Ba, tuyệt đối không bỏ sót ca nguy kịch. Một cơ chế đơn lẻ không thỏa được cả ba, nên em kết hợp hai nhánh."

## Slide 3 — Ý tưởng: hai nhánh + sàn an toàn
**Trên slide:** hai khối "Nhánh DÒ TỪ KHÓA — nhanh, tất định, không bao giờ lỗi (lớp bảo hiểm)" và "Nhánh MÔ HÌNH NGÔN NGỮ LỚN — hiểu ngữ cảnh (lớp hiểu sâu)", nối xuống một khối "Hợp nhất: LẤY MỨC CAO HƠN".

**Lời nói:**
"Ý tưởng cốt lõi: hai nhánh bù nhau. Nhánh dò từ khóa chạy cục bộ, nhanh, không bao giờ lỗi — đóng vai lớp bảo hiểm, luôn có kết quả kể cả khi mất mạng. Nhánh mô hình ngôn ngữ lớn hiểu ngữ cảnh sâu hơn. Cuối cùng hợp nhất bằng cách lấy mức cao hơn — em sẽ giải thích vì sao ở cuối."

## Slide 4 — Nhánh dò từ khóa
**Trên slide:** bảng mức gọn (5: máu/đuối nước/không thở; 4: trẻ em/người già/ngập nóc/bị thương; 3: kẹt/cô lập; 2: ngập/nước lên; 1: mặc định). Bên dưới một ví dụ: «Ba tôi bị thương chảy máu, phải đi cấp cứu» → thấy "máu" (mức 5) → kết quả mức 5, nhãn y_te.

**Lời nói:**
"Nhánh thứ nhất rất đơn giản về ý tưởng: có bảng từ khóa cho từng mức. Thấy từ khóa mức nào thì gán mức đó, và lấy mức cao nhất. Ví dụ câu này có 'máu' là từ khóa mức 5, có 'bị thương' và 'cấp cứu' — kết quả là mức 5, gắn nhãn y tế. Nhưng dò 'ngây thơ' sẽ sai, nên có ba tinh chỉnh quan trọng ở slide sau."

## Slide 5 — Ba tinh chỉnh của nhánh từ khóa (slide đinh)
**Trên slide:** ba ô, mỗi ô một tinh chỉnh + ví dụ:
1. "Khớp theo BIÊN TỪ" — ví dụ: 'không' chứa 'ông', 'bàn' chứa 'bà' → không được nhận nhầm.
2. "Xử lý PHỦ ĐỊNH (cửa sổ 2 từ)" — ví dụ: «không ai bị thương» → 'bị thương' bị vô hiệu.
3. "Loại CỤM ĐÁNH LỪA" — ví dụ: 'kẹt xe', 'xe chết máy' bị xóa trước khi dò.

**Lời nói:**
"Ba tinh chỉnh. Một, khớp theo biên từ chứ không phải chuỗi con — vì chữ 'không' chứa 'ông', 'bàn' chứa 'bà'; nếu tìm chuỗi con thì mọi câu có 'không' đều bị gán nhầm nhãn người già. Hai, xử lý phủ định: câu 'may quá không ai bị thương' có từ khóa 'bị thương' nhưng thực ra là báo an toàn, nên nếu ngay trước từ khóa trong hai từ có từ phủ định thì bỏ qua. Ba, loại các cụm đánh lừa như 'kẹt xe' hay 'xe chết máy' — chúng chứa từ khóa nhưng vô nghĩa với lũ, nên xóa trước khi dò."

## Slide 6 — Nhánh mô hình ngôn ngữ lớn (Gemini)
**Trên slide:** bốn gạch đầu dòng: "Prompt few-shot: định nghĩa thang 1–5 + ví dụ mẫu"; "Ép trả JSON, temperature 0,1 (giảm ngẫu nhiên)"; "Giới hạn thời gian chờ cứng ~3 giây → quá thì bỏ"; "Tắt suy luận nội tại để đủ nhanh".

**Lời nói:**
"Nhánh thứ hai gọi mô hình Gemini. Câu nhắc được thiết kế theo hướng học ít mẫu: định nghĩa thang mức và kèm vài ví dụ để định hướng; ép trả về JSON, temperature thấp để ổn định. Quan trọng: có giới hạn thời gian chờ cứng khoảng ba giây — quá thì bỏ. Và em tắt chế độ suy luận nội tại của mô hình, vì với bài gán một nhãn cho câu ngắn, nó không cải thiện chất lượng nhưng chiếm phần lớn thời gian — tắt đi thì ngưỡng ba giây mới khả thi."

## Slide 7 — Hợp nhất: sàn an toàn (slide đinh)
**Trên slide:** sơ đồ hai nhánh chụm vào một khối "MỨC = MAX(hai nhánh)". Bên dưới một ví dụ nổi bật: «có người đuối nước» → Từ khóa: mức 5 · Gemini: nhầm mức 2 · Kết quả MAX = 5. Câu chú thích: "Thà cao hơn còn hơn bỏ sót ca nguy kịch".

**Lời nói:**
"Bước hợp nhất là chỗ quan trọng nhất. Mức cuối luôn lấy giá trị cao hơn giữa hai nhánh. Ví dụ câu có 'đuối nước' — nhánh từ khóa cho mức 5; giả sử mô hình hiểu nhầm ngữ cảnh và cho mức 2; thì kết quả cuối vẫn là 5. Đây là sàn an toàn có chủ đích: trong cứu hộ, bỏ sót một ca nguy kịch là hậu quả không đảo ngược, còn một báo động giả chỉ tốn công — nên hệ thống cố ý nghiêng về phía an toàn. Ngoài ra, nếu mô hình mất mạng hoặc quá giờ, hệ vẫn dùng kết quả nhánh từ khóa, luồng tạo ca không bị nghẽn."

## Slide 8 — Kết / Sơ đồ tổng
**Trên slide:** sơ đồ luồng: "Câu SOS đã chuẩn hóa" → chia hai nhánh (Từ khóa / Gemini) → "MAX + hợp nhãn" → "Mức + Nhãn → Điều phối". Câu chốt lớn: "Hai lớp bù nhau — sàn an toàn nghiêng về không bỏ sót".

**Lời nói:**
"Tóm lại: phân loại không dựa vào một cơ chế duy nhất. Nhánh từ khóa là lớp bảo hiểm luôn có kết quả, với ba tinh chỉnh để không nhận nhầm. Nhánh mô hình lớn hiểu ngữ cảnh. Mức cuối lấy cao hơn giữa hai nhánh — sàn an toàn để không bỏ sót ca nguy kịch. Em xin hết phần này ạ."

---

# PHẦN 2 — PROMPT DÁN CHO CLAUDE ADD-IN TRONG POWERPOINT

Sao chép nguyên khối dưới đây, dán vào Claude add-in trong PowerPoint:

---

Hãy tạo một bộ slide PowerPoint 16:9 bằng tiếng Việt, chủ đề "Phân loại mức độ khẩn cấp" cho buổi bảo vệ khóa luận. Gồm đúng 8 slide theo nội dung bên dưới. Bộ này cùng phong cách với bộ slide "Chuẩn hóa phương ngữ" đã có, hãy giữ đồng bộ.

YÊU CẦU PHONG CÁCH (áp cho cả bộ):
- Phong cách học thuật, sạch, tối giản. TUYỆT ĐỐI KHÔNG dùng emoji, không clip-art, không hình trang trí.
- Bảng màu: xanh dương đậm (#1F4E79) làm màu nhấn cho tiêu đề và tiêu điểm; chữ thân màu xám đậm (#333333); nền trắng; dùng xanh nhạt (#DDEBF7) hoặc xám nhạt (#F2F2F2) cho ô/bảng.
- Font: một font sans-serif dễ đọc (Calibri hoặc Arial). Tiêu đề slide 28–32pt in đậm; chữ thân 18–20pt.
- Mỗi slide có thanh tiêu đề trên cùng và số trang ở góc dưới phải.
- Ưu tiên bảng, mũi tên, sơ đồ khối đơn giản; hạn chế gạch đầu dòng dài; mỗi ý ngắn gọn.
- Nhất quán bố cục giữa các slide.

NỘI DUNG TỪNG SLIDE:

Slide 1 (trang bìa): Tiêu đề lớn "PHÂN LOẠI MỨC ĐỘ KHẨN CẤP". Phụ đề "Gán mức 1–5 và nhãn cho mỗi ca SOS để điều phối đúng ưu tiên". Dòng nhỏ: "Đề tài FloodAid — Nền tảng điều phối cứu trợ lũ lụt".

Slide 2 (Vấn đề): Tiêu đề "Ba yêu cầu mâu thuẫn nhau". Ba ô ngang hàng, mỗi ô một yêu cầu: (1) "Luôn phải có kết quả — kể cả khi mất mạng hoặc AI sập"; (2) "Cần hiểu ngữ cảnh — 'không bị thương' khác 'bị thương'"; (3) "Không được bỏ sót ca nguy kịch". Bên dưới một dòng kết: "Một cơ chế đơn lẻ không thỏa cả ba → kết hợp hai nhánh".

Slide 3 (Ý tưởng): Tiêu đề "Giải pháp: hai nhánh + sàn an toàn". Hai khối song song: khối trái "Nhánh DÒ TỪ KHÓA — cục bộ, nhanh, không bao giờ lỗi → lớp bảo hiểm"; khối phải "Nhánh MÔ HÌNH NGÔN NGỮ LỚN (Gemini) — hiểu ngữ cảnh → lớp hiểu sâu". Hai khối có mũi tên chụm xuống một khối bên dưới: "Hợp nhất: LẤY MỨC CAO HƠN".

Slide 4 (Nhánh từ khóa): Tiêu đề "Nhánh 1 — Dò từ khóa". Một bảng 2 cột (Mức | Từ khóa tiêu biểu): 5 | máu, đuối nước, không thở, chết; 4 | trẻ em, người già, ngập nóc, bị thương, cấp cứu; 3 | kẹt, mắc kẹt, cô lập, nước dâng; 2 | ngập, nước lên, cần xuồng; 1 | (không khớp gì). Bên dưới một hộp ví dụ: «Ba tôi bị thương chảy máu, phải đi cấp cứu» → "máu" = mức 5 → Kết quả: mức 5, nhãn y_te.

Slide 5 (Ba tinh chỉnh): Tiêu đề "Ba tinh chỉnh để không nhận nhầm". Ba ô/thẻ, mỗi ô một tiêu đề + một ví dụ ngắn: Ô 1 "Khớp theo BIÊN TỪ" — ví dụ: 'không' chứa 'ông', 'bàn' chứa 'bà' → không nhận nhầm nhãn người già. Ô 2 "Xử lý PHỦ ĐỊNH (cửa sổ 2 từ)" — ví dụ: «không ai bị thương» → từ khóa 'bị thương' bị vô hiệu. Ô 3 "Loại CỤM ĐÁNH LỪA" — ví dụ: 'kẹt xe', 'xe chết máy' bị xóa trước khi dò.

Slide 6 (Nhánh Gemini): Tiêu đề "Nhánh 2 — Mô hình ngôn ngữ lớn (Gemini)". Bốn gạch đầu dòng ngắn: "Prompt học ít mẫu: định nghĩa thang 1–5 + ví dụ mẫu"; "Ép trả JSON, temperature 0,1 (ổn định, giảm ngẫu nhiên)"; "Giới hạn thời gian chờ cứng ~3 giây → quá thì bỏ, dùng nhánh từ khóa"; "Tắt suy luận nội tại (thinking) để đủ nhanh".

Slide 7 (Sàn an toàn): Tiêu đề "Hợp nhất — Sàn an toàn". Một sơ đồ: hai khối "Nhánh từ khóa" và "Nhánh Gemini" chụm bằng mũi tên vào một khối lớn "MỨC = MAX(hai nhánh)". Bên dưới một hộp ví dụ nổi bật: «có người đuối nước» → Từ khóa: mức 5 | Gemini: nhầm mức 2 | Kết quả MAX = 5. Một dòng chú thích in đậm màu nhấn: "Thà cao hơn còn hơn bỏ sót ca nguy kịch". Thêm một dòng nhỏ: "Nếu Gemini timeout/mất mạng → dùng kết quả nhánh từ khóa".

Slide 8 (Kết luận): Tiêu đề "Kết luận". Một sơ đồ luồng ngang: "Câu SOS đã chuẩn hóa" → tách hai nhánh "Từ khóa" và "Gemini" → "MAX + hợp nhãn" → "Mức + Nhãn → Điều phối". Bên dưới một câu chốt cỡ lớn, in đậm, màu nhấn: "Hai lớp bù nhau — sàn an toàn nghiêng về KHÔNG BỎ SÓT".

Sau khi tạo xong, giữ định dạng nhất quán với bộ slide chuẩn hóa và kiểm tra không có emoji nào.

---

## GHI CHÚ KHI DÙNG
- Slide 5 (ba tinh chỉnh) và Slide 7 (sàn an toàn) là hai slide quan trọng nhất — nói kỹ.
- Nếu bị giục thời gian: gộp Slide 2 vào Slide 3, và nói lướt Slide 6.
- Nếu add-in dựng bảng/sơ đồ chưa đúng, bảo nó "chỉnh slide X theo đúng các dòng em ghi".
