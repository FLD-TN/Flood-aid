# CHƯƠNG 4: HIỆN THỰC CÁC CƠ CHẾ CỐT LÕI CỦA HỆ THỐNG

Chương này trình bày cách hiện thực ba cơ chế cốt lõi của hệ thống là chuẩn hóa phương ngữ, phân loại mức độ khẩn cấp và điều phối cứu trợ, kèm cơ sở của từng quyết định thiết kế và kết quả đo đạc. Các đoạn mã được trích từ mã nguồn thực tế, lược bớt phần ghi nhật ký để tập trung vào logic.

## 4.1. Tổng quan hiện thực

Một yêu cầu SOS đi qua sáu bước tuần tự (Hình 4.1), ba bước đầu ở phía thiết bị và ba bước sau ở phía máy chủ.

1. Nhận dạng giọng nói. Thư viện `speech_to_text` gọi bộ nhận dạng của hệ điều hành (ngôn ngữ `vi-VN`) để chuyển lời nói thành văn bản. Tệp âm thanh không rời khỏi thiết bị, máy chủ chỉ nhận văn bản. Nạn nhân cũng có thể gõ chữ thay vì nói.
2. Chuẩn hóa phương ngữ. Văn bản được tra từ điển để thay các từ địa phương miền Trung ("răng", "rứa", "mô") bằng từ phổ thông tương ứng ("sao", "thế", "đâu"), giúp bước phân loại phía sau hiểu đúng nội dung (mục 4.2.2).
3. Gửi yêu cầu. Ứng dụng gọi `POST /api/sos` kèm văn bản đã chuẩn hóa và tọa độ GPS.
4. Phân loại. Máy chủ xác định mức khẩn cấp (1-5), nhãn phân loại và dòng mô tả ngắn bằng cơ chế kết hợp một nhánh dò từ khóa với một nhánh mô hình ngôn ngữ lớn (mục 4.2.3).
5. Lưu ca vào cơ sở dữ liệu PostGIS.
6. Điều phối. Máy chủ phát thông báo tới tình nguyện viên và theo dõi cho đến khi có người tiếp cận nạn nhân (mục 4.3).

*Hình 4.1 - Quy trình xử lý một yêu cầu SOS, từ giọng nói đến khi được điều phối.*

## 4.2. Phân loại ca SOS từ ngôn ngữ tự nhiên

### 4.2.1. Điểm tiếp nhận: bộ điều khiển tạo ca

Ba bước phía máy chủ (4-6) hội tụ tại bộ điều khiển `createSos`.

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

  const aiResult = await runUrgencyClassification(text);        // phân loại (mục 4.2.3)

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

### 4.2.2. Xử lý ngôn ngữ địa phương: chuẩn hóa phương ngữ miền Trung

Mô hình nhận dạng giọng nói được huấn luyện chủ yếu trên giọng chuẩn. Khi gặp giọng miền Trung, mô hình không "hiểu" người nói mà chỉ phiên âm theo âm nghe được: người dân nói "nhà" với âm địa phương thì mô hình ghi ra chữ "nhoà", nói "già" thì ra "gioà", nói "làm" thì ra "lồm".

Sai lệch này không ngẫu nhiên mà có tính quy luật, nên có thể mô hình hóa thành một tập luật biến âm rồi ánh xạ ngược về dạng chuẩn — cơ sở lý thuyết của hướng tiếp cận này đã trình bày ở mục 2.2.3.2. Mục này trình bày cách hiện thực.

Phương ngữ có hai nhóm hiện tượng đòi hỏi hai nguồn tri thức khác nhau: **biến âm**, mô hình hóa được bằng luật (Bảng 4.1); và **lớp từ vựng riêng**, hoàn toàn không suy ra được bằng luật nên phải liệt kê (Bảng 4.2).

*Bảng 4.1 - Tập luật biến âm được mô hình hóa (trích)*

| Hiện tượng biến âm | Luật (chuẩn sang phương ngữ) | Ví dụ |
|---|---|---|
| Vần "am" chuyển thành "ôm" | `àm→ồm`, `ám→ốm`, `ạm→ộm`, `am→ôm` | làm → lồm |
| Nguyên âm "a" chuyển thành "oa" | `à→oà`, `á→oá`, `ạ→oạ` | nhà → nhoà; già → gioà |
| Vần "ăn" chuyển thành "en" | `ăn→en`, `ắn→én`, `ặn→ẹn`, `ặng→ẹng` | chặn → chẹn |
| Phụ âm đầu "v" chuyển thành "d" | `^v→d` | vô → dô |

*Bảng 4.2 - Trích lớp từ vựng phương ngữ (không suy ra được bằng luật)*

| Phương ngữ | Nghĩa chuẩn | Phương ngữ | Nghĩa chuẩn |
|---|---|---|---|
| răng | sao | ni | này |
| rứa | thế | nớ | đó |
| mô | đâu | chừ | giờ |
| tê | kia | chu cha | ôi trời |
| tau | tao | mớ nhoà | mái nhà |
| mi | mày | con gớ | con gái |

Trên cơ sở đó, giải pháp phải xử lý ba vấn đề con: xây từ điển ánh xạ đủ lớn, cập nhật được từ điển khi phát hiện từ mới giữa mùa lũ, và thay thế sao cho không sai nghĩa. Ba mục tiếp theo trình bày cách giải quyết từng vấn đề.

