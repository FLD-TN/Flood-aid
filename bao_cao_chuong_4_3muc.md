# CHƯƠNG 4. HIỆN THỰC CÁC CƠ CHẾ CỐT LÕI CỦA HỆ THỐNG

Chương này trình bày cách hiện thực ba cơ chế cốt lõi của hệ thống là chuẩn hóa phương ngữ, phân loại mức độ khẩn cấp và điều phối cứu trợ, kèm cơ sở của từng quyết định thiết kế. Các đoạn mã được trích từ mã nguồn thực tế, lược bớt phần ghi nhật ký để tập trung vào logic.

## 4.1. Chuẩn hóa phương ngữ miền Trung

Mô hình nhận dạng giọng nói được huấn luyện chủ yếu trên giọng chuẩn. Khi gặp giọng miền Trung, mô hình không "hiểu" người nói mà chỉ phiên âm theo âm nghe được: người dân nói "nhà" với âm địa phương thì mô hình ghi ra chữ "nhoà", nói "già" thì ra "gioà", nói "làm" thì ra "lồm".

Sai lệch này có tính quy luật, nên có thể mô hình hóa thành một tập luật biến âm rồi ánh xạ ngược về dạng chuẩn; cơ sở lý thuyết đã nêu ở mục 2.2.3.2, phần này trình bày cách hiện thực. Phương ngữ gồm hai nhóm hiện tượng cần hai nguồn tri thức khác nhau: nhóm biến âm mô hình hóa được bằng luật (Bảng 4.1), và lớp từ vựng riêng thì không suy ra được bằng luật nên phải liệt kê (Bảng 4.2).

*Bảng 4.1 - Tập luật biến âm được mô hình hóa (trích)*

| Hiện tượng biến âm | Luật (chuẩn sang phương ngữ) | Ví dụ |
|---|---|---|
| Vần "am" chuyển thành "ôm" | `àm→ồm`, `ám→ốm`, `ạm→ộm`, `am→ôm` | làm thành lồm |
| Nguyên âm "a" chuyển thành "oa" | `à→oà`, `á→oá`, `ạ→oạ` | nhà thành nhoà; già thành gioà |
| Vần "ăn" chuyển thành "en" | `ăn→en`, `ắn→én`, `ặn→ẹn`, `ặng→ẹng` | chặn thành chẹn |
| Phụ âm đầu "v" chuyển thành "d" | `^v→d` | vô thành dô |

*Bảng 4.2 - Trích lớp từ vựng phương ngữ (không suy ra được bằng luật)*

| Phương ngữ | Nghĩa chuẩn | Phương ngữ | Nghĩa chuẩn |
|---|---|---|---|
| răng | sao | ni | này |
| rứa | thế | nớ | đó |
| mô | đâu | chừ | giờ |
| tê | kia | chu cha | ôi trời |
| tau | tao | mớ nhoà | mái nhà |
| mi | mày | con gớ | con gái |

Từ đó, giải pháp phải giải quyết hai vấn đề: xây từ điển ánh xạ đủ lớn và thay thế mà không sai nghĩa. Hai mục sau lần lượt trình bày từng vấn đề.

### 4.1.1. Sinh từ điển bằng luật biến âm

Thay vì liệt kê thủ công từng cặp từ, hệ thống sinh ngược dạng phương ngữ bằng cách áp các luật ở Bảng 4.1 lên một corpus tiếng Việt chuẩn. Corpus được sử dụng là Viet74K [12], gồm khoảng 74.000 mục từ vựng tiếng Việt phổ thông. Từ điển sinh ra được đóng gói sẵn trong ứng dụng (tệp `dialect_dict.json`) và nạp vào bộ nhớ khi chạy, nên chuẩn hóa hoạt động hoàn toàn cục bộ, không cần mạng (Hình 4.1).

```javascript
const hardcodedDict = { "răng":"sao", "rứa":"thế", "mô":"đâu", "tê":"kia", "ni":"này", "chừ":"giờ" };
const phoneticRules = [
  { regex: /am/g, replace: 'ôm' }, { regex: /à/g, replace: 'oà' },
  { regex: /ăn/g, replace: 'en' }, { regex: /^v/g, replace: 'd' },
];
const blacklist = new Set(["oà","hòa","dạ","men","kén"]);  // chặn dạng trùng từ chuẩn nghĩa khác

const dict = { ...hardcodedDict };
for (const word of standardVocab) {                        // standardVocab = Viet74K (~74.000 từ)
  const dialectWord = word.split(' ').map(applyRules).join(' ');   // "làm" thành "lồm"
  if (dialectWord !== word && !blacklist.has(dialectWord) && !standardVocab.has(dialectWord))
    dict[dialectWord] = word;                              // giữ mục: "lồm" ứng với "làm"
}
```
*Sinh từ điển từ corpus chuẩn bằng luật biến âm. Nguồn: `backend/src/generateDialectDict.js`*

Một mục chỉ được giữ khi thỏa cả ba điều kiện: dạng sinh ra khác từ gốc (trùng thì luật vô ích), không nằm trong danh sách chặn, và không trùng từ chuẩn đã có. Điều kiện cuối quan trọng nhất: nếu một dạng biến âm trùng từ chuẩn "hoà" thì mọi câu phổ thông chứa "hoà" đều bị thay sai nghĩa. Quy trình sinh ra tệp từ điển hơn 26.000 mục.

