import { useState } from 'react';
import { resolveCase } from '../api';
import Icon from './ui/Icon';
import {
  TAG_LABELS,
  formatWaiting,
  isOrphanCase,
  shortId,
  statusMeta,
  urgencyMeta,
} from '../lib/caseMeta';

/**
 * Panel chi tiết ca SOS.
 *
 * Bản cũ style bằng các biến CSS (--bg-elevated, --font-mono…) chưa từng được
 * định nghĩa nên hiện ra không có định dạng; giờ dùng token của design system.
 */
export default function CaseDetailPanel({ caseData, onClose, onResolved }) {
  const [closing, setClosing] = useState(false);
  const [error, setError] = useState('');

  if (!caseData) return null;

  const c = caseData;
  const urgency = urgencyMeta(c.urgency_level);
  const status = statusMeta(c.status);
  const orphan = isOrphanCase(c);
  const volunteers = c.volunteers || [];

  async function handleCloseCase() {
    if (!window.confirm(`Đóng ca SOS #${shortId(c.id)}?`)) return;
    setClosing(true);
    setError('');
    try {
      await resolveCase(c.id, 'admin');
      onResolved?.(c.id);
      onClose?.();
    } catch (err) {
      setError(err.response?.data?.error || 'Không đóng được ca. Thử lại sau.');
    } finally {
      setClosing(false);
    }
  }

  const stats = [
    { label: 'Thời gian chờ', value: formatWaiting(c.minutes_waiting), icon: 'schedule' },
    { label: 'TNV đang đến', value: c.responding_count ?? 0, icon: 'directions_run' },
  ];

  return (
    <div className="flex h-full min-h-0 w-full min-w-0 flex-col bg-surface">
      {/* Đầu panel */}
      <header className="flex shrink-0 items-start justify-between gap-sm border-b border-outline-variant/60 bg-surface-container/60 px-md py-sm">
        <div className="min-w-0">
          <p className="font-label-sm text-[10px] tracking-widest text-on-surface-variant">
            CA #{shortId(c.id)}
          </p>
          <p
            className="truncate font-h1 text-base font-semibold uppercase tracking-wide"
            style={{ color: `rgb(var(--${status.token}))` }}
          >
            {status.label}
          </p>
        </div>
        <button onClick={onClose} className="icon-btn h-8 w-8 shrink-0" aria-label="Đóng panel chi tiết">
          <Icon name="close" size={20} />
        </button>
      </header>

      {orphan && (
        <div className="flex shrink-0 items-center gap-xs border-l-4 border-error bg-error/10 px-md py-sm font-label-sm text-[11px] tracking-wider text-error">
          <Icon name="warning" size={16} />
          CA MỒ CÔI — CHƯA CÓ TNV SAU {Math.round(c.minutes_waiting ?? 0)} PHÚT
        </div>
      )}

      {/* Nội dung cuộn */}
      <div className="min-h-0 flex-1 space-y-lg overflow-y-auto p-md">
        {/* Mức độ & phân loại */}
        <section>
          <h4 className="section-label mb-sm">Mức độ &amp; phân loại</h4>
          <div className="flex flex-wrap items-center gap-xs">
            <span
              className="chip font-bold"
              style={{
                background: `rgb(var(--${urgency.token}) / 0.15)`,
                color: `rgb(var(--${urgency.token}))`,
              }}
            >
              Mức {c.urgency_level} · {urgency.label}
            </span>
            {(c.tags || []).map((tag) => (
              <span key={tag} className="chip bg-surface-bright text-on-surface-variant">
                {TAG_LABELS[tag] || tag}
              </span>
            ))}
          </div>
        </section>

        {/* Mô tả */}
        <section>
          <h4 className="section-label mb-sm">Mô tả SOS</h4>
          <p className="rounded-lg border border-outline-variant/50 bg-surface-container-low p-md font-body-md text-sm leading-relaxed text-on-surface">
            {c.summary_1line || c.sos_text || '(Không có mô tả)'}
          </p>
        </section>

        {/* Vị trí */}
        {c.lat != null && c.lon != null && (
          <section>
            <h4 className="section-label mb-sm">Vị trí</h4>
            <div className="flex items-center justify-between gap-sm rounded-lg border border-outline-variant/50 bg-surface-container-low p-md">
              <span className="font-label-sm text-xs text-on-surface">
                {c.lat.toFixed(5)}, {c.lon.toFixed(5)}
              </span>
              <a
                href={`https://www.google.com/maps?q=${c.lat},${c.lon}`}
                target="_blank"
                rel="noreferrer"
                className="btn-ghost px-sm py-xs no-underline"
              >
                <Icon name="open_in_new" size={16} />
                Mở bản đồ
              </a>
            </div>
          </section>
        )}

        {/* Số liệu */}
        <section className="grid grid-cols-2 gap-sm">
          {stats.map((s) => (
            <div key={s.label} className="rounded-lg border border-outline-variant/50 bg-surface-container-low p-md">
              <Icon name={s.icon} size={18} className="mb-xs text-on-surface-variant" />
              <p className="font-h1 text-xl leading-none text-on-surface">{s.value}</p>
              <p className="section-label mt-xs">{s.label}</p>
            </div>
          ))}
        </section>

        {/* TNV được cử */}
        {volunteers.length > 0 && (
          <section>
            <h4 className="section-label mb-sm">TNV được cử ({volunteers.length})</h4>
            <ul className="space-y-xs">
              {volunteers.map((vol) => (
                <li
                  key={vol.id}
                  className="flex items-center justify-between gap-sm rounded-lg border border-outline-variant/50 bg-surface-container-low p-sm"
                >
                  <div className="min-w-0">
                    <p className="truncate font-label-sm text-xs text-on-surface">
                      {vol.full_name || `TNV #${shortId(vol.id)}`}
                    </p>
                    <p className="truncate text-[11px] text-on-surface-variant">
                      {vol.distance_m != null ? `Cách ${vol.distance_m}m` : 'Chưa rõ khoảng cách'} ·{' '}
                      {vol.minutes_since_update ?? 0} phút trước
                    </p>
                  </div>
                  {vol.phone && (
                    <a href={`tel:${vol.phone}`} className="btn-ghost shrink-0 px-sm py-xs no-underline">
                      <Icon name="call" size={16} />
                      Gọi
                    </a>
                  )}
                </li>
              ))}
            </ul>
          </section>
        )}

        {error && (
          <p className="flex items-center gap-xs rounded-lg border border-error/40 bg-error/10 p-sm font-body-md text-xs text-error">
            <Icon name="error" size={16} />
            {error}
          </p>
        )}
      </div>

      {/* Hành động — ghim đáy, không bị nội dung đẩy khuất */}
      {c.status !== 'resolved' && (
        <footer className="shrink-0 border-t border-outline-variant/60 bg-surface-container/60 p-md">
          <button onClick={handleCloseCase} disabled={closing} className="btn-primary w-full py-sm">
            <Icon name="check_circle" size={18} />
            {closing ? 'Đang đóng...' : 'Đóng ca SOS này'}
          </button>
        </footer>
      )}
    </div>
  );
}
