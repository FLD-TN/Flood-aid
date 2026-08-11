/**
 * STT Controller — nhận audio, gọi Gemini chép lời (giữ phương ngữ), trả text thô.
 * Việc chuẩn hóa (dict) để app tự làm trên máy — giữ 1 nguồn từ điển duy nhất ở mobile.
 */

const { transcribeAudio } = require('../services/geminiStt');

/**
 * POST /api/stt
 * Body: { audio: <base64>, mimeType?: 'audio/mp4' }
 * Trả:  { text: '<câu đã chép, còn giữ phương ngữ>' }
 */
async function transcribe(req, res) {
  try {
    const { audio, mimeType } = req.body || {};
    if (!audio || typeof audio !== 'string') {
      return res.status(400).json({ error: 'Thiếu dữ liệu audio (base64)' });
    }
    const text = await transcribeAudio(audio, mimeType || 'audio/mp4');
    return res.json({ text });
  } catch (err) {
    console.error('[sttController] Lỗi:', err.message);
    return res.status(500).json({ error: 'Không nhận dạng được giọng nói' });
  }
}

module.exports = { transcribe };
