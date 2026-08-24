# CHƯƠNG 4: HIỆN THỰC CÁC CƠ CHẾ CỐT LÕI CỦA HỆ THỐNG

Chương này trình bày cách hiện thực ba cơ chế cốt lõi: chuẩn hóa phương ngữ, phân loại mức độ khẩn cấp và điều phối cứu trợ, kèm cơ sở của từng quyết định thiết kế. Các đoạn mã trích từ mã nguồn thực tế, lược phần ghi nhật ký.

## 4.1. Phân loại ca SOS từ ngôn ngữ tự nhiên

### 4.1.1. Điểm tiếp nhận: bộ điều khiển tạo ca

Ba bước phía máy chủ hội tụ tại `createSos`.

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

  const aiResult = await runUrgencyClassification(text);        // phân loại (mục 4.1.3)

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

Cơ sở dữ liệu lưu hai cột văn bản: `text_normalized` (đã chuẩn hóa, dùng để phân loại và hiển thị) và `text_original` (bản gốc, rỗng nếu gõ tay). Giữ cả hai để còn căn cứ đối chiếu khi chuẩn hóa sai và làm dữ liệu cải thiện từ điển về sau.

### 4.1.2. Xử lý ngôn ngữ địa phương: chuẩn hóa phương ngữ miền Trung

Mô hình nhận dạng giọng nói huấn luyện trên giọng chuẩn nên với giọng miền Trung chỉ phiên âm theo âm nghe được: "nhà" thành "nhoà", "già" thành "gioà", "làm" thành "lồm". Sai lệch này có tính quy luật nên mô hình hóa được thành luật biến âm rồi ánh xạ ngược về dạng chuẩn (cơ sở lý thuyết ở mục 2.2.3.2).

Phương ngữ có hai nhóm hiện tượng cần hai nguồn tri thức khác nhau: **biến âm** mô hình hóa được bằng luật (Bảng 4.1), và **lớp từ vựng riêng** không suy ra được nên phải liệt kê (Bảng 4.2).

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

Giải pháp phải giải hai vấn đề: xây từ điển đủ lớn và thay thế sao cho không sai nghĩa.

#### 4.1.2.1. Sinh từ điển bằng luật biến âm

Thay vì liệt kê tay, hệ thống sinh ngược dạng phương ngữ bằng cách áp luật ở Bảng 4.1 lên corpus tiếng Việt chuẩn Viet74K [12] (~74.000 mục từ). Từ điển sinh ra được đóng gói sẵn trong ứng dụng (`dialect_dict.json`) và nạp vào bộ nhớ khi chạy, nên chuẩn hóa hoạt động hoàn toàn cục bộ, không cần mạng (Hình 4.1).

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
*Sinh từ điển gốc từ corpus chuẩn bằng luật biến âm. Nguồn: `backend/src/generateDialectDict.js`*

Một mục chỉ giữ lại khi thỏa cả ba điều kiện: dạng sinh ra khác từ gốc, không nằm trong danh sách chặn, và không trùng một từ chuẩn đã có. Điều kiện cuối là quyết định: nếu dạng biến âm trùng từ chuẩn "hòa" thì mọi câu chứa "hòa" đều bị thay sai nghĩa. Quy trình cho ra từ điển hơn 26.000 mục.

*Hình 4.1 - Quy trình sinh từ điển chuẩn hóa từ luật biến âm và corpus Viet74K.*

#### 4.1.2.2. Thuật toán chuẩn hóa khi tạo yêu cầu SOS

Hàm chỉ đọc từ điển đã gộp trong bộ nhớ, không truy cập mạng. Duyệt văn bản trái sang phải, mỗi vị trí thử khớp **cụm ba từ, rồi hai từ, rồi từ đơn**.

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

Phải thử cụm dài trước vì "mớ nhoà" (nghĩa *mái nhà*) nếu xử lý từ đơn sẽ ra sai là "mớ nhà"; chỉ khớp ở mức cụm hai từ mới nhận diện đúng cả cụm. Hàm `_preserveCase` giữ quy tắc viết hoa; từ không có trong từ điển giữ nguyên nên bộ chuẩn hóa không làm hỏng văn bản.

### 4.1.3. Cơ chế phân loại mức độ khẩn cấp