#### 4.2.2.1. Kiến trúc từ điển hai lớp

Từ điển được tổ chức thành hai lớp, gộp lại trong bộ nhớ khi ứng dụng chạy (Hình 4.2):

- Lớp gốc, đóng gói sẵn trong ứng dụng: tệp `dialect_dict.json`, được sinh tự động (mục 4.2.2.2). Vì nằm sẵn trong ứng dụng nên luôn dùng được, kể cả ở lần chạy đầu tiên và khi không có mạng.
- Lớp bổ sung, tải từ máy chủ: các từ do quản trị viên thêm hoặc sửa, lưu trong cơ sở dữ liệu. Ứng dụng tải về, lưu đệm và gộp đè lên lớp gốc.

```dart
static void _rebuild() {
  _dict = {..._bundledDict, ..._overrides};   // lớp bổ sung đè lên lớp gốc khi trùng khóa
}
```

Ý nghĩa của thiết kế: khi phát hiện một từ địa phương chưa có trong từ điển giữa mùa lũ, quản trị viên chỉ cần gọi API thêm từ, không cần biên dịch và phát hành lại ứng dụng, người dùng cũng không phải cập nhật.

*Hình 4.2 - Kiến trúc từ điển hai lớp và luồng đồng bộ.*

#### 4.2.2.2. Sinh lớp gốc bằng luật biến âm

Thay vì liệt kê thủ công từng cặp từ, hệ thống sinh ngược dạng phương ngữ bằng cách áp các luật ở Bảng 4.1 lên một corpus tiếng Việt chuẩn. Corpus được sử dụng là Viet74K [12], gồm khoảng 74.000 mục từ vựng tiếng Việt phổ thông.

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

Một mục chỉ được giữ lại khi thỏa đồng thời ba điều kiện: dạng sinh ra phải khác từ gốc (nếu trùng thì luật không có tác dụng), không nằm trong danh sách chặn, và không trùng một từ chuẩn đã có. Điều kiện cuối giữ vai trò quyết định, bởi nếu một dạng biến âm trùng với từ chuẩn "hòa" thì mọi câu tiếng Việt phổ thông chứa "hòa" đều bị thay sai nghĩa. Quy trình sinh cho ra tệp từ điển gồm hơn 26.000 mục, được dùng làm lớp gốc.

#### 4.2.2.3. Cập nhật lớp bổ sung theo số phiên bản

Máy chủ lưu các từ bổ sung kèm một bộ đếm phiên bản, được tăng thêm một đơn vị sau mỗi lần thêm hoặc xóa từ. Ứng dụng dựa vào bộ đếm này để xác định thời điểm cần đồng bộ.

```dart
static Future<void> syncFromBackend() async {
  try {
    final localVersion = prefs.getInt(_kOverrideVersion) ?? -1;

    // (1) Hỏi phiên bản trước: truy vấn rẻ, tránh tải thừa
    final verResp = await http.get(Uri.parse('$_baseUrl/api/dialect-dict/version'));
    final remoteVersion = json.decode(verResp.body)['version'];
    if (remoteVersion <= localVersion) return;          // đã mới nhất

    // (2) Có bản mới: tải toàn bộ từ bổ sung, gộp và lưu đệm
    final resp = await http.get(Uri.parse('$_baseUrl/api/dialect-dict'));
    _overrides = (json.decode(resp.body)['terms'] as Map).cast<String, String>();
    _rebuild();
    await prefs.setString(_kOverrideTerms, json.encode(_overrides));
    await prefs.setInt(_kOverrideVersion, remoteVersion);
  } catch (e) {
    // (3) Offline hoặc máy chủ lỗi: bỏ qua, dùng bản đã lưu đệm hoặc lớp gốc
  }
}
```
*Đồng bộ từ bổ sung theo số phiên bản. Nguồn: `mobile/lib/services/dialect_normalizer.dart`*

Cơ chế đồng bộ hỏi số phiên bản trước rồi mới tải dữ liệu, nhờ đó tránh tải lại toàn bộ từ điển mỗi lần mở ứng dụng. Số phiên bản được thiết kế là một bộ đếm đơn điệu thay vì suy ra từ số lượng từ, bởi thao tác xóa làm số lượng giảm và sẽ khiến ứng dụng hiểu nhầm dữ liệu trên máy chủ là cũ hơn. Khi không có mạng, hàm kết thúc trong im lặng và chức năng chuẩn hóa vẫn hoạt động bình thường bằng lớp gốc.

#### 4.2.2.4. Thuật toán chuẩn hóa khi tạo yêu cầu SOS

Bước này chạy mỗi khi nạn nhân nhập mô tả. Hàm chỉ đọc từ điển đã gộp sẵn trong bộ nhớ, không truy cập mạng. Thuật toán duyệt văn bản từ trái sang phải, tại mỗi vị trí thử khớp **cụm ba từ, rồi cụm hai từ, rồi từ đơn** — khớp được ở mức nào thì thay và nhảy qua đúng số từ đó.

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

