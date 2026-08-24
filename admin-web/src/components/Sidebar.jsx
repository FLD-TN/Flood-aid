import Icon from './ui/Icon';
import { NAV_ITEMS } from '../lib/navItems';

/**
 * Điều hướng trái.
 *
 * Desktop: nằm trong luồng flex (không `fixed`) nên nội dung không bao giờ bị
 * đè; thu/mở bằng nút bấm chứ không phải hover — hover cũ làm layout nhảy và
 * che mất panel bên phải.
 * Mobile: drawer trượt có lớp phủ.
 */
export default function Sidebar({ activeSection, onNavigate, collapsed, onToggleCollapse, mobileOpen, onCloseMobile, pendingCount = 0 }) {
  const showLabels = !collapsed;

  return (
    <>
      {/* Lớp phủ chỉ có trên mobile */}
      {mobileOpen && (
        <div
          className="fixed inset-0 z-40 bg-black/50 backdrop-blur-sm md:hidden"
          onClick={onCloseMobile}
          aria-hidden="true"
        />
      )}

      <aside
        className={`
          fixed inset-y-0 left-0 z-50 flex w-64 shrink-0 flex-col
          border-r border-outline-variant bg-surface-container-lowest
          transition-[width,transform] duration-300 ease-emphasized
          md:static md:z-auto md:translate-x-0
          ${mobileOpen ? 'translate-x-0' : '-translate-x-full'}
          ${collapsed ? 'md:w-20' : 'md:w-64'}
        `}
      >
        {/* Thương hiệu */}
        <div className="flex h-16 shrink-0 items-center gap-sm border-b border-outline-variant px-md">
          <div className="grid h-9 w-9 shrink-0 place-items-center rounded-lg bg-primary/15 text-primary">
            <Icon name="emergency" size={22} />
          </div>
          <div className={`min-w-0 flex-1 overflow-hidden transition-opacity duration-200 ${showLabels ? 'opacity-100' : 'md:opacity-0'}`}>
            <h1 className="truncate font-h1 text-lg font-semibold leading-tight text-on-surface">Trang Quản Trị</h1>
            <p className="truncate font-label-sm text-[9px] uppercase tracking-widest text-on-surface-variant">
              Hệ Thống Điều Phối Cứu Trợ 
            </p>
          </div>
          <button
            className="icon-btn h-9 w-9 md:hidden"
            onClick={onCloseMobile}
            aria-label="Đóng menu"
          >
            <Icon name="close" size={20} />
          </button>
        </div>

        {/* Điều hướng */}
        <nav className="flex-1 space-y-1 overflow-y-auto overflow-x-hidden p-sm no-scrollbar">
          {NAV_ITEMS.map((item) => {
            const active = activeSection === item.key;
            const badge = item.key === 'teams' && pendingCount > 0 ? pendingCount : null;

            return (
              <button
                key={item.key}
                onClick={() => onNavigate(item.key)}
                title={collapsed ? item.label : undefined}
                aria-current={active ? 'page' : undefined}
                className={`
                  group relative flex w-full items-center gap-md rounded-lg px-sm py-sm
                  text-left transition-colors
                  ${active
                    ? 'bg-primary/10 text-primary'
                    : 'text-on-surface-variant hover:bg-surface-bright hover:text-on-surface'}
                `}
              >
                {/* Vạch chỉ mục — dùng absolute nên không đẩy icon lệch như border-l cũ */}
                <span
                  className={`absolute left-0 top-1/2 h-6 w-[3px] -translate-y-1/2 rounded-r-full bg-primary transition-opacity ${active ? 'opacity-100' : 'opacity-0'}`}
                />
                <span className="grid h-9 w-9 shrink-0 place-items-center">
                  <Icon name={item.icon} size={22} filled={active} />
                </span>
                <span
                  className={`min-w-0 flex-1 truncate font-label-sm text-xs transition-opacity duration-200 ${showLabels ? 'opacity-100' : 'md:hidden'}`}
                >
                  {item.label}
                </span>
                {badge != null && (
                  <span
                    className={`chip shrink-0 bg-warning/20 text-warning ${showLabels ? '' : 'md:absolute md:right-1 md:top-1 md:px-1 md:py-0'}`}
                  >
                    {badge}
                  </span>
                )}
              </button>
            );
          })}
        </nav>

        {/* Nút thu gọn — chỉ desktop */}
        <div className="hidden shrink-0 border-t border-outline-variant p-sm md:block">
          <button
            onClick={onToggleCollapse}
            className="icon-btn flex w-full items-center gap-md px-sm py-sm"
            title={collapsed ? 'Mở rộng menu' : 'Thu gọn menu'}
          >
            <span className="grid h-9 w-9 shrink-0 place-items-center">
              <Icon name={collapsed ? 'chevron_right' : 'chevron_left'} size={22} />
            </span>
            {showLabels && <span className="truncate font-label-sm text-xs">Thu gọn</span>}
          </button>
        </div>
      </aside>
    </>
  );
}
