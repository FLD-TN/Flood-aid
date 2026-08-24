KỊCH BẢN THUYẾT TRÌNH BẢO VỆ — FloodAid

Lời nói cho từng slide, theo đúng thứ tự trình chiếu (26 slide, tính cả các slide chuyển phần). Phần trong ngoặc là ghi chú thao tác, không đọc.


==================================================
SLIDE 1 — BÌA
==================================================
    
Em kính chào quý thầy cô trong hội đồng. Em tên là Trần Anh Duy, mã số sinh viên 23DH110527. Hôm nay em xin phép được trình bày khóa luận tốt nghiệp của mình, với đề tài: "Nghiên cứu và Xây dựng Nền tảng Hỗ trợ Điều phối Cứu trợ Lũ lụt tại Miền Trung dựa trên AI NLP", dưới sự hướng dẫn của cô Lê Thị Minh Nguyện.

Sau đây em xin bắt đầu phần trình bày.


==================================================
SLIDE 2 — MỤC LỤC
==================================================

Bài của em gồm năm phần chính.

Thứ nhất là đặt vấn đề và lý do em chọn đề tài này. Thứ hai là cơ sở lý thuyết và phương pháp nghiên cứu. Thứ ba, cũng là phần trọng tâm, là kiến trúc hệ thống và ba cơ chế lõi. Thứ tư, em sẽ demo sản phẩm chạy thực tế. Và cuối cùng là hạn chế, hướng phát triển và kết luận.

Em xin đi vào phần thứ nhất.


==================================================
(SLIDE CHUYỂN PHẦN 01) — ĐẶT VẤN ĐỀ VÀ LÝ DO CHỌN ĐỀ TÀI
==================================================

(Slide nền xanh báo hiệu bắt đầu phần một. Có thể đọc luôn tên phần hoặc dừng một nhịp rồi qua slide sau.)

Đầu tiên, em xin nói về thực trạng đã dẫn em tới đề tài này.


==================================================
SLIDE 3 — ĐẶT VẤN ĐỀ (THỰC TRẠNG)
==================================================

Miền Trung nước ta năm nào cũng phải hứng chịu mưa bão và lũ lụt, và mức độ thì rất khốc liệt. Chỉ riêng đợt lũ lịch sử cuối năm 2020 đã làm 249 người chết và mất tích, thiệt hại lên tới hơn 36.000 tỷ đồng. Gần đây nhất, đợt lũ năm 2025 tiếp tục cướp đi 219 sinh mạng. Đây là con số cho thấy vấn đề không hề giảm đi mà vẫn lặp lại hằng năm.

Trong khi đó, việc điều phối cứu trợ hiện nay phần lớn vẫn làm thủ công. Người dân kêu cứu chủ yếu qua Zalo, Facebook, hoặc gọi điện thoại một cách tự phát, chứ chưa có một hệ thống chuyên nghiệp nào đứng ra tiếp nhận và điều phối.

Hệ quả là thông tin bị phân tán và trùng lặp: cùng một nhà có thể được nhiều nơi kêu cứu, trong khi nhiều nhà khác lại bị bỏ sót. Quan trọng hơn, không có cơ chế phân loại xem ai nguy cấp hơn ai, nên lực lượng cứu hộ rất khó ưu tiên đúng người cần giúp trước.


==================================================
SLIDE 4 — LÝ DO VÀ MỤC TIÊU
==================================================

Từ thực trạng đó, em chọn đề tài này vì ba lý do.

Thứ nhất là nhu cầu thực tiễn: hiện nay chưa có một nền tảng chuyên biệt nào dành riêng cho việc điều phối cứu trợ khẩn cấp ngay tại hiện trường trong bão lũ.

Thứ hai là cơ hội về công nghệ: những năm gần đây, công nghệ xử lý ngôn ngữ tự nhiên, các mô hình ngôn ngữ lớn, cùng với hệ thống thông tin địa lý đã phát triển rất nhanh, cho phép em xây dựng một nền tảng thông minh với chi phí hợp lý.

