import { useEffect, useMemo, useState } from 'react';
import { MapContainer, TileLayer, Marker, Popup, useMap } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import Icon from './ui/Icon';
import { useTheme } from '../theme/themeContext';
import { URGENCY, formatWaiting, shortId, urgencyColor } from '../lib/caseMeta';

// Sửa đường dẫn icon mặc định của Leaflet (bundler làm hỏng)
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-icon-2x.png',
  iconUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-icon.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-shadow.png',
});

const DA_NANG = [16.0544, 108.2022];

const BASEMAPS = {
  auto: {
    label: 'Theo giao diện',
    icon: 'contrast',
    url: null, // quyết định theo theme
    attribution: '&copy; <a href="https://carto.com">CARTO</a>',
  },
  street: {
    label: 'Đường phố',
    icon: 'map',
    url: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
    attribution: '&copy; <a href="https://carto.com">CARTO</a>',
  },
  satellite: {
    label: 'Vệ tinh',
    icon: 'satellite_alt',
    url: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    attribution: '&copy; Esri',
  },
};

function createSosIcon(urgencyLevel, count = 1, selected = false) {
  const color = urgencyColor(urgencyLevel);
  const size = (count > 1 ? 38 : 30) + (selected ? 6 : 0);
  return L.divIcon({
    className: '',
    html: `<div style="
      width:${size}px;height:${size}px;background:${color};border-radius:50%;
      border:${selected ? 3 : 2.5}px solid rgba(255,255,255,0.9);
      display:flex;align-items:center;justify-content:center;
      color:#fff;font-weight:700;font-size:${count > 1 ? 13 : 11}px;
      box-shadow:0 0 ${selected ? 20 : 12}px ${color},0 2px 8px rgba(0,0,0,0.45);
      font-family:'Roboto Mono',monospace;
    ">${count > 1 ? count : '!'}</div>`,
    iconSize: [size, size],
    iconAnchor: [size / 2, size / 2],
  });
}

function createVolunteerIcon(isAvailable) {
  const color = isAvailable ? '#34D399' : '#FBBF24';
  return L.divIcon({
    className: '',
    html: `<div style="
      width:16px;height:16px;background:${color};border-radius:50%;
      border:2px solid rgba(255,255,255,0.85);
      box-shadow:0 0 8px ${color},0 2px 4px rgba(0,0,0,0.4);
    "></div>`,
    iconSize: [16, 16],
    iconAnchor: [8, 8],
  });
}

/**
 * Giữ kích thước bản đồ khớp với container.
 * Khi thu/mở sidebar hoặc mở panel chi tiết, container đổi bề rộng nhưng
 * Leaflet không tự biết → tile xám và marker lệch. ResizeObserver xử lý việc đó.
 */
function AutoResize() {
  const map = useMap();
  useEffect(() => {
    const el = map.getContainer();
    const ro = new ResizeObserver(() => map.invalidateSize({ animate: false }));
    ro.observe(el);
    return () => ro.disconnect();
  }, [map]);
  return null;
}

/** Bay tới ca đang chọn để nó không nằm khuất dưới panel. */
function FlyToSelected({ target }) {
  const map = useMap();
  useEffect(() => {
    if (!target) return;
    map.flyTo(target, Math.max(map.getZoom(), 14), { duration: 0.6 });
  }, [map, target]);
  return null;
}

