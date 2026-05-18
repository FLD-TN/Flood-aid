import { resolveCase } from '../api';

const URGENCY_COLORS = {
  5: 'var(--urgency-5)', 4: 'var(--urgency-4)',
  3: 'var(--urgency-3)', 2: 'var(--urgency-2)', 1: 'var(--urgency-1)',
};

const STATUS_LABELS = {
  pending:    { label: 'CHỜ CỨU HỘ',   color: 'var(--status-pending)' },
  responding: { label: 'CÓ TNV ĐI ĐẾN', color: 'var(--status-responding)' },
  on_scene:   { label: 'TNV TẠI CHỖ',  color: 'var(--status-on-scene)' },
  resolved:   { label: 'ĐÃ ĐÓNG',      color: 'var(--status-resolved)' },
};

const TAG_MAP = {
  y_te: '🩹 Y tế', tre_em: '👶 Trẻ em',
  nguoi_gia: '👴 Người già', can_xuong: '🚣 Xuồng', ngap_nha: '🏠 Ngập',
};

export default function CaseDetailPanel({ caseData, onClose }) {
  const c = caseData;
  const urgColor = URGENCY_COLORS[c.urgency_level] || 'var(--urgency-3)';
  const statusCfg = STATUS_LABELS[c.status] || STATUS_LABELS.pending;
  const isOrphan = c.minutes_waiting > 15 && (c.responding_count ?? 0) === 0
    && c.status === 'pending';

  async function handleCloseCase() {
    if (!window.confirm(`Đóng ca SOS #${c.id?.slice(0,8).toUpperCase()}?`)) return;
    await resolveCase(c.id, 'admin');
    onClose();
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
      {/* Header */}
      <div className="side-panel-header">
        <div>
          <div style={{
            fontFamily: 'var(--font-mono)',
            fontSize: 11,
            color: 'var(--text-muted)',
            letterSpacing: '0.1em',
            marginBottom: 2,
          }}>
            CA #{c.id?.slice(0,8).toUpperCase() || '--------'}
          </div>
          <div style={{
            fontFamily: 'var(--font-display)',
            fontSize: 16,
            fontWeight: 600,
            letterSpacing: '0.06em',
            textTransform: 'uppercase',
            color: statusCfg.color,
          }}>
            {statusCfg.label}
          </div>
        </div>
        <button
          onClick={onClose}
          style={{
            background: 'none', border: 'none',
            color: 'var(--text-muted)', cursor: 'pointer', fontSize: 18,
            width: 32, height: 32, display: 'flex', alignItems: 'center', justifyContent: 'center',
            borderRadius: 4, transition: 'color 0.15s',
          }}
          title="Đóng panel"
        >
          ✕
        </button>
      </div>

      {/* Orphan alert */}
      {isOrphan && (
        <div style={{
          padding: '8px 16px',
          background: 'rgba(239,68,68,0.08)',
          borderLeft: '3px solid var(--urgency-5)',
          fontFamily: 'var(--font-mono)',
          fontSize: 11,
          color: 'var(--urgency-5)',
          letterSpacing: '0.1em',
          animation: 'orphanPulse 2s infinite',
        }}>
          ⚠ CA MỒ CÔI — CHƯA CÓ TNV SAU {Math.round(c.minutes_waiting)}P
        </div>
      )}

      {/* Detail content */}
      <div className="detail-panel">
        {/* Urgency + Tags */}
        <div>
          <div className="detail-section-label">Mức độ & Phân loại</div>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, alignItems: 'center' }}>
            <span style={{
              fontFamily: 'var(--font-mono)',
              fontSize: 12,
              padding: '3px 8px',
              borderRadius: 4,
              background: `color-mix(in srgb, ${urgColor} 15%, transparent)`,
              color: urgColor,
              fontWeight: 500,
              letterSpacing: '0.08em',
            }}>
              MỨC {c.urgency_level}
            </span>
            {(c.tags || []).map(tag => (
              <span key={tag} className="tag-chip">
                {TAG_MAP[tag] || tag}
              </span>
            ))}
          </div>
        </div>

        {/* SOS Text */}
        <div>
          <div className="detail-section-label">Mô tả SOS</div>
          <div className="detail-sos-text">
            {c.summary_1line || c.sos_text || '(Không có mô tả)'}
          </div>
        </div>

        {/* Stats */}
        <div style={{
          display: 'grid',
          gridTemplateColumns: '1fr 1fr',
          gap: 8,
        }}>
          {[
            { label: 'CHỜ ĐỢI', value: `${Math.round(c.minutes_waiting ?? 0)}p` },
            { label: 'TNV ĐI ĐẾN', value: c.responding_count ?? 0 },
          ].map(({ label, value }) => (
            <div key={label} style={{
              padding: '10px 12px',
              background: 'var(--bg-elevated)',
              border: '1px solid var(--border-subtle)',
              borderRadius: 6,
            }}>
              <div style={{
                fontFamily: 'var(--font-mono)',
                fontSize: 'var(--text-2xl)',
                fontWeight: 500,
                color: 'var(--text-primary)',
                lineHeight: 1,
              }}>
                {value}
              </div>
              <div className="detail-section-label" style={{ marginBottom: 0, marginTop: 4 }}>
                {label}
              </div>
            </div>
          ))}
        </div>

        {/* Volunteers assigned */}
        {(c.volunteers || []).length > 0 && (
          <div>
            <div className="detail-section-label">TNV Được Cử</div>
            {c.volunteers.map(vol => (
              <div key={vol.id} style={{
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                padding: '8px 10px',
                background: 'var(--bg-elevated)',
                border: '1px solid var(--border-subtle)',
                borderRadius: 6,
                marginBottom: 6,
              }}>
                <div>
                  <div style={{
                    fontFamily: 'var(--font-mono)',
                    fontSize: 12,
                    color: 'var(--text-primary)',
                  }}>
                    TNV #{vol.id?.slice(0,8).toUpperCase()}
                  </div>
                  <div style={{ fontSize: 11, color: 'var(--text-muted)' }}>
                    {vol.distance_m != null ? `${vol.distance_m}m` : '–'} · {vol.minutes_since_update ?? 0}p trước
                  </div>
                </div>
                {vol.phone && (
                  <a
                    href={`tel:${vol.phone}`}
                    className="detail-action-btn call"
                    style={{ width: 'auto', textDecoration: 'none', fontSize: 12, padding: '5px 10px' }}
                  >
                    📞 GSM
                  </a>
                )}
              </div>
            ))}
          </div>
        )}

        {/* Actions */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {c.status !== 'resolved' && (
            <button className="detail-action-btn close-case" onClick={handleCloseCase}>
              ✅ Đóng ca SOS này
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
