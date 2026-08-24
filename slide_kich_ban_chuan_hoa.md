# SLIDE + KỊCH BẢN NÓI — CHUẨN HÓA PHƯƠNG NGỮ

> Dùng cho buổi phản biện. PHẦN 1 là kịch bản nói theo từng slide (đọc là giảng được).
> PHẦN 2 là prompt dán thẳng cho Claude add-in trong PowerPoint để dựng bộ slide này.
> Bộ gồm 8 slide, thời lượng nói khoảng 4–5 phút.

---

# PHẦN 1 — KỊCH BẢN NÓI THEO TỪNG SLIDE

## Slide 1 — Tiêu đề
**Trên slide:** "Chuẩn hóa phương ngữ miền Trung" — phụ đề "Cơ chế đưa lời cầu cứu giọng địa phương về tiếng Việt phổ thông" — tên đề tài FloodAid, tên SV, GVHD.

**Lời nói:**
"Thưa thầy, em xin trình bày một trong ba cơ chế cốt lõi của hệ thống: chuẩn hóa phương ngữ. Đây là bước đưa lời cầu cứu nói bằng giọng miền Trung về tiếng Việt phổ thông để hệ thống hiểu đúng."

## Slide 2 — Vấn đề
**Trên slide:** một bảng 3 dòng: "Người dân nói (nhà / làm / mái nhà)" → "Máy ghi ra (nhoà / lồm / mớ nhoà)". Bên dưới một câu ví dụ đỏ: *"Nhoà tui ngập tới mớ nhoà rồi"* với chú thích "hệ thống không hiểu 'mớ nhoà' là 'mái nhà' → xếp nhầm mức thấp".

**Lời nói:**
"Bộ nhận dạng giọng nói được huấn luyện trên giọng chuẩn. Khi gặp giọng miền Trung, nó không hiểu người nói mà chỉ phiên âm theo âm nghe được: nói 'nhà' nó ghi 'nhoà', nói 'mái nhà' nó ghi 'mớ nhoà'. Hậu quả: câu này, hệ thống không nhận ra đây là ca ngập tới mái — vốn rất nguy hiểm — nên xếp nhầm mức thấp. Chuẩn hóa sinh ra để giải quyết đúng chỗ này."

## Slide 3 — Ý tưởng cốt lõi
**Trên slide:** một dòng lớn "Sai lệch CÓ QUY LUẬT → sửa ngược được". Bên dưới ví dụ: "à → oà: nhà→nhoà, già→gioà, cà→coà". Một ô ẩn dụ nhỏ: "Giống người luôn viết sai chính tả theo một kiểu — ta lập bảng sửa ngược."

**Lời nói:**
"Điểm mấu chốt: sai lệch này không hỗn loạn mà có quy luật. Ví dụ hễ nguyên âm 'à' thì bị đọc thành 'oà' — nhà thành nhoà, già thành gioà. Đã có quy luật thì lập được bảng sửa ngược. Giống như biết một người luôn viết sai chính tả theo cùng một kiểu, mình lập bảng thấy chữ này thì sửa thành chữ kia."

## Slide 4 — Hai loại sai, hai cách xử lý
**Trên slide:** hai cột. Cột A "Biến âm — CÓ công thức": nhà→nhoà, làm→lồm, chặn→chẹn, vô→dô → "xử lý bằng LUẬT". Cột B "Từ vựng riêng — KHÔNG công thức": răng=sao, rứa=thế, mô=đâu, mi=mày → "phải LIỆT KÊ tay".

**Lời nói:**
"Phân tích kỹ thì có hai loại hiện tượng, bản chất khác nhau. Loại A là biến âm — cùng một từ nhưng đọc trại, loại này có công thức nên xử lý bằng luật. Loại B là từ vựng riêng — người miền Trung dùng hẳn từ khác, 'răng' nghĩa là 'sao', không công thức nào biến 'răng' thành 'sao' được, nên phải liệt kê tay. Vì hai loại khác bản chất, hệ thống dùng hai nguồn tri thức tương ứng."

