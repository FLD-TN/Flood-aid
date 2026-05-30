/**
 * AI Pipeline Service — Module 1
 */

const URGENCY_KEYWORDS = {
  5: ['máu', 'bất tỉnh', 'không thở', 'chết', 'chìm', 'đuối nước'],
  4: ['trẻ em', 'em bé', 'người già', 'ngập nóc', 'mái nhà', 'bị thương', 'gãy', 'cấp cứu'],
  3: ['ngập sâu', 'nước dâng', 'kẹt', 'không thoát được', 'mắc kẹt', 'cô lập'],
  2: ['ngập', 'cần xuồng', 'cần giúp', 'nước lên', 'cần hỗ trợ'],
};

const TAG_KEYWORDS = {
  y_te: ['máu', 'bất tỉnh', 'chấn thương', 'bị thương', 'không thở', 'cấp cứu', 'gãy'],
  tre_em: ['trẻ em', 'em bé', 'con nít', 'trẻ con', 'con nhỏ'],
  nguoi_gia: ['người già', 'ông', 'bà', 'cụ', 'cao tuổi'],
  ngap_noc: ['ngập nóc', 'nước đến nóc', 'ngập tới mái', 'nước ngập mái'],
  phuong_tien: ['cần xuồng', 'cần thuyền', 'không có phương tiện', 'cần ghe'],
};

/**
 * Rule-based fallback — chạy local, ~0ms latency
 * Luôn có kết quả, không bao giờ throw error
 */
function runRuleBasedFallback(text) {
  const lower = text.toLowerCase();

  // Tính urgency level
  let urgency = 1;
  for (const [level, words] of Object.entries(URGENCY_KEYWORDS)) {
    if (words.some(w => lower.includes(w))) {
      urgency = Math.max(urgency, Number(level));
    }
  }

  // Tính tags
  const tags = Object.entries(TAG_KEYWORDS)
    .filter(([, words]) => words.some(w => lower.includes(w)))
    .map(([tag]) => tag);

  // Summary đơn giản: cắt 80 ký tự
  const summary = text.length > 80 ? text.slice(0, 77) + '...' : text;

  return {
    urgency_level: urgency,
    tags,
    summary_1line: summary,
    source: 'rule_based',
  };
}

/**
 * Gemini AI call với timeout cứng
 * Chỉ hoạt động khi có GEMINI_API_KEY
 */
async function callGeminiWithTimeout(text) {
  if (!process.env.GEMINI_API_KEY) {
    throw new Error('GEMINI_API_KEY not configured');
  }

  // Lazy require — chỉ load khi cần
  const { GoogleGenerativeAI } = require('@google/generative-ai');
  const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
  const model = genAI.getGenerativeModel({
    model: 'gemini-2.5-flash',
    generationConfig: {
      responseMimeType: 'application/json',  // Force JSON output
      temperature: 0.1,  // Deterministic cho classification
    },
  });
  const prompt = `
Bạn là hệ thống AI phân loại tin nhắn SOS trong thiên tai lũ lụt tại Việt Nam.
Phân tích yêu cầu cứu trợ sau:
"${text}"

Trả về JSON với format chính xác:
{
  "urgency_level": <1-5>,
  "tags": <mảng các tag từ: y_te, tre_em, nguoi_gia, ngap_noc, phuong_tien>,
  "summary_1line": <tóm tắt tối đa 80 ký tự cho notification>
}

Thang urgency:
  1 = Ít khẩn cấp (cần hỗ trợ lương thực, nước uống)
  2 = Khẩn cấp thấp (ngập nhẹ, cần di dời)
  3 = Khẩn cấp TB (mắc kẹt, nước dâng cao, cô lập)
  4 = Khẩn cấp cao (trẻ em/người già, bị thương, ngập nóc)
  5 = Cực kỳ nguy hiểm (đuối nước, bất tỉnh, nguy hiểm tính mạng)

Ví dụ:
Input: "Cứu tôi với, nước ngập tới nóc nhà, có 2 em nhỏ"
Output: {"urgency_level":4,"tags":["ngap_noc","tre_em"],"summary_1line":"Ngập nóc nhà, 2 trẻ em cần cứu hộ khẩn cấp"}

Input: "Bà tôi 80 tuổi bị ngã gãy chân, nước đang lên"
Output: {"urgency_level":5,"tags":["y_te","nguoi_gia"],"summary_1line":"Cụ bà 80 tuổi gãy chân, nước đang dâng"}

Chỉ trả về JSON, không giải thích thêm.
`;

  const timeoutMs = parseInt(process.env.GEMINI_TIMEOUT_MS) || 3000;
  const timeoutPromise = new Promise((_, reject) =>
    setTimeout(() => reject(new Error('GEMINI_TIMEOUT')), timeoutMs)
  );

  const geminiPromise = (async () => {
    const result = await model.generateContent(prompt);
    const raw = result.response.text().trim().replace(/```json|```/g, '');
    let parsed;
    try {
      parsed = JSON.parse(raw);
    } catch (parseErr) {
      // Gemini trả về text không phải JSON → fallback
      console.warn('[aiPipeline] Gemini returned invalid JSON:', raw.slice(0, 100));
      throw new Error('GEMINI_INVALID_JSON');
    }

    // Validate schema
    if (!parsed.urgency_level || !Array.isArray(parsed.tags) || !parsed.summary_1line) {
      throw new Error('GEMINI_INVALID_SCHEMA');
    }

    // Clamp urgency vào range 1-5
    parsed.urgency_level = Math.max(1, Math.min(5, parsed.urgency_level));

    return { ...parsed, source: 'gemini' };
  })();


  return Promise.race([geminiPromise, timeoutPromise]);
}

/**
 * MAIN: Parallel Race Pipeline
 * Rule-based chạy ngay (sync), Gemini chạy song song (async)
 * Dùng kết quả Gemini nếu có, fallback Rule-based nếu timeout/error
 * urgency_level của Rule-based luôn là baseline tối thiểu
 */
async function runParallelAiPipeline(text) {
  // Rule-based: instant, không bao giờ fail
  const ruleResult = runRuleBasedFallback(text);

  let aiResult = null;
  try {
    aiResult = await callGeminiWithTimeout(text);
  } catch (err) {
    console.warn('[aiPipeline] Gemini unavailable:', err.message, '→ using rule-based');
  }

  // Dùng Gemini nếu có, fallback sang Rule-based
  const final = aiResult || ruleResult;

  // Safety: Rule-based urgency làm baseline tối thiểu
  final.urgency_level = Math.max(final.urgency_level, ruleResult.urgency_level);

  // Merge tags nếu Rule-based phát hiện thêm
  if (aiResult && ruleResult.tags.length > 0) {
    const mergedTags = [...new Set([...final.tags, ...ruleResult.tags])];
    final.tags = mergedTags;
  }

  return final;
}

module.exports = { runParallelAiPipeline, runRuleBasedFallback };

