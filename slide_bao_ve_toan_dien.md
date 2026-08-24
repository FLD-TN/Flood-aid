# SLIDE BẢO VỆ FloodAid — 15 SLIDE (~20 phút)

> Tập trung ĐIỂM MỚI và LUỒNG LÕI (chuẩn hóa · phân loại · điều phối). Sản phẩm = demo trực tiếp.
> PHẦN 1: kịch bản + thời gian. PHẦN 2: prompt dán cho Claude add-in PowerPoint.

| Phần | Slide | Phút |
|---|---|---|
| 1. Bìa & Mục lục | 1–2 | ~1 |
| 2. Đặt vấn đề & Lý do chọn đề tài | 3–4 | ~3 |
| 3. Cơ sở lý thuyết & Phương pháp | 5–7 | ~4 |
| 4. Demo & Kết quả thực nghiệm | 8–13 | ~10 |
| 5. Hạn chế & Kết luận | 14–15 | ~2 |

**Sơ đồ / bảng:** Slide 6 (kiến trúc — ảnh diagrams/kien_truc_tong_the.png) · Slide 7 (pipeline 3 cơ chế) · Slide 9 (bảng ví dụ chuẩn hóa) · Slide 10/11 (mini-pipeline phân loại/điều phối).
**Demo trực tiếp:** Slide 12.

---

PHẦN 1 — KỊCH BẢN THUYẾT TRÌNH (nội dung từng slide)


Slide 1 — Bìa  (0:30)
Nội dung slide: FloodAid — Nền tảng hỗ trợ điều phối cứu trợ lũ lụt miền Trung dựa trên AI NLP. SVTH: Trần Anh Duy. GVHD: ThS. Lê Thị Minh Nguyện.
Ý nói: Chào hội đồng, giới thiệu đề tài.


Slide 2 — Mục lục  (0:20)
Nội dung slide:
- Đặt vấn đề và lý do chọn đề tài
- Cơ sở lý thuyết và phương pháp
- Demo và kết quả thực nghiệm
- Hạn chế và hướng phát triển
- Kết luận
Ý nói: “Bài gồm 5 phần…”.


Slide 3 — Đặt vấn đề (Thực trạng)  (1:30)
Nội dung slide:
- Lũ lụt miền Trung khốc liệt, lặp lại hằng năm
- Điều phối cứu trợ còn thủ công
- Thông tin cầu cứu phân tán, không tập trung
Ý nói: Nêu bối cảnh; tự nói số liệu lũ 2020/2025; nhấn hai điểm — thiên tai khốc liệt và điều phối thủ công còn hạn chế.


Slide 4 — Lý do chọn đề tài và Mục tiêu  (1:30)
Nội dung slide:
- Nhu cầu thực tiễn: chưa có nền tảng riêng
- Cấp thiết: mỗi phút là tính mạng
- Cơ hội công nghệ: NLP/LLM + GIS
- Mục tiêu: nền tảng phân loại và điều phối cứu trợ
Ý nói: Diễn giải 3 lý do (thực tiễn – thời gian – công nghệ), chốt bằng mục tiêu tổng quát.


Slide 5 — Cơ sở lý thuyết và Phương pháp  (1:30)
Nội dung slide:
- Cơ sở lý thuyết: luật biến âm · khớp cụm dài · dò từ khóa + phủ định · LLM · PostGIS
- Phương pháp: xây và đánh giá hệ thống · dữ liệu Viet74K + bộ kiểm thử
- Điểm mới: từ điển sinh bằng luật · phân loại lai có sàn an toàn · điều phối tự phục hồi
Ý nói: Chỉ nêu thứ trực tiếp dùng; nói rõ Viet74K là gì khi trình bày; nhấn 3 điểm mới.


Slide 6 — Kiến trúc tổng thể  (1:30)
Nội dung slide: ảnh sơ đồ kiến trúc (diagrams/kien_truc_tong_the.png).
Ý nói: Đi qua 3 lớp Client – Máy chủ – CSDL + dịch vụ ngoài; nhấn thời gian thực (WebSocket/SSE).


Slide 7 — Pipeline ba cơ chế lõi  (1:00)
Nội dung slide:
- Chuẩn hóa: phương ngữ → từ điển → chuẩn
- Phân loại: chuẩn → (từ khóa | Gemini) → MAX → mức + nhãn
- Điều phối: SOS → phát sóng → tiếp cận → hoàn thành
Ý nói: Toàn cảnh 3 cơ chế; các slide sau đi vào từng cái.