## Slide 5 — Cách TẠO từ điển (tự sinh)
**Trên slide:** sơ đồ ngang: "74.000 từ chuẩn (Viet74K)" → [áp LUẬT biến âm] → "dạng phương ngữ". Một ví dụ chạy: `làm` --(àm→ồm)--> `lồm` ⇒ lưu `"lồm" → "làm"`. Bên dưới ô "3 điều kiện an toàn: (1) khác từ gốc (2) không bị chặn (3) KHÔNG trùng từ chuẩn". Góc: "Kết quả: hơn 26.000 mục — phần lớn tự sinh".

**Lời nói:**
"Đây là cách tạo từ điển — và là chỗ em muốn nhấn. Thay vì gõ tay hàng nghìn cặp, em sinh ngược tự động. Lấy 74.000 từ tiếng Việt chuẩn; với mỗi từ, áp luật biến âm để đoán ra dạng phương ngữ. Ví dụ 'làm' áp luật 'àm thành ồm' ra 'lồm', em lưu cặp 'lồm ứng với làm'. Làm vậy cho cả 74.000 từ. Nhưng chỉ giữ khi thỏa ba điều kiện an toàn, quan trọng nhất là dạng sinh ra không được trùng một từ chuẩn đang có — nếu không sẽ làm sai nghĩa văn bản bình thường. Kết quả là hơn 26.000 mục, trong đó phần lớn do luật tự sinh, chỉ vài chục mục là gõ tay cho từ vựng riêng."

## Slide 6 — Cách CHUẨN HÓA một câu (chạy từng bước)
**Trên slide:** tiêu đề "Khớp cụm DÀI trước, rồi ngắn". Bảng trace câu `Nhoà tui ngập tới mớ nhoà rồi`:
| Từ | Khớp | Ra |
|---|---|---|
| Nhoà | từ đơn | Nhà |
| tui | không có | tui (giữ) |
| ngập / tới | không có | giữ |
| **mớ nhoà** | **cụm 2 từ** | **mái nhà** |
| rồi | không có | rồi (giữ) |
Kết quả (đóng khung): "Nhà tui ngập tới mái nhà rồi". Ô cảnh báo: "Nếu xử lý từng từ: 'mớ nhoà' → 'mớ nhà' (SAI) → phải khớp cụm dài trước".

**Lời nói:**
"Có từ điển rồi, khi nạn nhân nhập câu, thuật toán duyệt từ trái sang phải, tại mỗi chỗ thử khớp cụm ba từ, rồi hai từ, rồi từ đơn. Ví dụ câu này: 'Nhoà' đổi thành 'Nhà'; 'tui' không có trong từ điển thì giữ nguyên; đến 'mớ nhoà' — chỗ này quan trọng — nếu xử lý từng từ thì 'mớ' giữ nguyên còn 'nhoà' thành 'nhà', ra 'mớ nhà' sai. Chỉ khi khớp cả cụm hai từ 'mớ nhoà' mới ra đúng 'mái nhà'. Vì thế phải thử cụm dài trước. Kết quả: 'Nhà tui ngập tới mái nhà rồi'."

## Slide 7 — Đặc điểm quan trọng
**Trên slide:** 4 gạch đầu dòng: "Chạy OFFLINE trên máy — hợp bối cảnh lũ mạng yếu"; "Giữ nguyên viết hoa (Lồm → Làm)"; "Từ lạ giữ nguyên — không làm hỏng văn bản"; "Lưu cả bản gốc + bản chuẩn hóa để đối chiếu".

**Lời nói:**
"Bốn đặc điểm em muốn lưu ý. Một, chuẩn hóa chạy hoàn toàn trên máy, không cần mạng — rất quan trọng vì vùng lũ mạng chập chờn. Hai, giữ nguyên viết hoa. Ba, từ nào không có trong từ điển thì giữ nguyên, nên bộ chuẩn hóa không bao giờ làm hỏng phần nó không chắc. Bốn, hệ thống lưu cả bản gốc lẫn bản đã chuẩn hóa để còn đối chiếu và cải thiện về sau."