Và từ đó, mục tiêu của đề tài là: xây dựng một nền tảng có thể tự động phân loại mức độ khẩn cấp của tin cầu cứu bằng AI, và điều phối tình nguyện viên tới hiện trường thông qua bản đồ thời gian thực.


==================================================
(SLIDE CHUYỂN PHẦN 02) — CƠ SỞ LÝ THUYẾT VÀ PHƯƠNG PHÁP NGHIÊN CỨU
==================================================

Tiếp theo, em xin trình bày cơ sở lý thuyết và phương pháp nghiên cứu.


==================================================
SLIDE 5 — CƠ SỞ LÝ THUYẾT VÀ PHƯƠNG PHÁP
==================================================

Về cơ sở lý thuyết, em chỉ nêu những thứ trực tiếp được dùng trong hệ thống.

Về xử lý ngôn ngữ, em kết hợp thuật toán dựa trên luật với mô hình ngôn ngữ lớn Gemini 2.5 Flash. Về nhận dạng giọng nói, em dùng bộ nhận dạng có sẵn trên thiết bị, kết hợp với việc mô hình hóa luật biến âm của phương ngữ. Về bản đồ và không gian, em dùng PostGIS để truy vấn khoảng cách, và bản đồ VietMap.

Về phương pháp, đây là đề tài theo hướng xây dựng và thực nghiệm hệ thống. Dữ liệu em dùng là bộ từ vựng tiếng Việt Viet74K, từ đó áp luật để sinh tự động ra bộ từ điển phương ngữ khoảng 26.000 mục.

Đề tài có ba điểm mới. Điểm mới thứ nhất là sinh từ điển phương ngữ bằng luật một cách tự động, thay vì phải gõ tay từng từ. Điểm mới thứ hai là áp dụng cơ chế phân loại lai, tức là kết hợp cả luật lẫn AI. Em sẽ đi sâu vào những điểm này ở phần sau.


==================================================
(SLIDE CHUYỂN PHẦN 03) — KIẾN TRÚC VÀ CÁC CƠ CHẾ LÕI CỦA HỆ THỐNG
==================================================

Sau đây là phần trọng tâm của bài: kiến trúc hệ thống và ba cơ chế lõi.


==================================================
SLIDE 6 — KIẾN TRÚC TỔNG THỂ
==================================================

(Chỉ vào sơ đồ trên màn hình.)

Đây là kiến trúc tổng thể của hệ thống, gồm ba lớp.

Lớp ngoài cùng là phía người dùng, gồm ba ứng dụng: app cho nạn nhân, app cho tình nguyện viên, và web cho quản trị viên. Ở giữa là máy chủ, viết bằng Node.js và Express, chịu trách nhiệm xử lý toàn bộ nghiệp vụ. Bên dưới là cơ sở dữ liệu PostgreSQL có PostGIS để xử lý dữ liệu bản đồ. Ngoài ra, hệ thống có kết nối tới một số dịch vụ ngoài như Gemini, VietMap và Firebase.

Điểm em muốn nhấn ở đây là hệ thống hoạt động theo thời gian thực: khi có tin cầu cứu, thông tin được đẩy ngay tới tình nguyện viên và quản trị viên chứ không phải chờ tải lại.


==================================================
SLIDE 7 — PIPELINE 3 CƠ CHẾ LÕI
==================================================

Toàn bộ hệ thống xoay quanh ba cơ chế lõi, nối tiếp nhau thành một chuỗi: chuẩn hóa, rồi phân loại, rồi điều phối.

Cơ chế thứ nhất là chuẩn hóa phương ngữ: một câu cầu cứu nói bằng giọng địa phương sẽ được đưa về tiếng Việt chuẩn, và bước này chạy hoàn toàn offline trên máy.

