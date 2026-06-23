import { useState } from 'react';
import LiveCommandMap from './components/LiveCommandMap';
import CaseList from './components/CaseList';
import TopBar from './components/TopBar';
import Sidebar from './components/Sidebar';
import VolunteerPanel from './components/VolunteerPanel';
import VolunteerManagement from './components/VolunteerManagement';
import LoginPage from './components/LoginPage';
import { usePolling } from './hooks/usePolling';
import './App.css';

function App() {
  const [activeSection, setActiveSection] = useState('dashboard');
  const [selectedCase, setSelectedCase] = useState(null);
  const [isSidebarOpen, setIsSidebarOpen] = useState(false);

  // Auth state — khởi tạo từ localStorage
  const [adminToken, setAdminToken] = useState(() => localStorage.getItem('adminToken'));
  const [adminInfo, setAdminInfo] = useState(() => {
    try { return JSON.parse(localStorage.getItem('adminInfo')); } catch { return null; }
  });

  function handleLogin(token, info) {
    localStorage.setItem('adminToken', token);
    localStorage.setItem('adminInfo', JSON.stringify(info));
    setAdminToken(token);
    setAdminInfo(info);
  }

  function handleLogout() {
    localStorage.removeItem('adminToken');
    localStorage.removeItem('adminInfo');
    setAdminToken(null);
    setAdminInfo(null);
  }

  // Hiển thị trang login nếu chưa xác thực
  if (!adminToken) {
    return <LoginPage onLogin={handleLogin} />;
  }

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
      <Sidebar 
        activeSection={activeSection} 
        setActiveSection={setActiveSection} 
        isOpen={isSidebarOpen} 
        setIsOpen={setIsSidebarOpen} 
      />
      
      {/* MAIN CONTENT AREA */}
      <div className="flex-1 flex flex-col relative h-full overflow-hidden w-full md:ml-20">
        <TopBar onMenuClick={() => setIsSidebarOpen(true)} adminInfo={adminInfo} onLogout={handleLogout} />
        
        <main className="flex-1 relative bg-background h-full w-full pt-16 md:pt-0">
          {activeSection === 'teams' ? (
            <VolunteerManagement />
          ) : (
            <>
          {/* FULL BACKGROUND MAP */}
          <div className="absolute inset-0 z-0 overflow-hidden mt-16 md:mt-0">
            <LiveCommandMap onCaseSelect={setSelectedCase} selectedCaseId={selectedCase?.id} />
          </div>
          
          {/* OVERLAY: TOP METRICS */}
          <div className="absolute top-20 md:top-gutter left-gutter right-gutter z-20 flex overflow-x-auto no-scrollbar gap-gutter pointer-events-none pb-2">
            <div className="glass-panel min-w-[200px] flex-1 px-md lg:px-lg py-sm lg:py-md rounded-xl flex items-center gap-sm lg:gap-md border-l-4 border-l-primary pointer-events-auto shrink-0">
              <div className="bg-primary/20 p-xs lg:p-sm rounded-lg text-primary">
                <span className="material-symbols-outlined text-[20px] lg:text-[24px]" data-icon="emergency">emergency</span>
              </div>
              <div>
                <p className="font-label-sm text-[9px] lg:text-[10px] text-on-surface-variant uppercase tracking-widest">Active SOS</p>
                <p className="font-h1 text-2xl lg:text-3xl text-on-surface leading-tight">{stats ? activeSos : '-'}</p>
              </div>
            </div>
            
            <div className="glass-panel min-w-[200px] flex-1 px-md lg:px-lg py-sm lg:py-md rounded-xl flex items-center gap-sm lg:gap-md pointer-events-auto shrink-0">
              <div className="bg-surface-bright p-xs lg:p-sm rounded-lg text-primary">
                <span className="material-symbols-outlined text-[20px] lg:text-[24px]" data-icon="groups">groups</span>
              </div>
              <div>
                <p className="font-label-sm text-[9px] lg:text-[10px] text-on-surface-variant uppercase tracking-widest">Deployed Teams</p>
                <p className="font-h1 text-2xl lg:text-3xl text-on-surface leading-tight">{stats ? deployedTeams : '-'}</p>
              </div>
            </div>
            
            <div className="glass-panel min-w-[200px] flex-1 px-md lg:px-lg py-sm lg:py-md rounded-xl flex items-center gap-sm lg:gap-md pointer-events-auto shrink-0">
              <div className="bg-surface-bright p-xs lg:p-sm rounded-lg text-primary">
                <span className="material-symbols-outlined text-[20px] lg:text-[24px]" data-icon="health_and_safety">health_and_safety</span>
              </div>
              <div>
                <p className="font-label-sm text-[9px] lg:text-[10px] text-on-surface-variant uppercase tracking-widest">Progress Saved</p>
                <p className="font-h1 text-2xl lg:text-3xl text-on-surface leading-tight">{stats ? progressSaved : '-'}</p>
              </div>
            </div>
          </div>
          
          {/* OVERLAY: PANELS (Mobile stacked, Desktop split) */}
          <div className="absolute top-[170px] md:top-32 left-gutter right-gutter md:right-auto md:w-80 md:bottom-gutter z-20 flex flex-col gap-md pointer-events-none h-[calc(100%-190px)] md:h-auto pb-4 md:pb-0">
            <div className="pointer-events-auto flex-1 md:h-full flex flex-col min-h-0">
              <CaseList onCaseSelect={setSelectedCase} selectedCaseId={selectedCase?.id} />
            </div>
            {/* Mobile Volunteer Panel */}
            <div className="pointer-events-auto flex-1 md:hidden min-h-0 flex flex-col">
              <VolunteerPanel />
            </div>
          </div>
          
          {/* OVERLAY: BOTTOM PANEL (ACTIVITY LOG) - Desktop Only */}
          <div className="hidden md:block absolute bottom-gutter left-[340px] right-gutter z-20 pointer-events-none">
            <div className="pointer-events-auto w-full">
              <VolunteerPanel />
            </div>
          </div>
          
          {/* MAP CONTROLS & FAB */}
          <div className="absolute bottom-gutter right-gutter z-30 flex flex-col gap-sm pointer-events-auto items-end">
            <button className="w-12 h-12 md:w-14 md:h-14 mb-2 rounded-full bg-primary text-on-primary shadow-2xl flex items-center justify-center hover:scale-110 active:scale-95 transition-all">
              <span className="material-symbols-outlined text-[28px] md:text-[32px]" data-icon="add_alert">add_alert</span>
            </button>
            <div className="flex flex-col gap-xs">
              <button className="w-9 h-9 md:w-10 md:h-10 glass-panel rounded-lg flex items-center justify-center hover:bg-surface-bright transition-colors text-on-surface-variant hover:text-primary">
                <span className="material-symbols-outlined text-[20px]" data-icon="layers">layers</span>
              </button>
              <button className="w-9 h-9 md:w-10 md:h-10 glass-panel rounded-lg flex items-center justify-center hover:bg-surface-bright transition-colors text-on-surface-variant hover:text-primary">
                <span className="material-symbols-outlined text-[20px]" data-icon="near_me">near_me</span>
              </button>
              <button className="w-9 h-9 md:w-10 md:h-10 glass-panel rounded-lg flex items-center justify-center hover:bg-surface-bright transition-colors text-on-surface-variant hover:text-primary">
                <span className="material-symbols-outlined text-[20px]" data-icon="add">add</span>
              </button>
              <button className="w-9 h-9 md:w-10 md:h-10 glass-panel rounded-lg flex items-center justify-center hover:bg-surface-bright transition-colors text-on-surface-variant hover:text-primary">
                <span className="material-symbols-outlined text-[20px]" data-icon="remove">remove</span>
              </button>
            </div>
          </div>
          
            </>
          )}
        </main>
      </div>
    </div>
  );
}

export default App;
