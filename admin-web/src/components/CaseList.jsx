import { usePolling } from '../hooks/usePolling';

export default function CaseList({ onCaseSelect, selectedCaseId }) {
  // Fetch real cases every 10s
  const { data: allCases, loading } = usePolling('/api/admin/cases', 10000);

  // Filter to show active cases (pending, responding, on_scene)
  const activeCases = (allCases || []).filter(c => c.status !== 'resolved');

  return (
    <div className="glass-panel rounded-xl flex-1 flex flex-col overflow-hidden border border-outline-variant/30 h-full">
      <div className="p-md border-b border-outline-variant/30 flex justify-between items-center bg-surface-dim/40">
        <h3 className="font-label-sm text-xs font-bold text-on-surface flex items-center gap-xs">
          <span className="material-symbols-outlined text-primary text-[18px]" data-icon="fmd_bad">fmd_bad</span>
          PRIORITY ALERTS
        </h3>
        <span className="px-2 py-[2px] bg-primary/20 text-primary text-[10px] rounded font-bold uppercase tracking-tighter">Live</span>
      </div>
      
      <div className="flex-1 overflow-y-auto p-sm space-y-sm no-scrollbar">
        {loading && <div className="text-center p-4 text-on-surface-variant font-label-sm">Loading...</div>}
        {!loading && activeCases.length === 0 && (
          <div className="text-center p-4 text-on-surface-variant font-label-sm">No active alerts.</div>
        )}
        {activeCases.map((alert) => {
          const isUrgent = alert.urgency_level >= 4;
          const urgencyLabel = alert.urgency_level === 5 ? 'Critical' : alert.urgency_level === 4 ? 'Urgent' : 'High';
          const timeLabel = Math.round(alert.minutes_waiting) + 'm ago';
          const location = `Tọa độ: ${alert.lat.toFixed(4)}, ${alert.lon.toFixed(4)}`;

          return (
            <div 
              key={alert.id}
              onClick={() => onCaseSelect && onCaseSelect(alert)}
              className={`p-md rounded-lg ${alert.id === selectedCaseId ? 'bg-surface-dim/80 border-primary' : isUrgent ? 'bg-surface-dim/60' : 'bg-surface-dim/20'} border border-outline-variant/20 hover:border-primary/50 transition-colors cursor-pointer group`}
            >
              <div className="flex justify-between items-start mb-xs">
                <span className={`font-label-sm text-[10px] uppercase ${isUrgent ? 'text-primary' : 'text-on-surface-variant'}`}>
                  {urgencyLabel} #{alert.id.substring(0, 4)}
                </span>
                <span className="font-label-sm text-[10px] text-on-surface-variant">{timeLabel}</span>
              </div>
              <p className="font-body-md text-sm text-on-surface font-semibold">{location}</p>
              <div className={`mt-sm p-2 bg-surface-container-lowest rounded text-[11px] text-on-surface-variant border-l-2 ${isUrgent ? 'border-primary' : 'border-outline'}`}>
                <span className={isUrgent ? 'text-primary font-bold' : 'text-on-surface font-bold'}>AI Summary: </span>
                {alert.summary_1line || 'N/A'}
              </div>
            </div>
          );
        })}
      </div>
      
      <div className="p-sm bg-surface-dim/60 border-t border-outline-variant/30 mt-auto">
        <button className="w-full py-2 bg-primary text-on-primary font-label-sm text-xs rounded-lg hover:brightness-110 transition-all uppercase tracking-widest font-bold">
          View Dispatch Queue
        </button>
      </div>
    </div>
  );
}
