import ThemeToggle from '../components/ThemeToggle';
import Icon from '../components/ui/Icon';
import { useTheme } from '../theme/themeContext';

const API_BASE = import.meta.env.VITE_API_BASE || 'http://localhost:3000';

function Row({ label, value }) {
  return (
    <div className="flex items-center justify-between gap-md border-b border-outline-variant/40 py-sm last:border-0">
      <span className="font-body-md text-sm text-on-surface-variant">{label}</span>
      <span className="min-w-0 truncate font-label-sm text-xs text-on-surface">{value}</span>
    </div>
  );
}

export default function SettingsPage({ adminInfo, onLogout }) {
  const { theme, setTheme } = useTheme();

  return (
    <div className="h-full min-h-0 overflow-y-auto p-md">
      <div className="mx-auto flex max-w-3xl flex-col gap-lg">
        <header>
          <h1 className="flex items-center gap-sm font-h1 text-xl font-semibold text-on-surface sm:text-2xl">
            <Icon name="settings" size={26} className="text-primary" />
            Cài đặt
          </h1>
        </header>

        {/* Giao diện */}
        <section className="panel p-md">
          <h2 className="section-label mb-md">Giao diện</h2>

          <ThemeToggle variant="switch" />

          <div className="mt-md grid grid-cols-2 gap-sm">
            {[
              { key: 'light', label: 'Sáng', icon: 'light_mode' },
              { key: 'dark', label: 'Tối', icon: 'dark_mode' },
            ].map((opt) => (
              <button
                key={opt.key}
                onClick={() => setTheme(opt.key)}
                className={`flex items-center justify-center gap-sm rounded-lg border px-md py-sm font-body-md text-sm transition-colors ${
                  theme === opt.key
                    ? 'border-primary bg-primary/10 text-primary'
                    : 'border-outline-variant/60 text-on-surface-variant hover:bg-surface-bright'
                }`}
              >
                <Icon name={opt.icon} size={20} />
                {opt.label}
              </button>
            ))}
          </div>

          <p className="mt-sm font-body-md text-xs text-on-surface-variant">
            Lựa chọn được lưu trên trình duyệt này. Lần đầu truy cập, hệ thống lấy theo cài đặt sáng/tối của
            máy.
          </p>
        </section>

        {/* Tài khoản */}
        <section className="panel p-md">
          <h2 className="section-label mb-md">Tài khoản</h2>
          <Row label="Họ và tên" value={adminInfo?.fullName || '—'} />
          <Row label="Email" value={adminInfo?.email || '—'} />
          <Row label="Vai trò" value="Quản trị viên" />

          <button
            onClick={onLogout}
            className="btn-ghost mt-md w-full border-error/40 text-error hover:bg-error/10 hover:text-error"
          >
            <Icon name="logout" size={18} />
            Đăng xuất
          </button>
        </section>

        {/* Kết nối */}
        <section className="panel p-md">
          <h2 className="section-label mb-md">Kết nối hệ thống</h2>
          <Row label="Máy chủ API" value={API_BASE} />
          <Row label="Chu kỳ làm mới ca SOS" value="10 giây" />
          <Row label="Chu kỳ làm mới vị trí TNV" value="15 giây" />
          <p className="mt-md font-body-md text-xs text-on-surface-variant">
            Dữ liệu tạm dừng cập nhật khi tab bị ẩn và tự làm mới ngay khi bạn quay lại.
          </p>
        </section>
      </div>
    </div>
  );
}
