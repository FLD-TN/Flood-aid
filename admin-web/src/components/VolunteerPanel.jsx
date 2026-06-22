import { usePolling } from '../hooks/usePolling';

export default function VolunteerPanel() {
  // Fetch real volunteers every 15s
  const { data: allVols } = usePolling('/api/volunteers', 15000);
  
  const volunteers = allVols || [];
  const activeCount = volunteers.filter(v => !v.is_available).length;

  return (
    <div className="glass-panel rounded-xl flex flex-col border border-outline-variant/30 w-full h-full overflow-hidden">
      <div className="px-lg py-sm border-b border-outline-variant/30 flex justify-between items-center cursor-pointer hover:bg-surface-bright/20">
        <div className="flex items-center gap-md">
          <span className="material-symbols-outlined text-primary text-[20px]" data-icon="history">history</span>
          <h3 className="font-label-sm text-xs font-bold text-on-surface uppercase tracking-widest">Volunteer Activity Log</h3>
          <div className="flex items-center gap-xs ml-lg">
            <span className="w-2 h-2 rounded-full bg-primary animate-pulse"></span>
            <span className="font-label-sm text-[10px] text-on-surface-variant">{activeCount} Active Threads</span>
          </div>
        </div>
        <span className="material-symbols-outlined text-on-surface-variant" data-icon="keyboard_arrow_up">keyboard_arrow_up</span>
      </div>
      
      <div className="p-sm flex gap-md overflow-x-auto no-scrollbar">
        {volunteers.map((vol) => {
          const isActive = !vol.is_available;
          const statusText = isActive ? 'Đang làm nhiệm vụ' : 'Đang rảnh rỗi';
          const defaultImg = `https://ui-avatars.com/api/?name=${encodeURIComponent(vol.full_name)}&background=142637&color=E8F0F5`;

          return (
            <div key={vol.id} className="min-w-[280px] p-sm bg-surface-dim/40 rounded-lg flex items-center gap-sm border border-outline-variant/20">
              <img 
                alt={vol.full_name} 
                className={`w-8 h-8 rounded-full border ${isActive ? 'border-primary/50' : 'border-outline-variant'} object-cover`} 
                src={defaultImg}
              />
              <div className="flex-1 overflow-hidden">
                <p className="font-label-sm text-xs text-on-surface truncate">{vol.full_name}</p>
                <p className={`font-label-sm text-[9px] truncate ${isActive ? 'text-primary' : 'text-on-surface-variant'}`}>{statusText}</p>
              </div>
            </div>
          );
        })}
        {volunteers.length === 0 && (
          <div className="text-on-surface-variant font-label-sm p-2">Không có TNV nào.</div>
        )}
      </div>
    </div>
  );
}