**Vì sao phải thử cụm dài trước.** Xét cụm "mớ nhoà", nghĩa là *mái nhà*. Nếu xử lý từ đơn trước, "mớ" không có trong từ điển nên được giữ nguyên, còn "nhoà" được thay thành "nhà", cho kết quả sai là "mớ nhà". Chỉ khi khớp ở mức cụm hai từ, thuật toán mới nhận diện "mớ nhoà" như một mục từ vựng nguyên khối và cho ra "mái nhà" đúng nghĩa; "chu cha" (nghĩa: *ôi trời*) cũng vậy. Thứ tự ba từ, hai từ, một từ vì thế là điều kiện cần để những cụm mang nghĩa riêng được nhận diện trọn vẹn.

Hàm phụ `_preserveCase` giữ quy tắc viết hoa của từ gốc ("LỒM" thành "LÀM"). Từ không có trong từ điển được giữ nguyên, bảo đảm bộ chuẩn hóa không làm hỏng văn bản.

### 4.2.3. Cơ chế phân loại mức độ khẩn cấp

Việc phân loại có ba yêu cầu xung đột nhau: phải luôn có kết quả kể cả khi mất mạng hoặc dịch vụ AI gặp sự cố, cần hiểu được ngữ cảnh (điều mà chỉ mô hình ngôn ngữ lớn làm tốt, nhưng mô hình này chậm và phụ thuộc mạng), và không được bỏ sót ca nguy kịch. Giải pháp là kết hợp hai nhánh: một nhánh dò từ khóa cục bộ giữ vai trò lớp bảo đảm tối thiểu, một nhánh mô hình ngôn ngữ lớn giữ vai trò lớp hiểu ngữ cảnh, hợp nhất theo nguyên tắc lấy mức khẩn cấp cao hơn (Hình 4.3).

*Hình 4.3 - Cơ chế phân loại mức độ khẩn cấp: nhánh dò từ khóa, nhánh mô hình ngôn ngữ lớn và quy tắc hợp nhất.*

#### 4.2.3.1. Nhánh dò từ khóa

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

Việc dò từ khóa không thể chỉ dựa vào phép kiểm tra chuỗi con, vì tiếng Việt có nhiều từ chứa nhau ở mức ký tự: "không" chứa "ông", "bàn" chứa "bà". Nếu so khớp theo chuỗi con, mọi câu có chữ "không" đều bị gán nhãn *người già*. Hàm `hasKeyword` do đó so khớp theo biên từ: văn bản được tách thành mệnh đề rồi thành từ, và một từ khóa chỉ được tính khi trùng khớp trọn vẹn dãy từ.

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

Ba lựa chọn trong hàm này đều xuất phát từ đặc thù của bài toán cứu hộ. Dấu câu được dùng làm ranh giới mệnh đề, để một từ phủ định ở vế trước không lan sang phủ định từ khóa ở vế sau: trong câu "nước không rút, nhà ngập nóc", từ khóa *ngập nóc* vẫn phải được tính. Cửa sổ phủ định được giới hạn hẹp ở hai từ, vì trong hệ thống cứu hộ, việc chặn nhầm một từ khóa thật (âm tính giả) nguy hiểm hơn nhiều so với việc phát sinh một báo động giả (dương tính giả), mà cửa sổ càng rộng thì rủi ro chặn nhầm càng cao. Riêng những từ khóa tự nó mở đầu bằng từ phủ định thì không xét phủ định, nếu không thì "không thở", vốn là dấu hiệu nguy kịch nhất, sẽ tự vô hiệu hóa chính nó.

Ngoài phủ định, một số cụm cố định chứa từ khóa nhưng hoàn toàn không mang nghĩa cứu hộ, chẳng hạn "kẹt xe" hay "xe chết máy". Các cụm này được xóa khỏi văn bản trước khi dò.

#### 4.2.3.2. Nhánh mô hình ngôn ngữ lớn

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

Một tham số cấu hình có ảnh hưởng quyết định tới tính khả dụng của nhánh này là `thinkingConfig`. Mô hình Gemini 2.5 Flash mặc định bật chế độ suy luận nội tại (thinking): trước khi sinh câu trả lời, mô hình tự tạo một chuỗi lập luận trung gian không hiển thị cho người dùng. Chế độ này có giá trị với các bài toán suy luận nhiều bước, nhưng bài toán của đề tài là gán một nhãn mức 1-5 cho một câu ngắn, không thuộc loại đó: chuỗi lập luận trung gian không cải thiện chất lượng phân loại nhưng chiếm phần lớn thời gian sinh.

```javascript
generationConfig: {
  responseMimeType: 'application/json',   // ép đầu ra JSON có cấu trúc
  temperature: 0.1,                       // giảm tính ngẫu nhiên, cần cho bài toán phân loại
  thinkingConfig: { thinkingBudget: 0 },  // tắt suy luận nội tại
}
```
*Cấu hình sinh của mô hình ngôn ngữ. Nguồn: `backend/src/services/aiPipeline.js`*

Tác động của tham số này được đo cụ thể ở mục 4.5.1: độ trễ trung bình giảm từ khoảng 5,6 giây xuống còn khoảng 1,2 giây, tức giảm hơn bốn lần, mà chất lượng phân loại không suy giảm. Chính nhờ vậy ngưỡng thời gian chờ mới có thể đặt ở mức 3 giây; nếu giữ chế độ suy luận mặc định, ngưỡng này sẽ vô hiệu hóa gần như toàn bộ nhánh mô hình ngôn ngữ.

#### 4.2.3.3. Quy tắc hợp nhất và sàn an toàn

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

