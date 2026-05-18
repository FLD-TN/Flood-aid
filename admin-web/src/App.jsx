import { useState } from 'react';
import LiveCommandMap from './components/LiveCommandMap';
import CaseList from './components/CaseList';
import TopBar from './components/TopBar';
import Sidebar from './components/Sidebar';
import VolunteerPanel from './components/VolunteerPanel';
import { usePolling } from './hooks/usePolling';
import './App.css';

function App() {
  const [activeSection, setActiveSection] = useState('dashboard');
  const [selectedCase, setSelectedCase] = useState(null);

  // Lấy dữ liệu thống kê từ backend (polling mỗi 10s)
  const { data: stats } = usePolling('/api/admin/stats', 10000);

  // Tính toán các con số
  const activeSos = stats ? parseInt(stats.cases.pending_count || 0) + parseInt(stats.cases.responding_count || 0) : 0;
  const totalVols = stats ? parseInt(stats.volunteers.total_volunteers || 0) : 0;
  const availVols = stats ? parseInt(stats.volunteers.available_count || 0) : 0;
  const deployedTeams = totalVols - availVols;
  const progressSaved = stats ? parseInt(stats.cases.resolved_count || 0) : 0;

  return (
    <div className="bg-background text-on-background font-body-md overflow-hidden flex h-screen w-screen">
      {/* SIDE NAVIGATION BAR */}
      <Sidebar activeSection={activeSection} setActiveSection={setActiveSection} />
      
      {/* MAIN CONTENT AREA */}
      <div className="flex-1 flex flex-col relative h-full overflow-hidden w-full ml-20">
        <TopBar />
        
        <main className="flex-1 relative bg-background h-full w-full">
          {/* FULL BACKGROUND MAP */}
          <div className="absolute inset-0 z-0 overflow-hidden">
            <LiveCommandMap onCaseSelect={setSelectedCase} selectedCaseId={selectedCase?.id} />
          </div>
          
          {/* OVERLAY: TOP METRICS */}
          <div className="absolute top-gutter left-gutter right-gutter z-20 flex gap-gutter pointer-events-none">
            <div className="glass-panel flex-1 px-lg py-md rounded-xl flex items-center gap-md border-l-4 border-l-primary pointer-events-auto">
              <div className="bg-primary/20 p-sm rounded-lg text-primary">
                <span className="material-symbols-outlined" data-icon="emergency">emergency</span>
              </div>
              <div>
                <p className="font-label-sm text-[10px] text-on-surface-variant uppercase tracking-widest">Active SOS</p>
                <p className="font-h1 text-3xl text-on-surface">{stats ? activeSos : '-'}</p>
              </div>
            </div>
            
            <div className="glass-panel flex-1 px-lg py-md rounded-xl flex items-center gap-md pointer-events-auto">
              <div className="bg-surface-bright p-sm rounded-lg text-primary">
                <span className="material-symbols-outlined" data-icon="groups">groups</span>
              </div>
              <div>
                <p className="font-label-sm text-[10px] text-on-surface-variant uppercase tracking-widest">Deployed Teams</p>
                <p className="font-h1 text-3xl text-on-surface">{stats ? deployedTeams : '-'}</p>
              </div>
            </div>
            
            <div className="glass-panel flex-1 px-lg py-md rounded-xl flex items-center gap-md pointer-events-auto">
              <div className="bg-surface-bright p-sm rounded-lg text-primary">
                <span className="material-symbols-outlined" data-icon="health_and_safety">health_and_safety</span>
              </div>
              <div>
                <p className="font-label-sm text-[10px] text-on-surface-variant uppercase tracking-widest">Progress Saved</p>
                <p className="font-h1 text-3xl text-on-surface">{stats ? progressSaved : '-'}</p>
              </div>
            </div>
          </div>
          
          {/* OVERLAY: LEFT PANEL (SOS FEED) */}
          <div className="absolute top-32 left-gutter bottom-gutter w-80 z-20 flex flex-col gap-md pointer-events-none">
            <div className="pointer-events-auto h-full flex flex-col">
              <CaseList onCaseSelect={setSelectedCase} selectedCaseId={selectedCase?.id} />
            </div>
          </div>
          
          {/* OVERLAY: BOTTOM PANEL (ACTIVITY LOG) */}
          <div className="absolute bottom-gutter left-[340px] right-gutter z-20 pointer-events-none">
            <div className="pointer-events-auto w-full">
              <VolunteerPanel />
            </div>
          </div>
          
          {/* FLOATING ACTION BUTTON */}
          <button className="absolute bottom-32 right-gutter z-30 w-14 h-14 rounded-full bg-primary text-on-primary shadow-2xl flex items-center justify-center hover:scale-110 active:scale-95 transition-all pointer-events-auto">
            <span className="material-symbols-outlined text-[32px]" data-icon="add_alert">add_alert</span>
          </button>
          
          {/* MAP CONTROLS */}
          <div className="absolute bottom-32 right-gutter translate-y-[-72px] z-30 flex flex-col gap-xs pointer-events-auto">
            <button className="w-10 h-10 glass-panel rounded-lg flex items-center justify-center hover:bg-surface-bright transition-colors text-on-surface-variant hover:text-primary">
              <span className="material-symbols-outlined text-[20px]" data-icon="layers">layers</span>
            </button>
            <button className="w-10 h-10 glass-panel rounded-lg flex items-center justify-center hover:bg-surface-bright transition-colors text-on-surface-variant hover:text-primary">
              <span className="material-symbols-outlined text-[20px]" data-icon="near_me">near_me</span>
            </button>
            <button className="w-10 h-10 glass-panel rounded-lg flex items-center justify-center hover:bg-surface-bright transition-colors text-on-surface-variant hover:text-primary">
              <span className="material-symbols-outlined text-[20px]" data-icon="add">add</span>
            </button>
            <button className="w-10 h-10 glass-panel rounded-lg flex items-center justify-center hover:bg-surface-bright transition-colors text-on-surface-variant hover:text-primary">
              <span className="material-symbols-outlined text-[20px]" data-icon="remove">remove</span>
            </button>
          </div>
          
        </main>
      </div>
    </div>
  );
}

export default App;
