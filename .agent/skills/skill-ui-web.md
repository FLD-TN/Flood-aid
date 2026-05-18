# skill-ui-web.md — UI Design System: Admin Web Dashboard

> File này định nghĩa design system cho toàn bộ React Admin Dashboard.
> AI Agent PHẢI đọc file này trước khi viết bất kỳ component/page nào.

---

## Định hướng thiết kế

**Tên concept:** *Ops Center* — Trung tâm điều hành, không phải bảng quản trị thông thường.

Dashboard này là "War Room" của người điều phối cứu hộ trong thiên tai.
Không phải SaaS dashboard với sidebar trắng và card bo góc nhẹ.
Không phải Material Design flat layout thông thường.

Thay vào đó: **Dark command center** — mật độ thông tin cao, hierarchy rõ ràng tức thì,
dữ liệu đọc được từ xa ở 80cm, màu sắc truyền tải ý nghĩa không cần nhãn.

Cảm hứng: Bloomberg Terminal gặp Figma + hiện đại hóa cho web 2024.
Typography: condensed, technical, authoritative.
Layout: không đối xứng có chủ ý — bản đồ chiếm 65% viewport là chủ thể.

---

## 1. Color System (CSS Variables)

```css
/* src/styles/tokens.css — import vào index.css */

:root {
  /* ── Backgrounds ── */
  --bg-base:        #080C10;   /* near-black, hơi blue tint */
  --bg-surface:     #0E1318;   /* card, panel */
  --bg-elevated:    #151C24;   /* input, hover row */
  --bg-overlay:     #1C2430;   /* dropdown, modal */
  --border-subtle:  #1F2937;   /* divider, card border */
  --border-default: #2D3748;   /* input border, separator */

  /* ── Brand ── */
  --brand:          #0EA5E9;   /* sky blue — primary action, active state */
  --brand-dim:      #0C2D3F;   /* brand background tint */
  --brand-glow:     rgba(14, 165, 233, 0.25);

  /* ── Status / Urgency ── */
  --status-pending:    #F87171;  /* đỏ nhạt — đang chờ, nguy hiểm */
  --status-responding: #FBBF24;  /* amber — đang xử lý */
  --status-on-scene:   #34D399;  /* teal green — tại chỗ */
  --status-resolved:   #4B5563;  /* xám — đã đóng */

  --urgency-5: #EF4444;  /* critical */
  --urgency-4: #F97316;  /* high */
  --urgency-3: #F59E0B;  /* medium */
  --urgency-2: #22C55E;  /* low */
  --urgency-1: #3B82F6;  /* info */

  /* ── Text ── */
  --text-primary:   #E2E8F0;  /* main content */
  --text-secondary: #94A3B8;  /* labels, metadata */
  --text-muted:     #475569;  /* placeholders, disabled */
  --text-accent:    #0EA5E9;  /* link, highlight */

  /* ── Map Markers ── */
  --marker-victim:    #EF4444;
  --marker-volunteer: #22C55E;
  --marker-flag:      #F59E0B;
  --marker-orphan:    #A855F7;  /* purple — ca mồ côi */

  /* ── Shadows ── */
  --shadow-card:  0 1px 3px rgba(0,0,0,0.5), 0 1px 2px rgba(0,0,0,0.3);
  --shadow-panel: 0 4px 24px rgba(0,0,0,0.6);
  --glow-danger:  0 0 16px rgba(239, 68, 68, 0.4);
  --glow-brand:   0 0 16px rgba(14, 165, 233, 0.3);
}
```

---

## 2. Typography

```css
/* src/styles/typography.css */
/* Fonts: Barlow Condensed (display/heading) + IBM Plex Mono (data/numbers) + Barlow (body) */

@import url('https://fonts.googleapis.com/css2?family=Barlow+Condensed:wght@500;600;700&family=Barlow:wght@400;500&family=IBM+Plex+Mono:wght@400;500&display=swap');

:root {
  --font-display: 'Barlow Condensed', sans-serif;
  --font-body:    'Barlow', sans-serif;
  --font-mono:    'IBM Plex Mono', monospace;

  /* Scale */
  --text-xs:   11px;
  --text-sm:   13px;
  --text-base: 15px;
  --text-lg:   17px;
  --text-xl:   20px;
  --text-2xl:  24px;
  --text-3xl:  30px;
  --text-4xl:  38px;

  --leading-tight:  1.1;
  --leading-normal: 1.5;
  --leading-loose:  1.8;
  --tracking-wide:  0.08em;
  --tracking-wider: 0.12em;
}

/* Heading styles */
.heading-display {
  font-family: var(--font-display);
  font-size: var(--text-4xl);
  font-weight: 700;
  letter-spacing: -0.02em;
  line-height: var(--leading-tight);
  color: var(--text-primary);
}

.heading-section {
  font-family: var(--font-display);
  font-size: var(--text-xl);
  font-weight: 600;
  letter-spacing: var(--tracking-wide);
  text-transform: uppercase;
  color: var(--text-secondary);
}

.data-number {
  font-family: var(--font-mono);
  font-size: var(--text-3xl);
  font-weight: 500;
  letter-spacing: -0.02em;
  color: var(--text-primary);
}

.data-label {
  font-family: var(--font-body);
  font-size: var(--text-xs);
  font-weight: 500;
  letter-spacing: var(--tracking-wider);
  text-transform: uppercase;
  color: var(--text-muted);
}
```

