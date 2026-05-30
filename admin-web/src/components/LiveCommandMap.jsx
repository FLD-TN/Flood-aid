import { useState } from 'react';
import { MapContainer, TileLayer, Marker, Popup } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { usePolling } from '../hooks/usePolling';

// Fix Leaflet default marker icon
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-icon-2x.png',
  iconUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-icon.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-shadow.png',
});

// Urgency → color theo design system
const URGENCY_COLORS = {
  5: '#EF4444', 4: '#FCA5A5', 3: '#FBBF24', 2: '#FDE047', 1: '#86EFAC',
};


// Custom SOS marker — dark style theo spec
function createSosIcon(urgencyLevel, count = 1) {
  const color = URGENCY_COLORS[urgencyLevel] || '#F59E0B';
  const size = count > 1 ? 38 : 30;
  return L.divIcon({
    className: '',
    html: `<div style="
      width:${size}px; height:${size}px;
      background:${color};
      border-radius:50%;
      border:2.5px solid rgba(255,255,255,0.85);
      display:flex; align-items:center; justify-content:center;
      color:white; font-weight:700; font-size:${count > 1 ? 13 : 11}px;
      box-shadow:0 0 12px ${color}60, 0 2px 8px rgba(0,0,0,0.5);
      font-family:'IBM Plex Mono',monospace;
      animation:markerAppear 0.3s ease;
    ">${count > 1 ? count : '!'}</div>`,
    iconSize: [size, size],
    iconAnchor: [size / 2, size / 2],
  });
}

// Volunteer marker — green dot
function createVolunteerIcon(isAvailable) {
  const color = isAvailable ? '#34D399' : '#FBBF24';
  return L.divIcon({
    className: '',
    html: `<div style="
      width:18px; height:18px;
      background:${color};
      border-radius:50%;
      border:2px solid rgba(255,255,255,0.7);
      box-shadow:0 0 8px ${color}80, 0 2px 4px rgba(0,0,0,0.4);
    "></div>`,
    iconSize: [18, 18],
    iconAnchor: [9, 9],
  });
}


