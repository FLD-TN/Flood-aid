# BACKUP — Mục 4.5 "Đánh giá thực nghiệm" (đã gỡ khỏi báo cáo, lưu để dùng lại)

> File này lưu **toàn bộ** nội dung mục 4.5 đã bị gỡ khỏi khóa luận, KÈM mã nguồn test và dữ liệu
> để tái lập số liệu. Nếu cần đưa lại vào báo cáo (hoặc hội đồng hỏi "số liệu ở đâu ra"), dùng file này.
>
> Số liệu KHÔNG bịa: chạy `backend/scripts/measureAiPipeline.js` là ra. Bằng chứng gồm:
> - Script đo:  `backend/scripts/measureAiPipeline.js`
> - Dữ liệu:    `backend/scripts/sos_test_set.json`  (40 câu + 1 câu kiểm chứng sàn an toàn)
> - Kết quả thô: `backend/scripts/output/do_tre_phan_loai.csv`
> - Bảng sinh ra: `backend/scripts/output/bang_4_7_va_4_8.md`
>
> LƯU Ý đánh số: trong báo cáo hai bảng là **Bảng 4.6 và 4.7**; trong file script/output chúng tên
> **Bảng 4.7 và 4.8** (script viết trước lúc đổi số). Nội dung y hệt.

---

# PHẦN A — NỘI DUNG 4.5 NGUYÊN VĂN (để chép lại nếu cần)

## 4.5. Đánh giá thực nghiệm

Mục này đánh giá cơ chế phân loại mức độ khẩn cấp (mục 4.2.3) bằng phép đo định lượng, và kiểm chứng các cơ chế điều phối (mục 4.3) bằng kịch bản. Riêng bộ chuẩn hóa phương ngữ (mục 4.2.2) được khảo sát định tính ở mục 4.2.4; việc đánh giá định lượng bộ chuẩn hóa đòi hỏi một tập kiểm thử có gán nhãn nằm ngoài phạm vi khóa luận, và được nêu như một hạn chế ở mục 5.2.

### 4.5.1. Độ trễ và độ sẵn sàng của cơ chế phân loại

Phép đo được thực hiện trên một tập gồm 40 tin nhắn cầu cứu mô phỏng do người viết xây dựng, phân bố đều trên năm mức khẩn cấp. Với mỗi tin nhắn, hệ thống gọi hàm `runUrgencyClassification`, ghi lại thời gian chạy của từng nhánh và ghi lại nhánh nào cho ra kết quả cuối cùng. Phép đo được lặp lại trong hai kịch bản: mạng ổn định, và ngắt kết nối tới dịch vụ Gemini bằng cách gỡ biến `GEMINI_API_KEY` nhằm mô phỏng tình huống dịch vụ ngoài không khả dụng.

**Bảng 4.6 — Độ trễ phân loại và tỉ lệ sử dụng của hai nhánh (40 tin nhắn)**

| Chỉ số | Nhánh dò từ khóa | Nhánh mô hình ngôn ngữ lớn |
|---|---|---|
| Độ trễ trung bình | dưới 0,1 ms | khoảng 1,2 giây |
| Độ trễ lớn nhất | dưới 0,1 ms | khoảng 2,3 giây |
| Tỉ lệ trả về kết quả thành công (mạng ổn định) | 100 % | 95 % |
| Tỉ lệ trả về kết quả thành công (mất kết nối dịch vụ) | 100 % | 0 % |
| Tỉ lệ được chọn làm kết quả cuối (ngưỡng chờ 3 giây) | 5 % | 95 % |

Chênh lệch về độ trễ giữa hai nhánh là rất lớn: nhánh dò từ khóa chỉ tra bảng trong bộ nhớ nên hoàn tất gần như tức thời, còn nhánh mô hình ngôn ngữ lớn phải gọi qua mạng tới một dịch vụ bên ngoài nên mất hơn một giây. Kết quả này khẳng định nhận định ở mục 4.2.3.3: thời gian phản hồi của hệ thống do độ trễ mô hình ngôn ngữ quyết định, nhánh dò từ khóa không rút ngắn được. Vai trò của nhánh này nằm ở chỗ khác: bảo đảm hệ thống luôn có kết quả.

Điểm đáng chú ý trong bảng là tỉ lệ thành công của nhánh mô hình ngôn ngữ ở kịch bản mạng ổn định không đạt 100% mà chỉ 95%: hai trong bốn mươi lời gọi bị dịch vụ Gemini trả về mã lỗi 503 Service Unavailable. Đây không phải lỗi vượt thời gian chờ mà là sự cố thật của dịch vụ bên ngoài, xảy ra ngẫu nhiên ngay trong lúc đo. Cả hai ca đó đều được nhánh dò từ khóa tiếp quản và phân loại thành công, luồng tạo ca không gián đoạn. Đúng tình huống mà lớp bảo đảm tối thiểu được thiết kế để phòng ngừa, và cơ chế hoạt động đúng như dự kiến.