## Slide 8 — Kết / Thông điệp
**Trên slide:** sơ đồ luồng gọn: "Giọng miền Trung → Nhận dạng → [CHUẨN HÓA offline] → Phân loại đúng mức". Câu chốt lớn: "Cơ chế SINH từ điển bằng luật — không phải bảng tra tay".

**Lời nói:**
"Tóm lại: em quan sát giọng miền Trung bị nhận dạng sai theo quy luật, nên mô hình hóa các quy luật đó thành luật biến âm, rồi áp lên 74.000 từ chuẩn để sinh tự động một từ điển hơn 26.000 mục, chạy offline ngay trên máy. Vai trò của nó là để bước phân loại phía sau hiểu đúng và không xếp nhầm mức khẩn cấp cho người nói phương ngữ. Đây là một cơ chế sinh, không phải một bảng tra thủ công. Em xin hết phần này ạ."

---

# PHẦN 2 — PROMPT DÁN CHO CLAUDE ADD-IN TRONG POWERPOINT

Sao chép nguyên khối dưới đây, dán vào Claude add-in trong PowerPoint:

---

Hãy tạo một bộ slide PowerPoint 16:9 bằng tiếng Việt, chủ đề "Chuẩn hóa phương ngữ miền Trung" cho buổi bảo vệ khóa luận. Gồm đúng 8 slide theo nội dung bên dưới.

