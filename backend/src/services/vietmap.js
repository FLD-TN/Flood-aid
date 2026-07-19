/**
 * VietMap service — gọi các API địa lý của VietMap từ backend.
 * Key được giữ ở server (biến môi trường VIETMAP_API_KEY), KHÔNG lộ ra frontend.
 *
 * Hiện dùng cho: Reverse geocoding (toạ độ GPS -> địa chỉ chữ) khi tạo ca SOS.
 * Docs: vietmap-agent-docs/search-geocoding.txt
 */

const API_KEY = process.env.VIETMAP_API_KEY;
const BASE = 'https://maps.vietmap.vn/api';
const TIMEOUT_MS = Number(process.env.VIETMAP_TIMEOUT_MS) || 3000;

/**
 * Reverse geocode: (lat, lon) -> chuỗi địa chỉ tiếng Việt.
 * Trả về null nếu thiếu key / lỗi mạng / không có kết quả — người gọi tự fallback.
 * display_type=6: định dạng địa chỉ cũ (3 cấp) làm chính, mới (2 cấp) trong data_new.
 *
 * @returns {Promise<string|null>}
 */
async function reverseGeocode(lat, lon) {
  if (!API_KEY) {
    console.warn('[vietmap] VIETMAP_API_KEY chưa cấu hình — bỏ qua reverse geocode');
    return null;
  }
  try {
    const url = `${BASE}/reverse/v4?apikey=${API_KEY}`
      + `&lat=${encodeURIComponent(lat)}&lng=${encodeURIComponent(lon)}&display_type=6`;

    const resp = await fetch(url, { signal: AbortSignal.timeout(TIMEOUT_MS) });
    if (!resp.ok) {
      console.warn(`[vietmap] reverse trả về HTTP ${resp.status}`);
      return null;
    }
    const data = await resp.json();
    // Reverse v4 trả về mảng; phần tử đầu là kết quả gần nhất.
    const first = Array.isArray(data) ? data[0] : null;
    return first?.display || null;
  } catch (err) {
    console.warn('[vietmap] reverseGeocode lỗi:', err.message);
    return null;
  }
}

/**
 * Route v4: quãng đường + thời gian THẬT theo đường đi (car) giữa 2 điểm.
 * Dùng để tính khoảng cách/ETA từ TNV → nạn nhân (thay đường chim bay ST_Distance).
 * Trả về { distanceM, etaSec } hoặc null khi lỗi/timeout/không có đường.
 *
 * @param {number} fromLat @param {number} fromLon  điểm xuất phát (TNV)
 * @param {number} toLat   @param {number} toLon     điểm đích (nạn nhân)
 * @param {string} vehicle 'car' | 'motorcycle' — mặc định motorcycle (phù hợp cứu hộ VN)
 * @returns {Promise<{distanceM: number, etaSec: number}|null>}
 */
async function routeEta(fromLat, fromLon, toLat, toLon, vehicle = 'motorcycle') {
  if (!API_KEY) {
    console.warn('[vietmap] VIETMAP_API_KEY chưa cấu hình — bỏ qua routeEta');
    return null;
  }
  try {
    const url = `${BASE}/route/v4?apikey=${API_KEY}`
      + `&point=${fromLat},${fromLon}&point=${toLat},${toLon}`
      + `&vehicle=${vehicle}&points_encoded=true`;

    const resp = await fetch(url, { signal: AbortSignal.timeout(TIMEOUT_MS) });
    if (!resp.ok) {
      console.warn(`[vietmap] route trả về HTTP ${resp.status}`);
      return null;
    }
    const data = await resp.json();
    const path = Array.isArray(data?.paths) ? data.paths[0] : null;
    if (!path) return null;
    // Route v4: distance = mét, time = mili-giây
    return {
      distanceM: Math.round(path.distance),
      etaSec: Math.round(path.time / 1000),
    };
  } catch (err) {
    console.warn('[vietmap] routeEta lỗi:', err.message);
    return null;
  }
}

/**
 * Giải mã Google Encoded Polyline (precision 5) → mảng [lat, lng].
 * Route v4 trả points ở định dạng này khi points_encoded=true.
 */
