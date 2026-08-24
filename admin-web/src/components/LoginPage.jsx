import { useState } from 'react';
import axios from 'axios';
import Icon from './ui/Icon';
import ThemeToggle from './ThemeToggle';

const API_BASE = import.meta.env.VITE_API_BASE || 'http://localhost:3000';

export default function LoginPage({ onLogin }) {
  const [mode, setMode] = useState('login'); // 'login' | 'register'
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [fullName, setFullName] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e) {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      const endpoint = mode === 'login' ? '/api/admin/login' : '/api/admin/register';
      const body = mode === 'login' ? { email, password } : { email, password, fullName };
      const res = await axios.post(`${API_BASE}${endpoint}`, body);
      onLogin(res.data.token, res.data.admin);
    } catch (err) {
      setError(err.response?.data?.error || 'Lỗi kết nối máy chủ');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="relative flex min-h-screen items-center justify-center bg-background p-md">
      <div className="absolute right-md top-md">
        <ThemeToggle />
      </div>

      <div className="w-full max-w-md">
        <div className="mb-lg text-center">
          <div className="mb-md inline-flex h-16 w-16 items-center justify-center rounded-2xl bg-primary/15 text-primary">
            <Icon name="emergency" size={36} />
          </div>
          <h1 className="font-h1 text-2xl font-semibold text-on-surface sm:text-3xl">Trang Quản trị Admin</h1>
          <p className="mt-xs font-body-md text-sm text-on-surface-variant">
            Hệ thống điều phối cứu trợ lũ lụt
          </p>
        </div>

        <div className="panel p-lg">
          <h2 className="mb-lg font-h1 text-lg font-semibold text-on-surface">
            {mode === 'login' ? 'Đăng nhập' : 'Tạo tài khoản Admin'}
          </h2>

          <form onSubmit={handleSubmit} className="flex flex-col gap-md">
            {mode === 'register' && (
              <div>
                <label htmlFor="fullname" className="section-label mb-xs block">
                  Họ và tên
                </label>
                <input
                  id="fullname"
                  type="text"
                  value={fullName}
                  onChange={(e) => setFullName(e.target.value)}
                  placeholder="Nguyễn Văn A"
                  required
                  autoComplete="name"
                  className="field py-3"
                />
              </div>
            )}

            <div>
              <label htmlFor="email" className="section-label mb-xs block">
                Email
              </label>
              <input
                id="email"
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="admin@floodaid.vn"
                required
                autoComplete="email"
                className="field py-3"
              />
            </div>

            <div>
              <label htmlFor="password" className="section-label mb-xs block">
                Mật khẩu
              </label>
              <input
                id="password"
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="Tối thiểu 6 ký tự"
                required
                autoComplete={mode === 'login' ? 'current-password' : 'new-password'}
                className="field py-3"
              />
            </div>

            {error && (
              <p className="flex items-center gap-xs rounded-lg border border-error/40 bg-error/10 px-md py-sm font-body-md text-sm text-error">
                <Icon name="error" size={18} />
                {error}
              </p>
            )}

            <button type="submit" disabled={loading} className="btn-primary mt-xs w-full py-3">
              {loading ? 'Đang xử lý...' : mode === 'login' ? 'Đăng nhập' : 'Tạo tài khoản'}
            </button>
          </form>

          <p className="mt-lg text-center font-body-md text-sm text-on-surface-variant">
            {mode === 'login' ? 'Chưa có tài khoản? ' : 'Đã có tài khoản? '}
            <button
              onClick={() => {
                setMode(mode === 'login' ? 'register' : 'login');
                setError('');
              }}
              className="font-semibold text-primary hover:underline"
            >
              {mode === 'login' ? 'Tạo tài khoản' : 'Đăng nhập'}
            </button>
          </p>
        </div>
      </div>
    </div>
  );
}
