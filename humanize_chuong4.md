# HUMANIZE CHƯƠNG 4 — Danh sách TÌM / THAY cho Claude add-in Word

> Mục tiêu: bỏ dấu hiệu "văn AI" (in đậm giữa câu, câu bình luận sáo, chốt kịch tính,
> gạch ngang thừa, khuôn bộ-ba lặp) và rút gọn câu, GIỮ NGUYÊN ý.
>
> QUY TẮC BẮT BUỘC khi áp dụng:
> - CHỈ thay phần văn xuôi nêu dưới đây. KHÔNG đụng vào: đoạn code, Bảng 4.1–4.7,
>   mọi con số (0,1 ms / 1,2 giây / 2,3 giây / 5,6 giây / 95% / 3 giây / 26.000…),
>   tên hàm–cột–bảng–file nguồn, và 4 chú thích "(Sơ đồ Hình 4.x - sẽ được chèn)".
> - Nếu không tìm thấy khớp chính xác 100% (do dấu ngoặc cong/thẳng khác nhau),
>   khớp theo nội dung câu rồi thay. Báo lại mục nào đã thay, mục nào không tìm thấy.
> - Không thêm/bớt in đậm nào khác ngoài việc GỠ in đậm ở các cụm chỉ định.

---

## 1. Mục 4.2.2 — câu dẫn + hai nhóm hiện tượng (gỡ in đậm "biến âm", "lớp từ vựng riêng")

TÌM đoạn bắt đầu "Sai lệch này không ngẫu nhiên mà có tính quy luật…" đến "…phải liệt kê (Bảng 4.2)."

THAY bằng:
Sai lệch này có tính quy luật, nên có thể mô hình hóa thành một tập luật biến âm rồi ánh xạ ngược về dạng chuẩn; cơ sở lý thuyết đã nêu ở mục 2.2.3.2, phần này trình bày cách hiện thực. Phương ngữ gồm hai nhóm hiện tượng cần hai nguồn tri thức khác nhau: nhóm biến âm mô hình hóa được bằng luật (Bảng 4.1), và lớp từ vựng riêng thì không suy ra được bằng luật nên phải liệt kê (Bảng 4.2).

---

## 2. Mục 4.2.2 — đoạn "ba vấn đề con" (ngay sau Bảng 4.2)

TÌM "Trên cơ sở đó, giải pháp phải xử lý ba vấn đề con… Ba mục tiếp theo trình bày cách giải quyết từng vấn đề."

THAY bằng:
Từ đó, giải pháp phải giải quyết ba vấn đề: xây từ điển ánh xạ đủ lớn, cập nhật được khi có từ mới giữa mùa lũ, và thay thế mà không sai nghĩa. Ba mục sau lần lượt trình bày từng vấn đề.

---

## 3. Mục 4.2.2.1 — "Ý nghĩa của thiết kế:"

TÌM "Ý nghĩa của thiết kế: khi phát hiện một từ địa phương chưa có trong từ điển giữa mùa lũ… người dùng cũng không phải cập nhật."

THAY bằng:
Nhờ thiết kế này, khi gặp một từ địa phương mới giữa mùa lũ, quản trị viên chỉ cần gọi API thêm từ; không phải biên dịch hay phát hành lại ứng dụng, người dùng cũng không phải cập nhật.

---

## 4. Mục 4.2.2.2 — "ba điều kiện" (sau đoạn code sinh từ điển)

TÌM "Một mục chỉ được giữ lại khi thỏa đồng thời ba điều kiện… được dùng làm lớp gốc."

THAY bằng:
Một mục chỉ được giữ khi thỏa cả ba điều kiện: dạng sinh ra khác từ gốc (trùng thì luật vô ích), không nằm trong danh sách chặn, và không trùng từ chuẩn đã có. Điều kiện cuối quan trọng nhất: nếu một dạng biến âm trùng từ chuẩn "hòa" thì mọi câu phổ thông chứa "hòa" đều bị thay sai nghĩa. Quy trình sinh ra tệp từ điển hơn 26.000 mục, dùng làm lớp gốc.