Bài toán có ba yêu cầu xung đột: luôn phải có kết quả kể cả khi mất mạng, cần hiểu ngữ cảnh (chỉ mô hình ngôn ngữ lớn làm tốt nhưng chậm và phụ thuộc mạng), và không được bỏ sót ca nguy kịch. Giải pháp kết hợp hai nhánh: **dò từ khóa cục bộ** làm lớp bảo đảm tối thiểu, **mô hình ngôn ngữ lớn** làm lớp hiểu ngữ cảnh, hợp nhất theo nguyên tắc lấy mức cao hơn (Hình 4.2).

*Hình 4.2 - Cơ chế phân loại mức độ khẩn cấp: nhánh dò từ khóa, nhánh mô hình ngôn ngữ lớn và quy tắc hợp nhất.*

#### 4.1.3.1. Nhánh dò từ khóa

Nhánh này dùng hai bảng tra (Bảng 4.3, Bảng 4.4), chạy đồng bộ, không bao giờ ném lỗi.

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

Dò từ khóa không thể dựa vào kiểm tra chuỗi con, vì tiếng Việt có từ chứa nhau ở mức ký tự ("không" chứa "ông", "bàn" chứa "bà"). `hasKeyword` do đó so khớp theo biên từ, và bỏ qua từ khóa nếu ngay trước nó (trong cùng mệnh đề, cửa sổ hai từ) có từ phủ định — để câu "May quá không ai bị thương" không bị gán mức 4.

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

Ba lựa chọn đều xuất phát từ đặc thù cứu hộ: dùng dấu câu làm ranh giới mệnh đề để phủ định vế trước không lan sang vế sau; giới hạn cửa sổ phủ định hẹp ở hai từ vì chặn nhầm một từ khóa thật (âm tính giả) nguy hiểm hơn báo động giả; và không xét phủ định cho những từ khóa tự nó mở đầu bằng từ phủ định như "không thở", nếu không nó sẽ tự vô hiệu hóa. Một số cụm cố định chứa từ khóa nhưng vô nghĩa cứu hộ ("kẹt xe", "chết máy") được xóa trước khi dò.

#### 4.1.3.2. Nhánh mô hình ngôn ngữ lớn

Nhánh này gọi Gemini 2.5 Flash. Câu nhắc theo hướng học ít mẫu (few-shot): định nghĩa thang mức 1-5, tập nhãn hợp lệ và hai ví dụ mẫu. Cấu hình `responseMimeType: application/json` để ép JSON và `temperature = 0,1` để giảm ngẫu nhiên.

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

Kết quả được kiểm tra lược đồ (đủ ba trường) và ép mức khẩn cấp về `[1,5]`; mọi sai lệch định dạng làm nhánh thất bại có kiểm soát. Lời gọi bị chặn bởi một giới hạn thời gian chờ cứng:

```javascript
const timeoutPromise = new Promise((_, reject) =>
  setTimeout(() => reject(new Error('GEMINI_TIMEOUT')), GEMINI_TIMEOUT_MS));  // mặc định 3 giây
return Promise.race([geminiPromise, timeoutPromise]);   // mô hình trả lời, hoặc hết giờ
```
*Giới hạn thời gian chờ mô hình ngôn ngữ. Nguồn: `backend/src/services/aiPipeline.js`*

Tham số quyết định tính khả dụng là `thinkingConfig`. Gemini 2.5 Flash mặc định bật suy luận nội tại (tự tạo chuỗi lập luận trung gian trước khi trả lời), hữu ích cho bài toán suy luận nhiều bước nhưng vô ích với việc gán một nhãn cho câu ngắn, mà lại chiếm phần lớn thời gian sinh. Vì vậy đặt `thinkingBudget: 0`.

```javascript
generationConfig: {
  responseMimeType: 'application/json',   // ép đầu ra JSON có cấu trúc
  temperature: 0.1,                       // giảm tính ngẫu nhiên, cần cho bài toán phân loại
  thinkingConfig: { thinkingBudget: 0 },  // tắt suy luận nội tại
}
```
*Cấu hình sinh của mô hình ngôn ngữ. Nguồn: `backend/src/services/aiPipeline.js`*

#### 4.1.3.3. Quy tắc hợp nhất và sàn an toàn

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

Hai nhánh không chạy đua: nhánh dò từ khóa chạy đồng bộ cho kết quả ngay, sau đó mới `await` nhánh mô hình (`Promise.race` chỉ nằm bên trong nhánh mô hình để giới hạn thời gian chờ). Nhánh dò từ khóa không rút ngắn thời gian phản hồi; giá trị của nó là bảo đảm hệ thống luôn có kết quả khi mô hình chậm, lỗi hoặc mất kết nối.

