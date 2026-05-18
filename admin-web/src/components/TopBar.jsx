export default function TopBar() {
  return (
    <header className="fixed top-0 right-0 left-20 z-40 bg-surface/80 backdrop-blur-md border-b border-outline-variant flex justify-between items-center h-16 px-gutter w-[calc(100%-5rem)]">
      <div className="flex items-center gap-xl">
        <h2 className="font-h1 text-2xl text-on-surface">RescueCore Admin</h2>
        <div className="relative hidden lg:block w-96">
          <span className="material-symbols-outlined absolute left-sm top-1/2 -translate-y-1/2 text-on-surface-variant" data-icon="search">search</span>
          <input 
            className="bg-surface-container-low border-outline-variant text-on-surface w-full pl-xl py-2 rounded-lg focus:ring-primary focus:border-primary font-body-md text-sm outline-none" 
            placeholder="Search coordinates, teams, or alerts..." 
            type="text"
          />
        </div>
      </div>
      <div className="flex items-center gap-lg">
        <div className="flex items-center gap-md">
          <button className="p-2 text-on-surface-variant hover:bg-surface-bright rounded-full transition-all duration-200">
            <span className="material-symbols-outlined" data-icon="notifications_active">notifications_active</span>
          </button>
          <button className="p-2 text-on-surface-variant hover:bg-surface-bright rounded-full transition-all duration-200">
            <span className="material-symbols-outlined" data-icon="sensors">sensors</span>
          </button>
        </div>
        <div className="h-8 w-px bg-outline-variant"></div>
        <div className="flex items-center gap-sm cursor-pointer hover:bg-surface-bright p-1 pr-3 rounded-full transition-all">
          <img 
            alt="Chief Controller Profile" 
            className="h-8 w-8 rounded-full border border-primary object-cover" 
            src="https://lh3.googleusercontent.com/aida-public/AB6AXuCMEnLOQ6hx7rDRubTGr5gVc_zUq_3ZDMUkv87wSvfDYMu72Hz2h7Cit4LjSn3mO1GELjo9vjVg2lTHSNpuMKD1r0CIu-3XP9l45Y-cHQP_gabYG6oDoG0lG9IGPOLfE699F3ctZBo7rIEaGEAwFTIfJTEfS8jmuA4Qk5wXOd0KEUEf22HEtMODZMjCpMozxU05NmpvmwbbmO0jNqqlE3wV2MyiFDwwKut7eP2uVakhHChBb23yg6S_COOSVimAR73Wb3ez-fs6TiI_"
          />
          <span className="font-label-sm text-on-surface hidden md:block">Chief Controller</span>
        </div>
      </div>
    </header>
  );
}