Cần nói rõ về bản chất luồng thực thi: hai nhánh không chạy đua với nhau. Nhánh dò từ khóa chạy đồng bộ và cho kết quả ngay, sau đó chương trình mới chờ (`await`) nhánh mô hình ngôn ngữ lớn; cấu trúc `Promise.race` chỉ tồn tại bên trong nhánh mô hình để giới hạn thời gian chờ. Do đó thời gian phản hồi của hệ thống bị chặn dưới bởi độ trễ của mô hình, tối đa bằng thời gian chờ đã cấu hình, và sự hiện diện của nhánh dò từ khóa không rút ngắn thời gian này. Giá trị của nhánh dò từ khóa nằm ở chỗ nó bảo đảm hệ thống luôn có kết quả: khi mô hình chậm, gặp lỗi, hoặc máy chủ mất kết nối tới dịch vụ, hệ thống vẫn phân loại được và luồng tạo ca không bị nghẽn. Mục 4.5.1 đo định lượng độ trễ và tỉ lệ sử dụng của từng nhánh.

Phép `Math.max` giữ vai trò sàn an toàn, bảo đảm mức khẩn cấp cuối cùng không bao giờ thấp hơn mức mà từ khóa cảnh báo phát hiện: nếu văn bản chứa "đuối nước", tức mức 5, nhưng mô hình đánh giá mức 2, kết quả cuối vẫn là 5. Đây là một đánh đổi được cân nhắc trước. Trong cứu hộ, việc bỏ sót một ca nguy kịch gây hậu quả không đảo ngược, trong khi một báo động giả chỉ gây tốn công; hệ thống vì vậy được thiết kế nghiêng hẳn về phía an toàn, chấp nhận đánh giá cao hơn thực tế còn hơn để lọt dấu hiệu nguy hiểm. Trường `ai_source` ghi lại nguồn của kết quả cuối cùng, nhận giá trị `gemini` hoặc `rule_based`, phục vụ thống kê tỉ lệ dự phòng ở mục 4.5.1.

### 4.2.4. Minh họa tác động của chuẩn hóa lên kết quả phân loại

Bảng 4.5 theo dõi sáu câu cầu cứu mang đặc trưng phương ngữ: từ văn bản do nhận dạng giọng nói sinh ra, qua bước chuẩn hóa (mục 4.2.2), đến kết quả phân loại của nhánh dò từ khóa trong hai trường hợp có và không có bước chuẩn hóa, đối chiếu với bảng từ khóa ở Bảng 4.3 và Bảng 4.4.

*Bảng 4.5 - Kết quả chuẩn hóa phương ngữ và tác động lên phân loại (nhánh dò từ khóa)*

| # | Văn bản do nhận dạng giọng nói sinh ra | Sau chuẩn hóa | Phân loại nếu không chuẩn hóa | Phân loại có chuẩn hóa |
|---|---|---|---|---|
| 1 | Nhoà tui ngập tới mớ nhoà rồi | Nhà tui ngập tới mái nhà rồi | Chỉ khớp "ngập", mức 2, không nhãn | Khớp "mái nhà", mức 4; khớp "ngập tới mái", nhãn `ngap_noc` |
| 2 | Có người gioà kẹt trong nhoà, nước lên nhanh | Có người già kẹt trong nhà, nước lên nhanh | Chỉ khớp "kẹt", mức 3, không nhãn | Khớp "người già", mức 4; nhãn `nguoi_gia` |
| 3 | Mấy đứa nhỏ đang ở trên mớ nhoà, nước dâng tới nơi rồi | Mấy đứa nhỏ đang ở trên mái nhà, nước dâng tới nơi rồi | Chỉ khớp "nước dâng", mức 3 | Khớp "mái nhà", mức 4 |
| 4 | Boà tui nỏ đi được, nước ngập dô tới ngực | Bà tôi không đi được, nước ngập vô tới ngực | Chỉ khớp "ngập", mức 2, không nhãn | Mức 2 (không đổi); khớp "bà", nhãn `nguoi_gia` |
| 5 | May quá nỏ ai bị thương, mà nhoà thì ngập tới mớ nhoà rồi | May quá không ai bị thương, mà nhà thì ngập tới mái nhà rồi | Khớp "bị thương", mức 4; nhãn `y_te` (sai, vì không ai bị thương) | Cụm "bị thương" bị vô hiệu bởi từ phủ định "không"; khớp "mái nhà", mức 4; nhãn `ngap_noc` (đúng) |
| 6 | Chu cha, nước lên răng mà nhanh rứa | Ôi trời, nước lên sao mà nhanh thế | Khớp "nước lên", mức 2 | Mức 2 (không đổi) |

Bảng cho thấy ba kiểu tác động. **Đổi mức khẩn cấp** (câu 1–3): các từ khóa quyết định như "mái nhà", "người già" chỉ xuất hiện *sau khi* dạng phương ngữ được ánh xạ về dạng chuẩn; thiếu bước này, một ca có người già mắc kẹt hoặc nước đã ngập tới mái bị xếp thấp hơn thực tế và bị ưu tiên sau. **Đổi nhãn phân loại** (câu 4–5). **Không đổi gì** (câu 6): các từ như "chu cha", "răng", "rứa" không trùng từ khóa nào, chuẩn hóa chỉ làm câu dễ hiểu hơn cho nhánh mô hình ngôn ngữ và cho tình nguyện viên đọc.