Cơ chế thứ hai là phân loại mức khẩn cấp: câu đã chuẩn hóa được đưa vào đánh giá bằng hai nhánh song song là từ khóa offline và Gemini, sau đó hợp nhất bằng cách lấy mức cao hơn để làm sàn an toàn.

Cơ chế thứ ba là điều phối cứu trợ: hệ thống phát tin cầu cứu tới tình nguyện viên phù hợp, theo sát quá trình họ tiếp cận, và tự động thu hồi ca nếu không có tiến triển.

Sau đây em sẽ đi vào từng cơ chế một.


==================================================
SLIDE 8 — CƠ CHẾ 1: CHUẨN HÓA PHƯƠNG NGỮ (VẤN ĐỀ)
==================================================

Bắt đầu với cơ chế thứ nhất là chuẩn hóa phương ngữ. Trước hết em xin nói về vấn đề.

Người dân vùng lũ nói giọng địa phương, và hệ thống của em tiếp nhận tin cầu cứu bằng cả giọng nói lẫn gõ chữ. Vấn đề nằm ở chỗ: khi người dân nói, bộ nhận dạng giọng nói chép lại đúng cái âm địa phương đó. Ví dụ họ nói "nhà" thì máy ghi ra "nhoà", nói "làm" thì ghi ra "lồm". Trong khi đó, các bước xử lý phía sau như phân loại hay dò từ khóa lại chỉ hiểu tiếng phổ thông chuẩn.

Hệ quả là nếu không chuẩn hóa, câu phương ngữ sẽ bị bỏ sót những từ khóa quan trọng, và hệ thống sẽ đánh giá sai mức độ khẩn cấp — điều rất nguy hiểm trong cứu hộ.

Qua khảo sát, em thấy phương ngữ cần xử lý chia làm hai loại. Loại thứ nhất là biến âm, tức là cùng một từ nhưng đọc chệch đi. Loại thứ hai là từ vựng riêng, tức là những từ khác hẳn tiếng phổ thông. Hai loại này cần hai cách xử lý khác nhau, em sẽ trình bày ở hai slide tiếp theo.


==================================================
SLIDE 9 — LOẠI 1: BIẾN ÂM
==================================================

Loại thứ nhất là biến âm. Đây là trường hợp cùng một từ nhưng phát âm chệch theo vùng.

Điều may mắn là kiểu biến đổi này có quy luật rõ ràng. Thầy cô nhìn bảng bên đây: "nhoà" là do âm "à" đọc thành "oà" của từ "nhà"; "goà" cũng vậy, từ "gà"; "coá" là âm "á" thành "oá" của "cá"; "lồm" là "àm" thành "ồm" của "làm"; "chẹn" là "ặn" thành "ẹn" của "chặn".

Vì có quy luật như vậy, em không cần gõ tay từng từ. Em chỉ cần viết các luật biến âm rồi áp lên bộ từ vựng chuẩn, thế là tự động sinh ra hàng chục nghìn cặp phương ngữ. Đây chính là điểm mới thứ nhất của đề tài.


==================================================
SLIDE 10 — LOẠI 2: TỪ VỰNG RIÊNG
==================================================

Loại thứ hai là từ vựng riêng. Đây là những từ hoàn toàn khác tiếng phổ thông, và không thể suy ra bằng bất kỳ quy luật âm nào.

Ví dụ như "răng" hay "ren" nghĩa là "sao"; "mô" là "đâu"; "rứa" là "thế"; "chừ" là "giờ"; "mi" là "mày"; "tau" là "tao"; "nỏ" là "không"; "chi" là "gì". Thầy cô thấy, giữa "răng" và "sao" không có liên hệ về âm nào cả, nên máy không thể tự đoán ra được.

Với nhóm này, bắt buộc phải liệt kê thủ công trong từ điển. Tuy nhiên số lượng những từ như vậy không nhiều, nên em có thể tự soạn được.


