import { useState } from 'react';
import axios from 'axios';

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
    <div className="min-h-screen bg-background flex items-center justify-center p-4">
      <div className="w-full max-w-md">
        {/* Header */}
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-primary/20 mb-4">
            <span className="material-symbols-outlined text-primary text-4xl" data-icon="emergency">emergency</span>
          </div>
          <h1 className="font-h1 text-3xl text-on-surface">RescueCore Admin</h1>
          <p className="text-on-surface-variant font-body-md mt-1">Hệ thống điều phối cứu trợ lũ lụt</p>
        </div>

        {/* Card */}
        <div className="glass-panel rounded-2xl p-8">
          <h2 className="font-h1 text-xl text-on-surface mb-6">
            {mode === 'login' ? 'Đăng nhập' : 'Tạo tài khoản Admin'}
          </h2>

          <form onSubmit={handleSubmit} className="flex flex-col gap-4">
            {mode === 'register' && (
              <div>
                <label className="font-label-sm text-on-surface-variant text-xs uppercase tracking-widest block mb-1">
                  Họ và tên
                </label>
                <input
                  type="text"
                  value={fullName}
                  onChange={e => setFullName(e.target.value)}
                  placeholder="Nguyễn Văn A"
                  required
                  className="w-full bg-surface-container-low border border-outline-variant text-on-surface rounded-lg px-4 py-3 font-body-md text-sm outline-none focus:border-primary focus:ring-1 focus:ring-primary transition-colors"
                />
              </div>
            )}

            <div>
              <label className="font-label-sm text-on-surface-variant text-xs uppercase tracking-widest block mb-1">
                Email
              </label>
              <input
                type="email"
                value={email}
                onChange={e => setEmail(e.target.value)}
                placeholder="admin@floodaid.vn"
                required
                className="w-full bg-surface-container-low border border-outline-variant text-on-surface rounded-lg px-4 py-3 font-body-md text-sm outline-none focus:border-primary focus:ring-1 focus:ring-primary transition-colors"
              />
            </div>

            <div>
              <label className="font-label-sm text-on-surface-variant text-xs uppercase tracking-widest block mb-1">
                Mật khẩu
              </label>
              <input
                type="password"
                value={password}
                onChange={e => setPassword(e.target.value)}
                placeholder="Tối thiểu 6 ký tự"
                required
                className="w-full bg-surface-container-low border border-outline-variant text-on-surface rounded-lg px-4 py-3 font-body-md text-sm outline-none focus:border-primary focus:ring-1 focus:ring-primary transition-colors"
              />
            </div>

            {error && (
              <div className="flex items-center gap-2 bg-error/10 border border-error/30 text-error rounded-lg px-4 py-3 text-sm">
                <span className="material-symbols-outlined text-[18px]" data-icon="error">error</span>
                {error}
              </div>
            )}

            <button
              type="submit"
              disabled={loading}
              className="w-full bg-primary text-on-primary rounded-lg py-3 font-label-sm font-semibold text-sm hover:opacity-90 active:scale-[0.98] transition-all disabled:opacity-50 disabled:cursor-not-allowed mt-2"
            >
              {loading ? 'Đang xử lý...' : mode === 'login' ? 'Đăng nhập' : 'Tạo tài khoản'}
            </button>
          </form>

          <div className="mt-6 text-center text-sm text-on-surface-variant">
            {mode === 'login' ? (
              <>
                Chưa có tài khoản?{' '}
                <button onClick={() => { setMode('register'); setError(''); }} className="text-primary hover:underline font-semibold">
                  Tạo tài khoản
                </button>
              </>
            ) : (
              <>
                Đã có tài khoản?{' '}
                <button onClick={() => { setMode('login'); setError(''); }} className="text-primary hover:underline font-semibold">
                  Đăng nhập
                </button>
              </>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