*(Sơ đồ Hình 4.1 - sẽ được chèn)*

*Hình 4.1 - Quy trình sinh từ điển chuẩn hóa từ luật biến âm và corpus Viet74K.*

### 4.1.2. Thuật toán chuẩn hóa khi tạo yêu cầu SOS

Bước này chạy mỗi khi nạn nhân nhập mô tả. Hàm chỉ đọc từ điển đã nạp sẵn trong bộ nhớ, không truy cập mạng. Thuật toán duyệt văn bản từ trái sang phải; tại mỗi vị trí, nó thử khớp cụm ba từ, rồi cụm hai từ, rồi từ đơn, khớp ở mức nào thì thay và nhảy qua đúng số từ đó.

```dart
static String normalize(String text) {
  final words = text.split(' ');
  final result = <String>[];
  int i = 0;

  while (i < words.length) {
    bool matched = false;

    // (1) Thử khớp cụm 3 từ trước, ví dụ "chu cha ơi"
    if (i + 2 < words.length) {
      final trigram = '${words[i]} ${words[i+1]} ${words[i+2]}'.toLowerCase();
      if (_dict.containsKey(trigram)) {
        result.add(_preserveCase(words[i], _dict[trigram]!));
        i += 3; matched = true;
      }
    }
    // (2) Không khớp thì thử cụm 2 từ, ví dụ "mớ nhoà"
    if (!matched && i + 1 < words.length) {
      final bigram = '${words[i]} ${words[i+1]}'.toLowerCase();
      if (_dict.containsKey(bigram)) {
        result.add(_preserveCase(words[i], _dict[bigram]!));
        i += 2; matched = true;
      }
    }
    // (3) Vẫn không khớp thì thử từ đơn; nếu vẫn không có thì giữ nguyên
    if (!matched) {
      final lower = words[i].toLowerCase();
      result.add(_dict.containsKey(lower)
          ? _preserveCase(words[i], _dict[lower]!)
          : words[i]);
      i++;
    }
  }
  return result.join(' ');
}
```
*Thuật toán khớp tham lam theo cụm dài nhất. Nguồn: `mobile/lib/services/dialect_normalizer.dart`*

Thứ tự thử cụm dài trước có lý do. Xét cụm "mớ nhoà" (nghĩa: mái nhà): nếu xử lý từ đơn trước, "mớ" không có trong từ điển nên giữ nguyên, còn "nhoà" bị thay thành "nhà", cho kết quả sai "mớ nhà". Chỉ khi khớp ở mức cụm hai từ, thuật toán mới nhận "mớ nhoà" là một mục nguyên khối và cho ra "mái nhà"; "chu cha" (ôi trời) cũng vậy. Vì thế phải thử theo thứ tự ba từ, hai từ, một từ thì các cụm mang nghĩa riêng mới được nhận diện trọn vẹn.

Hàm phụ `_preserveCase` giữ quy tắc viết hoa của từ gốc ("LỒM" thành "LÀM"). Từ không có trong từ điển được giữ nguyên, bảo đảm bộ chuẩn hóa không làm hỏng văn bản.

## 4.2. Phân loại mức độ khẩn cấp

Việc phân loại có ba yêu cầu xung đột nhau: phải luôn có kết quả kể cả khi mất mạng hoặc dịch vụ AI gặp sự cố, cần hiểu được ngữ cảnh (điều mà chỉ mô hình ngôn ngữ lớn làm tốt, nhưng mô hình này chậm và phụ thuộc mạng), và không được bỏ sót ca nguy kịch. Giải pháp là kết hợp hai nhánh: một nhánh dò từ khóa cục bộ giữ vai trò lớp bảo đảm tối thiểu, một nhánh mô hình ngôn ngữ lớn giữ vai trò lớp hiểu ngữ cảnh, hợp nhất theo nguyên tắc lấy mức khẩn cấp cao hơn (Hình 4.2).

*(Sơ đồ Hình 4.2 - sẽ được chèn)*

*Hình 4.2 - Cơ chế phân loại mức độ khẩn cấp: nhánh dò từ khóa, nhánh mô hình ngôn ngữ lớn và quy tắc hợp nhất.*

### 4.2.1. Điểm tiếp nhận: bộ điều khiển tạo ca

Yêu cầu SOS sau khi được chuẩn hóa ở thiết bị (mục 4.1) được gửi lên máy chủ và hội tụ tại bộ điều khiển `createSos`.