YÊU CẦU PHONG CÁCH (áp cho cả bộ):
- Phong cách học thuật, sạch, tối giản. TUYỆT ĐỐI KHÔNG dùng emoji, không clip-art, không hình trang trí.
- Bảng màu: xanh dương đậm (#1F4E79) làm màu nhấn cho tiêu đề và tiêu điểm; chữ thân màu xám đậm (#333333); nền trắng; dùng xanh nhạt (#DDEBF7) hoặc xám nhạt (#F2F2F2) cho ô/bảng.
- Font: một font sans-serif dễ đọc (Calibri hoặc Arial). Tiêu đề slide 28–32pt in đậm; chữ thân 18–20pt.
- Mỗi slide có thanh tiêu đề trên cùng và số trang ở góc dưới phải.
- Ưu tiên bảng, mũi tên, sơ đồ khối đơn giản; hạn chế gạch đầu dòng dài; mỗi ý ngắn gọn.
- Nhất quán bố cục giữa các slide.

NỘI DUNG TỪNG SLIDE:

Slide 1 (trang bìa): Tiêu đề lớn "CHUẨN HÓA PHƯƠNG NGỮ MIỀN TRUNG". Phụ đề "Đưa lời cầu cứu giọng địa phương về tiếng Việt phổ thông". Dòng nhỏ: "Đề tài FloodAid — Nền tảng điều phối cứu trợ lũ lụt". Chừa chỗ ghi tên sinh viên và giảng viên hướng dẫn.

Slide 2 (Vấn đề): Tiêu đề "Vấn đề: nhận dạng giọng nói ghi sai theo âm". Một bảng 2 cột 3 dòng — cột trái "Người dân nói": nhà / làm / mái nhà; cột phải "Máy ghi ra chữ": nhoà / lồm / mớ nhoà. Bên dưới một hộp nổi bật màu đỏ nhạt chứa câu ví dụ: «Nhoà tui ngập tới mớ nhoà rồi» kèm dòng chú thích: "Hệ thống không hiểu 'mớ nhoà' = 'mái nhà' → xếp nhầm mức thấp".

Slide 3 (Ý tưởng): Tiêu đề "Ý tưởng: sai lệch CÓ QUY LUẬT". Một dòng khẩu hiệu lớn giữa slide: "Có quy luật → sửa ngược được". Bên dưới ví dụ minh họa: "Luật à → oà: nhà→nhoà, già→gioà, cà→coà". Một hộp nhỏ bên dưới: "Ẩn dụ: như một người luôn viết sai chính tả theo cùng một kiểu — ta lập bảng sửa ngược".

Slide 4 (Hai loại sai): Tiêu đề "Hai loại hiện tượng — hai cách xử lý". Hai cột song song. Cột A tiêu đề "Biến âm (có công thức)": liệt kê nhà→nhoà, làm→lồm, chặn→chẹn, vô→dô; chân cột ghi "→ Xử lý bằng LUẬT". Cột B tiêu đề "Từ vựng riêng (không công thức)": liệt kê răng=sao, rứa=thế, mô=đâu, mi=mày; chân cột ghi "→ Phải LIỆT KÊ tay".

Slide 5 (Tạo từ điển): Tiêu đề "Cách tạo từ điển: sinh tự động bằng luật". Một sơ đồ ngang gồm ba khối nối bằng mũi tên: "74.000 từ chuẩn (Viet74K)" → "Áp LUẬT biến âm" → "Dạng phương ngữ". Bên dưới một dòng ví dụ chạy: làm --(luật àm→ồm)--> lồm ⇒ lưu cặp "lồm → làm". Một hộp "3 điều kiện an toàn khi giữ mục: (1) khác từ gốc; (2) không bị chặn; (3) KHÔNG trùng từ chuẩn (quan trọng nhất)". Góc dưới phải một nhãn nổi bật: "Kết quả: hơn 26.000 mục — phần lớn tự sinh, chỉ vài chục mục gõ tay".

Slide 6 (Chuẩn hóa một câu): Tiêu đề "Cách chuẩn hóa: khớp cụm DÀI trước". Một bảng 3 cột (Từ | Khớp ở mức | Kết quả) với các dòng: Nhoà | từ đơn | Nhà; tui | không có | tui (giữ); ngập, tới | không có | giữ nguyên; "mớ nhoà" | cụm 2 từ | "mái nhà" (tô đậm dòng này); rồi | không có | rồi (giữ). Bên dưới bảng, một hộp kết quả đóng khung: «Nhà tui ngập tới mái nhà rồi». Bên cạnh, một hộp cảnh báo màu vàng nhạt: "Nếu xử lý từng từ: 'mớ nhoà' → 'mớ nhà' (SAI) → vì vậy phải khớp cụm dài trước".

Slide 7 (Đặc điểm): Tiêu đề "Đặc điểm quan trọng". Bốn ô/thẻ ngang hàng, mỗi ô một ý ngắn: "Chạy OFFLINE trên máy — hợp bối cảnh lũ mạng yếu"; "Giữ nguyên viết hoa (Lồm → Làm)"; "Từ lạ giữ nguyên — không làm hỏng văn bản"; "Lưu cả bản gốc + bản đã chuẩn hóa để đối chiếu".

Slide 8 (Kết luận): Tiêu đề "Kết luận". Một sơ đồ luồng ngang 4 khối: "Giọng miền Trung" → "Nhận dạng giọng nói" → "CHUẨN HÓA (offline)" (tô nhấn khối này) → "Phân loại đúng mức khẩn cấp". Bên dưới một câu chốt cỡ lớn, in đậm, màu nhấn: "Cơ chế SINH từ điển bằng luật — không phải bảng tra thủ công".

Sau khi tạo xong, giữ định dạng nhất quán và kiểm tra không có emoji nào trong toàn bộ slide.

---

## GHI CHÚ KHI DÙNG
- Nếu add-in không dựng được bảng/sơ đồ đúng ý, bảo nó "chỉnh slide X: làm lại bảng theo đúng các dòng em ghi".
- Slide 5 và Slide 6 là hai slide quan trọng nhất (cách TẠO và cách DÙNG) — nói kỹ, các slide khác lướt nhanh.
- Tổng thời lượng ~4–5 phút; nếu bị giục, có thể gộp Slide 3 vào Slide 4 và Slide 7 nói lướt.
