# BÀI GIẢNG PHẢN BIỆN — CƠ CHẾ CHUẨN HÓA PHƯƠNG NGỮ (Chương 4.1)

> Tài liệu ôn cho buổi gặp giảng viên phản biện. Bám sát đúng nội dung Chương 4 đã nộp.
> Cấu trúc: (A) Kể mạch lạc 4.1 → (B) Giải thích sâu "tại sao" → (C) Số liệu chốt →
> (D) Bộ câu hỏi phản biện + trả lời → (E) Kịch bản demo → (F) Câu chốt hạ.

---

## A. KỂ MẠCH LẠC 4.1 (đường dây để trình bày trong ~2 phút)

Nói theo đúng thứ tự nhân–quả, mỗi ý một câu:

1. **Vấn đề gốc:** mô hình nhận dạng giọng nói huấn luyện trên giọng chuẩn, gặp giọng miền Trung thì **không hiểu người nói mà phiên âm theo âm nghe được** — "nhà" thành "nhoà", "làm" thành "lồm".
2. **Cơ hội:** sai lệch này **có quy luật**, nên **mô hình hóa được thành luật biến âm** rồi ánh xạ ngược về chuẩn.
3. **Nhưng phương ngữ có hai nhóm hiện tượng:** (a) nhóm **biến âm** — mô hình hóa được bằng luật (Bảng 4.1); (b) **lớp từ vựng riêng** — không suy ra được bằng luật (răng=sao, rứa=thế), phải **liệt kê** (Bảng 4.2).
4. **Vì thế cần hai nguồn tri thức:** luật (sinh tự động) + từ điển cứng (liệt kê tay).
5. **Cách sinh từ điển (4.1.1):** áp các luật lên **corpus Viet74K (~74.000 từ chuẩn)** để **sinh ngược** dạng phương ngữ; gộp với từ điển cứng → tệp `dialect_dict.json` **hơn 26.000 mục**, **đóng gói sẵn trong app, chạy offline**.
6. **Cách dùng khi chạy (4.1.2):** thuật toán duyệt câu trái→phải, **thử khớp cụm 3 từ, rồi 2 từ, rồi từ đơn**, khớp mức nào thay mức đó; **giữ nguyên viết hoa**, **từ lạ giữ nguyên** (không làm hỏng văn bản).
7. **Ý nghĩa (nối 4.2.5):** chuẩn hóa là **điều kiện để nhánh dò từ khóa chạy đúng** — lớp duy nhất còn hoạt động khi mất mạng.

Một câu tóm tất cả: *"Chúng tôi không tra bảng tay, mà mô hình hóa quy luật biến âm của giọng miền Trung thành luật, rồi sinh tự động một từ điển ánh xạ hơn 26.000 mục chạy hoàn toàn offline trên máy."*

---

## B. GIẢI THÍCH SÂU "TẠI SAO" (để trả lời khi bị hỏi vặn)

### B1. Vì sao chia hai nguồn (luật vs liệt kê)?
Hai nhóm hiện tượng **khác bản chất**:
- **Biến âm** là biến đổi ngữ âm có hệ thống (à→oà, ăn→en). Một luật phủ **hàng nghìn** từ → dùng luật.
- **Từ vựng riêng** là **khác từ hẳn**, không có công thức âm nào biến "răng" thành "sao" → phải liệt kê.
Trộn hai thứ vào một cơ chế là sai về phương pháp; tách ra mới đúng bản chất và bảo trì được.

### B2. Luật biến âm — bản chất là gì?
Không phải "thay chữ vu vơ" mà là **mô hình hóa hệ thống biến âm vùng phương ngữ**: mỗi luật là một quy tắc ngữ âm (vần "am"→"ôm", nguyên âm "a"→"oa", vần "ăn"→"en", phụ âm đầu "v"→"d"). Đây chính là phần "khoa học": chuyển tri thức ngôn ngữ học thành quy tắc máy tính chạy được.

### B3. Ba điều kiện lọc khi sinh — điều kiện nào quan trọng nhất?
Một mục chỉ giữ khi: (1) dạng sinh **khác** từ gốc, (2) **không** trong blacklist, (3) **không** trùng từ chuẩn có sẵn (`!standardVocab.has`).
**Điều kiện (3) là quan trọng nhất.** Nếu một dạng biến âm trùng một từ chuẩn mang nghĩa khác — ví dụ luật sinh ra "hoà" (đã là từ chuẩn: hoà bình) — thì **mọi câu phổ thông chứa "hoà" sẽ bị thay sai nghĩa**. Điều kiện (3) chặn đúng những va chạm đó. `blacklist` là lớp chặn thủ công bổ sung cho các trường hợp cá biệt.