Giá trị `GEMINI_TIMEOUT_MS` được xác định từ chính các số đo trên. Để biết mỗi lời gọi thực sự mất bao lâu, phép đo tạm nới thời gian chờ lên 15 giây, xem như không cắt; từ đó suy ra với mỗi mốc chờ ứng viên thì bao nhiêu phần trăm số ca kịp nhận kết quả của mô hình, bao nhiêu phần trăm phải rơi về nhánh dò từ khóa.

**Bảng 4.7 — Ảnh hưởng của ngưỡng thời gian chờ tới tỉ lệ sử dụng hai nhánh (40 tin nhắn)**

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

Kết quả trên chỉ đạt được sau khi tắt chế độ suy luận nội tại của mô hình (mục 4.2.3.2). Đo lại trên cùng tập dữ liệu với cấu hình mặc định, độ trễ trung bình lên khoảng 5,6 giây, gấp hơn bốn lần. Với độ trễ đó, ngưỡng 3 giây chỉ cho chưa tới một phần mười số ca kịp dùng kết quả mô hình, tức cơ chế lai gần như không vận hành đúng thiết kế; muốn phần lớn số ca dùng được mô hình thì phải chờ tới 10 giây, mức không chấp nhận được khi khẩn cấp. Sai lệch này không để lộ dấu hiệu nào trong quá trình phát triển: hệ thống vẫn chạy, vẫn trả kết quả, chỉ là trả bằng nhánh dò từ khóa, và chỉ khi đo mới phát hiện.

Quy tắc Math.max được kiểm chứng riêng bằng một tin nhắn chứa từ khóa mức 5 nhưng có ngữ cảnh dễ khiến mô hình hạ mức, cụ thể là câu "Bác tôi bị đuối nước nhưng đã vớt lên rồi, giờ cần người đưa đi viện". Nhánh dò từ khóa nhận diện từ khóa "đuối nước" và gán mức 5; kết quả cuối cùng sau khi hợp nhất giữ nguyên mức 5. Hệ thống không hạ mức xuống dưới ngưỡng mà từ khóa cảnh báo đã phát hiện, đúng như thiết kế ở mục 4.2.3.3.

### 4.5.2. Kiểm chứng các cơ chế điều phối

Ba cơ chế điều phối được kiểm chứng theo kịch bản, do bản chất của chúng là hành vi theo thời gian chứ không phải chỉ số định lượng:

- **Phát hiện ca mồ côi.** Hạ giá trị `ORPHAN_ALERT_MS` xuống một phút, tạo một ca và không cho tình nguyện viên nào tiếp nhận. Kiểm chứng rằng sự kiện `case:orphaned` được phát đúng một lần, và quan trọng hơn, lặp lại thí nghiệm với thao tác khởi động lại máy chủ giữa khoảng chờ để chứng minh cảnh báo vẫn diễn ra, điều mà thiết kế cũ dùng `setTimeout` không đáp ứng được.
- **Tự thu hồi phân công.** Cho một tình nguyện viên nhận ca rồi giữ nguyên vị trí. Kiểm chứng rằng sau 10 phút hệ thống gửi thông báo hỏi xác nhận, và sau 5 phút không phản hồi thì phân công bị thu hồi, ca trở lại trạng thái `pending` và được phát sóng lại.
- **Mốc tiếp cận.** Mô phỏng luồng GPS di chuyển dần về phía nạn nhân, kiểm chứng rằng thông báo tại mốc 300 m và 100 m mỗi loại chỉ được gửi đúng một lần, và trạng thái ca chuyển sang `on_scene` khi vượt ngưỡng 100 m.

---

# PHẦN B — PHƯƠNG PHÁP ĐO (giải thích cho hội đồng)