Slide 8 — Cơ chế 1: Chuẩn hóa phương ngữ (Ý tưởng)  (2:00)
Nội dung slide:
- Vấn đề: STT ghi sai theo âm (nhà → nhoà)
- Giải pháp: luật biến âm sinh từ điển, chạy offline
- Ví dụ: “Nhoà tui ngập tới mớ nhoà rồi” → “Nhà tui ngập tới mái nhà rồi”
Ý nói: Nhấn “cơ chế sinh, không phải bảng tra”; nói rõ Viet74K ~74k → ~26k mục khi trình bày; đây là điểm đặc biệt nhất; dùng đúng câu này để demo ở Slide 12.


Slide 9 — Chuẩn hóa phương ngữ: Ví dụ & Cách hoạt động  (1:30)
Nội dung slide:
- Bảng ví dụ (phương ngữ → chuẩn):
    · Biến âm (luật sinh): nhoà → nhà · lồm → làm · chẹn → chặn · dô → vô
    · Từ vựng riêng (liệt kê tay): răng → sao · rứa → thế · mô → đâu · mi → mày
    · Cụm nhiều từ: mớ nhoà → mái nhà · con gớ → con gái
- Cách chuẩn hóa (3 bước): tách câu thành từ → khớp cụm DÀI trước (3→2→1 từ) → giữ nguyên viết hoa, từ lạ giữ nguyên
Ý nói: Chỉ vào bảng, phân biệt 2 loại (biến âm sinh bằng luật vs từ vựng riêng phải liệt kê); giải thích vì sao khớp cụm dài trước — “mớ nhoà” khớp nguyên cụm mới ra “mái nhà”, tách từng từ sẽ ra “mớ nhà” (sai).


Slide 10 — Cơ chế 2: Phân loại mức khẩn cấp  (2:00)
Nội dung slide:
- Hai nhánh: từ khóa (offline) + Gemini (ngữ cảnh)
- Hợp nhất: lấy mức cao hơn = sàn an toàn
- Ví dụ: “đuối nước” → luôn mức 5
Ý nói: Nói rõ nhánh từ khóa (biên từ + phủ định) và vì sao lấy mức cao hơn; “thà cao hơn còn hơn bỏ sót”.


Slide 11 — Cơ chế 3: Điều phối cứu trợ  (1:30)
Nội dung slide:
- Phát sóng tới TNV rảnh (đã xác thực)
- Phát hiện ca mồ côi
- Theo sát tiếp cận + tự điều phối lại
Ý nói: Nói mốc 300m/100m và cơ chế thu hồi khi không tiến gần 10 phút; “nhận ca chưa đủ — phải thực sự tiếp cận”.


Slide 12 — Demo trực tiếp  (2:00)
Nội dung slide:
- DEMO TRỰC TIẾP
- Gửi một câu SOS phương ngữ → chuẩn hóa → phân loại → điều phối
Ý nói: Mở app, gửi câu “Nhoà tui ngập tới mớ nhoà rồi”, cho hội đồng xem hệ chạy thật end-to-end.


Slide 13 — Kết quả thực nghiệm và Bàn luận  (1:30)
Nội dung slide:
- Chuẩn hóa: 37/40 · Phân loại: nhãn 100%, mức ~92%
- Đo trên mã và từ điển thật
- Bàn luận: chuẩn hóa là điều kiện cho phân loại offline đúng; sàn an toàn → bền mạng yếu
Ý nói: Sau demo, cho xem số liệu; nhấn cách đo trung thực; liên hệ ngược về khoảng trống ở Phần 2.


Slide 14 — Hạn chế và Hướng phát triển  (1:00)
Nội dung slide:
- Hạn chế: phụ thuộc mạng/điện · nhánh LLM cần dịch vụ ngoài · luật biến âm chưa phủ hết vùng · mới là nguyên mẫu, chưa thử người dùng thật
- Hướng phát triển: định lượng chất lượng từ điển · dự phòng SMS/USSD · đa phương thức (ảnh/video hiện trường) · iOS và web
Ý nói: Nói thêm — chưa kiểm chứng LLM tự hiểu phương ngữ (nên giá trị bộ chuẩn hóa mới giới hạn ở nhánh từ khóa); hướng phân tích dữ liệu sau thiên tai (bản đồ nhiệt). Thành thật, hội đồng đánh giá cao.


Slide 15 — Kết luận và Cảm ơn  (1:00)
Nội dung slide:
- Hoàn thành nền tảng FloodAid (app + máy chủ + web), đạt các mục tiêu đề ra
- Ba cơ chế lõi giải đúng đặc thù bài toán
- Triết lý: chịu mạng yếu + không bỏ sót
Ý nói: Chốt câu “Số hóa và tự động hóa chuỗi tiếp nhận – phân loại – điều phối cứu trợ”; cảm ơn Hội đồng, sẵn sàng trả lời.

