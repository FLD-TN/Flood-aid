# skill-admin-dashboard.md — Module 5: Admin Web Dashboard

> Đọc file này khi làm task liên quan đến: React admin UI, Live Command Map, Mapbox/Leaflet, polling, cắm cờ cảnh báo, orphan case alerts.

---

## Trách nhiệm

- Live Command Map: hiển thị cluster SOS + GPS TNV real-time (polling 15s)
- Orphan case alerts: nhấp nháy đỏ với ca Mức 3-5 bị treo > 15 phút
- Cắm cờ cảnh báo tuyến đường (click 1 chạm lên bản đồ)
- Bảng danh sách ca SOS với filter
- Click TNV để lấy SĐT gọi trực tiếp

---

## Pattern: usePolling Hook

```js
// hooks/usePolling.js

import { useState, useEffect, useRef } from 'react';
import axios from 'axios';

/**
 * Universal polling hook
 * @param {string} url - API endpoint
 * @param {number} intervalMs - polling interval (mặc định 15s)
 */
export function usePolling(url, intervalMs = 15000) {
  const [data, setData] = useState(null);
  const [error, setError] = useState(null);
  const timerRef = useRef(null);

  const fetchData = async () => {
    try {
      const res = await axios.get(url, {
        headers: { Authorization: `Bearer ${localStorage.getItem('adminToken')}` }
      });
      setData(res.data);
      setError(null);
    } catch (err) {
      setError(err.message);
    }
  };

  useEffect(() => {
    fetchData(); // fetch ngay lần đầu
    timerRef.current = setInterval(fetchData, intervalMs);
    return () => clearInterval(timerRef.current);
  }, [url, intervalMs]);

  return { data, error, refresh: fetchData };
}
```

---

## Pattern: Live Command Map Component