function decodePolyline(str, precision = 5) {
  let index = 0, lat = 0, lng = 0;
  const coordinates = [];
  const factor = Math.pow(10, precision);
  while (index < str.length) {
    let result = 1, shift = 0, b;
    do { b = str.charCodeAt(index++) - 63 - 1; result += b << shift; shift += 5; } while (b >= 0x1f);
    lat += (result & 1) ? ~(result >> 1) : (result >> 1);
    result = 1; shift = 0;
    do { b = str.charCodeAt(index++) - 63 - 1; result += b << shift; shift += 5; } while (b >= 0x1f);
    lng += (result & 1) ? ~(result >> 1) : (result >> 1);
    coordinates.push([lat / factor, lng / factor]);
  }
  return coordinates;
}

/**
 * Route v4 đầy đủ: quãng đường + ETA + hình học tuyến (điểm [lat,lng] đã decode).
 * Dùng để VẼ tuyến đường thật lên bản đồ. Trả null khi lỗi.
 * @returns {Promise<{distanceM:number, etaSec:number, points:number[][]}|null>}
 */
async function routePath(fromLat, fromLon, toLat, toLon, vehicle = 'motorcycle') {
  if (!API_KEY) return null;
  try {
    const url = `${BASE}/route/v4?apikey=${API_KEY}`
      + `&point=${fromLat},${fromLon}&point=${toLat},${toLon}`
      + `&vehicle=${vehicle}&points_encoded=true`;
    const resp = await fetch(url, { signal: AbortSignal.timeout(TIMEOUT_MS) });
    if (!resp.ok) return null;
    const data = await resp.json();
    const path = Array.isArray(data?.paths) ? data.paths[0] : null;
    if (!path) return null;
    return {
      distanceM: Math.round(path.distance),
      etaSec: Math.round(path.time / 1000),
      points: typeof path.points === 'string' ? decodePolyline(path.points) : [],
    };
  } catch (err) {
    console.warn('[vietmap] routePath lỗi:', err.message);
    return null;
  }
}

/**
 * Autocomplete v4: gợi ý địa chỉ khi user gõ.
 * @param {string} text  chuỗi user đang gõ (>= 2 ký tự)
 * @param {number} [focusLat] @param {number} [focusLon]  toạ độ hiện tại để ưu tiên gần
 * @returns {Promise<Array<{ref_id, display, name, address, distance}>>}  [] khi lỗi
 */
async function autocomplete(text, focusLat, focusLon) {
  if (!API_KEY || !text || !text.trim()) return [];
  try {
    let url = `${BASE}/autocomplete/v4?apikey=${API_KEY}`
      + `&text=${encodeURIComponent(text)}&display_type=6`;
    if (focusLat != null && focusLon != null) {
      url += `&focus=${focusLat},${focusLon}`;
    }
    const resp = await fetch(url, { signal: AbortSignal.timeout(TIMEOUT_MS) });
    if (!resp.ok) return [];
    const data = await resp.json();
    if (!Array.isArray(data)) return [];
    // Chỉ trả các trường app cần; ref_id giữ nguyên (opaque) để gọi Place.
    return data.map((r) => ({
      ref_id: r.ref_id,
      display: r.display,
      name: r.name,
      address: r.address,
      distance: r.distance,
    }));
  } catch (err) {
    console.warn('[vietmap] autocomplete lỗi:', err.message);
    return [];
  }
}

/**
 * Place v4: đổi ref_id (từ autocomplete) → toạ độ + chi tiết địa chỉ.
 * @param {string} refId  token opaque, truyền nguyên văn
 * @returns {Promise<{lat, lng, display, address}|null>}
 */
async function place(refId) {
  if (!API_KEY || !refId) return null;
  try {
    const url = `${BASE}/place/v4?apikey=${API_KEY}&refid=${encodeURIComponent(refId)}`;
    const resp = await fetch(url, { signal: AbortSignal.timeout(TIMEOUT_MS) });
    if (!resp.ok) return null;
    const data = await resp.json();
    if (!data || data.lat == null || data.lng == null) return null;
    return {
      lat: data.lat,
      lng: data.lng,
      display: data.display,
      address: data.address,
    };
  } catch (err) {
    console.warn('[vietmap] place lỗi:', err.message);
    return null;
  }
}

module.exports = { reverseGeocode, routeEta, routePath, autocomplete, place };
