import { usePolling } from '../hooks/usePolling';

export default function StatsPanel() {
  const { data: stats, loading } = usePolling('/api/admin/stats', 15000);

  if (loading || !stats) {
    return (
      <div className="stats-panel">
        <div className="loading-spinner"><div className="spinner" /></div>
      </div>
    );
  }

  const cases = stats.cases || {};
  const vols = stats.volunteers || {};
  const flags = stats.flags || {};

  return (
    <div className="stats-panel">
      <div className="stats-grid">
        <div className="stat-card">
          <div className="stat-value red">{cases.pending_count || 0}</div>
          <div className="stat-label">Đang chờ</div>
        </div>
        <div className="stat-card">
          <div className="stat-value yellow">{cases.responding_count || 0}</div>
          <div className="stat-label">Đang ứng cứu</div>
        </div>
        <div className="stat-card">
          <div className="stat-value orange">{cases.on_scene_count || 0}</div>
          <div className="stat-label">Tại hiện trường</div>
        </div>
        <div className="stat-card">
          <div className="stat-value green">{cases.resolved_count || 0}</div>
          <div className="stat-label">Đã giải quyết</div>
        </div>
        <div className="stat-card">
          <div className="stat-value blue">{vols.available_count || 0}</div>
          <div className="stat-label">TNV sẵn sàng</div>
        </div>
        <div className="stat-card">
          <div className="stat-value purple">{flags.active_flags || 0}</div>
          <div className="stat-label">Cờ cảnh báo</div>
        </div>
      </div>
    </div>
  );
}
