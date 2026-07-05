import { useState, useEffect, useCallback } from 'react';
import { getDialectDict, addDialectTerm, removeDialectTerm } from '../api';

/**
 * DialectManagement — Trang quản lý từ điển phương ngữ (override) cho Admin.
 *
 * Thêm/xoá từ ở đây ghi vào file override phía backend (không DB). App mobile
 * tự đồng bộ về và merge chồng lên từ điển gốc → có hiệu lực mà không cần build
 * lại app.
 */
export default function DialectManagement() {
  const [version, setVersion] = useState(0);
  const [terms, setTerms] = useState({}); // { dialect: standard }
  const [loading, setLoading] = useState(true);
  const [dialect, setDialect] = useState('');
  const [standard, setStandard] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [search, setSearch] = useState('');
  const [error, setError] = useState('');

  const load = useCallback(async () => {
    try {
      const res = await getDialectDict();
      setVersion(res.data.version || 0);
      setTerms(res.data.terms || {});
    } catch (err) {
      setError('Không tải được từ điển. Kiểm tra kết nối backend.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const handleAdd = async (e) => {
    e?.preventDefault();
    const d = dialect.trim();
    const s = standard.trim();
    if (!d || !s) {
      setError('Nhập đủ cả từ địa phương và nghĩa phổ thông.');
      return;
    }
    setSubmitting(true);
    setError('');
    try {
      const res = await addDialectTerm(d, s);
      setVersion(res.data.version || version + 1);
      setTerms((prev) => ({ ...prev, [d.toLowerCase()]: s }));
      setDialect('');
      setStandard('');
    } catch (err) {
      setError(err.response?.status === 401
        ? 'Phiên đăng nhập hết hạn, đăng nhập lại.'
        : 'Thêm từ thất bại.');
    } finally {
      setSubmitting(false);
    }
  };

  const handleRemove = async (key) => {
    const prev = terms;
    // Optimistic: bỏ khỏi UI trước
    const next = { ...terms };
    delete next[key];
    setTerms(next);
    try {
      const res = await removeDialectTerm(key);
      setVersion(res.data.version || version + 1);
    } catch (err) {
      setTerms(prev); // rollback nếu lỗi
      setError('Xoá thất bại.');
    }
  };

  const entries = Object.entries(terms).filter(([k, v]) => {
    if (!search.trim()) return true;
    const q = search.trim().toLowerCase();
    return k.includes(q) || v.toLowerCase().includes(q);
  });

  return (
    <div className="absolute inset-0 z-10 bg-background overflow-auto p-gutter">
      {/* Header */}
      <div className="flex flex-col md:flex-row items-start md:items-center justify-between gap-md mb-lg">
        <div>
          <h1 className="font-h1 text-2xl md:text-3xl text-on-surface flex items-center gap-md">
            <span className="material-symbols-outlined text-primary text-2xl md:text-3xl" data-icon="translate">translate</span>
            Từ điển phương ngữ
          </h1>
          <p className="font-label-sm text-on-surface-variant mt-xs">
            {Object.keys(terms).length} từ override · phiên bản v{version}
          </p>
        </div>
      </div>

      {/* Form thêm từ */}
      <form onSubmit={handleAdd} className="glass-panel rounded-xl border border-outline-variant/30 p-lg mb-lg">
        <p className="font-label-sm text-on-surface-variant mb-md">
          App đọc sai từ nào? Thêm cặp <span className="text-primary">phương ngữ → nghĩa phổ thông</span>.
          App mobile sẽ tự đồng bộ, không cần build lại.
        </p>
        <div className="flex flex-col md:flex-row gap-md items-stretch md:items-end">
          <div className="flex-1">
            <label className="font-label-sm text-[10px] text-on-surface-variant uppercase tracking-widest block mb-xs">Từ địa phương</label>
            <input
              value={dialect}
              onChange={(e) => setDialect(e.target.value)}
              placeholder="vd: mô"
              className="w-full bg-surface-container-lowest border border-outline-variant/50 rounded-lg px-md py-sm text-on-surface font-body-md focus:border-primary outline-none"
            />
          </div>
          <span className="material-symbols-outlined text-on-surface-variant hidden md:block pb-sm" data-icon="arrow_forward">arrow_forward</span>
          <div className="flex-1">
            <label className="font-label-sm text-[10px] text-on-surface-variant uppercase tracking-widest block mb-xs">Nghĩa phổ thông</label>
            <input
              value={standard}
              onChange={(e) => setStandard(e.target.value)}
              placeholder="vd: đâu"
              className="w-full bg-surface-container-lowest border border-outline-variant/50 rounded-lg px-md py-sm text-on-surface font-body-md focus:border-primary outline-none"
            />
          </div>
          <button
            type="submit"
            disabled={submitting}
            className="bg-primary text-on-primary px-lg py-sm rounded-lg font-label-sm flex items-center justify-center gap-xs hover:opacity-90 active:scale-95 transition-all disabled:opacity-50"
          >
            <span className="material-symbols-outlined text-[20px]" data-icon="add">add</span>
            Thêm từ
          </button>
        </div>
        {error && <p className="text-error font-label-sm mt-md">{error}</p>}
      </form>

      {/* Danh sách */}
      <div className="glass-panel rounded-xl border border-outline-variant/30 overflow-hidden">
        <div className="flex items-center justify-between gap-md p-md border-b border-outline-variant/30">
          <p className="font-label-sm text-on-surface-variant">
            Từ đã thêm ({Object.keys(terms).length})
          </p>
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Tìm từ..."
            className="bg-surface-container-lowest border border-outline-variant/50 rounded-lg px-md py-xs text-on-surface font-body-md focus:border-primary outline-none w-40 md:w-64"
          />
        </div>

        {loading ? (
          <p className="text-center py-xl text-on-surface-variant font-label-sm">Đang tải...</p>
        ) : entries.length === 0 ? (
          <p className="text-center py-xl text-on-surface-variant font-label-sm">
            {Object.keys(terms).length === 0 ? 'Chưa có từ override nào.' : 'Không tìm thấy từ khớp.'}
          </p>
        ) : (
          <div className="overflow-x-auto w-full">
            <table className="w-full min-w-[500px]">
              <thead>
                <tr className="border-b border-outline-variant/30 text-left">
                  <th className="px-lg py-md font-label-sm text-[10px] text-on-surface-variant uppercase tracking-widest">Phương ngữ</th>
                  <th className="px-lg py-md font-label-sm text-[10px] text-on-surface-variant uppercase tracking-widest">Nghĩa phổ thông</th>
                  <th className="px-lg py-md font-label-sm text-[10px] text-on-surface-variant uppercase tracking-widest text-center">Xoá</th>
                </tr>
              </thead>
              <tbody>
                {entries.map(([k, v]) => (
                  <tr key={k} className="border-b border-outline-variant/10 hover:bg-surface-bright/20">
                    <td className="px-lg py-md text-on-surface font-body-md font-medium">{k}</td>
                    <td className="px-lg py-md text-primary font-body-md">{v}</td>
                    <td className="px-lg py-md text-center">
                      <button
                        onClick={() => handleRemove(k)}
                        className="text-on-surface-variant hover:text-error transition-colors"
                        title="Xoá từ này"
                      >
                        <span className="material-symbols-outlined text-[20px]" data-icon="delete">delete</span>
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
