export default function Sidebar({ activeSection, setActiveSection }) {
  return (
    <aside className="h-screen w-20 hover:w-64 transition-all duration-300 fixed left-0 top-0 z-50 bg-surface-container-lowest border-r border-outline-variant flex flex-col py-lg group">
      <div className="px-md mb-xl flex items-center overflow-hidden whitespace-nowrap">
        <span className="material-symbols-outlined text-primary text-2xl mr-md" data-icon="dashboard">dashboard</span>
        <div className="opacity-0 group-hover:opacity-100 transition-opacity">
          <h1 className="font-h1 text-2xl text-on-surface">RescueCore</h1>
          <p className="font-label-sm text-[10px] uppercase tracking-widest text-on-surface-variant">Incident Command</p>
        </div>
      </div>
      <nav className="flex-1 space-y-sm px-sm">
        <a 
          onClick={(e) => { e.preventDefault(); setActiveSection('dashboard'); }}
          className={`flex items-center p-md rounded-lg cursor-pointer transition-all duration-150 ${activeSection === 'dashboard' ? 'text-primary border-l-4 border-primary bg-primary/10' : 'text-on-surface-variant hover:bg-surface-bright'}`}
        >
          <span className="material-symbols-outlined" data-icon="dashboard">dashboard</span>
          <span className="ml-lg opacity-0 group-hover:opacity-100 font-label-sm">Dashboard</span>
        </a>
        <a 
          onClick={(e) => { e.preventDefault(); setActiveSection('alerts'); }}
          className={`flex items-center p-md rounded-lg cursor-pointer transition-colors ${activeSection === 'alerts' ? 'text-primary border-l-4 border-primary bg-primary/10' : 'text-on-surface-variant hover:bg-surface-bright'}`}
        >
          <span className="material-symbols-outlined" data-icon="warning">warning</span>
          <span className="ml-lg opacity-0 group-hover:opacity-100 font-label-sm">Alerts</span>
        </a>
        <a 
          onClick={(e) => { e.preventDefault(); setActiveSection('teams'); }}
          className={`flex items-center p-md rounded-lg cursor-pointer transition-colors ${activeSection === 'teams' ? 'text-primary border-l-4 border-primary bg-primary/10' : 'text-on-surface-variant hover:bg-surface-bright'}`}
        >
          <span className="material-symbols-outlined" data-icon="groups">groups</span>
          <span className="ml-lg opacity-0 group-hover:opacity-100 font-label-sm">Teams</span>
        </a>
        <a 
          onClick={(e) => { e.preventDefault(); setActiveSection('map'); }}
          className={`flex items-center p-md rounded-lg cursor-pointer transition-colors ${activeSection === 'map' ? 'text-primary border-l-4 border-primary bg-primary/10' : 'text-on-surface-variant hover:bg-surface-bright'}`}
        >
          <span className="material-symbols-outlined" data-icon="map">map</span>
          <span className="ml-lg opacity-0 group-hover:opacity-100 font-label-sm">Map</span>
        </a>
        <a 
          onClick={(e) => { e.preventDefault(); setActiveSection('reports'); }}
          className={`flex items-center p-md rounded-lg cursor-pointer transition-colors ${activeSection === 'reports' ? 'text-primary border-l-4 border-primary bg-primary/10' : 'text-on-surface-variant hover:bg-surface-bright'}`}
        >
          <span className="material-symbols-outlined" data-icon="assessment">assessment</span>
          <span className="ml-lg opacity-0 group-hover:opacity-100 font-label-sm">Reports</span>
        </a>
        <a 
          onClick={(e) => { e.preventDefault(); setActiveSection('settings'); }}
          className={`flex items-center p-md rounded-lg cursor-pointer transition-colors ${activeSection === 'settings' ? 'text-primary border-l-4 border-primary bg-primary/10' : 'text-on-surface-variant hover:bg-surface-bright'}`}
        >
          <span className="material-symbols-outlined" data-icon="settings">settings</span>
          <span className="ml-lg opacity-0 group-hover:opacity-100 font-label-sm">Settings</span>
        </a>
      </nav>
    </aside>
  );
}