---

## 5. Mục 4.2.2.3 — đoạn kết (gỡ nhân hóa "kết thúc trong im lặng")

TÌM "Cơ chế đồng bộ hỏi số phiên bản trước rồi mới tải dữ liệu… vẫn hoạt động bình thường bằng lớp gốc."

THAY bằng:
Cơ chế hỏi số phiên bản trước rồi mới tải dữ liệu, tránh tải lại toàn bộ từ điển mỗi lần mở ứng dụng. Số phiên bản là một bộ đếm chỉ tăng, không suy ra từ số lượng từ, vì thao tác xóa làm số lượng giảm sẽ khiến ứng dụng tưởng dữ liệu máy chủ cũ hơn. Khi mất mạng, hàm thoát mà không báo lỗi và chức năng chuẩn hóa vẫn chạy bằng lớp gốc.

---

## 6. Mục 4.2.2.4 — câu dẫn thuật toán (gỡ in đậm "cụm ba từ, rồi cụm hai từ, rồi từ đơn")

TÌM "Thuật toán duyệt văn bản từ trái sang phải, tại mỗi vị trí thử khớp cụm ba từ, rồi cụm hai từ, rồi từ đơn — khớp được ở mức nào thì thay và nhảy qua đúng số từ đó."

THAY bằng:
Thuật toán duyệt văn bản từ trái sang phải; tại mỗi vị trí, nó thử khớp cụm ba từ, rồi cụm hai từ, rồi từ đơn, khớp ở mức nào thì thay và nhảy qua đúng số từ đó.

---

## 7. Mục 4.2.2.4 — đoạn "Vì sao phải thử cụm dài trước" (gỡ in đậm câu tiêu đề)

TÌM "Vì sao phải thử cụm dài trước. Xét cụm "mớ nhoà", nghĩa là mái nhà… được nhận diện trọn vẹn."

THAY bằng:
Thứ tự thử cụm dài trước có lý do. Xét cụm "mớ nhoà" (nghĩa: mái nhà): nếu xử lý từ đơn trước, "mớ" không có trong từ điển nên giữ nguyên, còn "nhoà" bị thay thành "nhà", cho kết quả sai "mớ nhà". Chỉ khi khớp ở mức cụm hai từ, thuật toán mới nhận "mớ nhoà" là một mục nguyên khối và cho ra "mái nhà"; "chu cha" (ôi trời) cũng vậy. Vì thế phải thử theo thứ tự ba từ, hai từ, một từ thì các cụm mang nghĩa riêng mới được nhận diện trọn vẹn.

---

## 8. Mục 4.2.3.1 — đoạn "Ba lựa chọn" (gỡ "vốn là", nhân hóa "tự vô hiệu hóa chính nó")

TÌM "Ba lựa chọn trong hàm này đều xuất phát từ đặc thù của bài toán cứu hộ… sẽ tự vô hiệu hóa chính nó."

THAY bằng:
Cả ba lựa chọn trong hàm đều bắt nguồn từ đặc thù bài toán cứu hộ. Dấu câu làm ranh giới mệnh đề để từ phủ định ở vế trước không lan sang vế sau: trong câu "nước không rút, nhà ngập nóc", từ khóa ngập nóc vẫn phải tính. Cửa sổ phủ định chỉ rộng hai từ, vì chặn nhầm một từ khóa thật (âm tính giả) nguy hiểm hơn nhiều so với báo động giả (dương tính giả), mà cửa sổ càng rộng càng dễ chặn nhầm. Riêng các từ khóa tự mở đầu bằng từ phủ định thì bỏ qua bước xét phủ định, nếu không cụm "không thở", vốn là dấu hiệu nguy kịch nhất, sẽ bị loại ngay cả khi xuất hiện.

---

## 9. Mục 4.2.3.2 — hai câu meta