---

# PHẦN 2 — PROMPT DÁN CHO CLAUDE ADD-IN TRONG POWERPOINT

Sao chép nguyên khối dưới đây, dán vào Claude add-in trong PowerPoint:

---

Hãy tạo một bộ slide PowerPoint 16:9 bằng tiếng Việt để bảo vệ khóa luận (20 phút), gồm ĐÚNG 15 slide theo nội dung bên dưới, tổ chức theo 5 phần: Bìa & Mục lục; Đặt vấn đề & Lý do chọn đề tài; Cơ sở lý thuyết & Phương pháp; Demo & Kết quả thực nghiệm; Hạn chế & Kết luận.

PHONG CÁCH (áp cho cả bộ):
- Học thuật, sạch, tối giản. TUYỆT ĐỐI KHÔNG dùng emoji, không clip-art.
- Màu nhấn xanh dương đậm (#1F4E79) cho tiêu đề và điểm nhấn; chữ thân xám đậm (#333333); nền trắng; ô/thẻ dùng xám nhạt (#F2F2F2) hoặc xanh nhạt (#DDEBF7).
- Font sans-serif (Calibri/Arial). Tiêu đề 28–32pt đậm; chữ thân 18–20pt.
- Mỗi slide có thanh tiêu đề và số trang góc dưới phải.
- CHỮ ÍT, ưu tiên bảng/sơ đồ khối/mũi tên; mỗi ý một dòng ngắn.

NỘI DUNG:

Slide 1 (Bìa): Tiêu đề "FloodAid — NỀN TẢNG HỖ TRỢ ĐIỀU PHỐI CỨU TRỢ LŨ LỤT TẠI MIỀN TRUNG DỰA TRÊN AI NLP". Dòng nhỏ "Khóa luận tốt nghiệp — Khoa Công nghệ Thông tin". Chừa chỗ: SVTH Trần Anh Duy (MSSV 23DH110527, PM2301); GVHD ThS. Lê Thị Minh Nguyện.

Slide 2 (Mục lục): Tiêu đề "Nội dung trình bày". Danh sách đánh số 5 mục: 1) Đặt vấn đề & lý do chọn đề tài; 2) Cơ sở lý thuyết & phương pháp; 3) Demo & kết quả thực nghiệm; 4) Hạn chế & hướng phát triển; 5) Kết luận.

Slide 3 (Đặt vấn đề — Thực trạng): Tiêu đề "Đặt vấn đề — Thực trạng". Ba gạch đầu dòng: (1) miền Trung nằm dọc bờ biển, hằng năm hứng mùa mưa bão kéo dài gây lũ lụt, lũ quét, sạt lở diện rộng, hàng trăm nghìn hộ bị cô lập cần cứu trợ khẩn cấp; (2) mức độ tàn khốc — lũ lịch sử cuối 2020 làm 249 người chết và mất tích, thiệt hại hơn 36.000 tỷ đồng, xu hướng lặp lại (lũ 2025 khoảng 219 người chết và mất tích); (3) điều phối cứu trợ vẫn thủ công — tin cầu cứu phát qua điện thoại/tin nhắn/mạng xã hội, phân tán, không tập trung, khó xác định ai cần giúp, ở đâu, mức nào, cần gì. Dòng nhấn dưới cùng (màu nhấn): "Thiên tai khốc liệt + điều phối thủ công còn nhiều hạn chế".

Slide 4 (Lý do chọn đề tài & Mục tiêu): Tiêu đề "Lý do chọn đề tài & Mục tiêu". Danh sách 4 dòng, mỗi dòng có một biểu tượng đường nét đơn giản màu nhấn ở đầu (không emoji) + nhãn in đậm + mô tả ngắn: "Nhu cầu thực tiễn:" Việt Nam chưa có ứng dụng riêng cho điều phối cứu trợ lũ miền Trung; hoạt động tự phát, thông tin phân tán, trùng lặp, thiếu cơ chế ưu tiên. "Cấp thiết về thời gian:" mỗi phút nạn nhân chưa được tiếp cận là đe dọa tính mạng, cần tự động hóa tiếp nhận – đánh giá – phân bổ lực lượng. "Cơ hội công nghệ:" NLP và mô hình ngôn ngữ lớn (LLM), cùng PostGIS và VietMap cho phép xây nền tảng thông minh chi phí hợp lý. "Mục tiêu tổng quát:" nền tảng điều phối cứu trợ lũ miền Trung, dùng NLP tự động phân loại mức khẩn cấp và GIS điều phối tình nguyện viên, phù hợp hạ tầng trong thiên tai. Dòng nhấn dưới cùng: "Ba lý do: thực tiễn – thời gian – công nghệ".

