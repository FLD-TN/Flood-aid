/**
 * Admin Controller — Module 5
 * Dashboard data endpoints
 */

const { db } = require('../db');

/**
 * GET /api/admin/case-clusters — Cluster SOS cho Live Command Map
 */
async function getCaseClusters(req, res) {
  try {
    const result = await db.query(`
      WITH clustered AS (
        SELECT 
          id, coords, summary_1line, urgency_level, status,
          EXTRACT(EPOCH FROM (NOW() - created_at))/60 AS minutes_waiting,
          ST_ClusterDBSCAN(coords, eps := 0.00018, minpoints := 1) OVER () AS cluster_id
        FROM cases
        WHERE status IN ('pending', 'responding', 'on_scene')
      ),
      responding_counts AS (
        SELECT c.id, COUNT(ca.id) AS cnt
        FROM cases c
        LEFT JOIN case_assignments ca ON ca.case_id = c.id 
          AND ca.revoked_at IS NULL AND ca.completed_at IS NULL
        WHERE c.status != 'resolved'
        GROUP BY c.id
      )
      SELECT 
        cl.cluster_id,
        COUNT(*) AS victim_count,
        MAX(cl.urgency_level) AS max_urgency,
        MAX(cl.minutes_waiting)::int AS minutes_waiting,
        COALESCE(SUM(rc.cnt), 0) AS responding_count,
        ST_AsGeoJSON(ST_Centroid(ST_Collect(cl.coords)))::json AS cluster_center,
        CASE WHEN COUNT(*) = 1 THEN MAX(cl.summary_1line)
             ELSE CONCAT('[KHẨN CẤP] Cụm nạn nhân: ~', COUNT(*), ' người tại khu vực này')
        END AS display_label
      FROM clustered cl
      LEFT JOIN responding_counts rc ON rc.id = cl.id
      GROUP BY cl.cluster_id
      ORDER BY max_urgency DESC, minutes_waiting DESC
    `);

    const clusters = result.rows.map(row => ({
      ...row,
      cluster_center: row.cluster_center ? {
        lon: row.cluster_center.coordinates[0],
        lat: row.cluster_center.coordinates[1],
      } : null,
    }));

    res.json(clusters);
  } catch (err) {
    console.error('[adminController][getCaseClusters]', err.message);
    res.status(500).json({ error: 'Internal error' });
  }
}

/**
 * GET /api/admin/cases — Danh sách tất cả ca SOS
 */
async function getAllCases(req, res) {
  try {
    const { status } = req.query;
    let query = `
      SELECT id, urgency_level, tags, summary_1line, status, tnv_distance_m, ai_source,
             ST_X(coords::geometry) AS lon, ST_Y(coords::geometry) AS lat,
             created_at, resolved_at,
             EXTRACT(EPOCH FROM (NOW() - created_at))/60 AS minutes_waiting
      FROM cases
    `;
    const params = [];

    if (status) {
      query += ' WHERE status = $1';
      params.push(status);
    }

    query += ' ORDER BY created_at DESC LIMIT 100';

    const result = await db.query(query, params);
    res.json(result.rows);
  } catch (err) {
    console.error('[adminController][getAllCases]', err.message);
    res.status(500).json({ error: 'Internal error' });
  }
}

/**
 * GET /api/admin/stats — Thống kê tổng quan
 */
async function getDashboardStats(req, res) {
  try {
    const stats = await db.query(`
      SELECT 
        COUNT(*) FILTER (WHERE status = 'pending') AS pending_count,
        COUNT(*) FILTER (WHERE status = 'responding') AS responding_count,
        COUNT(*) FILTER (WHERE status = 'on_scene') AS on_scene_count,
        COUNT(*) FILTER (WHERE status = 'resolved') AS resolved_count,
        COUNT(*) AS total_count
      FROM cases
    `);

    const volStats = await db.query(`
      SELECT 
        COUNT(*) AS total_volunteers,
        COUNT(*) FILTER (WHERE is_available = true AND admin_approved = true) AS available_count,
        COUNT(*) FILTER (WHERE admin_approved = false) AS pending_approval
      FROM volunteers
    `);

    const flagStats = await db.query(`
      SELECT COUNT(*) AS active_flags FROM warning_flags WHERE is_active = true
    `);

    res.json({
      cases: stats.rows[0],
      volunteers: volStats.rows[0],
      flags: flagStats.rows[0],
    });
  } catch (err) {
    console.error('[adminController][getStats]', err.message);
    res.status(500).json({ error: 'Internal error' });
  }
}

module.exports = { getCaseClusters, getAllCases, getDashboardStats };