Câu 5 đáng chú ý nhất. Từ phủ định phương ngữ "nỏ" không nằm trong danh sách từ phủ định ở mục 4.2.3.1, nên khi chưa chuẩn hóa, cụm "bị thương" vẫn được tính và hệ thống gán sai nhãn `y_te` cho một ca thực tế không ai bị thương. Chỉ sau khi "nỏ" được ánh xạ thành "không", cơ chế phủ định mới hoạt động và nhãn sai bị loại. Bộ chuẩn hóa vì vậy không chỉ bổ sung thông tin cho bước phân loại, nó còn là **tiền đề để các cơ chế phía sau vận hành đúng**.

**Phạm vi của minh họa.** Đây là khảo sát định tính trên tập câu do người viết xây dựng, và chỉ đo tác động lên nhánh dò từ khóa — nhánh so khớp theo mặt chữ nên tất yếu thất bại với dạng phương ngữ. Khả năng nhánh mô hình ngôn ngữ lớn tự hiểu phương ngữ mà không cần chuẩn hóa thì chưa được kiểm chứng. Giá trị đã xác lập được của bộ chuẩn hóa vì thế hẹp nhưng chắc: nó bảo đảm nhánh dò từ khóa, lớp xử lý duy nhất còn hoạt động khi mất mạng, không đánh giá sai mức khẩn cấp với người nói phương ngữ (bàn thêm ở mục 5.2).

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

Cần lưu ý rằng tác vụ này không đổi trạng thái ca sang `orphaned` mà giữ nguyên ở `pending`, bởi ca vẫn phải hiển thị để tình nguyện viên có thể tiếp nhận; cảnh báo ca mồ côi nhằm huy động sự can thiệp của quản trị viên, không nhằm đóng ca. Nói cách khác, "mồ côi" là một sự kiện cảnh báo, không phải một trạng thái trong vòng đời ca.

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

Kết quả được xếp hạng bằng mệnh đề `ORDER BY (distance_m / 500) ASC, urgency_level DESC`: các ca được gom theo từng vành đai 500 m tính từ vị trí tình nguyện viên, và trong cùng một vành đai thì ca có mức khẩn cấp cao hơn đứng trước. Cách xếp hạng này cân bằng giữa hai yếu tố vốn xung đột nhau. Nếu xếp thuần theo khoảng cách, một ca ngập nhẹ cách 100 m sẽ luôn đứng trên một ca có người đuối nước cách 500 m. Ngược lại, nếu xếp thuần theo mức khẩn cấp, tình nguyện viên có thể bị đẩy tới một ca nguy kịch ở rất xa trong khi một người khác ở gần hơn nhiều. Việc chia vành đai coi mọi ca trong cùng một khoảng cách di chuyển là tương đương, rồi mới để mức nguy kịch quyết định thứ tự.

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

Điều kiện `khoảng_cách_hiện_tại ≥ 0,9 × khoảng_cách_ban_đầu` là định nghĩa định lượng của trạng thái "không tiến lại gần", với biên 10% để dung sai nhiễu định vị GPS. Quy trình thu hồi được thiết kế có bước hỏi lại: hệ thống gửi thông báo xác nhận trước, và chỉ khi tình nguyện viên tiếp tục không phản hồi thêm 5 phút thì phân công mới bị thu hồi và ca được mở lại để phát sóng cho người khác.

Một tác vụ tương tự phát hiện ca ở trạng thái `on_scene` quá 60 phút mà tình nguyện viên đã rời khu vực. Tác vụ này chỉ cảnh báo quản trị viên xem xét chứ không tự đóng ca, nhằm tránh đóng nhầm một ca còn đang diễn ra; quyết định kết thúc một ca cứu hộ được giữ lại cho con người.

Hình 4.4 tổng hợp toàn bộ vòng đời điều phối trình bày ở mục 4.3, từ lúc ca được phát sóng, qua các mốc tiếp cận, đến khi hoàn tất hoặc bị thu hồi và điều phối lại.

*Hình 4.4 - Vòng đời điều phối một ca, từ lúc phát sóng đến khi hoàn tất hoặc bị thu hồi.*

Cần lưu ý rằng cả hai cơ chế trên đều dựa trên khoảng cách đường chim bay chứ không phải quãng đường di chuyển thực. Trong vùng lũ, một tình nguyện viên buộc phải đi vòng có thể bị đánh giá nhầm là đang bế tắc; hạn chế này và hướng khắc phục được bàn ở mục 5.2 và 5.3.

## 4.4. Hạ tầng thời gian thực và các thành phần vận hành

Ba cơ chế trình bày ở trên đều dựa trên một hạ tầng chung: kênh truyền thời gian thực giữa máy chủ và thiết bị, cơ chế liên lạc giữa nạn nhân với tình nguyện viên, và lớp xác thực. Mục này trình bày phần hiện thực của hạ tầng đó.

### 4.4.1. Kênh truyền thời gian thực

Hệ thống sử dụng hai kỹ thuật cho hai nhu cầu khác nhau. Server-Sent Events (SSE) được dùng khi máy chủ cần đẩy một chiều các sự kiện đổi trạng thái ca (`case:accepted`, `case:resolved`, `case:orphaned`, `case:on_scene`) xuống client trên một kết nối HTTP giữ mở; kỹ thuật này thay thế cho việc client phải hỏi vòng định kỳ (polling), qua đó giảm số lượt gọi mạng và tiết kiệm pin.

