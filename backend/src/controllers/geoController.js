/**
 * Geo Controller — proxy các API địa lý VietMap cho app (giấu API key ở backend).
 *   GET /api/geo/autocomplete?text=...&lat=...&lon=...   → gợi ý địa chỉ khi gõ
 *   GET /api/geo/place?refid=...                         → ref_id → toạ độ
 *   GET /api/geo/reverse?lat=...&lon=...                 → toạ độ → địa chỉ
 */

const { autocomplete, place, reverseGeocode, routePath } = require('../services/vietmap');

/**
 * GET /api/geo/autocomplete — gợi ý địa chỉ (type-ahead).
 * Query: text (bắt buộc), lat/lon (khuyến nghị, để ưu tiên gần).
 */
async function geoAutocomplete(req, res) {
  try {
    const { text, lat, lon } = req.query;
    if (!text || text.trim().length < 2) {
      return res.json([]); // dưới 2 ký tự → không gọi VietMap
    }
    const focusLat = lat != null ? parseFloat(lat) : undefined;
    const focusLon = lon != null ? parseFloat(lon) : undefined;
    const results = await autocomplete(text.trim(), focusLat, focusLon);
    res.json(results);
  } catch (err) {
    console.error('[geoController][autocomplete]', err.message);
    res.status(500).json({ error: 'Internal error' });
  }
}

/**
 * GET /api/geo/place — ref_id → toạ độ + chi tiết.
 */
async function geoPlace(req, res) {
  try {
    const { refid } = req.query;
    if (!refid) {
      return res.status(400).json({ error: 'Missing refid' });
    }
    const result = await place(refid);
    if (!result) {
      return res.status(404).json({ error: 'Place not found' });
    }
    res.json(result);
  } catch (err) {
    console.error('[geoController][place]', err.message);
    res.status(500).json({ error: 'Internal error' });
  }
}

/**
 * GET /api/geo/reverse — toạ độ → địa chỉ chữ.
 */
async function geoReverse(req, res) {
  try {
    const { lat, lon } = req.query;
    if (lat == null || lon == null) {
      return res.status(400).json({ error: 'Missing lat/lon' });
    }
    const address = await reverseGeocode(parseFloat(lat), parseFloat(lon));
    res.json({ address });
  } catch (err) {
    console.error('[geoController][reverse]', err.message);
    res.status(500).json({ error: 'Internal error' });
  }
}

/**
 * GET /api/geo/route — quãng đường + ETA + hình học tuyến (để vẽ lên bản đồ).
 * Query: fromLat, fromLon, toLat, toLon, vehicle (tuỳ chọn).
 */
async function geoRoute(req, res) {
  try {
    const { fromLat, fromLon, toLat, toLon, vehicle } = req.query;
    if (fromLat == null || fromLon == null || toLat == null || toLon == null) {
      return res.status(400).json({ error: 'Missing fromLat/fromLon/toLat/toLon' });
    }
    const result = await routePath(
      parseFloat(fromLat), parseFloat(fromLon),
      parseFloat(toLat), parseFloat(toLon),
      vehicle || 'motorcycle'
    );
    if (!result) {
      return res.status(404).json({ error: 'Route not found' });
    }
    res.json(result);
  } catch (err) {
    console.error('[geoController][route]', err.message);
    res.status(500).json({ error: 'Internal error' });
  }
}

module.exports = { geoAutocomplete, geoPlace, geoReverse, geoRoute };
