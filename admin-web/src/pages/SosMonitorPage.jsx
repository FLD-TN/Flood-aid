import { useMemo, useState } from 'react';
import Icon from '../components/ui/Icon';
import EmptyState, { SkeletonList } from '../components/ui/EmptyState';
import CaseDetailDrawer from '../components/CaseDetailDrawer';
import { formatWaiting, isOrphanCase, shortId, statusMeta, urgencyMeta } from '../lib/caseMeta';

const STATUS_TABS = [
  { key: 'active', label: 'Đang mở' },
  { key: 'pending', label: 'Chờ cứu hộ' },
  { key: 'responding', label: 'TNV đang đến' },
  { key: 'on_scene', label: 'TNV tại chỗ' },
  { key: 'resolved', label: 'Đã đóng' },
  { key: 'all', label: 'Tất cả' },
];

const SORTS = {
  urgency: { label: 'Khẩn cấp nhất', fn: (a, b) => (b.urgency_level ?? 0) - (a.urgency_level ?? 0) || (b.minutes_waiting ?? 0) - (a.minutes_waiting ?? 0) },
  waiting: { label: 'Chờ lâu nhất', fn: (a, b) => (b.minutes_waiting ?? 0) - (a.minutes_waiting ?? 0) },
  newest: { label: 'Mới nhất', fn: (a, b) => (a.minutes_waiting ?? 0) - (b.minutes_waiting ?? 0) },
};

/**
 * Trang theo dõi ca SOS.
 *
 * Một cột dữ liệu duy nhất, cuộn được, kèm panel chi tiết đẩy ngang — không còn
 * chồng panel lên bản đồ như trước nên không phần nào bị che khuất.
 */