```javascript
async function createSos(req, res) {
  const { text, textOriginal, lat, lon } = req.body;        // text: đã chuẩn hóa; textOriginal: bản gốc
  const phoneHash = hashPhone(req.user.phone_number);       // băm HMAC-SHA256

  // Chống trùng: mỗi số điện thoại chỉ 1 ca chưa kết thúc
  const existing = await db.query(
    `SELECT id FROM cases WHERE phone_hash=$1 AND status NOT IN ('resolved','cancelled') LIMIT 1`,
    [phoneHash]);
  if (existing.rows.length > 0)
    return res.status(409).json({ error: 'ACTIVE_CASE_EXISTS', caseId: existing.rows[0].id });

  const aiResult = await runUrgencyClassification(text);        // phân loại (mục 4.2.4)

  const insert = await db.query(                             // lưu ca vào PostGIS
    `INSERT INTO cases (phone_hash, coords, text_normalized, text_original,
                        urgency_level, tags, summary_1line, status, ai_source)
     VALUES ($1, ST_SetSRID(ST_MakePoint($2,$3),4326), $4, $5, $6, $7::jsonb, $8, 'pending', $9)
     RETURNING id`,
    [phoneHash, lon, lat, text, textOriginal || null, aiResult.urgency_level,
     JSON.stringify(aiResult.tags), aiResult.summary_1line, aiResult.source]);

  setImmediate(() => dispatchToNearbyVolunteers(insert.rows[0].id)); // điều phối bất đồng bộ
  res.status(201).json({ caseId: insert.rows[0].id, urgencyLevel: aiResult.urgency_level,
                         tags: aiResult.tags, summary: aiResult.summary_1line });
}
```
*`createSos`: chống trùng, phân loại, lưu và kích hoạt điều phối. Nguồn: `backend/src/controllers/sosController.js`*

Do bước chuẩn hóa phương ngữ chạy ở phía thiết bị trước khi gửi, nếu chỉ lưu một cột văn bản thì hệ thống sẽ mất bản gốc: khi bộ chuẩn hóa thay thế sai, không còn căn cứ để đối chiếu, và cũng không thu thập được dữ liệu để cải thiện từ điển. Vì vậy ứng dụng gửi kèm cả hai phiên bản và cơ sở dữ liệu lưu vào hai cột riêng:

- `text_normalized`: văn bản đã chuẩn hóa, được dùng để phân loại và hiển thị cho tình nguyện viên;
- `text_original`: văn bản gốc do nhận dạng giọng nói sinh ra, trước chuẩn hóa (rỗng nếu nạn nhân gõ tay).

Cặp `(text_original, text_normalized)` chính là dữ liệu để đánh giá và cải thiện bộ chuẩn hóa về sau, và là điều kiện cần cho thí nghiệm kiểm chứng đề xuất ở mục 5.3. Đây cũng là lý do cột được đặt tên `text_normalized` thay vì `text_raw` như thiết kế ban đầu, bởi tên cũ gây hiểu nhầm rằng nội dung là văn bản thô.

### 4.2.2. Nhánh dò từ khóa

Nhánh này dùng hai bảng tra, chạy đồng bộ và không bao giờ ném lỗi. Bảng 4.3 trình bày bảng từ khóa xác định mức khẩn cấp, Bảng 4.4 trình bày bảng từ khóa gán nhãn phân loại.

*Bảng 4.3 - Bảng từ khóa xác định mức độ khẩn cấp*

| Mức | Ý nghĩa | Từ khóa |
|---|---|---|
| 5 | Nguy hiểm tính mạng | máu, bất tỉnh, không thở, chết, chìm, đuối nước |
| 4 | Khẩn cấp cao | trẻ em, em bé, người già, ngập nóc, mái nhà, bị thương, gãy, cấp cứu |
| 3 | Khẩn cấp trung bình | ngập sâu, nước dâng, kẹt, không thoát được, mắc kẹt, cô lập |
| 2 | Khẩn cấp thấp | ngập, cần xuồng, cần giúp, nước lên, cần hỗ trợ |
| 1 | Mặc định | (không khớp từ khóa nào) |

*Bảng 4.4 - Bảng từ khóa gán nhãn phân loại*

| Nhãn | Ý nghĩa | Từ khóa |
|---|---|---|
| `y_te` | Cần hỗ trợ y tế | máu, bất tỉnh, chấn thương, bị thương, không thở, cấp cứu, gãy |
| `tre_em` | Có trẻ em | trẻ em, em bé, con nít, trẻ con, con nhỏ |
| `nguoi_gia` | Có người cao tuổi | người già, ông, bà, cụ, cao tuổi |
| `ngap_noc` | Ngập tới mái nhà | ngập nóc, nước đến nóc, ngập tới mái, nước ngập mái |
| `phuong_tien` | Cần phương tiện đường thủy | cần xuồng, cần thuyền, không có phương tiện, cần ghe |

```javascript
function runRuleBasedFallback(text) {
  const clauses = toClauses(text);        // tách mệnh đề theo dấu câu, hạ chữ thường
  let urgency = 1;
  for (const [level, words] of Object.entries(URGENCY_KEYWORDS))
    if (words.some(w => hasKeyword(clauses, w)))
      urgency = Math.max(urgency, Number(level));
  const tags = Object.entries(TAG_KEYWORDS)
    .filter(([, words]) => words.some(w => hasKeyword(clauses, w)))
    .map(([tag]) => tag);
  const summary = text.length > 80 ? text.slice(0, 77) + '...' : text;
  return { urgency_level: urgency, tags, summary_1line: summary, source: 'rule_based' };
}
```
*Nhánh dò từ khóa, lớp bảo đảm tối thiểu. Nguồn: `backend/src/services/aiPipeline.js`*