TÌM "Một tham số cấu hình có ảnh hưởng quyết định tới tính khả dụng của nhánh này là thinkingConfig."
THAY bằng:
Một tham số cấu hình ảnh hưởng lớn tới tính khả dụng của nhánh này là thinkingConfig.

TÌM "Tác động của tham số này được đo cụ thể ở mục 4.5.1: độ trễ trung bình giảm từ khoảng 5,6 giây xuống còn khoảng 1,2 giây… vô hiệu hóa gần như toàn bộ nhánh mô hình ngôn ngữ."
THAY bằng:
Mục 4.5.1 đo tác động của tham số này: độ trễ trung bình giảm từ khoảng 5,6 giây xuống khoảng 1,2 giây (hơn bốn lần) mà chất lượng phân loại không đổi. Nhờ đó ngưỡng chờ mới đặt được ở mức 3 giây; nếu giữ chế độ suy luận mặc định, ngưỡng này gần như vô hiệu hóa toàn bộ nhánh mô hình ngôn ngữ.

---

## 10. Mục 4.2.3.3 — "Cần nói rõ… / Giá trị… nằm ở chỗ"

TÌM "Cần nói rõ về bản chất luồng thực thi: hai nhánh không chạy đua với nhau… đo định lượng độ trễ và tỉ lệ sử dụng của từng nhánh."

THAY bằng:
Về luồng thực thi, hai nhánh không chạy đua với nhau. Nhánh dò từ khóa chạy đồng bộ và cho kết quả ngay, rồi chương trình mới chờ (await) nhánh mô hình ngôn ngữ; cấu trúc Promise.race chỉ nằm bên trong nhánh mô hình để giới hạn thời gian chờ. Do đó thời gian phản hồi của hệ thống bị chặn dưới bởi độ trễ của mô hình, tối đa bằng ngưỡng đã cấu hình, và nhánh dò từ khóa không rút ngắn được thời gian này. Vai trò của nó là bảo đảm hệ thống luôn có kết quả: khi mô hình chậm, lỗi, hoặc mất kết nối tới dịch vụ, hệ thống vẫn phân loại được và luồng tạo ca không bị nghẽn. Mục 4.5.1 đo độ trễ và tỉ lệ sử dụng của từng nhánh.

---

## 11. Mục 4.2.3.3 — "Đây là một đánh đổi được cân nhắc trước"

TÌM "Phép Math.max giữ vai trò sàn an toàn… phục vụ thống kê tỉ lệ dự phòng ở mục 4.5.1."

THAY bằng:
Phép Math.max đóng vai trò sàn an toàn: mức khẩn cấp cuối không bao giờ thấp hơn mức mà từ khóa cảnh báo phát hiện. Nếu văn bản chứa "đuối nước" (mức 5) nhưng mô hình đánh giá mức 2, kết quả cuối vẫn là 5. Đây là đánh đổi có chủ đích: trong cứu hộ, bỏ sót một ca nguy kịch để lại hậu quả không đảo ngược, còn một báo động giả chỉ tốn công, nên hệ thống được thiết kế nghiêng về phía an toàn, thà đánh giá cao hơn thực tế còn hơn để lọt dấu hiệu nguy hiểm. Trường ai_source ghi nguồn của kết quả cuối (gemini hoặc rule_based), phục vụ thống kê tỉ lệ dự phòng ở mục 4.5.1.

---

## 12. Mục 4.2.4 — đoạn "ba kiểu tác động" (sau Bảng 4.5) — gỡ in đậm "Đổi mức khẩn cấp / Đổi nhãn phân loại / Không đổi gì"

TÌM "Bảng cho thấy ba kiểu tác động. Đổi mức khẩn cấp (câu 1–3)… cho tình nguyện viên đọc."

