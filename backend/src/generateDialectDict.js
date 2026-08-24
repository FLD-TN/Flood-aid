/**
 * Script sinh tự động từ điển phương ngữ miền Trung (Quảng Nam) từ dữ liệu thực tế
 * Tự động tải danh sách 74,000 từ vựng tiếng Việt (Viet74K) để làm nguồn chuẩn.
 */

const fs = require('fs');
const https = require('https');
const readline = require('readline');
const path = require('path');

const WORDLIST_URL = 'https://raw.githubusercontent.com/duyet/vietnamese-wordlist/master/Viet74K.txt';
const DICT_OUTPUT_PATH = path.join(__dirname, '../../mobile/assets/dialect_dict.json');
const RAW_VOCAB_PATH = path.join(__dirname, '../Viet74K.txt');

// 1. Từ điển cứng (Hardcoded Dictionary)
const hardcodedDict = {
  "răng": "sao",
  "ren": "sao",
  "lồm": "làm",
  "rứa": "thế",
  "mô": "đâu",
  "tê": "kia",
  "ni": "này",
  "nớ": "đó",
  "chừ": "giờ",
  "chu cha": "ôi trời",
  "tau": "tao",
  "mi": "mày",
  "hén": "nó",
  "hán": "nó",
  "con trơ": "con trai",
  "thằng trơ": "thằng trai",
  "con gớ": "con gái",
  "mớ nhoà": "mái nhà",
  "chẹn": "chặn",
  "dô": "vô",
  "nhoà": "nhà",
  "cái chi": "cái gì",
  "chi": "gì",
  "chi phí": "chi phí",
  "chi tiết": "chi tiết",
  "chi nhánh": "chi nhánh",
  "chi tiêu": "chi tiêu",
  "chi hội": "chi hội",
  "chi bộ": "chi bộ",
  "chi cục": "chi cục",
  "chi trả": "chi trả",
  "chi chít": "chi chít",
  "nác": "nóc",
  "nát nhoà": "nóc nhà",
  "núa": "nói",
  "nỏ": "không",
  "o": "cô",
  // "phở" = "phải" (bắt buộc). Trùng tên món ăn "phở", nhưng trong ngữ cảnh cứu hộ lũ
  // nghĩa "phải" áp đảo và "phải" đi với quá nhiều động từ để gom theo cụm → thêm blanket.
  "phở": "phải",
  // "cô" = "cao" (ở trên cao) — CHỈ thêm theo cụm để không phá nghĩa "cô/dì/cô giáo".
  "trên cô": "trên cao",
  "lên cô": "lên cao",
  // "xoa" = "xa" (khoảng cách) — CHỈ thêm theo cụm để không phá nghĩa "xoa bóp/xoa dịu".
  "ở xoa": "ở xa",
  "xoa lắm": "xa lắm",
  "còn xoa": "còn xa",
  "đường xoa": "đường xa",
  "xoa xôi": "xa xôi",
};

// 2. Công thức biến âm (Rules)
const phoneticRules = [
  { regex: /àm/g, replace: 'ồm' },
  { regex: /ám/g, replace: 'ốm' },
  { regex: /ạm/g, replace: 'ộm' },
  { regex: /am/g, replace: 'ôm' },
  { regex: /à/g, replace: 'oà' },
  { regex: /á/g, replace: 'oá' },
  { regex: /ạ/g, replace: 'oạ' },
  { regex: /ăn/g, replace: 'en' },
  { regex: /ắn/g, replace: 'én' },
  { regex: /ặn/g, replace: 'ẹn' },
  { regex: /ặng/g, replace: 'ẹng' },
  { regex: /^v/g, replace: 'd' }
];

// 3. Blacklist - Cấm sinh ra những từ này vì nó trùng với từ chuẩn mang nghĩa khác
const blacklist = new Set([
  "oà", "hòa", "hà", "dạ", "dề", "dợ", "men", "kén", "dạng", "dòng"
]);

function applyRules(word) {
  let dialectWord = word;
  for (const rule of phoneticRules) {
    dialectWord = dialectWord.replace(rule.regex, rule.replace);
  }
  return dialectWord;
}

async function downloadWordlist() {
  if (fs.existsSync(RAW_VOCAB_PATH)) {
    console.log('File Viet74K.txt đã tồn tại, tiến hành đọc...');
    return;
  }
  console.log('Đang tải 74,000 từ vựng tiếng Việt từ GitHub...');
  return new Promise((resolve, reject) => {
    const file = fs.createWriteStream(RAW_VOCAB_PATH);
    https.get(WORDLIST_URL, (response) => {
      response.pipe(file);
      file.on('finish', () => {
        file.close();
        resolve();
      });
    }).on('error', (err) => {
      fs.unlinkSync(RAW_VOCAB_PATH);
      reject(err);
    });
  });
}

async function generateDictionary() {
  await downloadWordlist();

  const standardVocab = new Set();
  const fileStream = fs.createReadStream(RAW_VOCAB_PATH);

  const rl = readline.createInterface({
    input: fileStream,
    crlfDelay: Infinity
  });

  // Đọc từng dòng (từng từ vựng)
  for await (const line of rl) {
    if (line.trim()) {
      standardVocab.add(line.trim().toLowerCase());
    }
  }

  console.log(` Đã đọc ${standardVocab.size} từ vựng chuẩn. Đang áp dụng công thức...`);

  const dict = { ...hardcodedDict };

  for (const word of standardVocab) {
    // Tách từ ghép thành các âm tiết lẻ (để biến âm từng chữ)
    const syllables = word.split(' ');
    const dialectSyllables = syllables.map(s => applyRules(s));
    const dialectWord = dialectSyllables.join(' ');

    // Nếu có sự biến âm VÀ từ sinh ra không nằm trong Blacklist VÀ từ sinh ra không phải là 1 từ chuẩn có sẵn (để tránh lỗi ngữ cảnh)
    if (dialectWord !== word && !blacklist.has(dialectWord) && !standardVocab.has(dialectWord)) {
      dict[dialectWord] = word;
    }
  }

  fs.writeFileSync(DICT_OUTPUT_PATH, JSON.stringify(dict, null, 2), 'utf8');
  console.log(`Đã tạo thành công từ điển với ${Object.keys(dict).length} mục.`);
  console.log(`Đường dẫn: ${DICT_OUTPUT_PATH}`);
}

generateDictionary().catch(console.error);