---

## 3. Layout System

```css
/* src/styles/layout.css */

/* Dashboard layout: sidebar cố định + main content + map chiếm 65% */
.dashboard-root {
  display: grid;
  grid-template-columns: 280px 1fr;
  grid-template-rows: 52px 1fr;
  height: 100vh;
  background: var(--bg-base);
  overflow: hidden;
}

.topbar {
  grid-column: 1 / -1;
  display: flex;
  align-items: center;
  padding: 0 20px;
  background: var(--bg-surface);
  border-bottom: 1px solid var(--border-subtle);
  gap: 16px;
}

.sidebar {
  background: var(--bg-surface);
  border-right: 1px solid var(--border-subtle);
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.main-content {
  display: grid;
  grid-template-columns: 1fr 360px; /* map 65% + panel 35% */
  overflow: hidden;
}

.map-container {
  position: relative;
  overflow: hidden;
}

.side-panel {
  background: var(--bg-surface);
  border-left: 1px solid var(--border-subtle);
  display: flex;
  flex-direction: column;
  overflow: hidden;
}
```

---

## 4. Components

### 4.1 Stat Card (KPI metrics ở topbar)

```jsx
// components/StatCard.jsx

export function StatCard({ label, value, unit, status, delta }) {
  const statusColor = {
    danger:  'var(--status-pending)',
    warning: 'var(--status-responding)',
    ok:      'var(--status-on-scene)',
    neutral: 'var(--text-secondary)',
  }[status || 'neutral'];

  return (
    <div style={{
      display: 'flex',
      flexDirection: 'column',
      gap: 2,
      padding: '8px 16px',
      borderLeft: `2px solid ${statusColor}`,
      minWidth: 100,
    }}>
      <span style={{
        fontFamily: 'var(--font-mono)',
        fontSize: 'var(--text-2xl)',
        fontWeight: 500,
        color: statusColor,
        lineHeight: 1,
      }}>
        {value}<span style={{ fontSize: 13, color: 'var(--text-muted)', marginLeft: 3 }}>{unit}</span>
      </span>
      <span className="data-label">{label}</span>
      {delta && (
        <span style={{ fontSize: 11, color: 'var(--text-muted)' }}>{delta}</span>
      )}
    </div>
  );
}

// Dùng:
// <StatCard label="CA ĐANG CHỜ" value={12} status="danger" />
// <StatCard label="TNV HOẠT ĐỘNG" value={34} status="ok" />
// <StatCard label="CA MỒ CÔI" value={2} status="danger" delta="+2 trong 15p" />
```

### 4.2 Case List Item

```jsx
// components/CaseListItem.jsx

const STATUS_CONFIG = {
  pending:    { color: 'var(--status-pending)',    dot: '●', label: 'CHỜ' },
  responding: { color: 'var(--status-responding)', dot: '●', label: 'XỬ LÝ' },
  on_scene:   { color: 'var(--status-on-scene)',   dot: '●', label: 'TẠI CHỖ' },
};

export function CaseListItem({ caseData, isSelected, onClick }) {
  const config = STATUS_CONFIG[caseData.status] || STATUS_CONFIG.pending;
  const isOrphan = caseData.minutes_waiting > 15 && caseData.responding_count === 0;
  const urgencyColor = `var(--urgency-${caseData.urgency_level})`;

  return (
    <div
      onClick={onClick}
      style={{
        padding: '10px 16px',
        background: isSelected ? 'var(--bg-elevated)' : 'transparent',
        borderLeft: isSelected ? `3px solid var(--brand)` : '3px solid transparent',
        cursor: 'pointer',
        transition: 'background 0.15s',
        animation: isOrphan ? 'orphanPulse 2s infinite' : 'none',
      }}
    >
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 4 }}>
        {/* Urgency badge */}
        <span style={{
          fontFamily: 'var(--font-mono)',
          fontSize: 10,
          fontWeight: 500,
          color: urgencyColor,
          background: urgencyColor + '20',
          padding: '2px 6px',
          borderRadius: 4,
          letterSpacing: '0.08em',
        }}>
          MỨC {caseData.urgency_level}
        </span>

        {/* Status dot */}
        <span style={{ color: config.color, fontSize: 11, display: 'flex', alignItems: 'center', gap: 4 }}>
          <span style={{ fontSize: 8 }}>{config.dot}</span>
          {config.label}
        </span>
      </div>

      {/* Summary */}
      <p style={{
        margin: '4px 0',
        fontFamily: 'var(--font-body)',
        fontSize: 'var(--text-sm)',
        color: 'var(--text-primary)',
        lineHeight: 1.4,
        overflow: 'hidden',
        display: '-webkit-box',
        WebkitLineClamp: 2,
        WebkitBoxOrient: 'vertical',
      }}>
        {caseData.summary_1line}
      </p>

      {/* Meta */}
      <div style={{ display: 'flex', gap: 12, marginTop: 4 }}>
        <span style={{ fontFamily: 'var(--font-mono)', fontSize: 11, color: 'var(--text-muted)' }}>
          {Math.round(caseData.minutes_waiting)}p
        </span>
        <span style={{ fontSize: 11, color: 'var(--text-secondary)' }}>
          {caseData.responding_count} TNV đang đến
        </span>
        {isOrphan && (
          <span style={{ fontSize: 11, color: 'var(--urgency-5)', fontWeight: 600 }}>
            ⚠ CA MỒ CÔI
          </span>
        )}
      </div>
    </div>
  );
}
```

