import { useEffect, useRef, useState } from 'react';
import Icon from './ui/Icon';
import ThemeToggle from './ThemeToggle';

/**
 * Thanh trên cùng.
 *
 * Nằm trong luồng flex (không `fixed`) nên không còn đè lên hàng số liệu như
 * bản cũ — đó là lý do các thẻ metric bị cắt mất nửa trên.
 */
export default function TopBar({
  title,
  onMenuClick,
  adminInfo,
  onLogout,
  onRefresh,
  refreshing = false,
  searchValue = '',
  onSearchChange,
  searchPlaceholder = 'Tìm ca SOS, toạ độ, tình nguyện viên...',
  showSearch = true,
}) {
  const [menuOpen, setMenuOpen] = useState(false);
  const menuRef = useRef(null);

  // Đóng menu tài khoản khi bấm ra ngoài hoặc nhấn Esc
  useEffect(() => {
    if (!menuOpen) return;
    const onClick = (e) => {
      if (menuRef.current && !menuRef.current.contains(e.target)) setMenuOpen(false);
    };
    const onKey = (e) => e.key === 'Escape' && setMenuOpen(false);
    document.addEventListener('mousedown', onClick);
    document.addEventListener('keydown', onKey);
    return () => {
      document.removeEventListener('mousedown', onClick);
      document.removeEventListener('keydown', onKey);
    };
  }, [menuOpen]);

  const initials = (adminInfo?.fullName || 'Admin')
    .split(' ')
    .filter(Boolean)
    .slice(-2)
    .map((w) => w[0])
    .join('')
    .toUpperCase();

  return (
    <header className="z-30 flex h-16 shrink-0 items-center gap-sm border-b border-outline-variant bg-surface px-md shadow-panel md:px-lg">
      {/* Trái */}
      <button className="icon-btn h-10 w-10 md:hidden" onClick={onMenuClick} aria-label="Mở menu">
        <Icon name="menu" size={22} />
      </button>

      <h2 className="min-w-0 shrink-0 truncate font-h1 text-base font-semibold text-on-surface md:text-lg">
        {title}
      </h2>

      {/* Ô tìm kiếm — co giãn, ẩn trên màn nhỏ */}
      {showSearch ? (
        <div className="relative ml-md hidden min-w-0 max-w-md flex-1 lg:block">
          <Icon
            name="search"
            size={18}
            className="pointer-events-none absolute left-sm top-1/2 -translate-y-1/2 text-on-surface-variant"
          />
          <input
            className="field py-2 pl-9"
            placeholder={searchPlaceholder}
            type="search"
            value={searchValue}
            onChange={(e) => onSearchChange?.(e.target.value)}
          />
        </div>
      ) : (
        <div className="flex-1" />
      )}

      {/* Phải */}
      <div className={`flex items-center gap-xs ${showSearch ? 'ml-auto' : ''}`}>
        {onRefresh && (
          <button
            className="icon-btn h-9 w-9"
            onClick={onRefresh}
            title="Làm mới dữ liệu"
            aria-label="Làm mới dữ liệu"
          >
            <Icon name="refresh" size={20} className={refreshing ? 'animate-spin' : ''} />
          </button>
        )}

        <ThemeToggle />

        <span className="mx-xs hidden h-6 w-px bg-outline-variant sm:block" />

        {/* Tài khoản */}
        <div className="relative" ref={menuRef}>
          <button
            onClick={() => setMenuOpen((v) => !v)}
            className="flex items-center gap-sm rounded-full py-1 pl-1 pr-1 transition-colors hover:bg-surface-bright sm:pr-sm"
            aria-haspopup="menu"
            aria-expanded={menuOpen}
          >
            <span className="grid h-8 w-8 shrink-0 place-items-center rounded-full border border-primary/50 bg-primary/15 font-label-sm text-[11px] font-bold text-primary">
              {initials || 'AD'}
            </span>
            <span className="hidden min-w-0 text-left md:block">
              <span className="block truncate font-label-sm text-xs leading-tight text-on-surface">
                {adminInfo?.fullName || 'Admin'}
              </span>
              <span className="block max-w-[160px] truncate text-[10px] leading-tight text-on-surface-variant">
                {adminInfo?.email || ''}
              </span>
            </span>
            <Icon name="expand_more" size={18} className="hidden text-on-surface-variant md:block" />
          </button>

          {menuOpen && (
            <div
              role="menu"
              className="panel absolute right-0 top-full z-50 mt-xs w-56 animate-fade-in overflow-hidden p-0"
            >
              <div className="border-b border-outline-variant/60 px-md py-sm md:hidden">
                <p className="truncate font-label-sm text-xs text-on-surface">{adminInfo?.fullName || 'Admin'}</p>
                <p className="truncate text-[10px] text-on-surface-variant">{adminInfo?.email || ''}</p>
              </div>
              <button
                role="menuitem"
                onClick={onLogout}
                className="flex w-full items-center gap-sm px-md py-sm text-left font-body-md text-sm text-on-surface transition-colors hover:bg-error/10 hover:text-error"
              >
                <Icon name="logout" size={20} />
                Đăng xuất
              </button>
            </div>
          )}
        </div>
      </div>
    </header>
  );
}