Slide 5 (Cơ sở lý thuyết & Phương pháp): Tiêu đề "Cơ sở lý thuyết & Phương pháp". Hai thẻ cạnh nhau, nền xám nhạt, viền bo góc, tiêu đề thẻ màu nhấn. Thẻ 1 "Cơ sở lý thuyết": luật biến âm mô hình hóa ngữ âm phương ngữ; khớp cụm dài nhất; dò từ khóa và xử lý phủ định; mô hình ngôn ngữ lớn Gemini; PostGIS truy vấn không gian. Thẻ 2 "Phương pháp": xây dựng hệ thống thực nghiệm; đánh giá định lượng (chạy trên mã thật) kết hợp định tính; công cụ Flutter, Node.js/Express, PostgreSQL+PostGIS, Gemini, VietMap, FPT.AI, Firebase; dữ liệu Viet74K và bộ kiểm thử tự xây. Dưới hai thẻ một dải màu nhấn: "Điểm mới: sinh từ điển phương ngữ bằng luật · phân loại lai có sàn an toàn · điều phối tự phục hồi".

Slide 6 (Kiến trúc tổng thể): Tiêu đề "Kiến trúc tổng thể". Chừa một khung lớn giữa slide ghi "Chèn ảnh: diagrams/kien_truc_tong_the.png" (sinh viên sẽ dán ảnh sơ đồ kiến trúc đã có). Nếu cần vẽ thay thế: sơ đồ khối 3 lớp Client (App Nạn nhân, App TNV, Web quản trị) — Máy chủ (Node.js/Express) — CSDL (PostgreSQL+PostGIS), và cột dịch vụ ngoài (Gemini, VietMap, FPT.AI, Firebase), nhãn "REST + WebSocket/SSE".

Slide 7 (Pipeline ba cơ chế): Tiêu đề "Ba cơ chế lõi — Pipeline". Vẽ BA pipeline nhỏ xếp dọc: Pipeline 1 "Chuẩn hóa": "Câu phương ngữ" → "Tra từ điển 26.000 mục" → "Câu chuẩn". Pipeline 2 "Phân loại": "Câu chuẩn" → hai nhánh "Từ khóa" và "Gemini" chụm vào "MAX (sàn an toàn)" → "Mức + Nhãn". Pipeline 3 "Điều phối": "Ca SOS" → "Phát sóng TNV" → "Theo sát tiếp cận" → "Hoàn thành".

Slide 8 (Cơ chế 1 — Chuẩn hóa, Ý tưởng): Tiêu đề "Cơ chế 1 — Chuẩn hóa phương ngữ". Bên trái vấn đề (nhận dạng giọng nói ghi sai theo âm: nhà→nhoà, mái nhà→mớ nhoà); bên phải giải pháp (luật biến âm áp lên 74.000 từ chuẩn, sinh tự động hơn 26.000 mục, chạy offline, khớp cụm dài trước). Bên dưới một hộp ví dụ câu đầy đủ trước → sau: dòng trên «Nhoà tui ngập tới mớ nhoà rồi», dòng dưới «Nhà tui ngập tới mái nhà rồi» (tô đậm "mái nhà"). Nhãn nhấn: "Cơ chế SINH từ điển, không phải bảng tra tay".

Slide 9 (Chuẩn hóa — Ví dụ & Cách hoạt động): Tiêu đề "Chuẩn hóa phương ngữ — Ví dụ & Cách hoạt động". Bên trái một BẢNG 2 cột (Phương ngữ | Chuẩn) chia 3 nhóm có nhãn: nhóm "Biến âm (luật sinh)": nhoà→nhà, lồm→làm, chẹn→chặn, dô→vô; nhóm "Từ vựng riêng (liệt kê tay)": răng→sao, rứa→thế, mô→đâu, mi→mày; nhóm "Cụm nhiều từ": mớ nhoà→mái nhà, con gớ→con gái. Bên phải một hộp "Cách chuẩn hóa (3 bước)": (1) tách câu thành từng từ; (2) khớp cụm DÀI trước rồi mới ngắn (3 từ → 2 từ → 1 từ); (3) giữ nguyên viết hoa, từ nào không có trong từ điển thì giữ nguyên. Ghi chú nhấn: "Khớp cụm dài trước để 'mớ nhoà' ra 'mái nhà', không thành 'mớ nhà'".