==================================================
SLIDE 11 — GIẢI PHÁP CHUẨN HÓA
==================================================

Tổng hợp lại, giải pháp chuẩn hóa của em gồm mấy điểm sau.

Thứ nhất, về việc sinh từ điển: em áp luật biến âm lên bộ Viet74K, tức là khoảng 74.000 từ tiếng Việt chuẩn, để tự động sinh ra khoảng 26.000 mục phương ngữ; cộng thêm phần từ vựng riêng em liệt kê tay.

Thứ hai, về thuật toán dịch, điểm quan trọng là khớp cụm dài trước. Nghĩa là hệ thống ưu tiên ghép cụm ba từ, rồi hai từ, rồi mới tới từng từ. Ví dụ "mớ nhoà" phải khớp nguyên cụm mới ra "mái nhà"; nếu tách lẻ ra thì sẽ sai thành "mớ nhà". Em sẽ minh họa kỹ điều này ở slide sau.

Thứ ba, hệ thống giữ nguyên viết hoa, và giữ nguyên những từ lạ không có trong từ điển, ví dụ như chữ "tui", để không làm hỏng câu.

Và cuối cùng, toàn bộ bước chuẩn hóa này chạy offline ngay trên thiết bị, không cần mạng, nên vẫn hoạt động được ngay cả khi lũ làm mất sóng.


==================================================
SLIDE 12 — KHỚP CỤM DÀI TRƯỚC HOẠT ĐỘNG THẾ NÀO?
==================================================

Đây là slide minh họa cách thuật toán khớp cụm dài chạy trên một câu thật. Câu vào là: "Nhoà tui ngập tới mớ nhoà rồi".

Hệ thống quét từ trái sang phải. Tại mỗi vị trí, nó thử ghép cụm dài trước, tức ba từ, rồi hai từ, rồi mới một từ; khớp được ở đâu thì lấy rồi nhảy qua đúng số từ đó.

Cụ thể như sau. Bước một, tại chữ "Nhoà", nó thử "Nhoà tui ngập" không có, "Nhoà tui" không có, tới từ đơn "Nhoà" thì khớp, ra "Nhà". Câu dịch tới lúc này là "Nhà".

Bước hai, tại "tui", thử các cụm đều không có trong từ điển, nên giữ nguyên "tui". Đây chính là quy tắc giữ nguyên từ lạ. Câu dịch thành "Nhà tui".

Bước ba và bốn, "ngập" và "tới" vốn đã là tiếng chuẩn, không có trong từ điển phương ngữ, nên giữ nguyên. Ở bước bốn, thầy cô để ý là nó có thử cụm "tới mớ nhoà", nhưng cụm này không khớp, nên "mớ nhoà" vẫn được để dành lại. Câu dịch thành "Nhà tui ngập tới".

Bước năm là bước quan trọng nhất. Tại chữ "mớ", nó thử "mớ nhoà rồi" không có, rồi thử cụm hai từ "mớ nhoà" thì khớp, ra "mái nhà", và nhảy luôn hai từ. Câu dịch thành "Nhà tui ngập tới mái nhà".

Bước sáu, "rồi" giữ nguyên, ra câu hoàn chỉnh.

Kết quả cuối cùng là "Nhà tui ngập tới mái nhà rồi". Điểm mấu chốt là ở bước năm: nhờ thử cụm "mớ nhoà" trước nên mới ra đúng "mái nhà". Nếu hệ thống xử lý từng từ đơn thì "mớ" giữ nguyên còn "nhoà" thành "nhà", ghép lại ra "mớ nhà" — vừa vô nghĩa, vừa làm mất tín hiệu ngập tới mái nhà, là một ca rất nguy hiểm.


==================================================
SLIDE 13 — MINH HỌA: CHUẨN HÓA CÂU SOS THỰC TẾ
==================================================

Để thấy rõ hơn, đây là bốn câu SOS thực tế mà người dân có thể nói.