### 4.3 Warning Flag Toolbar

```jsx
// components/FlagToolbar.jsx

const FLAG_TYPES = [
  { type: 'tree_down',        icon: '🌲', label: 'Cây đổ' },
  { type: 'bridge_collapsed', icon: '⛓',  label: 'Cầu sập' },
  { type: 'flooded_road',     icon: '🌊',  label: 'Đường ngập' },
];

export function FlagToolbar({ onSelectFlag, selectedFlagType }) {
  return (
    <div style={{
      position: 'absolute',
      top: 16,
      right: 16,
      zIndex: 10,
      background: 'var(--bg-surface)',
      border: '1px solid var(--border-default)',
      borderRadius: 8,
      overflow: 'hidden',
      boxShadow: 'var(--shadow-panel)',
    }}>
      <div style={{
        padding: '8px 12px 6px',
        borderBottom: '1px solid var(--border-subtle)',
      }}>
        <span className="data-label">Cắm cờ cảnh báo</span>
      </div>
      {FLAG_TYPES.map(({ type, icon, label }) => (
        <button
          key={type}
          onClick={() => onSelectFlag(type)}
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 10,
            width: '100%',
            padding: '9px 16px',
            background: selectedFlagType === type ? 'var(--brand-dim)' : 'transparent',
            border: 'none',
            borderLeft: selectedFlagType === type ? '2px solid var(--brand)' : '2px solid transparent',
            color: selectedFlagType === type ? 'var(--brand)' : 'var(--text-secondary)',
            cursor: 'pointer',
            fontSize: 13,
            fontFamily: 'var(--font-body)',
            textAlign: 'left',
            transition: 'all 0.15s',
          }}
        >
          <span>{icon}</span>
          <span>{label}</span>
        </button>
      ))}
      {selectedFlagType && (
        <div style={{
          padding: '8px 16px',
          background: 'var(--brand-dim)',
          borderTop: '1px solid var(--border-subtle)',
          fontSize: 11,
          color: 'var(--brand)',
          fontFamily: 'var(--font-mono)',
        }}>
          CLICK VÀO BẢN ĐỒ ĐỂ ĐẶT CỜ
        </div>
      )}
    </div>
  );
}
```

### 4.4 Volunteer Popup (click vào marker TNV)

