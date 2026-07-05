/**
 * Dialect override dictionary — quản lý các từ phương ngữ do admin thêm/sửa.
 *
 * KHÔNG dùng database: toàn bộ lưu trong 1 file JSON nhỏ (chỉ chứa phần override,
 * không phải 26k từ gốc). App mobile đã có sẵn từ điển gốc trong bundle; nó chỉ
 * tải phần override này về và merge chồng lên. Nhờ vậy:
 *  - Thêm từ mới = gọi API, KHÔNG cần build lại app.
 *  - App vẫn chạy offline bằng bundle nếu không tải được override.
 *
 * Cấu trúc file dialect_overrides.json:
 *   { "version": <int>, "terms": { "<phương ngữ>": "<chuẩn>", ... } }
 * version tăng mỗi lần thay đổi để app biết khi nào cần tải lại.
 */

const fs = require('fs').promises;
const path = require('path');

const OVERRIDES_PATH = path.join(__dirname, '../../dialect_overrides.json');

// Serialize các thao tác ghi để tránh race read-modify-write (2 request cùng lúc).
let _writeLock = Promise.resolve();

async function _readOverrides() {
  try {
    const raw = await fs.readFile(OVERRIDES_PATH, 'utf8');
    const data = JSON.parse(raw);
    return {
      version: Number(data.version) || 0,
      terms: data.terms && typeof data.terms === 'object' ? data.terms : {},
    };
  } catch (e) {
    // Chưa có file → coi như rỗng.
    return { version: 0, terms: {} };
  }
}

async function _writeOverrides(data) {
  await fs.writeFile(OVERRIDES_PATH, JSON.stringify(data, null, 2), 'utf8');
}

// Chạy fn (đọc → sửa → ghi) tuần tự qua lock.
function _withLock(fn) {
  const run = _writeLock.then(fn, fn);
  // Không để lỗi của lần này làm hỏng chuỗi lock cho lần sau.
  _writeLock = run.then(() => {}, () => {});
  return run;
}

// GET /api/dialect-dict → trả toàn bộ override + version cho app merge.
async function getDict(req, res) {
  try {
    const data = await _readOverrides();
    res.json(data);
  } catch (e) {
    res.status(500).json({ error: 'READ_FAILED' });
  }
}

// GET /api/dialect-dict/version → chỉ trả version (rẻ, để app kiểm tra nhanh).
async function getVersion(req, res) {
  try {
    const data = await _readOverrides();
    res.json({ version: data.version });
  } catch (e) {
    res.status(500).json({ error: 'READ_FAILED' });
  }
}

// POST /api/dialect-dict { dialect, standard } → thêm/cập nhật 1 từ (admin).
async function addTerm(req, res) {
  const dialect = (req.body?.dialect || '').trim().toLowerCase();
  const standard = (req.body?.standard || '').trim();
  if (!dialect || !standard) {
    return res.status(400).json({ error: 'MISSING_FIELDS' });
  }
  try {
    const data = await _withLock(async () => {
      const current = await _readOverrides();
      current.terms[dialect] = standard;
      current.version += 1;
      await _writeOverrides(current);
      return current;
    });
    res.json({ version: data.version, dialect, standard, count: Object.keys(data.terms).length });
  } catch (e) {
    res.status(500).json({ error: 'WRITE_FAILED' });
  }
}

// DELETE /api/dialect-dict { dialect } → xoá 1 từ override (admin).
async function removeTerm(req, res) {
  const dialect = (req.body?.dialect || '').trim().toLowerCase();
  if (!dialect) {
    return res.status(400).json({ error: 'MISSING_FIELDS' });
  }
  try {
    const data = await _withLock(async () => {
      const current = await _readOverrides();
      if (current.terms[dialect] !== undefined) {
        delete current.terms[dialect];
        current.version += 1;
        await _writeOverrides(current);
      }
      return current;
    });
    res.json({ version: data.version, count: Object.keys(data.terms).length });
  } catch (e) {
    res.status(500).json({ error: 'WRITE_FAILED' });
  }
}

module.exports = { getDict, getVersion, addTerm, removeTerm };
