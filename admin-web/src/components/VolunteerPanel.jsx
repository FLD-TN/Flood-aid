import { useState } from 'react';
import Icon from './ui/Icon';

/**
 * Dải theo dõi tình nguyện viên ở đáy trang tổng quan.
 * Thu gọn được để trả lại chiều cao cho bản đồ khi màn hình thấp.
 */
export default function VolunteerPanel({ volunteers = [], defaultCollapsed = false }) {
  const [collapsed, setCollapsed] = useState(defaultCollapsed);

  const busy = volunteers.filter((v) => !v.is_available);
  const free = volunteers.filter((v) => v.is_available);
  // TNV đang làm nhiệm vụ lên đầu — đó là nhóm cần theo dõi
  const ordered = [...busy, ...free];

  return (
    <section className="panel flex w-full flex-col overflow-hidden">
      <button
        onClick={() => setCollapsed((v) => !v)}
        className="panel-header w-full text-left transition-colors hover:bg-surface-bright/40"
        aria-expanded={!collapsed}
      >
        <span className="panel-title">
          <Icon name="history" size={18} className="text-primary" />
          Hoạt động tình nguyện viên
        </span>

        <span className="flex items-center gap-md">
          <span className="hidden items-center gap-xs sm:flex">
            <span className="h-1.5 w-1.5 rounded-full bg-warning" />
            <span className="font-label-sm text-[10px] text-on-surface-variant">
              {busy.length} đang làm nhiệm vụ
            </span>
          </span>
          <span className="hidden items-center gap-xs sm:flex">
            <span className="h-1.5 w-1.5 rounded-full bg-success" />
            <span className="font-label-sm text-[10px] text-on-surface-variant">{free.length} rảnh</span>
          </span>
          <Icon
            name="expand_less"
            size={20}
            className={`text-on-surface-variant transition-transform ${collapsed ? 'rotate-180' : ''}`}
          />
        </span>
      </button>

      {!collapsed && (
        <div className="flex gap-sm overflow-x-auto p-sm">
          {ordered.length === 0 ? (
            <p className="px-sm py-md font-label-sm text-xs text-on-surface-variant">
              Chưa có tình nguyện viên nào.
            </p>
          ) : (
            ordered.map((vol) => {
              const busyNow = !vol.is_available;
              return (
                <article
                  key={vol.id}
                  className="flex w-[240px] shrink-0 items-center gap-sm rounded-lg border border-outline-variant/50 bg-surface-container-low p-sm"
                >
                  <span
                    className={`grid h-9 w-9 shrink-0 place-items-center rounded-full border font-label-sm text-[11px] font-bold ${
                      busyNow
                        ? 'border-warning/50 bg-warning/15 text-warning'
                        : 'border-success/50 bg-success/15 text-success'
                    }`}
                  >
                    {(vol.full_name || 'TNV').trim().slice(0, 2).toUpperCase()}
                  </span>
                  <div className="min-w-0 flex-1">
                    <p className="truncate font-label-sm text-xs text-on-surface">
                      {vol.full_name || 'TNV chưa đặt tên'}
                    </p>
                    <p
                      className={`truncate font-label-sm text-[10px] ${busyNow ? 'text-warning' : 'text-success'}`}
                    >
                      {busyNow ? 'Đang làm nhiệm vụ' : 'Đang rảnh'}
                    </p>
                  </div>
                </article>
              );
            })
          )}
        </div>
      )}
    </section>
  );
}
