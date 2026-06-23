export default function TopBar({ onMenuClick, adminInfo, onLogout }) {
  return (
    <header className="fixed top-0 right-0 left-0 md:left-20 z-40 bg-surface/80 backdrop-blur-md border-b border-outline-variant flex justify-between items-center h-16 px-md md:px-gutter w-full md:w-[calc(100%-5rem)] transition-all duration-300">
      <div className="flex items-center gap-sm md:gap-xl">
        {/* Mobile Hamburger Menu */}
        <button
          className="md:hidden p-2 text-on-surface-variant hover:bg-surface-bright rounded-lg transition-colors"
          onClick={onMenuClick}
        >
          <span className="material-symbols-outlined" data-icon="menu">menu</span>
        </button>

        <h2 className="font-h1 text-xl md:text-2xl text-on-surface">RescueCore Admin</h2>

        <div className="relative hidden lg:block w-96">
          <span className="material-symbols-outlined absolute left-sm top-1/2 -translate-y-1/2 text-on-surface-variant" data-icon="search">search</span>
          <input
            className="bg-surface-container-low border-outline-variant text-on-surface w-full pl-xl py-2 rounded-lg focus:ring-primary focus:border-primary font-body-md text-sm outline-none"
            placeholder="Search coordinates, teams, or alerts..."
            type="text"
          />
        </div>
      </div>

      <div className="flex items-center gap-sm md:gap-lg">
        <div className="flex items-center gap-xs md:gap-md">
          <button className="p-2 text-on-surface-variant hover:bg-surface-bright rounded-full transition-all duration-200">
            <span className="material-symbols-outlined" data-icon="notifications_active">notifications_active</span>
          </button>
          <button className="p-2 text-on-surface-variant hover:bg-surface-bright rounded-full transition-all duration-200">
            <span className="material-symbols-outlined" data-icon="sensors">sensors</span>
          </button>
        </div>
        <div className="h-8 w-px bg-outline-variant hidden sm:block"></div>

        {/* Admin info + Logout */}
        <div className="flex items-center gap-sm">
          <div className="flex items-center gap-sm p-1 sm:pr-3 rounded-full">
            <div className="h-8 w-8 rounded-full border border-primary bg-primary/20 flex items-center justify-center">
              <span className="material-symbols-outlined text-primary text-[18px]" data-icon="admin_panel_settings">admin_panel_settings</span>
            </div>
            <div className="hidden md:block">
              <p className="font-label-sm text-on-surface text-sm leading-tight">{adminInfo?.fullName || 'Admin'}</p>
              <p className="text-on-surface-variant text-[10px] leading-tight">{adminInfo?.email || ''}</p>
            </div>
          </div>
          <button
            onClick={onLogout}
            className="p-2 text-on-surface-variant hover:bg-error/10 hover:text-error rounded-full transition-all duration-200"
            title="Đăng xuất"
          >
            <span className="material-symbols-outlined text-[20px]" data-icon="logout">logout</span>
          </button>
        </div>
      </div>
    </header>
  );
}
