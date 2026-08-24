/**
 * Test nhanh: đưa 1 file ghi âm giọng miền Trung -> Gemini chép lời (giữ phương ngữ)
 * -> chuẩn hóa bằng dict -> in ra để so sánh.
 *
 * Cách dùng:
 *   node backend/scripts/testGeminiStt.js "duong-dan-file-ghi-am.m4a"
 *
 * Hỗ trợ: .m4a .mp3 .wav .aac .ogg .flac .webm .mp4
 */

const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });
const fs = require('fs');
const { transcribeAudio } = require('../src/services/geminiStt');

// ---- Bản port JS của mobile/lib/services/dialect_normalizer.dart ----
const DICT = (() => {
  const raw = fs.readFileSync(
    path.join(__dirname, '../../mobile/assets/dialect_dict.json'), 'utf8');
  const m = JSON.parse(raw);
  const d = {};
  for (const k in m) d[k.toLowerCase()] = String(m[k]);
  return d;
})();

const PUNCT = new Set(",.;:!?\"'“”‘’()[]{}…-–—/\\`~@#$%^&*_+=|<>".split(''));
function splitPunct(w) {
  let s = 0, e = w.length;
  while (s < e && PUNCT.has(w[s])) s++;
  while (e > s && PUNCT.has(w[e - 1])) e--;
  return [w.slice(0, s), w.slice(s, e), w.slice(e)];
}
const isUpper = (s) => s.length > 1 && s === s.toUpperCase() && s !== s.toLowerCase();
const isTitle = (s) => s.length > 0 && s[0] === s[0].toUpperCase() && s[0] !== s[0].toLowerCase();
const cap = (s) => (s ? s[0].toUpperCase() + s.slice(1) : s);
function preserveCasePhrase(orig, rep) {
  if (!orig.length || !rep) return rep;
  const rw = rep.split(' ');
  if (orig.every(isUpper)) return rep.toUpperCase();
  if (orig.every(isTitle)) return rw.map(cap).join(' ');
  if (isTitle(orig[0])) { rw[0] = cap(rw[0]); return rw.join(' '); }
  return rep;
}
function normalize(text) {
  if (!text) return text;
  const words = text.split(' ');
  const out = [];
  let i = 0;
  while (i < words.length) {
    if (words[i] === '') { out.push(words[i]); i++; continue; }
    let matched = false;
    for (let n = 3; n >= 2 && !matched; n--) {
      if (i + n - 1 >= words.length) continue;
      const parts = [];
      let ok = true;
      for (let k = 0; k < n; k++) {
        const p = splitPunct(words[i + k]);
        const badPre = k !== 0 && p[0] !== '';
        const badSuf = k !== n - 1 && p[2] !== '';
        if (p[1] === '' || badPre || badSuf) { ok = false; break; }
        parts.push(p);
      }
      if (!ok) continue;
      const cores = parts.map((p) => p[1]);
      const key = cores.join(' ').toLowerCase();
      if (DICT[key] !== undefined) {
        out.push(parts[0][0] + preserveCasePhrase(cores, DICT[key]) + parts[parts.length - 1][2]);
        i += n; matched = true;
      }
    }
    if (!matched) {
      const p = splitPunct(words[i]);
      const core = p[1];
      const lower = core.toLowerCase();
      if (core !== '' && DICT[lower] !== undefined) {
        out.push(p[0] + preserveCasePhrase([core], DICT[lower]) + p[2]);
      } else {
        out.push(words[i]);
      }
      i++;
    }
  }
  return out.join(' ');
}

const MIME = {
  '.m4a': 'audio/mp4', '.mp4': 'audio/mp4', '.aac': 'audio/aac',
  '.mp3': 'audio/mp3', '.wav': 'audio/wav', '.ogg': 'audio/ogg',
  '.flac': 'audio/flac', '.webm': 'audio/webm',
};

// Tự kiểm tra bản port chuẩn hóa (offline, không gọi Gemini): node ... --selftest
if (process.argv[2] === '--selftest') {
  const cases = [
    ['Anh đi mô rứa?', 'Anh đi đâu thế?'],
    ['nác nhoà', 'nóc nhà'],
    ['Nhoà Tôi Ở Đường', 'Nhà Tôi Ở Đường'],
    ['Chu cha, mớ nhoà sập rồi', 'Ôi trời, mái nhà sập rồi'],
    ['Kêu hén dô nhoà', 'Kêu nó vô nhà'],
  ];
  let ok = 0;
  for (const [inp, exp] of cases) {
    const got = normalize(inp);
    const pass = got === exp;
    ok += pass;
    console.log(`${pass ? 'OK ' : 'SAI'} | ${inp}  ->  ${got}${pass ? '' : `  (mong: ${exp})`}`);
  }
  console.log(`\nPort normalizer: ${ok}/${cases.length}`);
  process.exit(ok === cases.length ? 0 : 1);
}

(async () => {
  const file = process.argv[2];
  if (!file) {
    console.error('Cách dùng: node backend/scripts/testGeminiStt.js "duong-dan-file.m4a"');
    process.exit(1);
  }
  if (!fs.existsSync(file)) {
    console.error('Không tìm thấy file:', file);
    process.exit(1);
  }
  const ext = path.extname(file).toLowerCase();
  const mimeType = MIME[ext] || 'audio/mp3';
  const base64 = fs.readFileSync(file).toString('base64');

  console.log(`Đang gửi "${path.basename(file)}" (${mimeType}) cho Gemini...`);
  const raw = await transcribeAudio(base64, mimeType);
  const norm = normalize(raw);

  console.log('\n===== KẾT QUẢ =====');
  console.log('Gemini chép (giữ phương ngữ) :', raw);
  console.log('Sau chuẩn hóa (dict)        :', norm);
})().catch((e) => {
  console.error('LỖI:', e.message);
  process.exit(1);
});