THAY bằng:
Bảng phản ánh ba kiểu tác động của chuẩn hóa. Kiểu thứ nhất là đổi mức khẩn cấp, thấy ở câu 1 đến 3: các từ khóa quyết định như "mái nhà", "người già" chỉ xuất hiện sau khi dạng phương ngữ được ánh xạ về dạng chuẩn; nếu thiếu bước này, một ca có người già mắc kẹt hay nước đã ngập tới mái sẽ bị xếp thấp hơn thực tế và bị ưu tiên sau. Kiểu thứ hai là đổi nhãn phân loại, thấy ở câu 4 và câu 5. Kiểu thứ ba là không thay đổi gì, như câu 6: các từ "chu cha", "răng", "rứa" không trùng từ khóa nào nên chuẩn hóa chỉ khiến câu dễ hiểu hơn cho nhánh mô hình ngôn ngữ và cho tình nguyện viên đọc.

---

## 13. Mục 4.2.4 — đoạn "Câu 5 đáng chú ý nhất" (gỡ in đậm "tiền đề để các cơ chế phía sau vận hành đúng")

TÌM "Câu 5 đáng chú ý nhất. Từ phủ định phương ngữ "nỏ"… tiền đề để các cơ chế phía sau vận hành đúng."

THAY bằng:
Câu 5 minh họa rõ nhất điều này. Từ phủ định phương ngữ "nỏ" không nằm trong danh sách từ phủ định ở mục 4.2.3.1, nên khi chưa chuẩn hóa, cụm "bị thương" vẫn được tính và hệ thống gán sai nhãn y_te cho một ca thực tế không có ai bị thương. Sau khi "nỏ" được ánh xạ thành "không", cơ chế phủ định mới nhận ra và loại bỏ nhãn sai. Như vậy chuẩn hóa không dừng ở việc bổ sung thông tin cho bước phân loại, mà còn là điều kiện để các cơ chế phía sau chạy đúng.

---

## 14. Mục 4.2.4 — đoạn "Phạm vi của minh họa" (gỡ in đậm câu tiêu đề, "hẹp nhưng chắc")

TÌM "Phạm vi của minh họa. Đây là khảo sát định tính trên tập câu do người viết xây dựng… (bàn thêm ở mục 5.2)."

THAY bằng:
Minh họa trên có phạm vi giới hạn. Đây là một khảo sát định tính trên tập câu do người viết tự xây dựng, và chỉ đo tác động lên nhánh dò từ khóa, vốn so khớp theo mặt chữ nên chắc chắn thất bại với dạng phương ngữ. Việc nhánh mô hình ngôn ngữ lớn có thể tự hiểu phương ngữ mà không cần chuẩn hóa hay không thì chưa được kiểm chứng. Do đó kết quả khẳng định được ở đây tuy giới hạn nhưng đáng tin cậy: bộ chuẩn hóa bảo đảm nhánh dò từ khóa, lớp xử lý duy nhất còn chạy khi mất mạng, không đánh giá sai mức khẩn cấp đối với người nói phương ngữ (bàn thêm ở mục 5.2).

---

## 15. Mục 4.3.1 — đoạn cuối "Cần lưu ý rằng… Nói cách khác"

TÌM "Cần lưu ý rằng tác vụ này không đổi trạng thái ca sang orphaned mà giữ nguyên ở pending… không phải một trạng thái trong vòng đời ca."

THAY bằng:
Tác vụ này không đổi trạng thái ca sang orphaned mà giữ ở pending, vì ca vẫn phải hiển thị để tình nguyện viên tiếp nhận; cảnh báo ca mồ côi là để huy động quản trị viên can thiệp, không phải để đóng ca. "Mồ côi" ở đây là một sự kiện cảnh báo, không phải một trạng thái trong vòng đời ca.

---

## 16. Mục 4.3.2 — đoạn "cân bằng hai yếu tố"

TÌM "Cách xếp hạng này cân bằng giữa hai yếu tố vốn xung đột nhau… rồi mới để mức nguy kịch quyết định thứ tự."