Câu thứ nhất, "Nhoà tui ngập tới mớ nhoà rồi", thành "Nhà tui ngập tới mái nhà rồi". Câu này gồm cả biến âm, cả khớp cụm dài, và giữ nguyên từ lạ "tui".

Câu thứ hai, "Chừ ren rồi, nước lên tới mô?", thành "Giờ sao rồi, nước lên tới đâu?" — toàn từ vựng riêng: chừ là giờ, ren là sao, mô là đâu.

Câu thứ ba, "Nhà tui ngập rồi, phở lồm răng chừ?", thành "Nhà tui ngập rồi, phải làm sao giờ?". Ở đây chữ "phở" trông giống tên món ăn, nhưng trong ngữ cảnh này nó nghĩa là "phải", và hệ thống vẫn dịch đúng.

Câu thứ tư, "Nước chẹn hết đường, tau nỏ ra được", thành "Nước chặn hết đường, tao không ra được".

Điểm em muốn nói là câu thật thường trộn cả hai loại phương ngữ cùng lúc, và hệ thống xử lý được đồng thời, với nguyên tắc khớp cụm dài trước để không dịch lẻ sai.


==================================================
SLIDE 14 — CƠ CHẾ 2: PHÂN LOẠI MỨC KHẨN CẤP
==================================================

Sau khi đã có câu chuẩn, em chuyển sang cơ chế thứ hai là phân loại mức khẩn cấp.

Em thiết kế theo kiểu lai, tức là dùng hai nhánh. Nhánh thứ nhất là nhánh từ khóa, chạy offline, tốc độ cao, và đặc biệt xử lý được từ phủ định, ví dụ phân biệt được "thở" với "không thở". Nhánh thứ hai là gọi Gemini để hiểu những câu có ngữ cảnh phức tạp mà luật cứng khó bắt.

Điểm quan trọng là cách hợp nhất hai nhánh: em luôn lấy mức khẩn cấp cao hơn giữa hai bên, và gọi đây là sàn an toàn. Triết lý là trong cứu hộ, thà đánh giá nguy hiểm cao hơn thực tế một chút, còn hơn là bỏ sót một dấu hiệu nguy kịch chỉ vì mạng chập chờn hay AI trả lời sai.


==================================================
SLIDE 15 — CƠ SỞ PHÂN LOẠI: THANG MỨC VÀ TỪ KHÓA
==================================================

Để thầy cô thấy việc phân loại dựa trên cơ sở nào chứ không phải đoán, đây là thang mức và bảng từ khóa mà hệ thống dùng.

Em chia làm năm mức. Mức 5 là cực kỳ nguy hiểm, đe dọa tính mạng, gồm các từ như máu, bất tỉnh, không thở, chết, chìm, đuối nước. Mức 4 là khẩn cấp cao, như trẻ em, người già, bị thương, ngập nóc. Mức 3 là khẩn cấp trung bình, như mắc kẹt, nước dâng, cô lập. Mức 2 là khẩn cấp thấp, như ngập, cần xuồng, cần hỗ trợ. Còn mức 1 là mặc định khi không khớp từ khóa nào.

Ở đây có một chi tiết em muốn làm rõ. Nhánh từ khóa offline thì tra đúng bảng này. Còn nhánh Gemini, em nhét luôn nguyên thang một đến năm này vào trong câu lệnh gửi cho nó, để nó chấm điểm theo đúng khung của em chứ không tự đặt ra thang riêng. Nhờ vậy hai nhánh mới so sánh được với nhau để lấy mức cao hơn. Ngoài mức độ, hệ thống còn gắn nhãn, lấy từ một tập cố định gồm y tế, trẻ em, người già, ngập nóc, và phương tiện.


==================================================
SLIDE 16 — MINH HỌA: PHÂN LOẠI MỨC KHẨN CẤP
==================================================

Đây là bốn ví dụ minh họa cách phân loại hoạt động.