Phép `Math.max` là **sàn an toàn**: mức cuối không bao giờ thấp hơn mức từ khóa cảnh báo (văn bản chứa "đuối nước" là mức 5, dù mô hình đánh giá mức 2 thì kết quả vẫn là 5). Đây là đánh đổi có chủ đích: trong cứu hộ, bỏ sót ca nguy kịch gây hậu quả không đảo ngược còn báo động giả chỉ tốn công, nên hệ thống nghiêng hẳn về phía an toàn. Trường `ai_source` ghi nguồn kết quả cuối (`gemini` hoặc `rule_based`).

### 4.1.4. Minh họa tác động của chuẩn hóa lên kết quả phân loại

Bảng 4.5 theo dõi sáu câu mang đặc trưng phương ngữ qua bước chuẩn hóa và kết quả phân loại của nhánh dò từ khóa, có và không có chuẩn hóa.

*Bảng 4.5 - Kết quả chuẩn hóa phương ngữ và tác động lên phân loại (nhánh dò từ khóa)*

| # | Văn bản do nhận dạng giọng nói sinh ra | Sau chuẩn hóa | Phân loại nếu không chuẩn hóa | Phân loại có chuẩn hóa |
|---|---|---|---|---|
| 1 | Nhoà tui ngập tới mớ nhoà rồi | Nhà tui ngập tới mái nhà rồi | Chỉ khớp "ngập", mức 2, không nhãn | Khớp "mái nhà", mức 4; nhãn `ngap_noc` |
| 2 | Có người gioà kẹt trong nhoà, nước lên nhanh | Có người già kẹt trong nhà, nước lên nhanh | Chỉ khớp "kẹt", mức 3, không nhãn | Khớp "người già", mức 4; nhãn `nguoi_gia` |
| 3 | Mấy đứa nhỏ đang ở trên mớ nhoà, nước dâng tới nơi rồi | Mấy đứa nhỏ đang ở trên mái nhà, nước dâng tới nơi rồi | Chỉ khớp "nước dâng", mức 3 | Khớp "mái nhà", mức 4 |
| 4 | Boà tui nỏ đi được, nước ngập dô tới ngực | Bà tôi không đi được, nước ngập vô tới ngực | Chỉ khớp "ngập", mức 2, không nhãn | Mức 2; khớp "bà", nhãn `nguoi_gia` |
| 5 | May quá nỏ ai bị thương, mà nhoà thì ngập tới mớ nhoà rồi | May quá không ai bị thương, mà nhà thì ngập tới mái nhà rồi | Khớp "bị thương", mức 4; nhãn `y_te` (sai) | "bị thương" bị vô hiệu bởi "không"; khớp "mái nhà", mức 4; nhãn `ngap_noc` (đúng) |
| 6 | Chu cha, nước lên răng mà nhanh rứa | Ôi trời, nước lên sao mà nhanh thế | Khớp "nước lên", mức 2 | Mức 2 (không đổi) |

Bảng cho thấy ba kiểu tác động: **đổi mức khẩn cấp** (câu 1–3, các từ khóa quyết định như "mái nhà", "người già" chỉ xuất hiện sau khi ánh xạ về dạng chuẩn), **đổi nhãn** (câu 4–5), và **không đổi** (câu 6, chỉ giúp câu dễ hiểu hơn). Câu 5 đáng chú ý: từ phủ định phương ngữ "nỏ" không có trong danh sách phủ định, nên khi chưa chuẩn hóa hệ thống gán sai nhãn `y_te`; chỉ sau khi "nỏ" thành "không" thì cơ chế phủ định mới hoạt động. Bộ chuẩn hóa vì vậy còn là tiền đề để các cơ chế phía sau vận hành đúng.

Đây là khảo sát định tính trên tập câu tự xây dựng và chỉ đo tác động lên nhánh dò từ khóa (nhánh so khớp theo mặt chữ nên tất yếu thất bại với phương ngữ). Giá trị đã xác lập hẹp nhưng chắc: bảo đảm nhánh dò từ khóa — lớp duy nhất còn hoạt động khi mất mạng — không đánh giá sai mức khẩn cấp với người nói phương ngữ (bàn thêm ở mục 5.2).

## 4.2. Điều phối cứu trợ

Phần điều phối gồm một chiến lược phát sóng và cơ chế theo sát tiếp cận, tự phục hồi phân công.

### 4.2.1. Chiến lược phát sóng hai giai đoạn