THAY bằng:
Cách xếp hạng này cân bằng hai yếu tố xung đột nhau. Xếp thuần theo khoảng cách thì một ca ngập nhẹ cách 100 m luôn đứng trên ca có người đuối nước cách 500 m; xếp thuần theo mức khẩn cấp thì tình nguyện viên có thể bị đẩy tới ca nguy kịch ở rất xa trong khi có ca khác gần hơn nhiều. Chia vành đai coi mọi ca trong cùng khoảng cách di chuyển là tương đương, rồi mới để mức nguy kịch quyết định thứ tự.

---


-------------- làm tới đấy r, FLD
## 17. Mục 4.3.3 — định nghĩa ngưỡng + quy trình thu hồi

TÌM "Điều kiện khoảng_cách_hiện_tại ≥ 0,9 × khoảng_cách_ban_đầu là định nghĩa định lượng của trạng thái "không tiến lại gần"… mở lại để phát sóng cho người khác."

THAY bằng:
Điều kiện khoảng_cách_hiện_tại ≥ 0,9 × khoảng_cách_ban_đầu chính là cách định lượng trạng thái "không tiến lại gần", với biên 10% để dung sai nhiễu GPS. Quy trình thu hồi có bước hỏi lại: hệ thống gửi thông báo xác nhận trước, chỉ khi tình nguyện viên im lặng thêm 5 phút thì phân công mới bị thu hồi và ca được mở lại để phát sóng cho người khác.

---

## 18. Mục 4.3.3 — "được giữ lại cho con người"

TÌM "Một tác vụ tương tự phát hiện ca ở trạng thái on_scene quá 60 phút… quyết định kết thúc một ca cứu hộ được giữ lại cho con người."

THAY bằng:
Một tác vụ tương tự phát hiện ca ở trạng thái on_scene quá 60 phút mà tình nguyện viên đã rời khu vực. Tác vụ này chỉ cảnh báo quản trị viên xem xét chứ không tự đóng ca, để tránh đóng nhầm một ca còn đang diễn ra; quyết định kết thúc một ca vẫn do con người đưa ra.

---

## 19. Mục 4.3.3 — câu cuối (gỡ "Cần lưu ý rằng")

TÌM "Cần lưu ý rằng cả hai cơ chế trên đều dựa trên khoảng cách đường chim bay… được bàn ở mục 5.2 và 5.3."

THAY bằng:
Cả hai cơ chế trên đều dựa trên khoảng cách đường chim bay chứ không phải quãng đường di chuyển thực. Trong vùng lũ, một tình nguyện viên buộc phải đi vòng có thể bị đánh giá nhầm là bế tắc; hạn chế này và hướng khắc phục được bàn ở mục 5.2 và 5.3.

---

## 20. Mục 4.5.1 — "Giá trị của nó nằm ở chỗ khác"

TÌM "Kết quả này khẳng định nhận định đã nêu ở mục 4.2.3.3: thời gian phản hồi của hệ thống hoàn toàn do độ trễ của mô hình ngôn ngữ quyết định… là bảo đảm hệ thống luôn có kết quả."

THAY bằng:
Kết quả này khẳng định nhận định ở mục 4.2.3.3: thời gian phản hồi của hệ thống do độ trễ mô hình ngôn ngữ quyết định, nhánh dò từ khóa không rút ngắn được. Vai trò của nhánh này nằm ở chỗ khác: bảo đảm hệ thống luôn có kết quả.

---

## 21. Mục 4.5.1 — "Tình huống… đã tự nó xảy ra"

TÌM "Cả hai ca đó đều được nhánh dò từ khóa tiếp quản và phân loại thành công… và cơ chế hoạt động đúng như dự kiến."

THAY bằng:
Cả hai ca đó đều được nhánh dò từ khóa tiếp quản và phân loại thành công, luồng tạo ca không gián đoạn. Đúng tình huống mà lớp bảo đảm tối thiểu được thiết kế để phòng ngừa, và cơ chế hoạt động đúng như dự kiến.

---

## 22. Mục 4.5.1 — đoạn "Cần nhấn mạnh rằng… Chỉ khi đo mới phát hiện ra"

