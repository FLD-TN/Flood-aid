export default function Sidebar({ activeSection, setActiveSection, isOpen, setIsOpen }) {
  return (
    <>
      {/* Mobile Overlay */}
      {isOpen && (
        <div 
          className="fixed inset-0 bg-black/50 z-[45] md:hidden backdrop-blur-sm"
          onClick={() => setIsOpen(false)}
        />
      )}
      
      {/* Sidebar Container */}
      <aside className={`
        fixed left-0 top-0 h-screen bg-surface-container-lowest border-r border-outline-variant flex flex-col py-lg group z-50
        transition-all duration-300 ease-in-out
        ${isOpen ? 'translate-x-0 w-64' : '-translate-x-full w-64 md:translate-x-0 md:w-20 md:hover:w-64'}
      `}>
        <div className="px-md mb-xl flex items-center justify-between overflow-hidden whitespace-nowrap">
          <div className="flex items-center">
            <span className="material-symbols-outlined text-primary text-2xl mr-md" data-icon="dashboard">dashboard</span>
            <div className={`transition-opacity duration-300 ${isOpen ? 'opacity-100' : 'opacity-0 md:group-hover:opacity-100'}`}>
              <h1 className="font-h1 text-2xl text-on-surface">RescueCore</h1>
              <p className="font-label-sm text-[10px] uppercase tracking-widest text-on-surface-variant">Incident Command</p>
            </div>
          </div>
          {/* Close button on Mobile */}
          <button 
            className="md:hidden text-on-surface-variant hover:text-on-surface p-1"
            onClick={() => setIsOpen(false)}
          >
            <span className="material-symbols-outlined" data-icon="close">close</span>
          </button>
        </div>
        
        <nav className="flex-1 space-y-sm px-sm overflow-y-auto no-scrollbar">
          <a 
            onClick={(e) => { e.preventDefault(); setActiveSection('dashboard'); setIsOpen(false); }}
            className={`flex items-center p-md rounded-lg cursor-pointer transition-all duration-150 ${activeSection === 'dashboard' ? 'text-primary border-l-4 border-primary bg-primary/10' : 'text-on-surface-variant hover:bg-surface-bright'}`}
          >
            <span className="material-symbols-outlined shrink-0" data-icon="dashboard">dashboard</span>
            <span className={`ml-lg font-label-sm transition-opacity duration-300 ${isOpen ? 'opacity-100' : 'opacity-0 md:group-hover:opacity-100'}`}>Dashboard</span>
          </a>
          <a 
            onClick={(e) => { e.preventDefault(); setActiveSection('alerts'); setIsOpen(false); }}
            className={`flex items-center p-md rounded-lg cursor-pointer transition-colors ${activeSection === 'alerts' ? 'text-primary border-l-4 border-primary bg-primary/10' : 'text-on-surface-variant hover:bg-surface-bright'}`}
          >
            <span className="material-symbols-outlined shrink-0" data-icon="warning">warning</span>
            <span className={`ml-lg font-label-sm transition-opacity duration-300 ${isOpen ? 'opacity-100' : 'opacity-0 md:group-hover:opacity-100'}`}>Alerts</span>
          </a>
          <a 
            onClick={(e) => { e.preventDefault(); setActiveSection('teams'); setIsOpen(false); }}
            className={`flex items-center p-md rounded-lg cursor-pointer transition-colors ${activeSection === 'teams' ? 'text-primary border-l-4 border-primary bg-primary/10' : 'text-on-surface-variant hover:bg-surface-bright'}`}
          >
            <span className="material-symbols-outlined shrink-0" data-icon="groups">groups</span>
            <span className={`ml-lg font-label-sm transition-opacity duration-300 ${isOpen ? 'opacity-100' : 'opacity-0 md:group-hover:opacity-100'}`}>Teams</span>
          </a>
          <a 
            onClick={(e) => { e.preventDefault(); setActiveSection('map'); setIsOpen(false); }}
            className={`flex items-center p-md rounded-lg cursor-pointer transition-colors ${activeSection === 'map' ? 'text-primary border-l-4 border-primary bg-primary/10' : 'text-on-surface-variant hover:bg-surface-bright'}`}
          >
            <span className="material-symbols-outlined shrink-0" data-icon="map">map</span>
            <span className={`ml-lg font-label-sm transition-opacity duration-300 ${isOpen ? 'opacity-100' : 'opacity-0 md:group-hover:opacity-100'}`}>Map</span>
          </a>
          <a
            onClick={(e) => { e.preventDefault(); setActiveSection('dialect'); setIsOpen(false); }}
            className={`flex items-center p-md rounded-lg cursor-pointer transition-colors ${activeSection === 'dialect' ? 'text-primary border-l-4 border-primary bg-primary/10' : 'text-on-surface-variant hover:bg-surface-bright'}`}
          >
            <span className="material-symbols-outlined shrink-0" data-icon="translate">translate</span>
            <span className={`ml-lg font-label-sm transition-opacity duration-300 ${isOpen ? 'opacity-100' : 'opacity-0 md:group-hover:opacity-100'}`}>Từ điển</span>
          </a>
          <a
            onClick={(e) => { e.preventDefault(); setActiveSection('reports'); setIsOpen(false); }}
            className={`flex items-center p-md rounded-lg cursor-pointer transition-colors ${activeSection === 'reports' ? 'text-primary border-l-4 border-primary bg-primary/10' : 'text-on-surface-variant hover:bg-surface-bright'}`}
          >
            <span className="material-symbols-outlined shrink-0" data-icon="assessment">assessment</span>
            <span className={`ml-lg font-label-sm transition-opacity duration-300 ${isOpen ? 'opacity-100' : 'opacity-0 md:group-hover:opacity-100'}`}>Reports</span>
          </a>
          <a 
            onClick={(e) => { e.preventDefault(); setActiveSection('settings'); setIsOpen(false); }}
            className={`flex items-center p-md rounded-lg cursor-pointer transition-colors ${activeSection === 'settings' ? 'text-primary border-l-4 border-primary bg-primary/10' : 'text-on-surface-variant hover:bg-surface-bright'}`}
          >
            <span className="material-symbols-outlined shrink-0" data-icon="settings">settings</span>
            <span className={`ml-lg font-label-sm transition-opacity duration-300 ${isOpen ? 'opacity-100' : 'opacity-0 md:group-hover:opacity-100'}`}>Settings</span>
          </a>
        </nav>
      </aside>
    </>
  );
}