### B4. Vì sao khớp cụm dài trước từ đơn? (câu hỏi hay bị hỏi)
Xét "**mớ nhoà**" (= mái nhà):
- Nếu xử lý **từ đơn trước**: "mớ" không có trong dict → giữ nguyên; "nhoà" → "nhà"; ra **"mớ nhà"** (SAI).
- Chỉ khi khớp ở **mức cụm 2 từ**, thuật toán nhận "mớ nhoà" là **một mục nguyên khối** → ra **"mái nhà"** (ĐÚNG).
Vì các cụm mang nghĩa riêng ("mớ nhoà", "chu cha") chỉ đúng khi được nhận trọn khối, nên phải thử **dài trước, ngắn sau** (greedy longest-match).

### B5. Vì sao giữ nguyên từ lạ + giữ viết hoa?
- **Từ lạ giữ nguyên:** bảo đảm bộ chuẩn hóa **không bao giờ làm hỏng** văn bản — chỉ đổi cái nó chắc chắn biết.
- **Giữ viết hoa (`_preserveCase`):** "Lồm" → "Làm", không phá tên riêng/đầu câu.

### B6. Vì sao đóng gói offline?
Tệp dict nạp sẵn trong app → chuẩn hóa chạy **không cần mạng**. Đây là quyết định **đúng bối cảnh thiên tai**: vùng lũ mạng chập chờn, băng thông thấp; một cơ chế phụ thuộc mạng ở bước nhập SOS là rủi ro. Đây cũng là **lý do tồn tại của nhánh dò từ khóa** (mục 4.2): lớp chạy được offline cần đầu vào đã chuẩn hóa offline.

---

## C. SỐ LIỆU CHỐT (nói con số cho chắc, không ước lượng mơ hồ)

| Chỉ số | Giá trị | Ý nghĩa khi nói |
|---|---|---|
| Corpus nguồn | **~74.000** từ Viet74K | nền để sinh ngược |
| Tổng mục từ điển | **hơn 26.000** | phần lớn **do luật tự sinh**, không nhồi tay |
| Mục liệt kê tay | **vài chục** (lớp từ vựng riêng) | phần nhỏ, đúng như Bảng 4.2 là "trích" |
| Số nhóm luật biến âm | **4 nhóm** (Bảng 4.1) | mô hình hóa hệ thống biến âm |
| Phụ thuộc mạng khi chuẩn hóa | **Không** | chạy cục bộ trên máy |

Điểm nhấn để nói: *"Chỉ vài chục mục là liệt kê tay; hơn 26.000 mục còn lại là **hệ quả tự động** của bộ luật áp lên 74.000 từ chuẩn — nên đây là cơ chế sinh, không phải bảng tra."*

---

## D. BỘ CÂU HỎI PHẢN BIỆN + CÁCH TRẢ LỜI (phần quan trọng nhất)

### Q1. "Chuẩn hóa bằng từ điển thì có gì là nghiên cứu? Chỉ là tra bảng thôi mà?"
**Trả lời:** Đây **không phải bảng tra thủ công**. Ba điểm:
1. Nó là **bộ sinh từ điển bằng luật**: mô hình hóa hệ thống biến âm của giọng miền Trung thành 4 nhóm luật ngữ âm, áp lên 74.000 từ chuẩn → sinh tự động hơn 26.000 ánh xạ. Chỉ vài chục mục là liệt kê tay.
2. Nó có **cơ chế an toàn khi sinh**: điều kiện chống trùng từ chuẩn (`!standardVocab.has`) + blacklist, để không làm sai nghĩa văn bản phổ thông.
3. Nó có **thuật toán khớp có thứ tự** (cụm dài trước, giữ hoa, giữ từ lạ).
Đóng góp là **mô hình hóa và tự động hóa** tri thức ngôn ngữ vùng, không phải nhập tay.

### Q2. "Sao không dùng luôn mô hình ngôn ngữ lớn để hiểu phương ngữ, cần gì từ điển?"
**Trả lời:** Vì hai lớp **bù nhau ở đúng điểm yếu của nhau** (báo cáo trình bày ở 4.2):
- Nhánh dò từ khóa **khớp theo mặt chữ** → **chắc chắn thất bại** với phương ngữ nếu không chuẩn hóa. Đây là lớp **duy nhất còn chạy khi mất mạng**.
- Từ điển: **tất định, offline, không tốn phí mỗi lần gọi, minh bạch/kiểm toán được**.
- Mô hình ngôn ngữ lớn: hiểu ngữ cảnh tốt nhưng **chậm và phụ thuộc mạng**.
Vùng lũ mạng yếu → **bắt buộc phải có lớp offline**, và lớp đó cần đầu vào đã chuẩn hóa. Từ điển là **xương sống tin cậy**; mô hình lớn là **lớp hiểu ngữ cảnh bù thêm**. Đây là thiết kế phòng thủ nhiều lớp, không phải chọn một–bỏ một.

