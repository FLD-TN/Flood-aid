import { useCallback, useEffect, useMemo, useState } from 'react';
import Sidebar from './components/Sidebar';
import TopBar from './components/TopBar';
import { NAV_ITEMS } from './lib/navItems';
import LoginPage from './components/LoginPage';
import VolunteerManagement from './components/VolunteerManagement';
import DialectManagement from './components/DialectManagement';
import DashboardPage from './pages/DashboardPage';
import SosMonitorPage from './pages/SosMonitorPage';
import MapPage from './pages/MapPage';
import ReportsPage from './pages/ReportsPage';
import SettingsPage from './pages/SettingsPage';
import { useOpsData } from './hooks/useOpsData';
import './App.css';

/** Nội dung đã đăng nhập — tách riêng để hook polling chỉ chạy sau khi có token. */
function AdminShell({ adminInfo, onLogout }) {
  const [section, setSection] = useState('dashboard');
  const [pickedCase, setPickedCase] = useState(null);
  const [search, setSearch] = useState('');
  const [mobileNavOpen, setMobileNavOpen] = useState(false);
  const [navCollapsed, setNavCollapsed] = useState(() => localStorage.getItem('navCollapsed') === '1');
  const [refreshing, setRefreshing] = useState(false);

  const ops = useOpsData();

  // Panel chi tiết luôn đọc bản mới nhất từ vòng poll thay vì đóng băng bản
  // chụp lúc bấm; marker trên bản đồ (cluster) không nằm trong danh sách ca nên
  // rơi về chính đối tượng đã bấm.
  const selectedCase = useMemo(() => {
    if (!pickedCase) return null;
    return ops.allCases.find((c) => c.id === pickedCase.id) || pickedCase;
  }, [pickedCase, ops.allCases]);

  useEffect(() => {
    localStorage.setItem('navCollapsed', navCollapsed ? '1' : '0');
  }, [navCollapsed]);

  // Esc đóng panel chi tiết đang mở
  useEffect(() => {
    if (!pickedCase) return;
    const onKey = (e) => e.key === 'Escape' && setPickedCase(null);
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [pickedCase]);

  const handleNavigate = useCallback((key) => {
    setSection(key);
    setMobileNavOpen(false);
    setSearch('');
    setPickedCase(null);
  }, []);

  const { refreshAll } = ops;
  const handleRefresh = useCallback(async () => {
    setRefreshing(true);
    try {
      await refreshAll();
    } finally {
      setRefreshing(false);
    }
  }, [refreshAll]);

  const pendingVolunteers = ops.volunteers.filter((v) => !v.admin_approved).length;
  const title = NAV_ITEMS.find((i) => i.key === section)?.label || 'Trang Quản Trị';

  const pageProps = {
    ops,
    selectedCase,
    onSelectCase: setPickedCase,
    onCloseCase: () => setPickedCase(null),
    onNavigate: handleNavigate,
    search,
  };

  function renderPage() {
    switch (section) {
      case 'alerts':
        return <SosMonitorPage {...pageProps} />;
      case 'map':
        return <MapPage {...pageProps} />;
      case 'teams':
        return (
          <VolunteerManagement
            volunteers={ops.volunteers}
            loading={ops.volunteersLoading}
            onRefresh={ops.refreshAll}
            search={search}
          />
        );
      case 'dialect':
        return <DialectManagement search={search} />;
      case 'reports':
        return <ReportsPage ops={ops} />;
      case 'settings':
        return <SettingsPage adminInfo={adminInfo} onLogout={onLogout} />;
      default:
        return <DashboardPage {...pageProps} />;
    }
  }

  const searchablePages = ['alerts', 'teams', 'dialect'];

  return (
    <div className="flex h-screen w-full overflow-hidden bg-background text-on-background">
      <Sidebar
        activeSection={section}
        onNavigate={handleNavigate}
        collapsed={navCollapsed}
        onToggleCollapse={() => setNavCollapsed((v) => !v)}
        mobileOpen={mobileNavOpen}
        onCloseMobile={() => setMobileNavOpen(false)}
        pendingCount={pendingVolunteers}
      />

      {/* min-w-0 để nội dung rộng (bảng, bản đồ) không kéo giãn layout ra ngoài */}
      <div className="flex min-w-0 flex-1 flex-col">
        <TopBar
          title={title}
          onMenuClick={() => setMobileNavOpen(true)}
          adminInfo={adminInfo}
          onLogout={onLogout}
          onRefresh={handleRefresh}
          refreshing={refreshing}
          searchValue={search}
          onSearchChange={setSearch}
          showSearch={searchablePages.includes(section)}
          searchPlaceholder={
            section === 'teams'
              ? 'Tìm tình nguyện viên...'
              : section === 'dialect'
                ? 'Tìm từ...'
                : 'Tìm ca SOS, toạ độ, mô tả...'
          }
        />

        <main className="min-h-0 flex-1 overflow-hidden">{renderPage()}</main>
      </div>
    </div>
  );
}

export default function App() {
  const [adminToken, setAdminToken] = useState(() => localStorage.getItem('adminToken'));
  const [adminInfo, setAdminInfo] = useState(() => {
    try {
      return JSON.parse(localStorage.getItem('adminInfo'));
    } catch {
      return null;
    }
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

  if (!adminToken) return <LoginPage onLogin={handleLogin} />;

  return <AdminShell adminInfo={adminInfo} onLogout={handleLogout} />;
}