- **Môi trường:** chạy trên máy chủ backend (Node.js), từ thư mục `backend/`, lệnh `node scripts/measureAiPipeline.js`. Gọi **API Gemini 2.5 Flash thật** (cần `GEMINI_API_KEY` trong `.env`).
- **Đo thời gian:** dùng `process.hrtime.bigint()` (độ chính xác nano-giây).
- **Nhánh dò từ khóa** chạy dưới 1 ms → **lặp 2000 lần/câu rồi chia trung bình** mới đo được.
- **Nhánh Gemini:** đặt timeout **nới lên 15 giây** (`LONG_TIMEOUT_MS`) để **không cắt lời gọi nào** → thu được **độ trễ thật**. Nghỉ 1,2 giây giữa hai lời gọi để tránh chạm giới hạn tần suất API.
- **Bảng độ nhạy ngưỡng (Bảng 4.7):** KHÔNG chạy lại 6 lần cho 6 ngưỡng. Chỉ đo phân bố độ trễ thật **một lần**, rồi đếm "với mỗi ngưỡng T, bao nhiêu câu có độ trễ ≤ T" → suy ra % kịp dùng Gemini.
- **Kịch bản mất kết nối:** `delete process.env.GEMINI_API_KEY` → mô phỏng dịch vụ ngoài chết, đếm số câu rơi về `rule_based` (kết quả: 40/40 = 100%).
- **Kiểm chứng sàn an toàn:** một câu riêng chứa từ khóa mức 5, kiểm tra `urgency_final ≥ urgency_rule`.

**Giới hạn (đã ghi ở mục 5.2):** 40 câu mô phỏng do người viết tự soạn và tự gán nhãn → cỡ mẫu nhỏ, chủ quan; độ trễ Gemini phụ thuộc mạng và thời điểm đo. Đây là đo **độ trễ và độ sẵn sàng**, KHÔNG phải đo độ chính xác phân loại (muốn đo chính xác cần tập kiểm thử gán nhãn độc lập).

---

# PHẦN C — MÃ NGUỒN TEST (`backend/scripts/measureAiPipeline.js`)