TÌM "Cần nhấn mạnh rằng kết quả trên chỉ đạt được sau khi tắt chế độ suy luận nội tại của mô hình (mục 4.2.3.2)… Chỉ khi đo mới phát hiện ra."

THAY bằng:
Kết quả trên chỉ đạt được sau khi tắt chế độ suy luận nội tại của mô hình (mục 4.2.3.2). Đo lại trên cùng tập dữ liệu với cấu hình mặc định, độ trễ trung bình lên khoảng 5,6 giây, gấp hơn bốn lần. Với độ trễ đó, ngưỡng 3 giây chỉ cho chưa tới một phần mười số ca kịp dùng kết quả mô hình, tức cơ chế lai gần như không vận hành đúng thiết kế; muốn phần lớn số ca dùng được mô hình thì phải chờ tới 10 giây, mức không chấp nhận được khi khẩn cấp. Sai lệch này không để lộ dấu hiệu nào trong quá trình phát triển: hệ thống vẫn chạy, vẫn trả kết quả, chỉ là trả bằng nhánh dò từ khóa, và chỉ khi đo mới phát hiện.

---

## 23. Mục 4.6 Kết luận chương — thay TOÀN BỘ (gỡ khuôn "— … Từ đó:" lặp 3 lần + mọi in đậm)

TÌM từ "Chương này đã trình bày cách hiện thực ba trụ cột nêu trong tên đề tài, mỗi trụ cột xoay quanh một nhận định thiết kế:" đến hết chương ("…kèm hướng khắc phục ở mục 5.3.").

THAY bằng:
Chương này đã trình bày cách hiện thực ba cơ chế cốt lõi của hệ thống, mỗi cơ chế bắt nguồn từ một quan sát trong quá trình xây dựng.

Với xử lý ngôn ngữ địa phương, quan sát then chốt là sai lệch của bộ nhận dạng giọng nói đối với phương ngữ tuân theo quy luật, nhờ đó có thể mô hình hóa bằng một tập luật biến âm và đảo ngược lại bằng một lớp hậu xử lý. Cách làm này cho phép sinh từ điển từ corpus chuẩn thay vì liệt kê thủ công, tổ chức từ điển thành hai lớp để cập nhật được ngay giữa mùa lũ, và chuẩn hóa văn bản bằng thuật toán khớp cụm dài nhất.

Với phân loại ca SOS, xuất phát điểm là đặc thù của bài toán cứu hộ: bỏ sót một ca nguy kịch để lại hậu quả nặng nề hơn một báo động giả. Vì vậy nhánh dò từ khóa cục bộ được giữ làm lớp bảo đảm hệ thống luôn có kết quả, còn quy tắc lấy mức khẩn cấp cao hơn giữa hai nhánh giúp không ca nào bị đánh giá nhẹ hơn mức mà từ khóa cảnh báo đã phát hiện.

Với điều phối cứu trợ, nguyên tắc rút ra là mọi trạng thái cần bền vững đều phải nằm trong cơ sở dữ liệu chứ không phải trong bộ nhớ tiến trình. Nhờ đó việc phát hiện ca mồ côi được chuyển sang một tác vụ quét định kỳ và vẫn hoạt động qua mọi lần máy chủ khởi động lại.

Kết quả đo ở mục 4.5 cho thấy nhánh dò từ khóa phân loại đúng toàn bộ số ca trong mọi kịch bản thử nghiệm, và ngưỡng chờ 3 giây chỉ trở nên khả thi sau khi tắt chế độ suy luận nội tại của mô hình ngôn ngữ. Những hạn chế còn lại được phân tích ở mục 5.2, cùng hướng khắc phục ở mục 5.3.

---

# HẾT — 23 mục. Sau khi thay xong, rà lại: không còn cụm in đậm giữa câu ở Chương 4;
# không còn "Cần lưu ý rằng / Cần nói rõ / Giá trị… nằm ở chỗ / Đây là một đánh đổi được cân nhắc trước".