function MapControls({ basemap, onBasemapChange }) {
  const map = useMap();
  const [layersOpen, setLayersOpen] = useState(false);

  return (
    <div className="absolute right-md top-md z-[1000] flex flex-col items-end gap-sm">
      {/* Chọn lớp nền */}
      <div className="relative">
        <button
          onClick={() => setLayersOpen((v) => !v)}
          className="glass-panel icon-btn h-9 w-9 rounded-lg"
          title="Lớp bản đồ"
          aria-label="Lớp bản đồ"
        >
          <Icon name="layers" size={20} />
        </button>

        {layersOpen && (
          <div className="panel absolute right-0 top-full mt-xs w-44 animate-fade-in overflow-hidden p-0">
            {Object.entries(BASEMAPS).map(([key, cfg]) => (
              <button
                key={key}
                onClick={() => {
                  onBasemapChange(key);
                  setLayersOpen(false);
                }}
                className={`flex w-full items-center gap-sm px-md py-sm text-left font-body-md text-xs transition-colors hover:bg-surface-bright ${
                  basemap === key ? 'bg-primary/10 text-primary' : 'text-on-surface'
                }`}
              >
                <Icon name={cfg.icon} size={18} />
                {cfg.label}
              </button>
            ))}
          </div>
        )}
      </div>

      <div className="glass-panel flex flex-col overflow-hidden rounded-lg">
        <button
          onClick={() => map.zoomIn()}
          className="icon-btn h-9 w-9 rounded-none"
          title="Phóng to"
          aria-label="Phóng to"
        >
          <Icon name="add" size={20} />
        </button>
        <span className="h-px bg-outline-variant/60" />
        <button
          onClick={() => map.zoomOut()}
          className="icon-btn h-9 w-9 rounded-none"
          title="Thu nhỏ"
          aria-label="Thu nhỏ"
        >
          <Icon name="remove" size={20} />
        </button>
      </div>

      <button
        onClick={() => map.flyTo(DA_NANG, 11, { duration: 0.6 })}
        className="glass-panel icon-btn h-9 w-9 rounded-lg"
        title="Về vùng trung tâm"
        aria-label="Về vùng trung tâm"
      >
        <Icon name="near_me" size={20} />
      </button>

      <button
        onClick={() =>
          map.locate({ setView: true, maxZoom: 15 }).on('locationerror', () =>
            window.alert('Không lấy được vị trí của bạn. Kiểm tra quyền truy cập vị trí của trình duyệt.'),
          )
        }
        className="glass-panel icon-btn h-9 w-9 rounded-lg"
        title="Vị trí của tôi"
        aria-label="Vị trí của tôi"
      >
        <Icon name="my_location" size={20} />
      </button>
    </div>
  );
}