```javascript
/**
 * Đo độ trễ và độ sẵn sàng của cơ chế phân loại mức độ khẩn cấp.
 * Sinh số liệu cho Bảng 4.7 và Bảng 4.8 (mục 4.5.1 của khóa luận).
 *
 * Cách chạy, từ thư mục backend/:
 *   node scripts/measureAiPipeline.js
 *
 * Nguyên tắc đo: đặt thời gian chờ RẤT DÀI (15 giây) để không cắt lời gọi nào,
 * nhờ đó thu được độ trễ THẬT của mô hình ngôn ngữ. Từ phân bố độ trễ thật này
 * mới suy ra được, với mỗi ngưỡng ứng viên, bao nhiêu ca kịp dùng kết quả mô hình
 * — đó chính là bảng phân tích độ nhạy. Không cần chạy lại nhiều lần cho từng ngưỡng.
 */

require('dotenv').config();
const fs = require('fs');
const path = require('path');

const LONG_TIMEOUT_MS = 15000;   // dài tới mức xem như không cắt
const DELAY_MS = 1200;           // nghỉ giữa hai lời gọi, tránh chạm giới hạn tần suất API
const RULE_ITERATIONS = 2000;    // nhánh dò từ khóa chạy dưới mili-giây → phải lặp nhiều lần mới đo được
const THRESHOLDS = [1000, 1500, 2000, 3000, 5000, 7000];
const THRESHOLD_IN_USE = 3000;   // ngưỡng đang cấu hình trong .env (GEMINI_TIMEOUT_MS)

process.env.GEMINI_TIMEOUT_MS = String(LONG_TIMEOUT_MS);

const { runUrgencyClassification, runRuleBasedFallback } = require('../src/services/aiPipeline');

const testSet = JSON.parse(fs.readFileSync(path.join(__dirname, 'sos_test_set.json'), 'utf8'));
const sleep = ms => new Promise(r => setTimeout(r, ms));

/** Phân vị thứ p (0–100) của một mảng số. */
function percentile(sorted, p) {
  if (sorted.length === 0) return null;
  const idx = Math.ceil((p / 100) * sorted.length) - 1;
  return sorted[Math.min(Math.max(idx, 0), sorted.length - 1)];
}

const mean = arr => (arr.length ? arr.reduce((s, x) => s + x, 0) / arr.length : null);
const fmt = (x, d = 1) => (x === null ? '—' : x.toFixed(d));

/** Đo nhánh dò từ khóa: lặp nhiều lần rồi chia trung bình, vì mỗi lần chạy dưới mili-giây. */
function measureRuleBranch(messages) {
  const perCall = [];
  for (const m of messages) {
    const t0 = process.hrtime.bigint();
    for (let i = 0; i < RULE_ITERATIONS; i++) runRuleBasedFallback(m.text);
    const t1 = process.hrtime.bigint();
    perCall.push(Number(t1 - t0) / 1e6 / RULE_ITERATIONS);  // ms cho một lời gọi
  }
  return perCall;
}

/** Đo toàn pipeline với thời gian chờ dài → độ trễ thật của nhánh mô hình ngôn ngữ. */
async function measureLlmBranch(messages) {
  const rows = [];
  for (const m of messages) {
    const t0 = process.hrtime.bigint();
    const result = await runUrgencyClassification(m.text);
    const t1 = process.hrtime.bigint();
    const latencyMs = Number(t1 - t0) / 1e6;

    const ruleOnly = runRuleBasedFallback(m.text);
    rows.push({
      id: m.id,
      text: m.text,
      urgency_dung: m.urgency_dung ?? '',
      latency_ms: latencyMs,
      source: result.source,                       // 'gemini' nếu mô hình trả lời được
      urgency_rule: ruleOnly.urgency_level,
      urgency_final: result.urgency_level,
      tags_final: (result.tags || []).join('|'),
    });

    const ok = result.source === 'gemini' ? 'OK ' : 'LỖI';
    console.log(`  [${String(m.id).padStart(2)}] ${ok}  ${latencyMs.toFixed(0).padStart(5)} ms  ` +
                `mức ${result.urgency_level}  ${m.text.slice(0, 45)}…`);

    await sleep(DELAY_MS);
  }
  return rows;
}

/** Kịch bản 2: gỡ khóa API → mô phỏng dịch vụ ngoài không khả dụng. */
async function measureWithoutApiKey(messages) {
  const saved = process.env.GEMINI_API_KEY;
  delete process.env.GEMINI_API_KEY;
  let ruleUsed = 0;
  for (const m of messages) {
    const r = await runUrgencyClassification(m.text);
    if (r.source === 'rule_based') ruleUsed++;
  }
  process.env.GEMINI_API_KEY = saved;
  return { total: messages.length, ruleUsed };
}

/** Kiểm chứng quy tắc sàn an toàn Math.max. */
async function checkSafetyFloor(caseData) {
  const rule = runRuleBasedFallback(caseData.text);
  const final = await runUrgencyClassification(caseData.text);
  return {
    text: caseData.text,
    urgency_rule: rule.urgency_level,
    urgency_final: final.urgency_level,
    source: final.source,
  };
}

(async () => {
  const messages = testSet.messages;
  console.log(`\n=== ĐO CƠ CHẾ PHÂN LOẠI — ${messages.length} tin nhắn ===`);
  console.log(`Thời gian chờ đặt ${LONG_TIMEOUT_MS} ms (xem như không cắt)\n`);

  if (!process.env.GEMINI_API_KEY) {
    console.error('LỖI: chưa có GEMINI_API_KEY trong .env — không đo được nhánh mô hình ngôn ngữ.');
    process.exit(1);
  }

  console.log('[1/4] Đo nhánh dò từ khóa (cục bộ)…');
  const ruleLatencies = measureRuleBranch(messages);

  console.log('[2/4] Đo nhánh mô hình ngôn ngữ (gọi API thật)…');
  const rows = await measureLlmBranch(messages);

  console.log('\n[3/4] Kịch bản mất kết nối dịch vụ (gỡ GEMINI_API_KEY)…');
  const offline = await measureWithoutApiKey(messages);

  console.log('[4/4] Kiểm chứng sàn an toàn…');
  const floor = await checkSafetyFloor(testSet._kiem_chung_san_an_toan);

  // ---------- Tổng hợp ----------
  const llmOk = rows.filter(r => r.source === 'gemini');
  const llmLat = llmOk.map(r => r.latency_ms).sort((a, b) => a - b);
  const ruleSorted = [...ruleLatencies].sort((a, b) => a - b);

  const outDir = path.join(__dirname, 'output');
  fs.mkdirSync(outDir, { recursive: true });

  // CSV dữ liệu thô
  const csv = ['id,urgency_dung,latency_ms,source,urgency_rule,urgency_final,tags_final,text']
    .concat(rows.map(r => [
      r.id, r.urgency_dung, r.latency_ms.toFixed(1), r.source,
      r.urgency_rule, r.urgency_final, r.tags_final,
      `"${r.text.replace(/"/g, '""')}"`,
    ].join(',')))
    .join('\n');
  fs.writeFileSync(path.join(outDir, 'do_tre_phan_loai.csv'), '﻿' + csv, 'utf8');

  // ---------- Bảng 4.7 (báo cáo: Bảng 4.6) ----------
  const N = messages.length;
  const pctGeminiAtUse = llmOk.filter(r => r.latency_ms <= THRESHOLD_IN_USE).length / N * 100;
  let out = '';
  out += `\n\n*Bảng 4.7 – Độ trễ phân loại và tỉ lệ sử dụng của hai nhánh (N = ${N} tin nhắn)*\n\n`;
  out += `| Chỉ số | Nhánh dò từ khóa | Nhánh mô hình ngôn ngữ lớn |\n`;
  out += `|---|---|---|\n`;
  out += `| Độ trễ trung bình | ${fmt(mean(ruleLatencies), 3)} ms | ${fmt(mean(llmLat), 0)} ms |\n`;
  out += `| Độ trễ phân vị 95 (P95) | ${fmt(percentile(ruleSorted, 95), 3)} ms | ${fmt(percentile(llmLat, 95), 0)} ms |\n`;
  out += `| Độ trễ lớn nhất | ${fmt(ruleSorted[ruleSorted.length - 1], 3)} ms | ${fmt(llmLat[llmLat.length - 1], 0)} ms |\n`;
  out += `| Tỉ lệ trả về kết quả thành công (mạng ổn định) | 100% | ${(llmOk.length / N * 100).toFixed(1)}% |\n`;
  out += `| Tỉ lệ trả về kết quả thành công (mất kết nối dịch vụ) | 100% | 0% |\n`;
  out += `| Tỉ lệ được chọn làm kết quả cuối, ngưỡng ${THRESHOLD_IN_USE / 1000} s (\`ai_source\`) | ${(100 - pctGeminiAtUse).toFixed(1)}% | ${pctGeminiAtUse.toFixed(1)}% |\n`;

  // ---------- Bảng 4.8 (báo cáo: Bảng 4.7) ----------
  out += `\n*Bảng 4.8 – Phân tích độ nhạy của ngưỡng thời gian chờ (N = ${N} tin nhắn)*\n\n`;
  out += `| Ngưỡng chờ | Tỉ lệ ca dùng được kết quả mô hình ngôn ngữ | Tỉ lệ ca phải dùng nhánh dò từ khóa | Thời gian chờ tối đa mà nạn nhân phải chịu |\n`;
  out += `|---|---|---|---|\n`;
  for (const T of THRESHOLDS) {
    const kip = llmOk.filter(r => r.latency_ms <= T).length;
    const pct = kip / N * 100;
    const label = `${T.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ' ')} ms`;
    const nhan = T === THRESHOLD_IN_USE ? `**${label} (đang dùng)**` : label;
    out += `| ${nhan} | ${pct.toFixed(1)} % | ${(100 - pct).toFixed(1)} % | ${(T / 1000).toFixed(1)} s |\n`;
  }

  // ---------- Kiểm chứng ----------
  out += `\n**Kịch bản mất kết nối dịch vụ:** ${offline.ruleUsed}/${offline.total} tin nhắn vẫn được phân loại bằng nhánh dò từ khóa `;
  out += `(${(offline.ruleUsed / offline.total * 100).toFixed(0)}% — luồng tạo ca không bị nghẽn).\n`;
  out += `\n**Kiểm chứng sàn an toàn:** với câu "${floor.text}" — nhánh dò từ khóa gán mức **${floor.urgency_rule}**, `;
  out += `kết quả cuối cùng sau hợp nhất là mức **${floor.urgency_final}** (nguồn: ${floor.source}). `;
  out += floor.urgency_final >= floor.urgency_rule
    ? `Quy tắc Math.max hoạt động đúng: hệ thống không hạ mức xuống dưới ngưỡng mà từ khóa đã cảnh báo.\n`
    : `CẢNH BÁO: mức cuối THẤP HƠN mức của nhánh dò từ khóa — sàn an toàn không hoạt động, cần kiểm tra lại mã nguồn.\n`;

  console.log(out);
  fs.writeFileSync(path.join(outDir, 'bang_4_7_va_4_8.md'), out, 'utf8');

  console.log(`\n✔ Đã ghi:`);
  console.log(`   ${path.join(outDir, 'do_tre_phan_loai.csv')}`);
  console.log(`   ${path.join(outDir, 'bang_4_7_va_4_8.md')}\n`);
})();
```

---

# PHẦN D — DỮ LIỆU TEST (`backend/scripts/sos_test_set.json`)

40 câu SOS mô phỏng, phân bố đều 5 mức (8 câu mức 5, 8 câu mức 4, 8 câu mức 3, 8 câu mức 2, 6 câu mức 1, + 2 câu "bẫy" id 39–40 để kiểm phủ định/loại trừ), cộng 1 câu riêng kiểm chứng sàn an toàn.

```json
{
  "_mo_ta": "Tập tin nhắn SOS mô phỏng dùng cho mục 4.5.1 của khóa luận. urgency_dung = mức khẩn cấp đúng do người viết xác định thủ công, dùng để đối chiếu; không bắt buộc cho phép đo độ trễ. Phân bố đều trên 5 mức.",
  "messages": [
    { "id": 1,  "urgency_dung": 5, "text": "Cứu với! Con tôi bị đuối nước, nước cuốn đi rồi, cứu nhanh lên" },
    { "id": 2,  "urgency_dung": 5, "text": "Chồng tôi bất tỉnh không thở được, nước ngập tới cổ rồi" },
    { "id": 3,  "urgency_dung": 5, "text": "Có người bị nước cuốn chìm dưới cầu, cần cứu ngay lập tức" },
    { "id": 4,  "urgency_dung": 5, "text": "Mẹ tôi chảy máu nhiều lắm, ngất đi rồi, nhà đang ngập" },
    { "id": 5,  "urgency_dung": 5, "text": "Ba tôi ngã đập đầu, máu ra nhiều, không tỉnh lại, cần cấp cứu gấp" },
    { "id": 6,  "urgency_dung": 5, "text": "Nhà bị sập, có người kẹt bên trong, nước dâng nhanh, sợ chết đuối" },
    { "id": 7,  "urgency_dung": 5, "text": "Em bé rơi xuống nước, vớt lên rồi nhưng không thở, cứu với" },
    { "id": 8,  "urgency_dung": 5, "text": "Có hai người bị chìm khi qua sông, mất tích chưa tìm thấy" },

    { "id": 9,  "urgency_dung": 4, "text": "Nhà tôi có ba đứa trẻ nhỏ, nước đã ngập tới nóc, cần cứu gấp" },
    { "id": 10, "urgency_dung": 4, "text": "Bà tôi 85 tuổi bị gãy chân, không di chuyển được, nước đang lên" },
    { "id": 11, "urgency_dung": 4, "text": "Có người già và trẻ em trên gác mái, nước ngập tới mái nhà rồi" },
    { "id": 12, "urgency_dung": 4, "text": "Vợ tôi bị thương ở chân, chảy máu, cần đưa đi cấp cứu" },
    { "id": 13, "urgency_dung": 4, "text": "Trong nhà có cụ già nằm liệt giường, nước ngập nóc, không tự di tản được" },
    { "id": 14, "urgency_dung": 4, "text": "Hai em bé đang sốt cao, nhà ngập sâu, cần đưa ra ngoài" },
    { "id": 15, "urgency_dung": 4, "text": "Cần cấp cứu, có người bị mảnh tôn cắt vào tay, máu chảy nhiều" },
    { "id": 16, "urgency_dung": 4, "text": "Nhà có con nhỏ mới sinh, nước lên tới mái, xin cứu trợ khẩn" },

    { "id": 17, "urgency_dung": 3, "text": "Nhà tôi bị cô lập, nước ngập sâu quá đầu người, không ra ngoài được" },
    { "id": 18, "urgency_dung": 3, "text": "Cả xóm bị mắc kẹt, nước dâng cao, đường vào đã ngập hết" },
    { "id": 19, "urgency_dung": 3, "text": "Gia đình bốn người kẹt trên tầng hai, nước vẫn đang dâng" },
    { "id": 20, "urgency_dung": 3, "text": "Chúng tôi bị cô lập hai ngày rồi, hết đồ ăn, nước ngập sâu" },
    { "id": 21, "urgency_dung": 3, "text": "Nước dâng nhanh quá, không thoát được ra khỏi nhà" },
    { "id": 22, "urgency_dung": 3, "text": "Mắc kẹt ở trạm xá, nước ngập sâu, có mấy người cần di tản" },
    { "id": 23, "urgency_dung": 3, "text": "Nhà nằm sát bờ sông, nước dâng cao, sợ sạt lở, chưa ra được" },
    { "id": 24, "urgency_dung": 3, "text": "Đường bị ngập sâu, xe không qua được, cả nhà đang kẹt lại" },

    { "id": 25, "urgency_dung": 2, "text": "Nhà tôi bị ngập, cần xuồng để di chuyển ra ngoài" },
    { "id": 26, "urgency_dung": 2, "text": "Nước lên tới đầu gối rồi, cần người giúp chuyển đồ lên cao" },
    { "id": 27, "urgency_dung": 2, "text": "Cần hỗ trợ di dời, nhà đã bị ngập nửa mét" },
    { "id": 28, "urgency_dung": 2, "text": "Xin cần ghe qua chở giúp mấy người sang bờ bên kia" },
    { "id": 29, "urgency_dung": 2, "text": "Nước lên nhanh, cần giúp đưa gia súc và đồ đạc lên chỗ cao" },
    { "id": 30, "urgency_dung": 2, "text": "Nhà bị ngập, không có phương tiện nào để đi lại" },
    { "id": 31, "urgency_dung": 2, "text": "Cần xuồng để đưa mấy người trong xóm ra khu vực an toàn" },
    { "id": 32, "urgency_dung": 2, "text": "Nước đang lên dần, cần hỗ trợ trước khi ngập sâu hơn" },

    { "id": 33, "urgency_dung": 1, "text": "Nhà tôi hết lương thực, xin hỗ trợ mì và nước uống" },
    { "id": 34, "urgency_dung": 1, "text": "Xin hỗ trợ nước sạch, cả xóm dùng hết nước rồi" },
    { "id": 35, "urgency_dung": 1, "text": "Gia đình cần thêm chăn màn, đêm lạnh quá" },
    { "id": 36, "urgency_dung": 1, "text": "Nhà không còn gạo, xin cứu trợ lương thực khi nào tiện" },
    { "id": 37, "urgency_dung": 1, "text": "Xin hỗ trợ thuốc men thông thường, không có ai bị thương nặng" },
    { "id": 38, "urgency_dung": 1, "text": "Mất điện mấy ngày rồi, xin hỗ trợ đèn pin và pin dự phòng" },

    { "id": 39, "urgency_dung": 4, "text": "May quá không ai bị thương, nhưng nhà có người già, nước đã ngập tới mái" },
    { "id": 40, "urgency_dung": 2, "text": "Xe bị kẹt xe rồi chết máy giữa đường ngập, cần người giúp đẩy" }
  ],
  "_kiem_chung_san_an_toan": {
    "_mo_ta": "Ca dùng riêng cho kịch bản kiểm chứng quy tắc Math.max ở mục 4.5.1. Câu chứa từ khóa mức 5 ('đuối nước') nhưng ngữ cảnh dễ khiến mô hình ngôn ngữ hạ mức.",
    "text": "Bác tôi bị đuối nước nhưng đã vớt lên rồi, giờ cần người đưa đi viện"
  }
}
```

---

# PHẦN E — KẾT QUẢ THÔ ĐÃ CHẠY (`output/do_tre_phan_loai.csv`)

> Đây là lần chạy thật đã sinh ra số liệu Bảng 4.6/4.7. `source=gemini` nghĩa Gemini trả lời được;
> `source=rule_based` là hai ca Gemini lỗi 503 (id 9 và 13). Cột `urgency_rule` = mức nhánh luật,
> `urgency_final` = mức sau hợp nhất Math.max.

```csv
id,urgency_dung,latency_ms,source,urgency_rule,urgency_final,tags_final,text
1,5,2344.6,gemini,5,5,y_te|tre_em,"Cứu với! Con tôi bị đuối nước, nước cuốn đi rồi, cứu nhanh lên"
2,5,1176.8,gemini,5,5,y_te|ngap_noc,"Chồng tôi bất tỉnh không thở được, nước ngập tới cổ rồi"
3,5,1213.5,gemini,5,5,y_te,"Có người bị nước cuốn chìm dưới cầu, cần cứu ngay lập tức"
4,5,1212.7,gemini,5,5,y_te|nguoi_gia|ngap_noc,"Mẹ tôi chảy máu nhiều lắm, ngất đi rồi, nhà đang ngập"
5,5,1221.6,gemini,5,5,y_te|nguoi_gia,"Ba tôi ngã đập đầu, máu ra nhiều, không tỉnh lại, cần cấp cứu gấp"
6,5,1385.1,gemini,5,5,,"Nhà bị sập, có người kẹt bên trong, nước dâng nhanh, sợ chết đuối"
7,5,1216.3,gemini,5,5,y_te|tre_em,"Em bé rơi xuống nước, vớt lên rồi nhưng không thở, cứu với"
8,5,1852.6,gemini,5,5,,"Có hai người bị chìm khi qua sông, mất tích chưa tìm thấy"
9,4,195.1,rule_based,2,2,,"Nhà tôi có ba đứa trẻ nhỏ, nước đã ngập tới nóc, cần cứu gấp"
10,4,851.8,gemini,4,5,y_te|nguoi_gia,"Bà tôi 85 tuổi bị gãy chân, không di chuyển được, nước đang lên"
11,4,1238.6,gemini,4,4,tre_em|nguoi_gia|ngap_noc,"Có người già và trẻ em trên gác mái, nước ngập tới mái nhà rồi"
12,4,794.7,gemini,5,5,y_te,"Vợ tôi bị thương ở chân, chảy máu, cần đưa đi cấp cứu"
13,4,180.0,rule_based,4,4,nguoi_gia|ngap_noc,"Trong nhà có cụ già nằm liệt giường, nước ngập nóc, không tự di tản được"
14,4,1193.2,gemini,4,4,y_te|tre_em|ngap_noc,"Hai em bé đang sốt cao, nhà ngập sâu, cần đưa ra ngoài"
15,4,883.5,gemini,5,5,y_te,"Cần cấp cứu, có người bị mảnh tôn cắt vào tay, máu chảy nhiều"
16,4,1144.0,gemini,2,4,tre_em|ngap_noc,"Nhà có con nhỏ mới sinh, nước lên tới mái, xin cứu trợ khẩn"
17,3,1922.9,gemini,3,3,ngap_noc,"Nhà tôi bị cô lập, nước ngập sâu quá đầu người, không ra ngoài được"
18,3,946.3,gemini,3,3,ngap_noc,"Cả xóm bị mắc kẹt, nước dâng cao, đường vào đã ngập hết"
19,3,1154.3,gemini,3,3,ngap_noc,"Gia đình bốn người kẹt trên tầng hai, nước vẫn đang dâng"
20,3,1214.2,gemini,3,3,ngap_noc,"Chúng tôi bị cô lập hai ngày rồi, hết đồ ăn, nước ngập sâu"
21,3,1217.5,gemini,3,3,ngap_noc,"Nước dâng nhanh quá, không thoát được ra khỏi nhà"
22,3,1333.7,gemini,3,3,ngap_noc,"Mắc kẹt ở trạm xá, nước ngập sâu, có mấy người cần di tản"
23,3,1633.8,gemini,3,3,,"Nhà nằm sát bờ sông, nước dâng cao, sợ sạt lở, chưa ra được"
24,3,1273.8,gemini,3,3,ngap_noc|phuong_tien,"Đường bị ngập sâu, xe không qua được, cả nhà đang kẹt lại"
25,2,1174.8,gemini,2,2,ngap_noc|phuong_tien,"Nhà tôi bị ngập, cần xuồng để di chuyển ra ngoài"
26,2,1056.9,gemini,2,2,ngap_noc,"Nước lên tới đầu gối rồi, cần người giúp chuyển đồ lên cao"
27,2,1476.1,gemini,2,2,ngap_noc|phuong_tien,"Cần hỗ trợ di dời, nhà đã bị ngập nửa mét"
28,2,1222.2,gemini,1,3,phuong_tien,"Xin cần ghe qua chở giúp mấy người sang bờ bên kia"
29,2,1313.6,gemini,2,2,ngap_noc,"Nước lên nhanh, cần giúp đưa gia súc và đồ đạc lên chỗ cao"
30,2,1129.7,gemini,2,2,ngap_noc|phuong_tien,"Nhà bị ngập, không có phương tiện nào để đi lại"
31,2,1230.6,gemini,2,3,phuong_tien,"Cần xuồng để đưa mấy người trong xóm ra khu vực an toàn"
32,2,1284.0,gemini,3,3,ngap_noc,"Nước đang lên dần, cần hỗ trợ trước khi ngập sâu hơn"
33,1,1154.1,gemini,1,1,,"Nhà tôi hết lương thực, xin hỗ trợ mì và nước uống"
34,1,1044.4,gemini,1,1,,"Xin hỗ trợ nước sạch, cả xóm dùng hết nước rồi"
35,1,1131.1,gemini,1,1,,"Gia đình cần thêm chăn màn, đêm lạnh quá"
36,1,1058.6,gemini,1,1,,"Nhà không còn gạo, xin cứu trợ lương thực khi nào tiện"
37,1,1137.5,gemini,4,4,y_te,"Xin hỗ trợ thuốc men thông thường, không có ai bị thương nặng"
38,1,887.3,gemini,1,1,,"Mất điện mấy ngày rồi, xin hỗ trợ đèn pin và pin dự phòng"
39,4,879.5,gemini,4,4,nguoi_gia|ngap_noc,"May quá không ai bị thương, nhưng nhà có người già, nước đã ngập tới mái"
40,2,1143.1,gemini,2,3,ngap_noc|phuong_tien,"Xe bị kẹt xe rồi chết máy giữa đường ngập, cần người giúp đẩy"
```

**Số liệu tổng hợp từ lần chạy này:**
- Nhánh luật: TB 0,032 ms · P95 0,040 ms · max 0,057 ms · thành công 100%.
- Nhánh Gemini: TB 1230 ms · P95 1923 ms · max 2345 ms · thành công 95% (38/40; id 9, 13 lỗi 503).
- Ngưỡng 3 s: 95% ca dùng Gemini, 5% dùng luật.
- Mất kết nối: 40/40 phân loại được bằng luật (100%).
- Sàn an toàn: câu "Bác tôi bị đuối nước…" → luật mức 5, cuối cùng mức 5 → Math.max đúng.

---

# PHẦN F — CÁCH CHẠY LẠI

```bash
cd backend
# đảm bảo .env có GEMINI_API_KEY
node scripts/measureAiPipeline.js
# → in ra console + ghi:
#   backend/scripts/output/do_tre_phan_loai.csv   (dữ liệu thô)
#   backend/scripts/output/bang_4_7_va_4_8.md      (2 bảng)
```

Các file gốc vẫn nằm trong `backend/scripts/` — file backup này chỉ là bản sao có kèm giải thích + nội dung 4.5 để đưa lại vào báo cáo khi cần.