```jsx
// components/LiveCommandMap.jsx

import { useEffect, useRef } from 'react';
import mapboxgl from 'mapbox-gl';
import { usePolling } from '../hooks/usePolling';

mapboxgl.accessToken = import.meta.env.VITE_MAPBOX_TOKEN;

const URGENCY_COLORS = {
  1: '#3B82F6', // blue
  2: '#EAB308', // yellow
  3: '#F97316', // orange
  4: '#EF4444', // red
  5: '#7C3AED', // purple (critical)
};

export default function LiveCommandMap() {
  const mapRef = useRef(null);
  const mapInstance = useRef(null);
  const markersRef = useRef({ cases: {}, volunteers: {}, flags: {} });

  // Polling data
  const { data: caseClusters } = usePolling('/api/admin/case-clusters', 15000);
  const { data: volunteerLocations } = usePolling('/api/volunteers/locations', 15000);
  const { data: warningFlags } = usePolling('/api/flags', 30000);

  // Init Mapbox
  useEffect(() => {
    mapInstance.current = new mapboxgl.Map({
      container: mapRef.current,
      style: 'mapbox://styles/mapbox/streets-v12',
      center: [108.2022, 16.0544], // Đà Nẵng — trung tâm Miền Trung
      zoom: 10,
    });
    return () => mapInstance.current?.remove();
  }, []);

  // Update SOS case markers
  useEffect(() => {
    if (!caseClusters || !mapInstance.current) return;
    const map = mapInstance.current;

    // Xóa marker cũ
    Object.values(markersRef.current.cases).forEach(m => m.remove());
    markersRef.current.cases = {};

    caseClusters.forEach(cluster => {
      const isOrphan = cluster.minutes_waiting > 15 && cluster.responding_count === 0;
      const color = URGENCY_COLORS[cluster.max_urgency] || '#EF4444';

      const el = document.createElement('div');
      el.className = `sos-marker ${isOrphan ? 'orphan-blink' : ''}`;
      el.style.cssText = `
        width: ${cluster.victim_count > 1 ? 40 : 28}px;
        height: ${cluster.victim_count > 1 ? 40 : 28}px;
        background: ${color};
        border-radius: 50%;
        border: 3px solid white;
        cursor: pointer;
        display: flex; align-items: center; justify-content: center;
        color: white; font-weight: bold; font-size: 12px;
        box-shadow: 0 2px 8px rgba(0,0,0,0.3);
        ${isOrphan ? 'animation: blink 1s infinite;' : ''}
      `;
      el.textContent = cluster.victim_count > 1 ? `${cluster.victim_count}` : '!';

      const popup = new mapboxgl.Popup({ offset: 25 }).setHTML(`
        <div style="font-family: sans-serif; min-width: 200px;">
          <p style="font-weight: bold; color: ${color}; margin: 0 0 8px">
            Mức ${cluster.max_urgency} — ${cluster.display_label}
          </p>
          <p style="margin: 0; color: #666; font-size: 13px">
            ${cluster.victim_count} nạn nhân · ${cluster.minutes_waiting} phút chờ
          </p>
          <p style="margin: 4px 0 0; color: #666; font-size: 13px">
            ${cluster.responding_count} TNV đang đến
          </p>
          ${isOrphan ? '<p style="color: red; font-weight: bold; margin: 8px 0 0">⚠️ Ca mồ côi — cần can thiệp!</p>' : ''}
        </div>
      `);

      const marker = new mapboxgl.Marker(el)
        .setLngLat([cluster.cluster_center.lon, cluster.cluster_center.lat])
        .setPopup(popup)
        .addTo(map);

      markersRef.current.cases[cluster.cluster_id] = marker;
    });
  }, [caseClusters]);

  // Update TNV markers
  useEffect(() => {
    if (!volunteerLocations || !mapInstance.current) return;
    const map = mapInstance.current;

    Object.values(markersRef.current.volunteers).forEach(m => m.remove());
    markersRef.current.volunteers = {};

    volunteerLocations.forEach(vol => {
      const el = document.createElement('div');
      el.style.cssText = `
        width: 20px; height: 20px;
        background: #22C55E;
        border-radius: 50%;
        border: 2px solid white;
        cursor: pointer;
      `;

      const popup = new mapboxgl.Popup({ offset: 15 }).setHTML(`
        <div>
          <p style="font-weight: bold; margin: 0">TNV #${vol.id.slice(0, 8)}</p>
          <p style="margin: 4px 0 0; font-size: 13px">
            Trạng thái: ${vol.is_available ? '🟢 Rảnh' : '🟡 Đang cứu hộ'}
          </p>
          <a href="tel:${vol.phone}" style="color: blue; font-size: 13px">📞 Gọi trực tiếp</a>
        </div>
      `);

      const marker = new mapboxgl.Marker(el)
        .setLngLat([vol.lon, vol.lat])
        .setPopup(popup)
        .addTo(map);

      markersRef.current.volunteers[vol.id] = marker;
    });
  }, [volunteerLocations]);

  // Cắm cờ cảnh báo: click vào bản đồ
  const handleMapClick = async (flagType, lngLat) => {
    await axios.post('/api/flags', {
      lat: lngLat.lat,
      lon: lngLat.lng,
      type: flagType,
    }, {
      headers: { Authorization: `Bearer ${localStorage.getItem('adminToken')}` }
    });
  };

  return (
    <div style={{ position: 'relative', height: '100vh' }}>
      <div ref={mapRef} style={{ width: '100%', height: '100%' }} />

      {/* Flag toolbar */}
      <div style={{
        position: 'absolute', top: 16, right: 16,
        background: 'white', borderRadius: 8, padding: 12,
        boxShadow: '0 2px 12px rgba(0,0,0,0.2)',
      }}>
        <p style={{ margin: '0 0 8px', fontWeight: 'bold', fontSize: 13 }}>Cắm cờ cảnh báo</p>
        {[
          { type: 'tree_down', label: '🌲 Cây đổ' },
          { type: 'bridge_collapsed', label: '🌉 Cầu sập' },
          { type: 'flooded_road', label: '🌊 Đường ngập' },
        ].map(({ type, label }) => (
          <button key={type} onClick={() => {
            // Bật chế độ click-to-place
            mapInstance.current?.once('click', (e) => handleMapClick(type, e.lngLat));
          }} style={{
            display: 'block', width: '100%', margin: '4px 0',
            padding: '6px 12px', background: '#FEF2F2',
            border: '1px solid #FCA5A5', borderRadius: 6, cursor: 'pointer',
          }}>
            {label}
          </button>
        ))}
      </div>

      <style>{`
        @keyframes blink {
          0%, 100% { opacity: 1; box-shadow: 0 0 0 0 rgba(239,68,68,0.4); }
          50% { opacity: 0.7; box-shadow: 0 0 0 8px rgba(239,68,68,0); }
        }
      `}</style>
    </div>
  );
}
```

---

## API Endpoint: GET /api/admin/case-clusters

```js
// controllers/adminController.js

async function getCaseClusters(req, res) {
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
      LEFT JOIN case_assignments ca ON ca.case_id = c.id AND ca.revoked_at IS NULL AND ca.completed_at IS NULL
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

  res.json(result.rows.map(row => ({
    ...row,
    cluster_center: {
      lon: row.cluster_center.coordinates[0],
      lat: row.cluster_center.coordinates[1],
    }
  })));
}
```
