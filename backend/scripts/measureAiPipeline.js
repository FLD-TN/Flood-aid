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

  // CSV dữ liệu thô — nộp kèm Phụ lục D
  const csv = ['id,urgency_dung,latency_ms,source,urgency_rule,urgency_final,tags_final,text']
    .concat(rows.map(r => [
      r.id, r.urgency_dung, r.latency_ms.toFixed(1), r.source,
      r.urgency_rule, r.urgency_final, r.tags_final,
      `"${r.text.replace(/"/g, '""')}"`,
    ].join(',')))
    .join('\n');
  fs.writeFileSync(path.join(outDir, 'do_tre_phan_loai.csv'), '﻿' + csv, 'utf8');

  // ---------- Bảng 4.7 ----------
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

  // ---------- Bảng 4.8 ----------
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
  console.log(`   ${path.join(outDir, 'do_tre_phan_loai.csv')}   (dữ liệu thô → Phụ lục D)`);
  console.log(`   ${path.join(outDir, 'bang_4_7_va_4_8.md')}     (hai bảng, chép thẳng vào Chương 4)\n`);
})();