Việc dò từ khóa không thể chỉ dựa vào phép kiểm tra chuỗi con, vì tiếng Việt có nhiều từ chứa nhau ở mức ký tự: "không" chứa "ông", "bàn" chứa "bà". Nếu so khớp theo chuỗi con, mọi câu có chữ "không" đều bị gán nhãn người già. Hàm `hasKeyword` do đó so khớp theo biên từ: văn bản được tách thành mệnh đề rồi thành từ, và một từ khóa chỉ được tính khi trùng khớp trọn vẹn dãy từ.

Ngoài ra, sự có mặt của một từ khóa chưa chắc mang nghĩa khẩn cấp. Câu "May quá không ai bị thương" chứa từ khóa mức 4 nhưng nội dung lại thông báo tình trạng an toàn. Hàm vì vậy bỏ qua một từ khóa nếu ngay trước nó, trong cùng mệnh đề và trong cửa sổ hai từ, có từ phủ định:

```javascript
const NEGATION_WORDS = ['không','chưa','chẳng','chả','khỏi','đừng'];
const EXCLUSION_PHRASES = ['kẹt xe','chết máy'];   // từ khóa bên trong không mang nghĩa khẩn cấp

function hasKeyword(clauses, keyword) {
  const kw = keyword.split(' ');
  const kwStartsWithNegation = NEGATION_WORDS.includes(kw[0]);   // "không thở"

  for (const rawWords of clauses) {
    const words = maskExclusions(rawWords);                      // xóa "kẹt xe", "chết máy"
    for (let i = 0; i + kw.length <= words.length; i++) {
      if (!kw.every((w, k) => words[i + k] === w)) continue;     // khớp trọn dãy từ
      if (!kwStartsWithNegation) {
        const window = words.slice(Math.max(0, i - 2), i);       // hai từ ngay trước
        if (window.some(w => NEGATION_WORDS.includes(w))) continue;
      }
      return true;
    }
  }
  return false;
}
```
*So khớp theo biên từ, có xử lý phủ định. Nguồn: `backend/src/services/aiPipeline.js`*

Cả ba lựa chọn trong hàm đều bắt nguồn từ đặc thù bài toán cứu hộ. Dấu câu làm ranh giới mệnh đề để từ phủ định ở vế trước không lan sang vế sau: trong câu "nước không rút, nhà ngập nóc", từ khóa ngập nóc vẫn phải tính. Cửa sổ phủ định chỉ rộng hai từ, vì chặn nhầm một từ khóa thật (âm tính giả) nguy hiểm hơn nhiều so với báo động giả (dương tính giả), mà cửa sổ càng rộng càng dễ chặn nhầm. Riêng các từ khóa tự mở đầu bằng từ phủ định thì bỏ qua bước xét phủ định, nếu không cụm "không thở", vốn là dấu hiệu nguy kịch nhất, sẽ bị loại ngay cả khi xuất hiện.

Ngoài phủ định, một số cụm cố định chứa từ khóa nhưng hoàn toàn không mang nghĩa cứu hộ, chẳng hạn "kẹt xe" hay "xe chết máy". Các cụm này được xóa khỏi văn bản trước khi dò.

### 4.2.3. Nhánh mô hình ngôn ngữ lớn

Nhánh này gọi mô hình Gemini 2.5 Flash. Câu nhắc (prompt) được thiết kế theo hướng học ít mẫu (few-shot): ngoài phần định nghĩa thang mức 1-5 và tập nhãn hợp lệ, câu nhắc chứa hai ví dụ mẫu để định hướng đầu ra. Mô hình được cấu hình `responseMimeType: application/json` nhằm ép trả về JSON, và `temperature = 0,1` nhằm giảm tính ngẫu nhiên, phù hợp với bài toán phân loại vốn đòi hỏi cùng một đầu vào cho ra cùng một kết quả.

```
Bạn là hệ thống AI phân loại tin nhắn SOS trong thiên tai lũ lụt tại Việt Nam.
Phân tích yêu cầu cứu trợ sau: "{text}"

Trả về JSON: { "urgency_level": <1-5>,
               "tags": <mảng từ: y_te, tre_em, nguoi_gia, ngap_noc, phuong_tien>,
               "summary_1line": <tóm tắt tối đa 80 ký tự> }

Thang urgency:  1 = Ít khẩn cấp ... 5 = Cực kỳ nguy hiểm (đuối nước, bất tỉnh)

Ví dụ:
Input:  "Cứu tôi với, nước ngập tới nóc nhà, có 2 em nhỏ"
Output: {"urgency_level":4,"tags":["ngap_noc","tre_em"],"summary_1line":"Ngập nóc nhà, 2 trẻ em cần cứu hộ khẩn cấp"}
```
*Câu nhắc gửi tới mô hình ngôn ngữ lớn (trích rút gọn). Nguồn: `backend/src/services/aiPipeline.js`*

Kết quả trả về được kiểm tra lược đồ, tức phải có đủ ba trường, và ép mức khẩn cấp về khoảng hợp lệ `[1, 5]` trước khi sử dụng; mọi sai lệch định dạng đều được coi là lỗi và làm nhánh này thất bại một cách có kiểm soát. Lời gọi được bao bởi một giới hạn thời gian chờ cứng:

```javascript
const timeoutPromise = new Promise((_, reject) =>
  setTimeout(() => reject(new Error('GEMINI_TIMEOUT')), GEMINI_TIMEOUT_MS));  // mặc định 3 giây
return Promise.race([geminiPromise, timeoutPromise]);   // mô hình trả lời, hoặc hết giờ
```
*Giới hạn thời gian chờ mô hình ngôn ngữ. Nguồn: `backend/src/services/aiPipeline.js`*

Một tham số cấu hình ảnh hưởng lớn tới tính khả dụng của nhánh này là `thinkingConfig`. Mô hình Gemini 2.5 Flash mặc định bật chế độ suy luận nội tại (thinking): trước khi sinh câu trả lời, mô hình tự tạo một chuỗi lập luận trung gian không hiển thị cho người dùng. Chế độ này có giá trị với các bài toán suy luận nhiều bước, nhưng bài toán của đề tài là gán một nhãn mức 1-5 cho một câu ngắn, không thuộc loại đó: chuỗi lập luận trung gian không cải thiện chất lượng phân loại nhưng chiếm phần lớn thời gian sinh.

```javascript
generationConfig: {
  responseMimeType: 'application/json',   // ép đầu ra JSON có cấu trúc
  temperature: 0.1,                       // giảm tính ngẫu nhiên, cần cho bài toán phân loại
  thinkingConfig: { thinkingBudget: 0 },  // tắt suy luận nội tại
}
```
*Cấu hình sinh của mô hình ngôn ngữ. Nguồn: `backend/src/services/aiPipeline.js`*

Việc tắt chế độ suy luận nội tại giúp giảm đáng kể độ trễ sinh của mô hình, nhờ đó ngưỡng thời gian chờ mới có thể đặt ở mức 3 giây; nếu giữ chế độ mặc định, độ trễ tăng cao và phần lớn lời gọi sẽ không kịp trong ngưỡng này.

### 4.2.4. Quy tắc hợp nhất và sàn an toàn

Hàm điều phối hợp nhất kết quả hai nhánh:

```javascript
async function runUrgencyClassification(text) {
  const ruleResult = runRuleBasedFallback(text);          // đồng bộ, không bao giờ lỗi
  let aiResult = null;
  try { aiResult = await callGeminiWithTimeout(text); }   // chờ, có giới hạn thời gian
  catch { /* mô hình chậm hoặc lỗi: dùng kết quả dò từ khóa */ }

  const final = aiResult || ruleResult;
  final.urgency_level = Math.max(final.urgency_level, ruleResult.urgency_level); // sàn an toàn
  if (aiResult) final.tags = [...new Set([...final.tags, ...ruleResult.tags])];  // hợp nhãn
  return final;
}
```
*Hợp nhất kết quả hai nhánh, lấy mức khẩn cấp cao hơn. Nguồn: `backend/src/services/aiPipeline.js`*

Về luồng thực thi, hai nhánh không chạy đua với nhau. Nhánh dò từ khóa chạy đồng bộ và cho kết quả ngay, rồi chương trình mới chờ (`await`) nhánh mô hình ngôn ngữ; cấu trúc `Promise.race` chỉ nằm bên trong nhánh mô hình để giới hạn thời gian chờ. Do đó thời gian phản hồi của hệ thống bị chặn dưới bởi độ trễ của mô hình, tối đa bằng ngưỡng đã cấu hình, và nhánh dò từ khóa không rút ngắn được thời gian này. Vai trò của nó là bảo đảm hệ thống luôn có kết quả: khi mô hình chậm, lỗi, hoặc mất kết nối tới dịch vụ, hệ thống vẫn phân loại được và luồng tạo ca không bị nghẽn.

Phép `Math.max` đóng vai trò sàn an toàn: mức khẩn cấp cuối không bao giờ thấp hơn mức mà từ khóa cảnh báo phát hiện. Nếu văn bản chứa "đuối nước" (mức 5) nhưng mô hình đánh giá mức 2, kết quả cuối vẫn là 5. Đây là đánh đổi có chủ đích: trong cứu hộ, bỏ sót một ca nguy kịch để lại hậu quả không đảo ngược, còn một báo động giả chỉ tốn công, nên hệ thống được thiết kế nghiêng về phía an toàn, thà đánh giá cao hơn thực tế còn hơn để lọt dấu hiệu nguy hiểm. Trường `ai_source` ghi nguồn của kết quả cuối (`gemini` hoặc `rule_based`).

### 4.2.5. Minh họa tác động của chuẩn hóa lên kết quả phân loại

Bảng 4.5 theo dõi sáu câu cầu cứu mang đặc trưng phương ngữ: từ văn bản do nhận dạng giọng nói sinh ra, qua bước chuẩn hóa (mục 4.1), đến kết quả phân loại của nhánh dò từ khóa trong hai trường hợp có và không có bước chuẩn hóa, đối chiếu với bảng từ khóa ở Bảng 4.3 và Bảng 4.4.

*Bảng 4.5 - Kết quả chuẩn hóa phương ngữ và tác động lên phân loại (nhánh dò từ khóa)*