```jsx
// Mapbox popup content cho TNV
function buildVolunteerPopupHtml(vol) {
  return `
    <div style="
      font-family: 'Barlow', sans-serif;
      min-width: 220px;
      background: #0E1318;
      color: #E2E8F0;
      border: 1px solid #2D3748;
      border-radius: 8px;
      overflow: hidden;
    ">
      <div style="padding: 10px 14px; border-bottom: 1px solid #1F2937;">
        <div style="display:flex; justify-content:space-between; align-items:center;">
          <span style="font-family:'Barlow Condensed'; font-size:15px; font-weight:600; letter-spacing:0.05em; text-transform:uppercase;">
            TNV #${vol.id.slice(0,8).toUpperCase()}
          </span>
          <span style="
            font-size:11px; padding:2px 8px; border-radius:12px;
            background: ${vol.is_available ? '#052E16' : '#1C1003'};
            color: ${vol.is_available ? '#34D399' : '#FBBF24'};
            font-family:'IBM Plex Mono';
          ">
            ${vol.is_available ? '● RẢNH' : '● CỨU HỘ'}
          </span>
        </div>
      </div>
      <div style="padding: 10px 14px; display:flex; flex-direction:column; gap:8px;">
        <div style="display:flex; align-items:center; gap:8px;">
          <span style="font-size:11px; color:#475569; font-family:'IBM Plex Mono'; text-transform:uppercase; letter-spacing:0.08em; width:60px;">Kỹ năng</span>
          <span style="font-size:12px; color:#94A3B8;">${(vol.skills || []).join(', ') || 'Chưa khai báo'}</span>
        </div>
        <div style="display:flex; align-items:center; gap:8px;">
          <span style="font-size:11px; color:#475569; font-family:'IBM Plex Mono'; text-transform:uppercase; letter-spacing:0.08em; width:60px;">Cập nhật</span>
          <span style="font-size:12px; font-family:'IBM Plex Mono'; color:#94A3B8;">${vol.minutes_since_update}p trước</span>
        </div>
      </div>
      <div style="padding: 8px 14px; border-top: 1px solid #1F2937;">
        <a href="tel:${vol.phone}" style="
          display:block; text-align:center;
          background:#0C2D3F; color:#0EA5E9;
          padding:8px; border-radius:6px;
          text-decoration:none; font-size:13px; font-weight:500;
          border: 1px solid #0EA5E9;
        ">
          📞 Gọi GSM trực tiếp
        </a>
      </div>
    </div>
  `;
}
```

---

## 5. Keyframe Animations

```css
/* src/styles/animations.css */

/* Ca mồ côi — nhấp nháy đỏ */
@keyframes orphanPulse {
  0%, 100% { background: transparent; }
  50%       { background: rgba(239, 68, 68, 0.08); }
}

/* Marker mới xuất hiện */
@keyframes markerAppear {
  from { transform: scale(0) translateY(-8px); opacity: 0; }
  to   { transform: scale(1) translateY(0); opacity: 1; }
}

/* Số liệu update */
@keyframes numberFlash {
  0%   { color: var(--brand); }
  100% { color: var(--text-primary); }
}

/* Dot pulse cho status indicator */
@keyframes dotPulse {
  0%, 100% { opacity: 1; transform: scale(1); }
  50%      { opacity: 0.5; transform: scale(0.85); }
}

.status-dot--pending    { animation: dotPulse 1.2s infinite; }
.status-dot--responding { animation: dotPulse 2s infinite; }
```

---

## 6. Dashboard Layout (Visual Spec)

```
┌─────────────────────────────────────────────────────────────────────┐
│ TOPBAR 52px                                                         │
│ [FloodAid ⚡] │ ● 12 CA CHỜ │ ● 34 TNV │ ⚠ 2 MỒ CÔI │ [Admin ▾] │
├───────────────┬─────────────────────────────────────┬───────────────┤
│ SIDEBAR 280px │                                     │ PANEL 360px   │
│               │        LIVE COMMAND MAP             │               │
│ [CẢ CA SOS]   │                                     │ [CaseList     │
│ ─────────────  │   65% viewport                      │  scroll]      │
│ Mức 5 (2)     │                                     │               │
│ Mức 4 (5)     │   📍📍 victim markers               │ ──────────── │
│ Mức 3 (5)     │       🟢 volunteer markers           │ [Đang chờ]   │
│ ─────────────  │         🚩 warning flags            │ ● Ca #1... 5p│
│ [TNV RÀNh]    │                                     │ ● Ca #2... 8p│
│ [CẢNH BÁO]    │   [Flag Toolbar]                    │ ⚠ Ca #3 ORPHAN│
│               │                                     │               │
│ ─────────────  │                                     │ ──────────── │
│ [THỐNG KÊ]    │                                     │ [KHI CHỌN CA]│
│               │                                     │ > Chi tiết   │
│               │                                     │ > Gọi TNV    │
│               │                                     │ > Đóng ca    │
└───────────────┴─────────────────────────────────────┴───────────────┘
```

---

## 7. UI Rules (Không được vi phạm)

```
1. KHÔNG dùng màu trắng (#fff) làm background — dùng var(--bg-base) hoặc var(--bg-surface)
2. KHÔNG dùng border-radius > 12px cho panel/card lớn — trông giống SaaS generic
3. Data numbers PHẢI dùng font-mono (IBM Plex Mono) — không dùng sans-serif
4. Section heading PHẢI uppercase + letter-spacing rộng — không title case
5. Ca mồ côi (orphan) PHẢI có animation pulse — không chỉ đổi màu tĩnh
6. Map chiếm tối thiểu 60% width — đây là primary content
7. Hover state: background đổi sang var(--bg-elevated), transition 0.15s
8. Link gọi điện TNV PHẢI là <a href="tel:..."> — không button giả
9. Polling interval 15s PHẢI có visual indicator (timestamp "Cập nhật: Xs trước")
10. Mobile responsive KHÔNG cần — dashboard chỉ dùng trên desktop admin
```