WebSocket được dùng cho luồng dữ liệu hai chiều tần suất cao. Máy chủ tổ chức các kết nối theo phòng (room) ứng với mỗi `caseId`; luồng vị trí GPS và luồng tin nhắn dùng chung một kết nối, phân biệt bằng trường `type` trong gói tin, nhận giá trị `gps_update` hoặc `chat`. Việc hợp nhất hai luồng trên một kết nối giúp giảm số kết nối bền vững phải duy trì trên mỗi thiết bị, vốn là tài nguyên tốn kém trong điều kiện mạng yếu. Máy chủ duy trì tín hiệu nhịp (heartbeat) mỗi 30 giây và đóng các kết nối không phản hồi để giải phóng phòng.

Khi kết nối WebSocket bị gián đoạn, client tự động chuyển sang cơ chế dự phòng qua REST: tin nhắn được gửi bằng `POST /api/case/:id/messages` và lịch sử được tải bằng `GET /api/case/:id/messages`. Nhờ vậy người dùng không nhận được thông báo "gửi thất bại" trong lúc mạng chập chờn.

### 4.4.2. Liên lạc đa kênh trong ca và bảo vệ dữ liệu cá nhân

Sau khi tình nguyện viên nhận ca, hai bên có ba tầng liên lạc theo thứ tự dự phòng giảm dần về yêu cầu hạ tầng: nhắn tin thời gian thực qua WebSocket, nhắn tin qua REST khi WebSocket gián đoạn, và cuối cùng là gọi điện trực tiếp qua mạng GSM bằng lược đồ `tel://`. Kênh cuối hoạt động ngay cả khi thiết bị chỉ có sóng 2G và không có kết nối Internet. Thiết kế ba tầng bảo đảm việc liên lạc không bị đứt hoàn toàn trong địa hình lũ lụt, nơi chất lượng mạng dữ liệu không ổn định.

Do liên lạc đòi hỏi trao số điện thoại giữa hai bên, dữ liệu này được bảo vệ bằng hai biện pháp. Số điện thoại được mã hóa bằng thuật toán AES-256-GCM khi lưu trong cơ sở dữ liệu và chỉ được giải mã tại thời điểm trao cho đúng người trong đúng ca, tức khi tình nguyện viên nhận ca. Toàn bộ tin nhắn của một ca được xóa khỏi cơ sở dữ liệu ngay khi ca kết thúc (hoàn thành hoặc hủy) bằng một câu lệnh xóa tường minh, nhằm tránh tích lũy dữ liệu nhạy cảm sau thiên tai; ràng buộc khóa ngoại `ON DELETE CASCADE` trên bảng tin nhắn giữ vai trò lưới an toàn, bảo đảm không sót tin nhắn nếu bản ghi ca bị xóa hẳn.

### 4.4.3. Theo dõi vị trí tiết kiệm pin

Việc theo dõi vị trí liên tục là tác nhân tiêu thụ pin lớn nhất trên thiết bị tình nguyện viên, trong khi pin lại là tài nguyên khan hiếm giữa vùng lũ mất điện. Ứng dụng vì vậy áp dụng ba chế độ định vị thích nghi theo ngữ cảnh: chế độ chờ (tắt GPS, dùng vị trí đã lưu đệm khi chưa nhận ca), chế độ di chuyển (chỉ phát tọa độ khi thiết bị đã dịch chuyển quá 30 m, độ chính xác ở mức cân bằng và được nâng lên mức cao khi khoảng cách còn dưới 500 m), và chế độ tại hiện trường (hạ độ chính xác, ngưỡng dịch chuyển 100 m khi đã ở rất gần nạn nhân). Một Foreground Service của Android giữ cho việc theo dõi không bị hệ điều hành dừng khi ứng dụng chạy nền.

### 4.4.4. Xác thực và định danh

Nạn nhân và tình nguyện viên xác thực bằng mã OTP gửi tới số điện thoại thông qua Firebase Authentication; mọi yêu cầu tới các tuyến API cần bảo vệ đều đi qua một middleware kiểm tra mã thông báo (token) do Firebase cấp. Quản trị viên đăng nhập bằng email và mật khẩu được băm bằng bcrypt, tách khỏi luồng Firebase. Hệ thống áp dụng cơ chế giới hạn tần suất truy cập (`express-rate-limit`) nhằm chống lạm dụng.

Tình nguyện viên phải qua bước định danh điện tử (eKYC) trước khi được duyệt: hệ thống đóng vai trò proxy gọi dịch vụ FPT.AI để nhận dạng thông tin trên Căn cước công dân và đối sánh khuôn mặt với ảnh chân dung, với ngưỡng tương đồng tối thiểu 80%. Đây là bước tích hợp dịch vụ bên thứ ba, không thuộc phần đóng góp kỹ thuật của đề tài.

## 4.5. Đánh giá thực nghiệm