Slide 10 (Cơ chế 2 — Phân loại): Tiêu đề "Cơ chế 2 — Phân loại mức độ khẩn cấp". Hai khối "Nhánh dò từ khóa (cục bộ, luôn có kết quả; khớp biên từ + phủ định)" và "Nhánh Gemini (hiểu ngữ cảnh)" chụm vào khối "Hợp nhất: LẤY MỨC CAO HƠN (sàn an toàn)" → "Mức + Nhãn". Hộp ví dụ nhấn: "'đuối nước' → dù mô hình nhầm mức 2, kết quả vẫn mức 5". Nhãn: "Thà cao hơn còn hơn bỏ sót ca nguy kịch".

Slide 11 (Cơ chế 3 — Điều phối): Tiêu đề "Cơ chế 3 — Điều phối cứu trợ". Mini-pipeline: "Ca SOS" → "Phát sóng TNV (đã xác thực)" → "Theo sát tiếp cận (300m/100m)" → "Hoàn thành / tự điều phối lại". Hai ghi chú ngắn: phát hiện ca mồ côi bằng quét CSDL (bền qua khởi động lại); tự phục hồi phân công khi TNV không tiến gần sau 10 phút. Nhãn: "Nhận ca chưa đủ — phải bảo đảm thực sự tiếp cận".

Slide 12 (Demo trực tiếp): Tiêu đề "Demo trực tiếp". Giữa slide đặt một nhãn/huy hiệu lớn màu nhấn ghi "DEMO TRỰC TIẾP" (không chèn ảnh app). Bên dưới một dòng: "Gửi một câu SOS phương ngữ → chuẩn hóa → phân loại → điều phối (chạy thật, end-to-end)".

Slide 13 (Kết quả thực nghiệm & Bàn luận): Tiêu đề "Kết quả thực nghiệm & Bàn luận". Ba khối số liệu: "Chuẩn hóa: đúng 37/40"; "Phân loại (nhánh luật): nhãn 100%, mức khoảng 92%"; "Đo trên mã và từ điển thật (không nhập tay kết quả)". Bên dưới một dải "Bàn luận": chuẩn hóa là điều kiện để phân loại offline không đánh giá sai với người nói phương ngữ; sàn an toàn cùng dự phòng nhiều lớp giúp hệ bền mạng yếu và nghiêng về an toàn.

Slide 14 (Hạn chế & Hướng phát triển): Tiêu đề "Hạn chế và hướng phát triển". Hai cột. Cột Hạn chế: phụ thuộc hạ tầng mạng và nguồn điện (lũ mất điện kéo theo mất sóng, cạn pin); nhánh mô hình ngôn ngữ phụ thuộc dịch vụ bên ngoài; tập luật biến âm soạn thủ công, chưa phủ hết khác biệt giữa các địa phương miền Trung; hệ thống mới ở mức nguyên mẫu trên Android, chưa thử với người dùng thật. Cột Hướng phát triển: định lượng chất lượng từ điển; bổ sung kênh dự phòng SMS/USSD; xử lý đa phương thức (ảnh, video hiện trường và thị giác máy tính đánh giá mức ngập); phát triển iOS và web; phân tích dữ liệu sau thiên tai (bản đồ nhiệt vùng thường cần cứu trợ).

Slide 15 (Kết luận & Cảm ơn): Tiêu đề "Kết luận". Ba đúc kết: hoàn thành nền tảng FloodAid gồm ba thành phần vận hành được (ứng dụng di động, máy chủ nghiệp vụ, web quản trị) và đạt các mục tiêu đề ra; ba cơ chế lõi giải quyết đúng đặc thù bài toán; triết lý chịu mạng yếu và nghiêng về không bỏ sót. Câu chốt cỡ lớn in đậm màu nhấn: "Số hóa và tự động hóa chuỗi tiếp nhận – phân loại – điều phối cứu trợ". Dưới cùng: "Trân trọng cảm ơn Hội đồng".

Sau khi tạo xong, kiểm tra: đúng 15 slide, không emoji, mỗi slide chữ gọn, phong cách nhất quán.

---

## GHI CHÚ
- Cơ chế 1 (Chuẩn hóa) được tách 2 slide: Slide 8 ý tưởng + ví dụ câu, Slide 9 bảng ví dụ + cách hoạt động — vì đây là điểm nhấn nhất.
- Trọng tâm: Slide 8–13 (chuẩn hóa → phân loại → điều phối → demo → kết quả). Demo trực tiếp là Slide 12.
- Câu hỏi sâu về từng cơ chế → mở file giải thích/Q&A đã có (chuẩn hóa, phân loại).
