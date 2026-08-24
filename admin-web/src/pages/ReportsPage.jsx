import { useMemo } from 'react';
import StatCard from '../components/ui/StatCard';
import Icon from '../components/ui/Icon';
import EmptyState from '../components/ui/EmptyState';
import { URGENCY, STATUS, formatWaiting, statusMeta, urgencyMeta } from '../lib/caseMeta';

/** Thanh tỉ lệ ngang — dùng chung cho cả hai biểu đồ phân bố. */
function BarRow({ label, value, total, token }) {
  const pct = total > 0 ? Math.round((value / total) * 100) : 0;

  return (
    <div className="flex items-center gap-sm">
      <span className="w-32 shrink-0 truncate font-label-sm text-[11px] text-on-surface-variant">{label}</span>
      <div className="h-2.5 min-w-0 flex-1 overflow-hidden rounded-full bg-surface-container-highest">
        <div
          className="h-full rounded-full transition-[width] duration-500"
          style={{ width: `${pct}%`, background: `rgb(var(--${token}))` }}
        />
      </div>
      <span className="w-16 shrink-0 text-right font-label-sm text-[11px] text-on-surface">
        {value} <span className="text-on-surface-variant">({pct}%)</span>
      </span>
    </div>
  );
}

export default function ReportsPage({ ops }) {
  const { metrics, allCases, volunteers, statsLoading } = ops;

  const byUrgency = useMemo(() => {
    const acc = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 };
    for (const c of allCases) if (acc[c.urgency_level] != null) acc[c.urgency_level] += 1;
    return acc;
  }, [allCases]);

  const byStatus = useMemo(() => {
    const acc = { pending: 0, responding: 0, on_scene: 0, resolved: 0 };
    for (const c of allCases) if (acc[c.status] != null) acc[c.status] += 1;
    return acc;
  }, [allCases]);

  const avgWaiting = useMemo(() => {
    const open = allCases.filter((c) => c.status !== 'resolved');
    if (!open.length) return 0;
    return open.reduce((sum, c) => sum + (c.minutes_waiting ?? 0), 0) / open.length;
  }, [allCases]);

  const resolveRate = allCases.length
    ? Math.round((byStatus.resolved / allCases.length) * 100)
    : 0;

  const slowest = useMemo(
    () =>
      [...allCases]
        .filter((c) => c.status !== 'resolved')
        .sort((a, b) => (b.minutes_waiting ?? 0) - (a.minutes_waiting ?? 0))
        .slice(0, 5),
    [allCases],
  );

  return (
    <div className="h-full min-h-0 overflow-y-auto p-md">
      <div className="mx-auto flex max-w-6xl flex-col gap-lg">
        <header>
          <h1 className="flex items-center gap-sm font-h1 text-xl font-semibold text-on-surface sm:text-2xl">
            <Icon name="assessment" size={26} className="text-primary" />
            Báo cáo vận hành
          </h1>
          <p className="mt-xs font-label-sm text-xs text-on-surface-variant">
            Tổng hợp từ {allCases.length} ca SOS và {volunteers.length} tình nguyện viên
          </p>
        </header>

        {/* Chỉ số tổng hợp */}
        <div className="grid grid-cols-1 gap-md sm:grid-cols-2 xl:grid-cols-4">
          <StatCard
            icon="fact_check"
            label="Tỉ lệ xử lý xong"
            value={`${resolveRate}%`}
            hint={`${byStatus.resolved}/${allCases.length} ca`}
            tone="success"
            loading={statsLoading && !metrics}
          />
          <StatCard
            icon="timer"
            label="Chờ trung bình"
            value={formatWaiting(avgWaiting)}
            hint="Trên các ca đang mở"
            tone="warning"
            loading={statsLoading && !metrics}
          />
          <StatCard
            icon="groups"
            label="Tổng tình nguyện viên"
            value={metrics?.totalVolunteers ?? volunteers.length}
            hint={`${metrics?.availableVolunteers ?? 0} đang rảnh`}
            tone="primary"
            loading={statsLoading && !metrics}
          />
          <StatCard
            icon="emergency"
            label="Ca đang mở"
            value={metrics?.activeSos ?? 0}
            tone="danger"
            loading={statsLoading && !metrics}
          />
        </div>

        {/* Hai biểu đồ phân bố */}
        <div className="grid grid-cols-1 gap-md lg:grid-cols-2">
          <section className="panel p-md">
            <h2 className="section-label mb-md">Phân bố theo mức độ khẩn cấp</h2>
            {allCases.length === 0 ? (
              <EmptyState icon="bar_chart" title="Chưa có dữ liệu" />
            ) : (
              <div className="space-y-sm">
                {[5, 4, 3, 2, 1].map((lv) => (
                  <BarRow
                    key={lv}
                    label={`Mức ${lv} — ${URGENCY[lv].label}`}
                    value={byUrgency[lv]}
                    total={allCases.length}
                    token={urgencyMeta(lv).token}
                  />
                ))}
              </div>
            )}
          </section>

          <section className="panel p-md">
            <h2 className="section-label mb-md">Phân bố theo trạng thái</h2>
            {allCases.length === 0 ? (
              <EmptyState icon="donut_small" title="Chưa có dữ liệu" />
            ) : (
              <div className="space-y-sm">
                {Object.keys(STATUS).map((key) => (
                  <BarRow
                    key={key}
                    label={STATUS[key].label}
                    value={byStatus[key]}
                    total={allCases.length}
                    token={statusMeta(key).token}
                  />
                ))}
              </div>
            )}
          </section>
        </div>

        {/* Ca chờ lâu nhất */}
        <section className="panel overflow-hidden">
          <div className="panel-header">
            <h2 className="panel-title">
              <Icon name="hourglass_top" size={18} className="text-primary" />
              Ca chờ lâu nhất
            </h2>
          </div>

          {slowest.length === 0 ? (
            <EmptyState icon="check_circle" title="Không còn ca nào đang chờ" />
          ) : (
            <div className="overflow-x-auto">
              <table className="data-table">
                <thead>
                  <tr>
                    <th className="w-20">Mức</th>
                    <th>Mô tả</th>
                    <th className="w-32">Trạng thái</th>
                    <th className="w-28 text-right">Đã chờ</th>
                  </tr>
                </thead>
                <tbody>
                  {slowest.map((c) => {
                    const urgency = urgencyMeta(c.urgency_level);
                    const status = statusMeta(c.status);
                    return (
                      <tr key={c.id}>
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
                        <td className="max-w-0">
                          <p className="truncate font-body-md text-sm text-on-surface">
                            {c.summary_1line || c.sos_text || '(Chưa có mô tả)'}
                          </p>
                        </td>
                        <td>
                          <span
                            className="font-label-sm text-[11px]"
                            style={{ color: `rgb(var(--${status.token}))` }}
                          >
                            {status.label}
                          </span>
                        </td>
                        <td className="text-right font-label-sm text-[11px] text-on-surface-variant">
                          {formatWaiting(c.minutes_waiting)}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </section>
      </div>
    </div>
  );
}