Mục này đánh giá cơ chế phân loại mức độ khẩn cấp (mục 4.2.3) bằng phép đo định lượng, và kiểm chứng các cơ chế điều phối (mục 4.3) bằng kịch bản. Riêng bộ chuẩn hóa phương ngữ (mục 4.2.2) được khảo sát định tính ở mục 4.2.4; việc đánh giá định lượng bộ chuẩn hóa đòi hỏi một tập kiểm thử có gán nhãn nằm ngoài phạm vi khóa luận, và được nêu như một hạn chế ở mục 5.2.

### 4.5.1. Độ trễ và độ sẵn sàng của cơ chế phân loại

Phép đo được thực hiện trên một tập gồm 40 tin nhắn cầu cứu mô phỏng do người viết xây dựng, phân bố đều trên năm mức khẩn cấp. Với mỗi tin nhắn, hệ thống gọi hàm `runUrgencyClassification`, ghi lại thời gian chạy của từng nhánh và ghi lại nhánh nào cho ra kết quả cuối cùng. Phép đo được lặp lại trong hai kịch bản: mạng ổn định, và ngắt kết nối tới dịch vụ Gemini bằng cách gỡ biến `GEMINI_API_KEY` nhằm mô phỏng tình huống dịch vụ ngoài không khả dụng.

*Bảng 4.6 - Độ trễ phân loại và tỉ lệ sử dụng của hai nhánh (40 tin nhắn)*

| Chỉ số | Nhánh dò từ khóa | Nhánh mô hình ngôn ngữ lớn |
|---|---|---|
| Độ trễ trung bình | dưới 0,1 ms | khoảng 1,2 giây |
| Độ trễ lớn nhất | dưới 0,1 ms | khoảng 2,3 giây |
| Tỉ lệ trả về kết quả thành công (mạng ổn định) | 100 % | 95 % |
| Tỉ lệ trả về kết quả thành công (mất kết nối dịch vụ) | 100 % | 0 % |
| Tỉ lệ được chọn làm kết quả cuối (ngưỡng chờ 3 giây) | 5 % | 95 % |

Chênh lệch về độ trễ giữa hai nhánh là rất lớn: nhánh dò từ khóa chỉ tra bảng trong bộ nhớ nên hoàn tất gần như tức thời, còn nhánh mô hình ngôn ngữ lớn phải gọi qua mạng tới một dịch vụ bên ngoài nên mất hơn một giây. Kết quả này khẳng định nhận định đã nêu ở mục 4.2.3.3: thời gian phản hồi của hệ thống hoàn toàn do độ trễ của mô hình ngôn ngữ quyết định, và nhánh dò từ khóa không rút ngắn được thời gian đó. Giá trị của nó nằm ở chỗ khác, là bảo đảm hệ thống luôn có kết quả.

Điểm đáng chú ý trong bảng là tỉ lệ thành công của nhánh mô hình ngôn ngữ ở kịch bản mạng ổn định không đạt 100% mà chỉ 95%: hai trong bốn mươi lời gọi bị dịch vụ Gemini trả về mã lỗi 503 Service Unavailable. Đây không phải lỗi vượt thời gian chờ mà là sự cố thật của dịch vụ bên ngoài, xảy ra ngẫu nhiên ngay trong lúc đo. Cả hai ca đó đều được nhánh dò từ khóa tiếp quản và phân loại thành công, luồng tạo ca không bị gián đoạn. Tình huống mà lớp bảo đảm tối thiểu được thiết kế để phòng ngừa đã tự nó xảy ra, và cơ chế hoạt động đúng như dự kiến.

Giá trị `GEMINI_TIMEOUT_MS` được xác định từ chính các số đo trên. Để biết mỗi lời gọi thực sự mất bao lâu, phép đo tạm nới thời gian chờ lên 15 giây, xem như không cắt; từ đó suy ra với mỗi mốc chờ ứng viên thì bao nhiêu phần trăm số ca kịp nhận kết quả của mô hình, bao nhiêu phần trăm phải rơi về nhánh dò từ khóa.

*Bảng 4.7 - Ảnh hưởng của ngưỡng thời gian chờ tới tỉ lệ sử dụng hai nhánh (40 tin nhắn)*

| Ngưỡng chờ | Tỉ lệ ca dùng được kết quả mô hình ngôn ngữ | Tỉ lệ ca phải dùng nhánh dò từ khóa | Thời gian chờ tối đa của nạn nhân |
|---|---|---|---|
| 1 giây | 15 % | 85 % | 1 giây |
| 1,5 giây | 85 % | 15 % | 1,5 giây |
| 2 giây | 92,5 % | 7,5 % | 2 giây |
| 3 giây (đang dùng) | 95 % | 5 % | 3 giây |
| 5 giây | 95 % | 5 % | 5 giây |
| 7 giây | 95 % | 5 % | 7 giây |

Bảng 4.7 cho thấy một sự đánh đổi: ngưỡng càng thấp thì nạn nhân chờ càng ít nhưng càng nhiều ca mất đi khả năng hiểu ngữ cảnh của mô hình ngôn ngữ, ngưỡng càng cao thì ngược lại. Số đo cho thấy hai đầu của bảng đều không có lợi. Ở mốc 1 giây, chỉ 15% số ca kịp nhận kết quả của mô hình, nghĩa là hệ thống gần như chỉ còn chạy bằng từ khóa. Từ mốc 3 giây trở lên, nâng thêm cũng không cải thiện được gì, tỉ lệ đứng yên ở 95%, bởi 5% còn lại không phải do mô hình trả lời chậm mà do dịch vụ trả về lỗi 503, mà lỗi thì chờ bao lâu cũng không có kết quả.