### Q3. "STT có thật sự ghi ra 'nhoà', 'lồm' không? Bạn đã kiểm chứng chưa?" (câu dễ bị xoáy nhất)
**Trả lời thành thật, có lớp lang:**
- Cơ chế nền (4.1 mở đầu): STT **phiên âm theo âm nghe**. Với các từ phương ngữ **vốn là từ tiếng Việt hợp lệ** (rứa, mô, răng, mi), STT có xu hướng **ghi verbatim** → chuẩn hóa bắt được.
- Báo cáo **đã tự nêu giới hạn** (4.2.5): đây là **khảo sát định tính**, chỉ đo tác động lên **nhánh dò từ khóa**; việc nhánh mô hình lớn tự hiểu phương ngữ **chưa kiểm chứng**.
- Nếu bị ép sâu: thừa nhận **độ phủ của STT thay đổi theo từng từ** — từ ngắn/hiếm có thể bị nghe lệch; đây là **hạn chế đã ghi nhận (mục 5.2)**, không phóng đại.
- **Lá bài mạnh (nếu bị dồn):** *"Sau khi nộp báo cáo, em có thử nghiệm thêm hướng dùng một mô hình nhận dạng **điều khiển được** (đưa trước danh sách từ phương ngữ để định hướng nhận dạng), và thấy nó bắt được các từ như 'hén', 'nhoà', 'nác' tốt hơn hẳn nhận dạng mặc định. Đây là hướng phát triển em đang làm."* → cho thấy đã đi xa hơn báo cáo. Nói rõ đây là **bổ sung sau nộp**, không giả vờ có trong báo cáo.

### Q4. "Xử lý từ đồng âm thế nào? Một dạng biến âm trùng từ chuẩn thì sao?"
**Trả lời:** Chính là điều kiện lọc thứ ba khi sinh (`!standardVocab.has`) + blacklist: **không sinh ra** dạng biến âm nào trùng một từ chuẩn mang nghĩa khác (ví dụ chặn "hoà"). Với vài từ vựng thêm tay có va chạm nghĩa, nguyên tắc là **chỉ thêm khi nghĩa phương ngữ áp đảo trong ngữ cảnh cứu hộ lũ**; còn lại để nguyên hoặc để lớp mô hình lớn hiểu theo ngữ cảnh. Đây là **đánh đổi có chủ đích**, không phải bỏ sót.

### Q5. "Độ chính xác bao nhiêu? Đánh giá bằng cách nào?"
**Trả lời:** Trong báo cáo (4.2.5) là **khảo sát định tính 6 câu**, đo **tác động lên nhánh dò từ khóa** — và em **nêu rõ giới hạn** ngay trong báo cáo. Kết luận khẳng định được tuy hẹp nhưng **đáng tin về mặt logic**: nhánh dò từ khóa khớp theo mặt chữ nên **chắc chắn** sai với phương ngữ nếu không chuẩn hóa; chuẩn hóa loại bỏ đúng lỗi đó. *(Nếu có làm thêm bộ kiểm thử định lượng, nói: "em có một bộ kiểm thử chạy trên mã thật, có thể trình bày bổ sung.")*

### Q6. "Vì sao khớp cụm dài trước? Ví dụ?"
→ Dùng thẳng ví dụ "mớ nhoà" ở mục B4: nếu từ đơn trước sẽ ra "mớ nhà" (sai); khớp cụm 2 từ mới ra "mái nhà". (Đây là ví dụ đã có trong báo cáo 4.1.2.)

### Q7. "Gặp từ phương ngữ KHÔNG có trong từ điển thì sao?"
**Trả lời:** **Giữ nguyên từ đó** — bộ chuẩn hóa không bao giờ làm hỏng văn bản. Phần còn thiếu (đuôi dài từ hiếm) được đỡ bởi **nhánh mô hình lớn hiểu ngữ cảnh** và bởi **ô mô tả người dùng sửa được** trước khi gửi. Độ phủ là bài toán mở rộng dần, không phải điều kiện sống–chết.

### Q8. "26.000 mục — có phải nhồi cho nhiều không?"
**Trả lời:** Không. Đó là **hệ quả tự động** của việc áp 4 nhóm luật lên 74.000 từ Viet74K. Em **không nhập tay** 26.000 mục; chỉ nhập vài chục mục từ vựng riêng. Con số lớn phản ánh **độ phủ của luật**, không phải công sức gõ tay.

