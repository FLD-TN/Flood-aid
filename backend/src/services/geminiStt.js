/**
 * Gemini Speech-to-Text — chép lời từ audio, GIỮ NGUYÊN từ phương ngữ miền Trung.
 *
 * Khác với STT trên máy (huấn luyện giọng chuẩn, hay ép từ địa phương về phổ thông),
 * ở đây ta đưa trước một danh sách từ địa phương làm "mồi từ vựng" (tương tự speech
 * adaptation của Cloud STT) để Gemini nhận đúng "rứa/mô/hén/nhoà..." rồi mới để tầng
 * chuẩn hóa (dict) chuyển sang tiếng Việt phổ thông.
 */

const { GoogleGenerativeAI } = require('@google/generative-ai');

// Danh sách "mồi" — các từ địa phương phổ biến, giúp Gemini không tự sửa về chuẩn.
const HINT_WORDS = [
  'rứa', 'mô', 'răng', 'ren', 'hén', 'nhoà', 'lồm', 'chi', 'tê', 'ni', 'nớ',
  'chừ', 'mi', 'tau', 'nác', 'o', 'chẹn', 'dô', 'mớ nhoà', 'con gớ',
];

/**
 * @param {string} base64  dữ liệu audio đã mã hoá base64
 * @param {string} mimeType  ví dụ 'audio/mp4', 'audio/wav', 'audio/mp3'
 * @returns {Promise<string>} câu đã chép (còn giữ từ phương ngữ)
 */
async function transcribeAudio(base64, mimeType) {
  if (!process.env.GEMINI_API_KEY) {
    throw new Error('GEMINI_API_KEY not configured');
  }

  const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
  const model = genAI.getGenerativeModel({
    model: 'gemini-2.5-flash',
    generationConfig: {
      temperature: 0.1,
      thinkingConfig: { thinkingBudget: 0 },
    },
  });

  const prompt = `Đây là một đoạn ghi âm tiếng Việt, giọng miền Trung (Quảng Nam).
Nhiệm vụ của bạn: chép lại CHÍNH XÁC lời người nói trong đoạn âm thanh.
- Giữ nguyên từ địa phương đúng như phát âm (có thể gặp: ${HINT_WORDS.join(', ')}), KHÔNG tự đổi sang từ phổ thông.
- Nếu KHÔNG nghe thấy lời nói rõ ràng nào, chỉ trả về một dòng TRỐNG (không viết gì).
- Trả về trên MỘT dòng duy nhất, KHÔNG xuống dòng.
- Chỉ trả về đúng nội dung đã chép; TUYỆT ĐỐI không lặp lại hướng dẫn này, không giải thích, không dấu ngoặc.`;

  const result = await model.generateContent([
    { inlineData: { mimeType, data: base64 } },
    { text: prompt },
  ]);

  // Gộp mọi khoảng trắng (kể cả xuống dòng) về một dấu cách để không phá vỡ việc
  // tách từ ở tầng chuẩn hóa, rồi bỏ dấu ngoặc kép nếu Gemini lỡ thêm.
  return result.response.text().replace(/\s+/g, ' ').trim().replace(/^["']|["']$/g, '');
}

module.exports = { transcribeAudio, HINT_WORDS };