/** Chú giải — thu gọn mặc định, đặt góc dưới phải để không đè lên panel trái. */
function MapLegend() {
  const [open, setOpen] = useState(false);

  return (
    <div className="absolute bottom-md right-md z-[1000] max-w-[calc(100%-2rem)]">
      <div className="glass-panel overflow-hidden rounded-xl">
        <button
          onClick={() => setOpen((v) => !v)}
          className="flex w-full items-center gap-sm px-md py-sm text-left transition-colors hover:bg-surface-bright/40"
          aria-expanded={open}
        >
          <span className="section-label">Mức 1</span>
          <span
            className="h-2.5 w-14 rounded-full"
            style={{
              background:
                'linear-gradient(to right, rgb(var(--urgency-1)), rgb(var(--urgency-2)), rgb(var(--urgency-3)), rgb(var(--urgency-4)), rgb(var(--urgency-5)))',
            }}
          />
          <span className="section-label">Mức 5</span>
          <Icon
            name="expand_less"
            size={18}
            className={`ml-auto text-on-surface-variant transition-transform ${open ? 'rotate-180' : ''}`}
          />
        </button>

        {open && (
          <div className="space-y-xs border-t border-outline-variant/60 px-md py-sm">
            {[5, 4, 3, 2, 1].map((lv) => (
              <div key={lv} className="flex items-center gap-sm">
                <span
                  className="h-3 w-3 shrink-0 rounded"
                  style={{ background: `rgb(var(--${URGENCY[lv].token}))` }}
                />
                <span className="font-body-md text-xs text-on-surface">
                  Mức {lv} — {URGENCY[lv].label}
                </span>
              </div>
            ))}
            <div className="my-xs h-px bg-outline-variant/60" />
            <div className="flex items-center gap-sm">
              <span className="h-3 w-3 shrink-0 rounded-full" style={{ background: '#34D399' }} />
              <span className="font-body-md text-xs text-on-surface">TNV đang rảnh</span>
            </div>
            <div className="flex items-center gap-sm">
              <span className="h-3 w-3 shrink-0 rounded-full" style={{ background: '#FBBF24' }} />
              <span className="font-body-md text-xs text-on-surface">TNV đang làm nhiệm vụ</span>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

/**
 * Bản đồ chỉ huy. Thuần hiển thị — dữ liệu do trang cha truyền xuống
 * (xem hooks/useOpsData) nên bản đồ và các bảng luôn cùng một mốc thời gian.
 */
export default function LiveCommandMap({
  clusters = [],
  volunteers = [],
  onCaseSelect,
  selectedCaseId,
  selectedPosition,
  className = '',
}) {
  const { isDark, theme } = useTheme();
  const [basemap, setBasemap] = useState('auto');

  const tile = useMemo(() => {
    if (basemap !== 'auto') return BASEMAPS[basemap];
    return {
      url: isDark
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
        : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
      attribution: BASEMAPS.auto.attribution,
    };
  }, [basemap, isDark]);

  return (
    // `isolate` nhốt các z-index cao của Leaflet (pane, control ~1000) vào một
    // stacking context riêng — không có nó, nút điều khiển bản đồ sẽ nổi đè lên
    // cả ngăn kéo chi tiết (z-50) khi mở trên mobile.
    <div className={`relative isolate h-full w-full overflow-hidden ${className}`}>
      <MapContainer
        center={DA_NANG}
        zoom={11}
        zoomControl={false}
        attributionControl
        className="h-full w-full"
      >
        {/* key ép Leaflet thay tile khi đổi theme/lớp nền */}
        <TileLayer key={`${basemap}-${theme}`} url={tile.url} attribution={tile.attribution} />

        <AutoResize />
        <FlyToSelected target={selectedPosition} />
        <MapControls basemap={basemap} onBasemapChange={setBasemap} />

        {clusters.map((cluster, i) => {
          if (!cluster.cluster_center) return null;
          const id = cluster.cluster_id || `c-${i}`;
          const selected = id === selectedCaseId;

          return (
            <Marker
              key={`case-${id}`}
              position={[cluster.cluster_center.lat, cluster.cluster_center.lon]}
              icon={createSosIcon(cluster.max_urgency, cluster.victim_count, selected)}
              zIndexOffset={selected ? 1000 : 0}
              eventHandlers={{ click: () => onCaseSelect?.({ ...cluster, id }) }}
            >
              <Popup>
                <div className="min-w-[200px] font-body-md">
                  <div className="mb-sm flex items-center justify-between gap-sm">
                    <span className="font-label-sm text-xs font-bold uppercase tracking-wider text-on-surface">
                      Mức {cluster.max_urgency} — {cluster.display_label || 'SOS'}
                    </span>
                    <span
                      className="chip"
                      style={{
                        background: `rgb(var(--${URGENCY[cluster.max_urgency]?.token || 'urgency-3'}) / 0.15)`,
                        color: `rgb(var(--${URGENCY[cluster.max_urgency]?.token || 'urgency-3'}))`,
                      }}
                    >
                      {cluster.victim_count} ca
                    </span>
                  </div>
                  <p className="text-xs text-on-surface-variant">
                    Chờ {formatWaiting(cluster.minutes_waiting)} · {cluster.responding_count || 0} TNV đang đến
                  </p>
                  {cluster.minutes_waiting > 15 && !cluster.responding_count && (
                    <p className="mt-xs font-label-sm text-[11px] tracking-wider text-error">⚠ CA MỒ CÔI</p>
                  )}
                  <button
                    onClick={() => onCaseSelect?.({ ...cluster, id })}
                    className="btn-primary mt-sm w-full"
                  >
                    Xem chi tiết
                  </button>
                </div>
              </Popup>
            </Marker>
          );
        })}

        {volunteers.map((vol) => {
          if (!vol.lat || !vol.lon) return null;
          return (
            <Marker
              key={`vol-${vol.id}`}
              position={[vol.lat, vol.lon]}
              icon={createVolunteerIcon(vol.is_available)}
            >
              <Popup>
                <div className="min-w-[190px] font-body-md">
                  <div className="mb-sm flex items-center justify-between gap-sm">
                    <span className="font-label-sm text-xs font-bold text-on-surface">
                      TNV #{shortId(vol.id)}
                    </span>
                    <span
                      className={`chip ${vol.is_available ? 'bg-success/15 text-success' : 'bg-warning/15 text-warning'}`}
                    >
                      {vol.is_available ? 'Rảnh' : 'Cứu hộ'}
                    </span>
                  </div>
                  <p className="text-xs text-on-surface-variant">
                    Cập nhật {vol.minutes_since_update ?? 0} phút trước
                  </p>
                  {vol.phone && (
                    <a href={`tel:${vol.phone}`} className="btn-primary mt-sm w-full no-underline">
                      Gọi {vol.phone}
                    </a>
                  )}
                </div>
              </Popup>
            </Marker>
          );
        })}
      </MapContainer>

      <MapLegend />
    </div>
  );
}