| STT | Văn bản do nhận dạng giọng nói sinh ra | Sau chuẩn hóa | Phân loại nếu không chuẩn hóa | Phân loại có chuẩn hóa |
|---|---|---|---|---|
| 1 | Nhoà tui ngập tới mớ nhoà rồi | Nhà tui ngập tới mái nhà rồi | Chỉ khớp "ngập", mức 2, không nhãn | Khớp "mái nhà", mức 4; khớp "ngập tới mái", nhãn `ngap_noc` |
| 2 | Có người gioà kẹt trong nhoà, nước lên nhanh | Có người già kẹt trong nhà, nước lên nhanh | Chỉ khớp "kẹt", mức 3, không nhãn | Khớp "người già", mức 4; nhãn `nguoi_gia` |
| 3 | Mấy đứa nhỏ đang ở trên mớ nhoà, nước dâng tới nơi rồi | Mấy đứa nhỏ đang ở trên mái nhà, nước dâng tới nơi rồi | Chỉ khớp "nước dâng", mức 3 | Khớp "mái nhà", mức 4 |
| 4 | Boà tui nỏ đi được, nước ngập dô tới ngực | Bà tôi không đi được, nước ngập vô tới ngực | Chỉ khớp "ngập", mức 2, không nhãn | Mức 2 (không đổi); khớp "bà", nhãn `nguoi_gia` |
| 5 | May quá nỏ ai bị thương, mà nhoà thì ngập tới mớ nhoà rồi | May quá không ai bị thương, mà nhà thì ngập tới mái nhà rồi | Khớp "bị thương", mức 4; nhãn `y_te` (sai, vì không ai bị thương) | Cụm "bị thương" bị vô hiệu bởi từ phủ định "không"; khớp "mái nhà", mức 4; nhãn `ngap_noc` (đúng) |
| 6 | Chu cha, nước lên răng mà nhanh rứa | Ôi trời, nước lên sao mà nhanh thế | Khớp "nước lên", mức 2 | Mức 2 (không đổi) |

Bảng phản ánh ba kiểu tác động của chuẩn hóa. Kiểu thứ nhất là đổi mức khẩn cấp, thấy ở câu 1 đến 3: các từ khóa quyết định như "mái nhà", "người già" chỉ xuất hiện sau khi dạng phương ngữ được ánh xạ về dạng chuẩn; nếu thiếu bước này, một ca có người già mắc kẹt hay nước đã ngập tới mái sẽ bị xếp thấp hơn thực tế và bị ưu tiên sau. Kiểu thứ hai là đổi nhãn phân loại, thấy ở câu 4 và câu 5. Kiểu thứ ba là không thay đổi gì, như câu 6: các từ "chu cha", "răng", "rứa" không trùng từ khóa nào nên chuẩn hóa chỉ khiến câu dễ hiểu hơn cho nhánh mô hình ngôn ngữ và cho tình nguyện viên đọc.

Câu 5 minh họa rõ nhất điều này. Từ phủ định phương ngữ "nỏ" không nằm trong danh sách từ phủ định ở mục 4.2.2, nên khi chưa chuẩn hóa, cụm "bị thương" vẫn được tính và hệ thống gán sai nhãn `y_te` cho một ca thực tế không có ai bị thương. Sau khi "nỏ" được ánh xạ thành "không", cơ chế phủ định mới nhận ra và loại bỏ nhãn sai. Như vậy chuẩn hóa không dừng ở việc bổ sung thông tin cho bước phân loại, mà còn là điều kiện để các cơ chế phía sau chạy đúng.

Minh họa trên có phạm vi giới hạn. Đây là một khảo sát định tính trên tập câu do người viết tự xây dựng, và chỉ đo tác động lên nhánh dò từ khóa, vốn so khớp theo mặt chữ nên chắc chắn thất bại với dạng phương ngữ. Việc nhánh mô hình ngôn ngữ lớn có thể tự hiểu phương ngữ mà không cần chuẩn hóa hay không thì chưa được kiểm chứng. Do đó kết quả khẳng định được ở đây tuy giới hạn nhưng đáng tin cậy: bộ chuẩn hóa bảo đảm nhánh dò từ khóa, lớp xử lý duy nhất còn chạy khi mất mạng, không đánh giá sai mức khẩn cấp đối với người nói phương ngữ (bàn thêm ở mục 5.2).

## 4.3. Điều phối cứu trợ

Sau khi ca được phân loại và lưu, hệ thống phải đưa ca đến người cứu và bảo đảm việc cứu hộ thực sự diễn ra. Phần điều phối gồm một chiến lược phát sóng và hai thuật toán quyết định.

### 4.3.1. Chiến lược phát sóng hai giai đoạn

Bài toán đặt ra là đưa ca đến tình nguyện viên nhanh và không bỏ sót, đồng thời không để một ca không có ai tiếp nhận, gọi tắt là "ca mồ côi", tồn tại vô thời hạn.

Ở giai đoạn đầu, ngay khi ca được tạo, hệ thống gửi thông báo tới mọi tình nguyện viên đang rảnh, đã được quản trị viên duyệt và đang bật nhận thông báo, mà không lọc theo bán kính. Trong cơ sở dữ liệu, cột `notification_radius_km` mang ba ngữ nghĩa: giá trị `NULL` nghĩa là tình nguyện viên bật nhận thông báo cho mọi ca, giá trị `0` nghĩa là tắt nhận thông báo, và một số dương nghĩa là chỉ nhận thông báo trong bán kính đó. Bước phát sóng hiện chỉ gửi cho nhóm có giá trị `NULL`.

