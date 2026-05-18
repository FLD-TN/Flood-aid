/**
 * Warning Flags Controller — Module 5
 * Admin cắm cờ cảnh báo tuyến đường
 */

const { db } = require('../db');

/**
 * POST /api/flags — Admin cắm cờ cảnh báo
 */
async function createFlag(req, res) {
  try {
    const { lat, lon, type, adminId } = req.body;

    if (!lat || !lon || !type) {
      return res.status(400).json({ error: 'Missing lat, lon, or type' });
    }

    const validTypes = ['tree_down', 'bridge_collapsed', 'flooded_road'];
    if (!validTypes.includes(type)) {
      return res.status(400).json({ error: `Invalid type. Must be one of: ${validTypes.join(', ')}` });
    }

    const result = await db.query(
      `INSERT INTO warning_flags (coords, type, created_by)
       VALUES (ST_SetSRID(ST_MakePoint($1, $2), 4326), $3::flag_type, $4)
       RETURNING id, type, is_active, created_at`,
      [lon, lat, type, adminId || '00000000-0000-0000-0000-000000000000']
    );

    console.log(`[flagController] New warning flag: ${result.rows[0].id}, type: ${type}`);

    res.status(201).json({
      ...result.rows[0],
      lat,
      lon,
    });
  } catch (err) {
    console.error('[flagController][createFlag]', err.message);
    res.status(500).json({ error: 'Internal error' });
  }
}

/**
 * GET /api/flags — Lấy tất cả cờ active (Bản đồ An toàn)
 */
async function getFlags(req, res) {
  try {
    const result = await db.query(`
      SELECT id, type, is_active, created_at,
             ST_X(coords::geometry) AS lon,
             ST_Y(coords::geometry) AS lat
      FROM warning_flags
      WHERE is_active = true
      ORDER BY created_at DESC
    `);

    res.json(result.rows);
  } catch (err) {
    console.error('[flagController][getFlags]', err.message);
    res.status(500).json({ error: 'Internal error' });
  }
}

/**
 * DELETE /api/flags/:id — Admin gỡ cờ
 */
async function deactivateFlag(req, res) {
  try {
    const { id } = req.params;

    await db.query(
      `UPDATE warning_flags SET is_active = false, deactivated_at = NOW() WHERE id = $1`,
      [id]
    );

    res.json({ success: true });
  } catch (err) {
    console.error('[flagController][deactivateFlag]', err.message);
    res.status(500).json({ error: 'Internal error' });
  }
}

module.exports = { createFlag, getFlags, deactivateFlag };
