import { useState, useEffect, useCallback, useMemo } from 'react';
import { getDialectDict, addDialectTerm, removeDialectTerm } from '../api';
import Icon from './ui/Icon';
import EmptyState from './ui/EmptyState';

/**
 * Quản lý từ điển phương ngữ (override).
 *
 * Thêm/xoá từ ở đây ghi vào file override phía backend (không DB). App mobile
 * tự đồng bộ về và merge chồng lên từ điển gốc → có hiệu lực mà không cần build
 * lại app.
 */
export default function DialectManagement({ search = '' }) {
  const [version, setVersion] = useState(0);
  const [terms, setTerms] = useState({});
  const [loading, setLoading] = useState(true);
  const [dialect, setDialect] = useState('');
  const [standard, setStandard] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [localSearch, setLocalSearch] = useState('');
  const [error, setError] = useState('');

  const load = useCallback(async () => {
    try {
      const res = await getDialectDict();
      setVersion(res.data.version || 0);
      setTerms(res.data.terms || {});
    } catch {
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
      setError(
        err.response?.status === 401
          ? 'Phiên đăng nhập hết hạn, đăng nhập lại.'
          : 'Thêm từ thất bại.',
      );
    } finally {
      setSubmitting(false);
    }
  };

  const handleRemove = async (key) => {
    const prev = terms;
    const next = { ...terms };
    delete next[key];
    setTerms(next); // optimistic
    try {
      const res = await removeDialectTerm(key);
      setVersion(res.data.version || version + 1);
    } catch {
      setTerms(prev); // rollback
      setError('Xoá thất bại.');
    }
  };

  // Ô tìm trên thanh trên cùng và ô tìm trong trang dùng chung một bộ lọc
  const query = (search || localSearch).trim().toLowerCase();

  const entries = useMemo(
    () =>
      Object.entries(terms).filter(
        ([k, v]) => !query || k.includes(query) || v.toLowerCase().includes(query),
      ),
    [terms, query],
  );

  return (
    <div className="h-full min-h-0 overflow-y-auto p-md">
      <div className="mx-auto flex max-w-4xl flex-col gap-md">
        <header>
          <h1 className="flex items-center gap-sm font-h1 text-xl font-semibold text-on-surface sm:text-2xl">
            <Icon name="translate" size={26} className="text-primary" />
            Từ điển phương ngữ
          </h1>
          <p className="mt-xs font-label-sm text-xs text-on-surface-variant">
            {Object.keys(terms).length} từ override · phiên bản v{version}
          </p>
        </header>

        {/* Form thêm từ */}
        <form onSubmit={handleAdd} className="panel p-md">
          <p className="mb-md font-body-md text-sm text-on-surface-variant">
            App đọc sai từ nào? Thêm cặp <span className="text-primary">phương ngữ → nghĩa phổ thông</span>. App
            mobile sẽ tự đồng bộ, không cần build lại.
          </p>

          <div className="flex flex-col gap-md md:flex-row md:items-end">
            <div className="flex-1">
              <label htmlFor="dialect-in" className="section-label mb-xs block">
                Từ địa phương
              </label>
              <input
                id="dialect-in"
                value={dialect}
                onChange={(e) => setDialect(e.target.value)}
                placeholder="vd: mô"
                className="field"
              />
            </div>

            <Icon name="arrow_forward" size={20} className="hidden self-center text-on-surface-variant md:block md:pb-sm" />

            <div className="flex-1">
              <label htmlFor="standard-in" className="section-label mb-xs block">
                Nghĩa phổ thông
              </label>
              <input
                id="standard-in"
                value={standard}
                onChange={(e) => setStandard(e.target.value)}
                placeholder="vd: đâu"
                className="field"
              />
            </div>

            <button type="submit" disabled={submitting} className="btn-primary shrink-0 py-sm">
              <Icon name="add" size={18} />
              {submitting ? 'Đang thêm...' : 'Thêm từ'}
            </button>
          </div>

          {error && (
            <p className="mt-md flex items-center gap-xs font-body-md text-xs text-error">
              <Icon name="error" size={16} />
              {error}
            </p>
          )}
        </form>

        {/* Danh sách */}
        <section className="panel overflow-hidden">
          <div className="panel-header">
            <h2 className="panel-title">Từ đã thêm ({Object.keys(terms).length})</h2>
            <div className="relative w-40 sm:w-64">
              <Icon
                name="search"
                size={16}
                className="pointer-events-none absolute left-sm top-1/2 -translate-y-1/2 text-on-surface-variant"
              />
              <input
                value={localSearch}
                onChange={(e) => setLocalSearch(e.target.value)}
                placeholder="Tìm từ..."
                className="field py-xs pl-8 text-xs"
              />
            </div>
          </div>

          {loading ? (
            <EmptyState icon="hourglass_top" title="Đang tải từ điển..." />
          ) : entries.length === 0 ? (
            <EmptyState
              icon="menu_book"
              title={Object.keys(terms).length === 0 ? 'Chưa có từ override nào' : 'Không tìm thấy từ khớp'}
              hint={
                Object.keys(terms).length === 0
                  ? 'Thêm từ đầu tiên bằng biểu mẫu phía trên.'
                  : undefined
              }
            />
          ) : (
            <div className="overflow-x-auto">
              <table className="data-table">
                <thead>
                  <tr>
                    <th>Phương ngữ</th>
                    <th>Nghĩa phổ thông</th>
                    <th className="w-20 text-center">Xoá</th>
                  </tr>
                </thead>
                <tbody>
                  {entries.map(([k, v]) => (
                    <tr key={k}>
                      <td className="font-body-md text-sm font-medium text-on-surface">{k}</td>
                      <td className="font-body-md text-sm text-primary">{v}</td>
                      <td className="text-center">
                        <button
                          onClick={() => handleRemove(k)}
                          className="icon-btn h-8 w-8 hover:bg-error/10 hover:text-error"
                          title={`Xoá từ "${k}"`}
                          aria-label={`Xoá từ ${k}`}
                        >
                          <Icon name="delete" size={18} />
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </section>
      </div>
    </div>
  );
}