Việc không lọc theo bán kính là một lựa chọn được cân nhắc: trong thiên tai, lực lượng cứu hộ khan hiếm và phân tán, nên việc lọc hẹp theo khoảng cách có nguy cơ khiến một ca không tiếp cận được bất kỳ ai. Đổi lại, cơ chế này đơn giản và không phải là một thuật toán tối ưu; yếu tố khoảng cách chỉ được đưa vào ở khâu tình nguyện viên chủ động tìm ca (mục 4.3.2). Hạn chế của lựa chọn này được bàn thêm ở mục 5.2.

Giai đoạn sau là phát hiện ca mồ côi. Thiết kế ban đầu đặt một bộ hẹn giờ (`setTimeout`) ngay sau bước phát sóng để kiểm tra lại sau 15 phút. Cách làm này chứa một lỗi độ tin cậy nghiêm trọng: bộ hẹn giờ nằm trong bộ nhớ tiến trình, nên nếu máy chủ khởi động lại trong khoảng chờ, điều xảy ra thường xuyên trên hạ tầng triển khai miễn phí, thì bộ hẹn giờ bị hủy cùng tiến trình và ca sẽ không bao giờ được cảnh báo, đúng vào tình huống mà cơ chế được thiết kế để phòng ngừa.

Hệ thống do đó được sửa theo nguyên tắc: mọi trạng thái cần bền vững phải nằm trong cơ sở dữ liệu, không nằm trong bộ nhớ tiến trình. Việc phát hiện ca mồ côi được chuyển sang một tác vụ nền quét định kỳ:

```javascript
// jobs/orphanCaseChecker.js: cron chạy mỗi 1 phút
// UPDATE ... RETURNING là một câu lệnh nguyên tử, vừa đánh dấu vừa lấy danh sách,
// nên mỗi ca chỉ được cảnh báo đúng một lần dù có nhiều tiến trình chạy song song.
const result = await db.query(
  `UPDATE cases
   SET orphan_alerted_at = NOW()
   WHERE status = 'pending'                                  -- vẫn chưa ai nhận
     AND orphan_alerted_at IS NULL                           -- chưa từng cảnh báo
     AND created_at < NOW() - ($1::bigint * INTERVAL '1 millisecond')
   RETURNING id, urgency_level`,
  [ORPHAN_ALERT_MS]);

for (const row of result.rows)
  emitCaseEvent(row.id, 'case:orphaned', { caseId: row.id, status: 'orphaned' });
```
*Phát hiện ca mồ côi bằng tác vụ nền quét cơ sở dữ liệu. Nguồn: `backend/src/jobs/orphanCaseChecker.js`*

Mốc thời gian được suy ra từ `created_at` đã lưu trong cơ sở dữ liệu, nên cảnh báo vẫn diễn ra đúng hạn kể cả khi máy chủ đã khởi động lại nhiều lần trong khoảng chờ. Cột `orphan_alerted_at` đóng vai trò cờ chống cảnh báo lặp: vì thao tác đánh dấu và thao tác lấy danh sách nằm trong cùng một câu lệnh `UPDATE ... RETURNING` nguyên tử, mỗi ca chỉ được cảnh báo đúng một lần ngay cả khi có nhiều tiến trình cùng quét.

Tác vụ này không đổi trạng thái ca sang `orphaned` mà giữ ở `pending`, vì ca vẫn phải hiển thị để tình nguyện viên tiếp nhận; cảnh báo ca mồ côi là để huy động quản trị viên can thiệp, không phải để đóng ca. "Mồ côi" ở đây là một sự kiện cảnh báo, không phải một trạng thái trong vòng đời ca.

### 4.3.2. Xếp hạng ca gần theo vị trí

Tình nguyện viên cần tự tìm ca phù hợp quanh vị trí của mình. Đây là nơi yếu tố không gian địa lý được sử dụng, thông qua truy vấn và xếp hạng đa tiêu chí trên PostGIS.

```sql
SELECT c.id, c.urgency_level, c.tags, c.summary_1line,
       ROUND(ST_Distance(c.coords::geography,
             ST_SetSRID(ST_MakePoint($1,$2),4326)::geography))::int AS distance_m
FROM cases c
WHERE c.status IN ('pending','responding','on_scene')
  AND ST_DWithin(c.coords::geography, ST_MakePoint($1,$2)::geography, $radius) -- lọc bán kính
  AND c.urgency_level = ANY($levels)          -- lọc mức khẩn cấp
  AND c.tags ?| $tagList                      -- lọc nhãn (JSONB)
ORDER BY (ST_Distance(...) / 500)::int ASC,   -- gom theo vành đai 500m
         c.urgency_level DESC,                -- trong vành đai: ca khẩn cấp hơn trước
         ST_Distance(...) ASC                 -- cùng mức: ca gần hơn trước
LIMIT 50;
```
*Truy vấn lọc không gian và xếp hạng danh sách ca gần. Nguồn: hàm `getNearbyCases`, `backend/src/controllers/sosController.js`*