Ví dụ thứ nhất, "Có người bị chìm, không thở": nhánh từ khóa bắt được "chìm" và "không thở", cho mức 5 và nhãn y tế; Gemini cũng cho mức 5. Kết quả là mức 5.

Ví dụ thứ hai, "Nhà ngập nóc, người già mắc kẹt": nhánh từ khóa bắt "ngập nóc" là mức 4, "mắc kẹt" là mức 3, nên lấy mức cao hơn là 4, kèm hai nhãn ngập nóc và người già. Kết quả là mức 4.

Ví dụ thứ ba là để minh họa sàn an toàn. Câu "Con tui đuối nước rồi": nhánh từ khóa bắt "đuối nước", cho mức 5. Giả sử lúc này Gemini nhầm, chỉ cho mức 2. Nhờ lấy mức cao hơn giữa 5 và 2, kết quả cuối vẫn là mức 5. Đây chính là lúc sàn an toàn cứu được một ca nguy kịch khỏi bị đánh giá thấp.

Ví dụ thứ tư là để minh họa xử lý phủ định. Câu "May quá không ai bị thương": chữ "bị thương" nếu bắt máy móc thì sẽ nhầm là có người bị thương. Nhưng vì ngay trước nó có chữ "không", hệ thống hiểu là bị phủ định, nên bỏ qua, cho mức 1 và không gắn nhãn y tế. Nhờ vậy tránh được báo động giả.

Tóm lại, hai nhánh chạy độc lập rồi hợp nhất bằng cách lấy mức cao hơn; còn việc dò từ khóa thì theo biên từ và có xét phủ định trong phạm vi hai từ đứng trước.


==================================================
SLIDE 17 — CƠ CHẾ 3: ĐIỀU PHỐI CỨU TRỢ
==================================================

Cơ chế thứ ba là điều phối cứu trợ, tức là sau khi biết ai nguy cấp thì đưa người tới cứu.

Khi có một ca, hệ thống phát thông báo ngay lập tức tới tất cả tình nguyện viên đang rảnh và đã qua xác thực danh tính eKYC.

Điểm em tâm đắc nhất ở cơ chế này là việc tự động thu hồi. Nếu một tình nguyện viên đã nhận ca, nhưng mười phút sau khoảng cách tới nạn nhân vẫn gần như không giảm, tức là họ không thực sự di chuyển, thì hệ thống sẽ tự nhắn hỏi, và nếu cần thì thu hồi ca đó để phát lại cho người khác. Nghĩa là nhận ca thôi chưa đủ, hệ thống phải bảo đảm người đó thực sự đang tiến tới hiện trường.

Ngoài ra, hệ thống phát cảnh báo khi tình nguyện viên còn cách nạn nhân 300 mét và 100 mét, để hai bên chuẩn bị gặp nhau. Và có một tác vụ chạy nền quét định kỳ để phát hiện những ca bị bỏ ngỏ quá lâu chưa ai nhận, rồi cảnh báo cho quản trị viên.


==================================================
(SLIDE CHUYỂN PHẦN 04) — DEMO THỰC TẾ
==================================================

Phần lý thuyết em xin dừng ở đây. Bây giờ em xin phép demo sản phẩm chạy thực tế.


==================================================
SLIDE DEMO — DEMO TRỰC TIẾP
==================================================

(Mở ứng dụng đã chuẩn bị sẵn. Gửi một câu SOS bằng phương ngữ, ví dụ "Nhoà tui ngập tới mớ nhoà rồi".)

Bây giờ em gửi một tin cầu cứu bằng đúng giọng địa phương. Thầy cô có thể thấy câu vừa nhập được chuẩn hóa về tiếng phổ thông, rồi được chấm mức khẩn cấp và gắn nhãn tự động. Ca này lập tức hiện lên bản đồ ở phía tình nguyện viên và phía quản trị.