### Q9. "Chuẩn hóa thay sai thì hậu quả gì? Có an toàn không?"
**Trả lời:** Hệ thống **lưu song song bản gốc** `text_original` bên cạnh `text_normalized` (mục 4.2.1) — nên khi chuẩn hóa thay sai vẫn **đối chiếu và kiểm toán được**, và thu được dữ liệu để cải thiện dict. Ở bước phân loại còn có **sàn an toàn Math.max** (4.2.4): mức khẩn cấp cuối không bao giờ thấp hơn mức từ khóa phát hiện. Từ lạ thì giữ nguyên. Nên rủi ro được kiểm soát nhiều tầng.

### Q10. "Chỉ làm cho Quảng Nam? Vùng khác thì sao?"
**Trả lời:** Tập luật hiện tại đặc thù cho giọng vùng này, nhưng **khung giải pháp tổng quát hóa được**: với vùng khác chỉ cần **thay tập luật biến âm + lớp từ vựng riêng**, còn quy trình sinh và thuật toán khớp giữ nguyên. Đây là điểm em xem là hướng mở rộng.

### Q11. "Minh họa 4.2.5 là tập câu do em tự xây — có thiên vị không?"
**Trả lời:** Em **thừa nhận và đã nêu rõ điều này ngay trong báo cáo** (4.2.5). Đây là khảo sát **định tính**, không phải đo hiệu năng thống kê. Nhưng kết luận rút ra **không dựa vào số lượng câu** mà dựa vào **logic**: nhánh dò từ khóa khớp mặt chữ, nên với đầu vào phương ngữ nó **tất yếu** sai nếu không chuẩn hóa — điều này đúng bất kể tập câu lớn hay nhỏ.

### Q12. "Vì sao chuẩn hóa ở thiết bị (client) mà không ở máy chủ?"
**Trả lời:** Để chạy **offline ngay tại chỗ nhập**, không phụ thuộc mạng; và để giữ **một nguồn từ điển duy nhất** đóng gói trong app. Máy chủ nhận cả bản gốc lẫn bản chuẩn hóa (4.2.1) nên vẫn kiểm toán được.

---

## E. KỊCH BẢN DEMO PHẦN CHUẨN HÓA (nói gì khi thao tác)

Khi demo tính năng nhập SOS bằng giọng/chữ phương ngữ, nói theo mạch:
1. "Em nhập/nói một câu giọng miền Trung, ví dụ *'Nhoà tui ngập tới mớ nhoà rồi'*."
2. "Ở đây, ngay trên máy và **không cần mạng**, bộ chuẩn hóa đổi thành *'Nhà tui ngập tới mái nhà rồi'*."
3. "Nhờ vậy, bước phân loại phía sau **khớp được từ khóa 'mái nhà'** → nâng đúng mức khẩn cấp; nếu không chuẩn hóa thì nó chỉ thấy 'ngập' và xếp thấp hơn thực tế."
4. "Và hệ thống **giữ cả bản gốc** để đối chiếu — em cho thầy xem hai cột `text_original` và `text_normalized` trong dữ liệu."

Chuẩn bị sẵn 2–3 câu chạy chắc chắn (nhoà→nhà, mớ nhoà→mái nhà, người già, "nỏ ai bị thương" để khoe cơ chế phủ định ở câu 5 Bảng 4.5).

---

## F. CÂU CHỐT HẠ (thông điệp cốt lõi, học thuộc)

> "Chuẩn hóa phương ngữ trong đề tài **không phải một bảng tra tay**, mà là việc **mô hình hóa quy luật biến âm của giọng miền Trung thành luật, rồi sinh tự động một từ điển ánh xạ hơn 26.000 mục chạy hoàn toàn offline**. Vai trò của nó là **điều kiện để nhánh xử lý offline (dò từ khóa) không đánh giá sai mức khẩn cấp cho người nói phương ngữ** — nhóm người dùng thực tế của một hệ cứu hộ ở miền Trung. Em cũng **nêu rõ giới hạn** của phần đánh giá ngay trong báo cáo, và xem việc mở rộng độ phủ cùng kiểm thử định lượng là hướng phát triển."

---

## GHI NHỚ NHANH TRƯỚC KHI VÀO (đọc lướt 5 phút cuối)
- 2 nhóm: **biến âm (luật)** + **từ vựng riêng (liệt kê)**.
- Sinh từ **74.000 từ Viet74K** → **>26.000 mục**, phần lớn tự sinh.
- 3 điều kiện lọc; quan trọng nhất: **không trùng từ chuẩn**.
- Khớp **cụm dài trước** (mớ nhoà → mái nhà).
- **Offline**; **giữ bản gốc** `text_original`; **sàn an toàn Math.max**.
- Điểm yếu cần thành thật: **độ phủ STT** + **đánh giá định tính** — báo cáo đã tự nêu (4.2.5, 5.2).
- Thông điệp: **cơ chế sinh + phòng thủ nhiều lớp**, không phải bảng tra.
