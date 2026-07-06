/**
 * Dialect override dictionary — quản lý các từ phương ngữ do admin thêm/sửa.
 *
 * Lưu trong DB (bảng dialect_terms + dialect_meta) để BỀN qua restart/redeploy
 * trên Render — khác với file JSON ephemeral trước đây. Chỉ chứa phần override,
 * không phải 26k từ gốc (app đã có sẵn trong bundle và merge chồng lên).
 *
 * Contract API giữ nguyên để mobile/admin-web không phải đổi:
 *   GET    /api/dialect-dict          -> { version, terms: { <pn>: <chuẩn> } }
 *   GET    /api/dialect-dict/version  -> { version }
 *   POST   /api/dialect-dict          -> thêm/sửa 1 từ (admin)
 *   DELETE /api/dialect-dict          -> xoá 1 từ (admin)
 *
 * version là bộ đếm đơn điệu trong dialect_meta, +1 mỗi lần thay đổi → app biết
 * khi nào cần đồng bộ lại (không suy ra từ dữ liệu vì delete sẽ làm version lùi).
 */

const { db } = require('../db');

async function _currentVersion() {
  const r = await db.query('SELECT version FROM dialect_meta WHERE id = 1');
  return r.rows[0] ? Number(r.rows[0].version) : 0;
}

// GET /api/dialect-dict → toàn bộ override + version cho app merge.
async function getDict(req, res) {
  try {
    // Một câu SELECT = một snapshot nhất quán trong Postgres → version và terms
    // luôn khớp nhau kể cả có ghi xen giữa.
    const r = await db.query(
      `SELECT (SELECT version FROM dialect_meta WHERE id = 1) AS version,
              dialect, standard
       FROM dialect_terms`
    );
    const version = r.rows.length ? Number(r.rows[0].version) : await _currentVersion();
    const terms = {};
    for (const row of r.rows) terms[row.dialect] = row.standard;
    res.json({ version, terms });
  } catch (e) {
    console.error('[dialect] getDict:', e.message);
    res.status(500).json({ error: 'READ_FAILED' });
  }
}

// GET /api/dialect-dict/version → chỉ version (rẻ, để app kiểm tra nhanh).
async function getVersion(req, res) {
  try {
    res.json({ version: await _currentVersion() });
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
  const client = await db.getPool().connect();
  try {
    await client.query('BEGIN');
    await client.query(
      `INSERT INTO dialect_terms (dialect, standard, updated_at)
       VALUES ($1, $2, NOW())
       ON CONFLICT (dialect) DO UPDATE SET standard = EXCLUDED.standard, updated_at = NOW()`,
      [dialect, standard]
    );
    const v = await client.query(
      'UPDATE dialect_meta SET version = version + 1 WHERE id = 1 RETURNING version'
    );
    const cnt = await client.query('SELECT COUNT(*)::int AS c FROM dialect_terms');
    await client.query('COMMIT');
    res.json({ version: Number(v.rows[0].version), dialect, standard, count: cnt.rows[0].c });
  } catch (e) {
    await client.query('ROLLBACK').catch(() => {});
    console.error('[dialect] addTerm:', e.message);
    res.status(500).json({ error: 'WRITE_FAILED' });
  } finally {
    client.release();
  }
}

// DELETE /api/dialect-dict { dialect } → xoá 1 từ override (admin).
async function removeTerm(req, res) {
  const dialect = (req.body?.dialect || '').trim().toLowerCase();
  if (!dialect) {
    return res.status(400).json({ error: 'MISSING_FIELDS' });
  }
  const client = await db.getPool().connect();
  try {
    await client.query('BEGIN');
    const del = await client.query('DELETE FROM dialect_terms WHERE dialect = $1', [dialect]);
    let version;
    if (del.rowCount > 0) {
      const v = await client.query(
        'UPDATE dialect_meta SET version = version + 1 WHERE id = 1 RETURNING version'
      );
      version = Number(v.rows[0].version);
    } else {
      version = await _currentVersion();
    }
    const cnt = await client.query('SELECT COUNT(*)::int AS c FROM dialect_terms');
    await client.query('COMMIT');
    res.json({ version, count: cnt.rows[0].c });
  } catch (e) {
    await client.query('ROLLBACK').catch(() => {});
    console.error('[dialect] removeTerm:', e.message);
    res.status(500).json({ error: 'WRITE_FAILED' });
  } finally {
    client.release();
  }
}

module.exports = { getDict, getVersion, addTerm, removeTerm };
