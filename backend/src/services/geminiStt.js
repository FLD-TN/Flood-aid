/**
 * Gemini Speech-to-Text — chép lời từ audio, GIỮ NGUYÊN từ phương ngữ miền Trung.
 *
 * Khác với STT trên máy (huấn luyện giọng chuẩn, hay ép từ địa phương về phổ thông),
 * ở đây ta đưa trước một danh sách từ địa phương làm "mồi từ vựng" (tương tự speech
 * adaptation của Cloud STT) để Gemini nhận đúng "rứa/mô/hén/nhoà..." rồi mới để tầng
 * chuẩn hóa (dict) chuyển sang tiếng Việt phổ thông.
 */

const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFile } = require('child_process');
const ffmpegPath = require('ffmpeg-static');
const { GoogleGenerativeAI } = require('@google/generative-ai');

/**
 * Chuyển audio sang mp3 bằng ffmpeg. Chrome (web) ghi webm/opus nhưng thường THIẾU
 * header duration → Gemini không giải mã được (trả rỗng). Đưa qua ffmpeg vừa sửa
 * header vừa đổi sang mp3 — định dạng Gemini chắc chắn nhận.
 */
function _transcodeToMp3(inputBuffer, inExt) {
  return new Promise((resolve, reject) => {
    const base = path.join(
      os.tmpdir(), `stt_${Date.now()}_${Math.random().toString(36).slice(2)}`);
    const inFile = `${base}.${inExt}`;
    const outFile = `${base}.mp3`;
    fs.writeFileSync(inFile, inputBuffer);
    execFile(ffmpegPath, ['-y', '-i', inFile, '-f', 'mp3', outFile], (err) => {
      try { fs.unlinkSync(inFile); } catch (_) {}
      if (err) return reject(err);
      fs.readFile(outFile, (e, data) => {
        try { fs.unlinkSync(outFile); } catch (_) {}
        if (e) return reject(e);
        resolve(data);
      });
    });
  });
}

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
      // Bật suy luận nội tại để phân biệt các từ ngắn dễ nhầm (mi/mì, nác/nát...).
      // STT không nằm dưới ngưỡng chờ 3s như phân loại nên chấp nhận trễ thêm ~1-2s.
      thinkingConfig: { thinkingBudget: 512 },
    },
  });

  const prompt = `Bạn nghe một đoạn ghi âm giọng QUẢNG NAM (miền Trung), người dân báo tin trong tình huống LŨ LỤT khẩn cấp.
Hãy chép lại lời nói, GIỮ dạng phương ngữ, nhưng DÙNG NGỮ CẢNH cứu hộ để chọn đúng ở các cặp DỄ NHẦM:
- "mi" (=mày/bạn) KHÔNG phải "mì"
- "nác" (=nóc nhà) KHÔNG phải "nát"
- "moà" (=mà) KHÔNG phải "mò"
- "hén" (=nó) KHÔNG phải "hán/háng/hắn"
- "tau" (=tao) KHÔNG phải "tàu"
- "trơ" (con trơ/thằng trơ) KHÔNG phải "trê/ghế"
- "chừ" (=giờ) KHÔNG phải "trừ"
- Từ địa phương khác cứ giữ nguyên: ${HINT_WORDS.join(', ')}.
Ưu tiên cách hiểu HỢP LÝ trong bối cảnh nhà/nước/nóc/cứu/kẹt.
- Nếu KHÔNG nghe rõ lời nào, trả về một dòng TRỐNG.
- Chỉ trả về đúng nội dung đã chép trên MỘT dòng, KHÔNG lặp lại hướng dẫn, không giải thích, không dấu ngoặc.`;

  // Chuẩn hóa định dạng: webm/ogg (thường từ web) → mp3 để Gemini đọc chắc chắn.
  let mime = mimeType || 'audio/mp4';
  let data = base64;
  if (mime.includes('webm') || mime.includes('ogg')) {
    try {
      const mp3 = await _transcodeToMp3(Buffer.from(base64, 'base64'), 'webm');
      data = mp3.toString('base64');
      mime = 'audio/mp3';
    } catch (e) {
      console.warn('[geminiStt] Transcode webm→mp3 lỗi, gửi nguyên bản:', e.message);
    }
  }

  const result = await model.generateContent([
    { inlineData: { mimeType: mime, data } },
    { text: prompt },
  ]);

  // Gộp mọi khoảng trắng (kể cả xuống dòng) về một dấu cách để không phá vỡ việc
  // tách từ ở tầng chuẩn hóa, rồi bỏ dấu ngoặc kép nếu Gemini lỡ thêm.
  return result.response.text().replace(/\s+/g, ' ').trim().replace(/^["']|["']$/g, '');
}

module.exports = { transcribeAudio, HINT_WORDS };