Giai đoạn đầu: ngay khi ca được tạo, hệ thống gửi thông báo tới mọi tình nguyện viên đang rảnh, đã duyệt và đang bật nhận thông báo, **không lọc theo bán kính**. Trong thiên tai, lực lượng khan hiếm và phân tán nên lọc hẹp theo khoảng cách có nguy cơ khiến ca không tiếp cận được ai; yếu tố khoảng cách chỉ được dùng khi tình nguyện viên chủ động lọc danh sách ca theo bán kính. Hạn chế bàn thêm ở mục 5.2.

Giai đoạn sau: phát hiện "ca mồ côi" (ca không ai tiếp nhận). Thiết kế ban đầu dùng `setTimeout` trong bộ nhớ tiến trình, chứa lỗi độ tin cậy nghiêm trọng: nếu máy chủ khởi động lại trong khoảng chờ (thường xuyên trên hạ tầng miễn phí), bộ hẹn giờ bị hủy và ca không bao giờ được cảnh báo. Nguyên tắc sửa: **mọi trạng thái cần bền vững phải nằm trong cơ sở dữ liệu**, chuyển sang tác vụ nền quét định kỳ.

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

Mốc thời gian suy từ `created_at` đã lưu nên cảnh báo vẫn đúng hạn kể cả khi máy chủ khởi động lại nhiều lần. Cột `orphan_alerted_at` là cờ chống lặp; nhờ đánh dấu và lấy danh sách nằm trong cùng câu `UPDATE ... RETURNING` nguyên tử, mỗi ca chỉ cảnh báo đúng một lần. Tác vụ không đổi trạng thái sang `orphaned` mà giữ `pending` (ca vẫn phải hiển thị để tiếp nhận); "mồ côi" là sự kiện cảnh báo, không phải trạng thái vòng đời.

### 4.2.2. Theo sát tiếp cận và tự phục hồi phân công

Nhận ca chưa bảo đảm nạn nhân được tiếp cận (người nhận có thể không di chuyển), nên hệ thống phải tự phát hiện bế tắc và điều phối lại. Mỗi lần tình nguyện viên gửi vị trí, hệ thống tính khoảng cách và phát các mốc tiếp cận:

```javascript
if (distM < 300 && !row.notif_sent_300m) { /* báo TNV "sắp tới nơi", đặt cờ */ }
if (distM < 100 && !row.notif_sent_100m) {  // báo cả hai bên và chuyển trạng thái
  await db.query(`UPDATE cases SET status='on_scene' WHERE id=$1 AND status='responding'`, [caseId]);
}
```
*Chuyển trạng thái theo mốc 300 m và 100 m, kèm cờ chống gửi trùng. Nguồn: `backend/src/jobs/distanceTracker.js`*

Hai cờ `notif_sent_300m`/`notif_sent_100m` bảo đảm mỗi mốc chỉ báo một lần. Việc tính khoảng cách đặt ở máy chủ (thay vì geofencing của Android) để logic nhất quán và giảm tải cho thiết bị. Một tác vụ nền phát hiện tình nguyện viên không tiến về nạn nhân và điều phối lại:

```sql
-- Điều kiện: nhận ca hơn 10 phút mà khoảng cách hiện tại vẫn từ 90% khoảng cách ban đầu trở lên
WHERE c.status='responding'
  AND ca.assigned_at < NOW() - INTERVAL '10 minutes'
  AND ST_Distance(vol.current_coords::geography, c.coords::geography) >= ca.initial_distance_m * 0.9;
-- Sau đó: hỏi xác nhận; nếu 5 phút im lặng thì thu hồi phân công, mở lại ca và phát sóng lại
```
*Quy tắc tự thu hồi và điều phối lại. Nguồn: `backend/src/jobs/staleAssignmentChecker.js`*

Điều kiện `khoảng_cách_hiện_tại ≥ 0,9 × khoảng_cách_ban_đầu` là định nghĩa định lượng của "không tiến lại gần", biên 10% để dung sai nhiễu GPS. Quy trình thu hồi có bước hỏi lại trước, chỉ thu hồi khi tiếp tục im lặng thêm 5 phút. Một tác vụ tương tự cảnh báo ca `on_scene` quá 60 phút mà tình nguyện viên đã rời khu vực, nhưng chỉ cảnh báo chứ không tự đóng ca — quyết định kết thúc ca giữ lại cho con người. Cả hai cơ chế dùng khoảng cách đường chim bay chứ không phải quãng đường thực (hạn chế bàn ở mục 5.2, 5.3).

*Hình 4.3 - Vòng đời điều phối một ca, từ lúc phát sóng đến khi hoàn tất hoặc bị thu hồi.*
