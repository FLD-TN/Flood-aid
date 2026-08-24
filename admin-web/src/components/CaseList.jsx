import { useMemo, useState } from 'react';
import Icon from './ui/Icon';
import EmptyState, { SkeletonList } from './ui/EmptyState';
import { formatWaiting, isOrphanCase, shortId, statusMeta, urgencyMeta } from '../lib/caseMeta';

const FILTERS = [
  { key: 'all', label: 'Tất cả' },
  { key: 'critical', label: 'Khẩn cấp' },
  { key: 'orphan', label: 'Mồ côi' },
];

/**
 * Danh sách ca ưu tiên. Thuần hiển thị — dữ liệu do trang cha truyền vào.
 */
export default function CaseList({ cases = [], loading, onCaseSelect, selectedCaseId, onViewAll }) {
  const [filter, setFilter] = useState('all');

  const visible = useMemo(() => {
    if (filter === 'critical') return cases.filter((c) => (c.urgency_level ?? 0) >= 4);
    if (filter === 'orphan') return cases.filter(isOrphanCase);
    return cases;
  }, [cases, filter]);

  const orphanCount = useMemo(() => cases.filter(isOrphanCase).length, [cases]);

  return (
    <section className="panel flex h-full min-h-0 flex-col overflow-hidden">
      <header className="panel-header shrink-0">
        <h3 className="panel-title">
          <Icon name="fmd_bad" size={18} className="text-primary" />
          Ca ưu tiên
          <span className="ml-xs rounded bg-surface-bright px-xs py-0.5 text-[10px] font-normal text-on-surface-variant">
            {cases.length}
          </span>
        </h3>
        <span className="chip bg-primary/15 text-primary">
          <span className="h-1.5 w-1.5 rounded-full bg-primary animate-pulse" />
          Live
        </span>
      </header>

      {/* Bộ lọc */}
      <div className="flex shrink-0 gap-xs border-b border-outline-variant/60 px-sm py-xs">
        {FILTERS.map((f) => {
          const count = f.key === 'orphan' ? orphanCount : null;
          return (
            <button
              key={f.key}
              onClick={() => setFilter(f.key)}
              className={`flex-1 rounded-lg px-sm py-xs font-label-sm text-[11px] transition-colors ${
                filter === f.key
                  ? 'bg-primary text-on-primary'
                  : 'text-on-surface-variant hover:bg-surface-bright'
              }`}
            >
              {f.label}
              {count ? ` (${count})` : ''}
            </button>
          );
        })}
      </div>

      {/* Danh sách */}
      <div className="min-h-0 flex-1 overflow-y-auto">
        {loading && cases.length === 0 ? (
          <SkeletonList rows={3} />
        ) : visible.length === 0 ? (
          <EmptyState
            icon="check_circle"
            title={filter === 'all' ? 'Không có ca nào đang mở' : 'Không có ca khớp bộ lọc'}
            hint={filter === 'all' ? 'Mọi ca SOS đã được xử lý xong.' : undefined}
          />
        ) : (
          <ul className="space-y-sm p-sm">
            {visible.map((c) => {
              const urgency = urgencyMeta(c.urgency_level);
              const status = statusMeta(c.status);
              const selected = c.id === selectedCaseId;
              const orphan = isOrphanCase(c);

              return (
                <li key={c.id}>
                  <button
                    onClick={() => onCaseSelect?.(c)}
                    aria-current={selected ? 'true' : undefined}
                    className={`w-full rounded-lg border p-md text-left transition-all ${
                      selected
                        ? 'border-primary bg-primary/10 shadow-raised'
                        : 'border-outline-variant/50 bg-surface-container-low hover:border-primary/50 hover:bg-surface-bright/50'
                    }`}
                  >
                    {/* Dòng 1: mức độ + thời gian chờ */}
                    <div className="mb-xs flex items-center justify-between gap-sm">
                      <span
                        className="chip font-bold"
                        style={{
                          background: `rgb(var(--${urgency.token}) / 0.15)`,
                          color: `rgb(var(--${urgency.token}))`,
                        }}
                      >
                        Mức {c.urgency_level} · {urgency.label}
                      </span>
                      <span className="shrink-0 font-label-sm text-[10px] text-on-surface-variant">
                        {formatWaiting(c.minutes_waiting)}
                      </span>
                    </div>

                    {/* Dòng 2: mã ca + trạng thái */}
                    <div className="mb-xs flex items-center gap-xs">
                      <span className="font-label-sm text-[10px] text-on-surface-variant">#{shortId(c.id)}</span>
                      <span className="text-on-surface-variant/40">·</span>
                      <span
                        className="inline-flex items-center gap-xs font-label-sm text-[10px]"
                        style={{ color: `rgb(var(--${status.token}))` }}
                      >
                        <Icon name={status.icon} size={13} />
                        {status.label}
                      </span>
                    </div>

                    {/* Tóm tắt AI */}
                    <p className="line-clamp-2 font-body-md text-sm leading-snug text-on-surface">
                      {c.summary_1line || c.sos_text || '(Chưa có mô tả)'}
                    </p>

                    {/* Toạ độ */}
                    {c.lat != null && c.lon != null && (
                      <p className="mt-xs font-label-sm text-[10px] text-on-surface-variant">
                        {c.lat.toFixed(4)}, {c.lon.toFixed(4)}
                      </p>
                    )}

                    {orphan && (
                      <p className="mt-sm flex items-center gap-xs rounded border-l-2 border-error bg-error/10 px-sm py-xs font-label-sm text-[10px] tracking-wider text-error">
                        <Icon name="warning" size={13} />
                        CA MỒ CÔI — CHƯA CÓ TNV
                      </p>
                    )}
                  </button>
                </li>
              );
            })}
          </ul>
        )}
      </div>

      {onViewAll && (
        <footer className="shrink-0 border-t border-outline-variant/60 p-sm">
          <button className="btn-primary w-full" onClick={onViewAll}>
            Xem toàn bộ hàng đợi
          </button>
        </footer>
      )}
    </section>
  );
}