// Popup content (styled theo Ops Center)
function buildCasePopup(cluster) {
  const color = URGENCY_COLORS[cluster.max_urgency] || '#F59E0B';
  const isOrphan = cluster.minutes_waiting > 15 && cluster.responding_count === 0;
  return `
    <div style="font-family:'Barlow',sans-serif;min-width:200px;padding:2px;">
      <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px;">
        <span style="font-family:'Barlow Condensed',sans-serif;font-size:15px;font-weight:700;
          letter-spacing:0.05em;text-transform:uppercase;color:#E2E8F0;">
          MỨC ${cluster.max_urgency} — ${cluster.display_label || 'SOS'}
        </span>
        <span style="font-family:'IBM Plex Mono',monospace;font-size:10px;
          padding:2px 6px;border-radius:4px;
          background:${color}20;color:${color};">
          ${cluster.victim_count} CA
        </span>
      </div>
      <div style="font-size:12px;color:#94A3B8;margin-bottom:4px;">
        ⏱ ${Math.round(cluster.minutes_waiting)}p chờ · ${cluster.responding_count} TNV đến
      </div>
      ${isOrphan ? `<div style="font-family:'IBM Plex Mono',monospace;font-size:11px;
        color:#EF4444;margin-top:6px;letter-spacing:0.06em;">⚠ CA MỒ CÔI</div>` : ''}
    </div>
  `;
}

function buildVolPopup(vol) {
  const color = vol.is_available ? '#34D399' : '#FBBF24';
  const label = vol.is_available ? '● RẢNH' : '● CỨU HỘ';
  const mins = vol.minutes_since_update ?? 0;
  return `
    <div style="font-family:'Barlow',sans-serif;min-width:210px;">
      <div style="display:flex;justify-content:space-between;align-items:center;padding:10px 14px;
        border-bottom:1px solid #1F2937;">
        <span style="font-family:'Barlow Condensed',sans-serif;font-size:14px;font-weight:600;
          letter-spacing:0.05em;text-transform:uppercase;color:#E2E8F0;">
          TNV #${(vol.id || '').slice(0,8).toUpperCase()}
        </span>
        <span style="font-family:'IBM Plex Mono',monospace;font-size:11px;
          padding:2px 8px;border-radius:12px;
          background:${vol.is_available ? '#052E16' : '#1C1003'};color:${color};">
          ${label}
        </span>
      </div>
      <div style="padding:10px 14px;display:flex;flex-direction:column;gap:6px;">
        <div style="display:flex;gap:8px;align-items:center;">
          <span style="font-family:'IBM Plex Mono',monospace;font-size:10px;color:#475569;
            text-transform:uppercase;letter-spacing:0.08em;width:60px;">Kỹ năng</span>
          <span style="font-size:12px;color:#94A3B8;">
            ${(vol.skills || []).join(', ') || 'Chưa khai báo'}
          </span>
        </div>
        <div style="display:flex;gap:8px;align-items:center;">
          <span style="font-family:'IBM Plex Mono',monospace;font-size:10px;color:#475569;
            text-transform:uppercase;letter-spacing:0.08em;width:60px;">Cập nhật</span>
          <span style="font-family:'IBM Plex Mono',monospace;font-size:12px;color:#94A3B8;">
            ${mins}p trước
          </span>
        </div>
      </div>
      ${vol.phone ? `<div style="padding:8px 14px;border-top:1px solid #1F2937;">
        <a href="tel:${vol.phone}" style="display:block;text-align:center;
          background:#0C2D3F;color:#0EA5E9;padding:7px;border-radius:6px;
          text-decoration:none;font-size:13px;font-weight:500;
          border:1px solid #0EA5E9;font-family:'Barlow',sans-serif;">
          📞 Gọi GSM trực tiếp
        </a>
      </div>` : ''}
    </div>
  `;
}


export default function LiveCommandMap({ onCaseSelect, selectedCaseId }) {
  const [isLegendExpanded, setIsLegendExpanded] = useState(false);

  const { data: caseClusters } = usePolling('/api/admin/case-clusters', 15000);
  const { data: volunteerLocations } = usePolling('/api/volunteers/locations', 15000);

  const center = [16.0544, 108.2022];

  return (
    <div style={{ width: '100%', height: '100%', position: 'relative' }}>
      <MapContainer
        center={center}
        zoom={10}
        style={{ width: '100%', height: '100%', background: '#080C10' }}
        zoomControl={false}
      >
        <TileLayer
          url="https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png"
          attribution='&copy; <a href="https://carto.com">CARTO</a>'
        />


        {/* SOS clusters */}
        {caseClusters?.map((cluster, i) => {
          if (!cluster.cluster_center) return null;
          return (
            <Marker
              key={`case-${cluster.cluster_id || i}`}
              position={[cluster.cluster_center.lat, cluster.cluster_center.lon]}
              icon={createSosIcon(cluster.max_urgency, cluster.victim_count)}
              eventHandlers={{
                click: () => onCaseSelect?.({ ...cluster, id: cluster.cluster_id }),
              }}
            >
              <Popup>
                <div dangerouslySetInnerHTML={{ __html: buildCasePopup(cluster) }} />
              </Popup>
            </Marker>
          );
        })}

        {/* Volunteers */}
        {volunteerLocations?.map(vol => {
          if (!vol.lat || !vol.lon) return null;
          return (
            <Marker
              key={`vol-${vol.id}`}
              position={[vol.lat, vol.lon]}
              icon={createVolunteerIcon(vol.is_available)}
            >
              <Popup>
                <div dangerouslySetInnerHTML={{ __html: buildVolPopup(vol) }} />
              </Popup>
            </Marker>
          );
        })}
      </MapContainer>

      {/* Map Legend — bottom left */}
      <div className="map-legend" style={{ position: 'absolute', bottom: 20, left: 20, zIndex: 1000 }}>
        <div style={{
          background: 'white',
          borderRadius: 8,
          padding: 12,
          boxShadow: '0 2px 10px rgba(0,0,0,0.1)',
          fontFamily: 'sans-serif',
          color: '#333',
          minWidth: 200,
          cursor: 'pointer'
        }} onClick={() => setIsLegendExpanded(!isLegendExpanded)}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <span style={{ fontSize: 13, fontWeight: 500 }}>Mức 1</span>
            <div style={{
              width: 60, height: 16, borderRadius: 8,
              background: 'linear-gradient(to right, #86EFAC, #FDE047, #FBBF24, #FCA5A5, #EF4444)'
            }} />
            <span style={{ fontSize: 13, fontWeight: 500 }}>Mức 5</span>
            <span style={{ marginLeft: 8 }}>
              {isLegendExpanded ? '⌄' : '⌃'}
            </span>
          </div>

          {isLegendExpanded && (
            <div style={{ marginTop: 12, display: 'flex', flexDirection: 'column', gap: 8 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <div style={{ width: 16, height: 16, borderRadius: 4, background: '#EF4444' }} />
                <span style={{ fontSize: 13 }}>Mức 5 - Rất cao</span>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <div style={{ width: 16, height: 16, borderRadius: 4, background: '#FCA5A5' }} />
                <span style={{ fontSize: 13 }}>Mức 4 - Cao</span>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <div style={{ width: 16, height: 16, borderRadius: 4, background: '#FBBF24' }} />
                <span style={{ fontSize: 13 }}>Mức 3 - Trung bình</span>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <div style={{ width: 16, height: 16, borderRadius: 4, background: '#FDE047' }} />
                <span style={{ fontSize: 13 }}>Mức 2 - Thấp</span>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <div style={{ width: 16, height: 16, borderRadius: 4, background: '#86EFAC' }} />
                <span style={{ fontSize: 13 }}>Mức 1 - Rất thấp</span>
              </div>
              <div style={{ height: 1, background: '#eee', margin: '4px 0' }} />
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <div style={{ width: 12, height: 12, borderRadius: '50%', background: '#34D399' }} />
                <span style={{ fontSize: 13 }}>Tình nguyện viên</span>
              </div>

            </div>
          )}
        </div>
      </div>
    </div>
  );
}