Ngưỡng 3 giây vì vậy được chọn: đây là mốc thấp nhất đạt được tỉ lệ sử dụng cao nhất mà số đo cho phép, đồng thời vẫn còn dư một khoảng so với lời gọi chậm nhất đo được (khoảng 2,3 giây) để dung sai các dao động mạng. Nâng lên 5 hay 7 giây chỉ kéo dài thời gian chờ của nạn nhân mà không đổi lấy được lợi ích nào.

Cần nhấn mạnh rằng kết quả trên chỉ đạt được sau khi tắt chế độ suy luận nội tại của mô hình (mục 4.2.3.2). Đo lại trên cùng tập dữ liệu với cấu hình mặc định, độ trễ trung bình lên tới khoảng 5,6 giây, gấp hơn bốn lần. Với độ trễ đó, ngưỡng 3 giây chỉ cho phép chưa tới một phần mười số ca kịp dùng kết quả của mô hình, nghĩa là cơ chế lai gần như không vận hành như thiết kế; muốn phần lớn số ca dùng được mô hình thì phải chờ tới 10 giây, mức không chấp nhận được trong tình huống khẩn cấp. Đây là một sai lệch mà quá trình phát triển không hề để lộ dấu hiệu: hệ thống vẫn chạy, vẫn trả kết quả, chỉ là trả bằng nhánh dò từ khóa. Chỉ khi đo mới phát hiện ra.

Quy tắc `Math.max` được kiểm chứng riêng bằng một tin nhắn chứa từ khóa mức 5 nhưng có ngữ cảnh dễ khiến mô hình hạ mức, cụ thể là câu "Bác tôi bị đuối nước nhưng đã vớt lên rồi, giờ cần người đưa đi viện". Nhánh dò từ khóa nhận diện từ khóa "đuối nước" và gán mức 5; kết quả cuối cùng sau khi hợp nhất giữ nguyên mức 5. Hệ thống không hạ mức xuống dưới ngưỡng mà từ khóa cảnh báo đã phát hiện, đúng như thiết kế ở mục 4.2.3.3.

### 4.5.2. Kiểm chứng các cơ chế điều phối

Ba cơ chế điều phối được kiểm chứng theo kịch bản, do bản chất của chúng là hành vi theo thời gian chứ không phải chỉ số định lượng:

- Phát hiện ca mồ côi. Hạ giá trị `ORPHAN_ALERT_MS` xuống một phút, tạo một ca và không cho tình nguyện viên nào tiếp nhận. Kiểm chứng rằng sự kiện `case:orphaned` được phát đúng một lần, và quan trọng hơn, lặp lại thí nghiệm với thao tác khởi động lại máy chủ giữa khoảng chờ để chứng minh cảnh báo vẫn diễn ra, điều mà thiết kế cũ dùng `setTimeout` không đáp ứng được.
- Tự thu hồi phân công. Cho một tình nguyện viên nhận ca rồi giữ nguyên vị trí. Kiểm chứng rằng sau 10 phút hệ thống gửi thông báo hỏi xác nhận, và sau 5 phút không phản hồi thì phân công bị thu hồi, ca trở lại trạng thái `pending` và được phát sóng lại.
- Mốc tiếp cận. Mô phỏng luồng GPS di chuyển dần về phía nạn nhân, kiểm chứng rằng thông báo tại mốc 300 m và 100 m mỗi loại chỉ được gửi đúng một lần, và trạng thái ca chuyển sang `on_scene` khi vượt ngưỡng 100 m.

## 4.6. Kết luận chương

Chương này đã trình bày cách hiện thực ba trụ cột nêu trong tên đề tài, mỗi trụ cột xoay quanh một nhận định thiết kế:

- **Xử lý ngôn ngữ địa phương** — sai lệch của bộ nhận dạng giọng nói đối với phương ngữ có tính quy luật, nên mô hình hóa được bằng luật biến âm và đảo ngược được bằng một lớp hậu xử lý. Từ đó: sinh từ điển từ corpus chuẩn thay vì liệt kê tay, tổ chức hai lớp để cập nhật giữa mùa lũ, chuẩn hóa bằng khớp cụm dài nhất.
- **Phân loại ca SOS** — trong cứu hộ, bỏ sót nguy hiểm hơn báo động giả. Từ đó: nhánh dò từ khóa cục bộ bảo đảm luôn có kết quả, và quy tắc lấy mức cao hơn giữa hai nhánh bảo đảm không đánh giá một ca nhẹ hơn mức từ khóa đã cảnh báo.
- **Điều phối cứu trợ** — trạng thái cần bền vững phải nằm trong cơ sở dữ liệu, không nằm trong bộ nhớ tiến trình. Từ đó: phát hiện ca mồ côi bằng tác vụ quét định kỳ, sống sót qua mọi lần khởi động lại máy chủ.

Phép đo ở mục 4.5 xác nhận nhánh dò từ khóa phân loại thành công 100% số ca ở mọi kịch bản, và cho thấy ngưỡng chờ 3 giây chỉ khả thi sau khi tắt chế độ suy luận nội tại của mô hình ngôn ngữ. Các hạn chế còn tồn tại được phân tích ở mục 5.2, kèm hướng khắc phục ở mục 5.3.