(Nếu các chức năng có hẹn giờ như thu hồi hay cảnh báo mốc khoảng cách không tiện demo trực tiếp, nói: Riêng chức năng tự thu hồi diễn ra sau mười phút nên em xin phép chiếu một đoạn video em đã quay lại và tua nhanh.)


==================================================
(SLIDE CHUYỂN PHẦN 05) — HẠN CHẾ, HƯỚNG PHÁT TRIỂN VÀ KẾT LUẬN
==================================================

Sau phần demo, em xin nói thẳng thắn về những hạn chế còn tồn tại, hướng phát triển, và kết luận.


==================================================
SLIDE 18 — HẠN CHẾ CỦA HỆ THỐNG
==================================================

Hệ thống của em vẫn còn một số hạn chế.

Thứ nhất, về hạ tầng: dù đã cố gắng cho nhiều thứ chạy offline, hệ thống vẫn phụ thuộc vào sóng 4G hoặc Wifi và vào nguồn pin — hai thứ vốn rất khan hiếm trong bão lũ.

Thứ hai, nhánh AI hiểu ngữ cảnh vẫn phải phụ thuộc vào dịch vụ Gemini bên ngoài.

Thứ ba, tập luật biến âm là do em tự soạn nên chưa thể phủ hết 100% các biến thể và tiếng lóng của từng địa phương.

Và thứ tư, em cũng xin thành thật: em chưa kiểm chứng được là nếu bỏ hẳn bộ chuẩn hóa đi thì bản thân Gemini tự hiểu phương ngữ tới mức nào. Đây là điều em sẽ cần đánh giá kỹ hơn.


==================================================
SLIDE 19 — HƯỚNG PHÁT TRIỂN TƯƠNG LAI
==================================================

Từ những hạn chế đó, em có mấy hướng phát triển.

Một là bổ sung kênh dự phòng: cho phép gửi tin cầu cứu qua tin nhắn SMS truyền thống khi mất hẳn mạng Internet.

Hai là xử lý đa phương thức: cho phép nạn nhân gửi kèm ảnh hoặc video, rồi dùng thị giác máy tính để ước tính độ sâu ngập nước một cách tự động.

Ba là mở rộng nền tảng sang iOS và web, hiển thị bản đồ ngập lụt theo thời gian thực.

Và bốn là phân tích dữ liệu sau thiên tai: từ lịch sử các ca cứu hộ, xây dựng bản đồ nhiệt để hỗ trợ chính quyền trong việc quy hoạch và phòng chống về sau.


==================================================
SLIDE 20 — KẾT LUẬN
==================================================

Để kết luận, em xin tóm lại như sau.

Em đã xây dựng được nền tảng FloodAid tương đối hoàn chỉnh, gồm ba thành phần chạy được thực tế: app cho nạn nhân, app cho tình nguyện viên, và web quản trị; và đã đạt được các mục tiêu đề ra ban đầu.

Xuyên suốt hệ thống là ba cơ chế lõi, mỗi cơ chế giải quyết một đặc thù riêng của bài toán. Chuẩn hóa phương ngữ giúp hệ thống hiểu đúng tiếng nói của người dân vùng lũ. Phân loại lai có sàn an toàn giúp ưu tiên đúng ca nguy cấp và không bỏ sót khi mạng chập chờn. Và điều phối tự giám sát, tự thu hồi giúp bảo đảm tình nguyện viên thực sự tiếp cận được nạn nhân.

Nói ngắn gọn, đề tài đã số hóa và tự động hóa được toàn bộ chuỗi từ tiếp nhận, chuẩn hóa, phân loại, cho tới điều phối.


==================================================
SLIDE 21 — CẢM ƠN
==================================================

Phần trình bày của em tới đây là hết. Em xin trân trọng cảm ơn quý thầy cô trong hội đồng đã lắng nghe. Em rất mong nhận được nhận xét và các câu hỏi từ thầy cô ạ.