Truy vấn dùng `ST_DWithin` để lọc theo bán kính, tận dụng chỉ mục không gian GiST đã tạo trên cột `coords`, và `ST_Distance` để tính khoảng cách thực, kết hợp với lọc theo mức khẩn cấp và theo nhãn.

Kết quả được xếp hạng bằng mệnh đề `ORDER BY (distance_m / 500) ASC, urgency_level DESC`: các ca được gom theo từng vành đai 500 m tính từ vị trí tình nguyện viên, và trong cùng một vành đai thì ca có mức khẩn cấp cao hơn đứng trước. Cách xếp hạng này cân bằng hai yếu tố xung đột nhau. Xếp thuần theo khoảng cách thì một ca ngập nhẹ cách 100 m luôn đứng trên ca có người đuối nước cách 500 m; xếp thuần theo mức khẩn cấp thì tình nguyện viên có thể bị đẩy tới ca nguy kịch ở rất xa trong khi có ca khác gần hơn nhiều. Chia vành đai coi mọi ca trong cùng khoảng cách di chuyển là tương đương, rồi mới để mức nguy kịch quyết định thứ tự.

### 4.3.3. Theo sát tiếp cận và tự phục hồi phân công

Việc một tình nguyện viên nhận ca chưa bảo đảm nạn nhân sẽ được tiếp cận, bởi người đó có thể nhận ca rồi không di chuyển. Hệ thống cần tự phát hiện tình huống bế tắc và điều phối lại.

Mỗi lần tình nguyện viên gửi vị trí, hệ thống tính khoảng cách tới nạn nhân và phát các mốc tiếp cận:

```javascript
if (distM < 300 && !row.notif_sent_300m) { /* báo TNV "sắp tới nơi", đặt cờ */ }
if (distM < 100 && !row.notif_sent_100m) {  // báo cả hai bên và chuyển trạng thái
  await db.query(`UPDATE cases SET status='on_scene' WHERE id=$1 AND status='responding'`, [caseId]);
}
```
*Chuyển trạng thái theo mốc khoảng cách 300 m và 100 m, kèm cờ chống gửi trùng. Nguồn: `backend/src/jobs/distanceTracker.js`*

Hai cờ `notif_sent_300m` và `notif_sent_100m` bảo đảm mỗi mốc chỉ phát thông báo đúng một lần, tránh việc tình nguyện viên bị làm phiền liên tục khi dao động quanh ngưỡng. Việc tính khoảng cách được đặt ở máy chủ thay vì dùng cơ chế hàng rào địa lý (geofencing) của Android, nhằm giữ logic nhất quán giữa hai phía và giảm gánh nặng xử lý cho thiết bị.

Một tác vụ nền phát hiện tình nguyện viên không tiến về phía nạn nhân và điều phối lại:

```sql
-- Điều kiện: nhận ca hơn 10 phút mà khoảng cách hiện tại vẫn từ 90% khoảng cách ban đầu trở lên
WHERE c.status='responding'
  AND ca.assigned_at < NOW() - INTERVAL '10 minutes'
  AND ST_Distance(vol.current_coords::geography, c.coords::geography) >= ca.initial_distance_m * 0.9;
-- Sau đó: hỏi xác nhận; nếu 5 phút im lặng thì thu hồi phân công, mở lại ca và phát sóng lại
```
*Quy tắc tự thu hồi và điều phối lại. Nguồn: `backend/src/jobs/staleAssignmentChecker.js`*

Điều kiện `khoảng_cách_hiện_tại ≥ 0,9 × khoảng_cách_ban_đầu` chính là cách định lượng trạng thái "không tiến lại gần", với biên 10% để dung sai nhiễu GPS. Quy trình thu hồi có bước hỏi lại: hệ thống gửi thông báo xác nhận trước, chỉ khi tình nguyện viên im lặng thêm 5 phút thì phân công mới bị thu hồi và ca được mở lại để phát sóng cho người khác.

Một tác vụ tương tự phát hiện ca ở trạng thái `on_scene` quá 60 phút mà tình nguyện viên đã rời khu vực. Tác vụ này chỉ cảnh báo quản trị viên xem xét chứ không tự đóng ca, để tránh đóng nhầm một ca còn đang diễn ra; quyết định kết thúc một ca vẫn do con người đưa ra.

Hình 4.3 tổng hợp toàn bộ vòng đời điều phối trình bày ở mục 4.3, từ lúc ca được phát sóng, qua các mốc tiếp cận, đến khi hoàn tất hoặc bị thu hồi và điều phối lại.

*(Sơ đồ Hình 4.3 - sẽ được chèn)*

*Hình 4.3 - Vòng đời điều phối một ca, từ lúc phát sóng đến khi hoàn tất hoặc bị thu hồi.*

Cả hai cơ chế trên đều dựa trên khoảng cách đường chim bay chứ không phải quãng đường di chuyển thực. Trong vùng lũ, một tình nguyện viên buộc phải đi vòng có thể bị đánh giá nhầm là bế tắc; hạn chế này và hướng khắc phục được bàn ở mục 5.2 và 5.3.