export default function SosMonitorPage({ ops, selectedCase, onSelectCase, onCloseCase, search }) {
  const [tab, setTab] = useState('active');
  const [sort, setSort] = useState('urgency');
  const [onlyOrphan, setOnlyOrphan] = useState(false);

  const { allCases, casesLoading, error } = ops;

  const counts = useMemo(() => {
    const base = { active: 0, all: allCases.length, pending: 0, responding: 0, on_scene: 0, resolved: 0 };
    for (const c of allCases) {
      if (base[c.status] != null) base[c.status] += 1;
      if (c.status !== 'resolved') base.active += 1;
    }
    return base;
  }, [allCases]);

  const rows = useMemo(() => {
    const q = search.trim().toLowerCase();

    let list = allCases.filter((c) => {
      if (tab === 'active') return c.status !== 'resolved';
      if (tab === 'all') return true;
      return c.status === tab;
    });

    if (onlyOrphan) list = list.filter(isOrphanCase);

    if (q) {
      list = list.filter((c) =>
        [c.id, c.summary_1line, c.sos_text, c.lat, c.lon, ...(c.tags || [])]
          .filter((v) => v != null)
          .join(' ')
          .toLowerCase()
          .includes(q),
      );
    }

    return [...list].sort(SORTS[sort].fn);
  }, [allCases, tab, sort, onlyOrphan, search]);

  const orphanTotal = useMemo(() => allCases.filter(isOrphanCase).length, [allCases]);

  return (
    <div className="flex h-full min-h-0">
      <div className="flex min-h-0 flex-1 flex-col gap-md p-md">
        {/* Tiêu đề + thao tác */}
        <div className="flex shrink-0 flex-wrap items-end justify-between gap-md">
          <div className="min-w-0">
            <h1 className="flex items-center gap-sm font-h1 text-xl font-semibold text-on-surface sm:text-2xl">
              <Icon name="e911_emergency" size={26} className="text-primary" />
              Theo dõi ca SOS
            </h1>
            <p className="mt-xs font-label-sm text-xs text-on-surface-variant">
              {counts.active} ca đang mở · {counts.resolved} đã đóng
              {orphanTotal > 0 && (
                <span className="text-error"> · {orphanTotal} ca mồ côi</span>
              )}
            </p>
          </div>

          <div className="flex flex-wrap items-center gap-sm">
            <button
              onClick={() => setOnlyOrphan((v) => !v)}
              className={`btn-ghost ${onlyOrphan ? 'border-error bg-error/10 text-error' : ''}`}
            >
              <Icon name="warning" size={16} />
              Chỉ ca mồ côi
            </button>

            <label className="flex items-center gap-xs">
              <span className="section-label hidden sm:inline">Sắp xếp</span>
              <select
                value={sort}
                onChange={(e) => setSort(e.target.value)}
                className="field w-auto py-xs pr-lg font-label-sm text-xs"
              >
                {Object.entries(SORTS).map(([key, cfg]) => (
                  <option key={key} value={key}>{cfg.label}</option>
                ))}
              </select>
            </label>
          </div>
        </div>

        {error && (
          <div className="flex shrink-0 items-center gap-sm rounded-lg border border-error/40 bg-error/10 px-md py-sm font-body-md text-sm text-error">
            <Icon name="cloud_off" size={18} />
            {error}
          </div>
        )}

        {/* Tab trạng thái — cuộn ngang trên màn hẹp thay vì tràn ra ngoài */}
        <div className="shrink-0 overflow-x-auto no-scrollbar">
          <div className="flex w-max gap-xs rounded-xl border border-outline-variant/60 bg-surface-container p-xs">
            {STATUS_TABS.map((t) => (
              <button
                key={t.key}
                onClick={() => setTab(t.key)}
                className={`whitespace-nowrap rounded-lg px-md py-sm font-label-sm text-xs transition-colors ${
                  tab === t.key
                    ? 'bg-primary text-on-primary shadow-panel'
                    : 'text-on-surface-variant hover:bg-surface-bright'
                }`}
              >
                {t.label}
                <span className="ml-xs opacity-70">{counts[t.key] ?? 0}</span>
              </button>
            ))}
          </div>
        </div>

        {/* Bảng dữ liệu */}
        <div className="panel flex min-h-0 flex-1 flex-col overflow-hidden">
          {casesLoading && allCases.length === 0 ? (
            <SkeletonList rows={5} />
          ) : rows.length === 0 ? (
            <EmptyState
              icon="search_off"
              title="Không có ca nào khớp"
              hint="Thử đổi tab trạng thái, bỏ bộ lọc hoặc xoá từ khoá tìm kiếm."
            />
          ) : (
            <div className="min-h-0 flex-1 overflow-auto">
              {/* Desktop: bảng */}
              <table className="data-table hidden md:table">
                <thead className="sticky top-0 z-10 bg-surface-container">
                  <tr>
                    <th className="w-24">Mức</th>
                    <th className="w-28">Mã ca</th>
                    <th>Mô tả</th>
                    <th className="w-36">Trạng thái</th>
                    <th className="w-28">Chờ</th>
                    <th className="w-24 text-center">TNV</th>
                    <th className="w-20" />
                  </tr>
                </thead>
                <tbody>
                  {rows.map((c) => {
                    const urgency = urgencyMeta(c.urgency_level);
                    const status = statusMeta(c.status);
                    const orphan = isOrphanCase(c);
                    const selected = c.id === selectedCase?.id;

                    return (
                      <tr
                        key={c.id}
                        onClick={() => onSelectCase(c)}
                        className={`cursor-pointer ${selected ? 'bg-primary/10' : ''}`}
                      >
                        <td>
                          <span
                            className="chip font-bold"
                            style={{
                              background: `rgb(var(--${urgency.token}) / 0.15)`,
                              color: `rgb(var(--${urgency.token}))`,
                            }}
                          >
                            {c.urgency_level}
                          </span>
                        </td>
                        <td className="font-label-sm text-[11px] text-on-surface-variant">#{shortId(c.id)}</td>
                        <td className="max-w-0">
                          <p className="truncate font-body-md text-sm text-on-surface">
                            {c.summary_1line || c.sos_text || '(Chưa có mô tả)'}
                          </p>
                          {orphan && (
                            <span className="font-label-sm text-[10px] tracking-wider text-error">
                              ⚠ CA MỒ CÔI
                            </span>
                          )}
                        </td>
                        <td>
                          <span
                            className="inline-flex items-center gap-xs font-label-sm text-[11px]"
                            style={{ color: `rgb(var(--${status.token}))` }}
                          >
                            <Icon name={status.icon} size={14} />
                            {status.label}
                          </span>
                        </td>
                        <td className="font-label-sm text-[11px] text-on-surface-variant">
                          {formatWaiting(c.minutes_waiting)}
                        </td>
                        <td className="text-center font-label-sm text-xs text-on-surface">
                          {c.responding_count ?? 0}
                        </td>
                        <td className="text-right">
                          <Icon name="chevron_right" size={20} className="text-on-surface-variant" />
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>

              {/* Mobile: thẻ, vì bảng 7 cột không thể đọc trên màn hẹp */}
              <ul className="space-y-sm p-sm md:hidden">
                {rows.map((c) => {
                  const urgency = urgencyMeta(c.urgency_level);
                  const status = statusMeta(c.status);
                  const selected = c.id === selectedCase?.id;

                  return (
                    <li key={c.id}>
                      <button
                        onClick={() => onSelectCase(c)}
                        className={`w-full rounded-lg border p-md text-left transition-colors ${
                          selected
                            ? 'border-primary bg-primary/10'
                            : 'border-outline-variant/50 bg-surface-container-low'
                        }`}
                      >
                        <div className="mb-xs flex items-center justify-between gap-sm">
                          <span
                            className="chip font-bold"
                            style={{
                              background: `rgb(var(--${urgency.token}) / 0.15)`,
                              color: `rgb(var(--${urgency.token}))`,
                            }}
                          >
                            Mức {c.urgency_level}
                          </span>
                          <span className="font-label-sm text-[10px] text-on-surface-variant">
                            {formatWaiting(c.minutes_waiting)}
                          </span>
                        </div>
                        <p className="line-clamp-2 font-body-md text-sm text-on-surface">
                          {c.summary_1line || c.sos_text || '(Chưa có mô tả)'}
                        </p>
                        <p
                          className="mt-xs inline-flex items-center gap-xs font-label-sm text-[10px]"
                          style={{ color: `rgb(var(--${status.token}))` }}
                        >
                          <Icon name={status.icon} size={13} />
                          {status.label} · {c.responding_count ?? 0} TNV
                        </p>
                      </button>
                    </li>
                  );
                })}
              </ul>
            </div>
          )}
        </div>
      </div>

      {/* Chi tiết — cột riêng ở desktop, ngăn kéo ở mobile */}
      <CaseDetailDrawer
        caseData={selectedCase}
        onClose={onCloseCase}
        onResolved={ops.refreshAll}
        className="lg:my-md lg:mr-md"
      />
    </div>
  );
}
