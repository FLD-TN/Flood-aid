import { useMemo, useState } from 'react';
import { approveVolunteer } from '../api';
import Icon from './ui/Icon';
import EmptyState, { SkeletonList } from './ui/EmptyState';

/**
 * Quản lý & phê duyệt tình nguyện viên.
 * Nằm trong luồng trang (không còn `absolute inset-0`) nên cuộn và bố cục
 * hoạt động bình thường trên mọi kích thước màn hình.
 */
export default function VolunteerManagement({ volunteers = [], loading, onRefresh, search = '' }) {
  const [filter, setFilter] = useState('all');
  const [actionId, setActionId] = useState(null);
  const [error, setError] = useState('');

  const pendingCount = volunteers.filter((v) => !v.admin_approved).length;

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    return volunteers.filter((v) => {
      if (filter === 'pending' && v.admin_approved) return false;
      if (filter === 'approved' && !v.admin_approved) return false;
      if (!q) return true;
      return [v.full_name, v.phone, v.id].filter(Boolean).join(' ').toLowerCase().includes(q);
    });
  }, [volunteers, filter, search]);

  async function handleApprove(id, approved) {
    setActionId(id);
    setError('');
    try {
      await approveVolunteer(id, approved);
      await onRefresh?.();
    } catch (err) {
      setError(err.response?.data?.error || 'Thao tác thất bại. Thử lại sau.');
    } finally {
      setActionId(null);
    }
  }

  const tabs = [
    { key: 'all', label: 'Tất cả', count: volunteers.length },
    { key: 'pending', label: 'Chờ duyệt', count: pendingCount },
    { key: 'approved', label: 'Đã duyệt', count: volunteers.length - pendingCount },
  ];

  return (
    <div className="h-full min-h-0 overflow-y-auto p-md">
      <div className="mx-auto flex max-w-6xl flex-col gap-md">
        {/* Tiêu đề */}
        <header className="flex flex-wrap items-end justify-between gap-md">
          <div className="min-w-0">
            <h1 className="flex items-center gap-sm font-h1 text-xl font-semibold text-on-surface sm:text-2xl">
              <Icon name="groups" size={26} className="text-primary" />
              Quản lý tình nguyện viên
            </h1>
            <p className="mt-xs font-label-sm text-xs text-on-surface-variant">
              {volunteers.length} TNV
              {pendingCount > 0 && <span className="text-warning"> · {pendingCount} chờ duyệt</span>}
            </p>
          </div>

          <div className="flex w-full gap-xs rounded-xl border border-outline-variant/60 bg-surface-container p-xs sm:w-auto">
            {tabs.map((t) => (
              <button
                key={t.key}
                onClick={() => setFilter(t.key)}
                className={`flex-1 whitespace-nowrap rounded-lg px-md py-sm font-label-sm text-xs transition-colors sm:flex-none ${
                  filter === t.key
                    ? 'bg-primary text-on-primary shadow-panel'
                    : 'text-on-surface-variant hover:bg-surface-bright'
                }`}
              >
                {t.label} <span className="opacity-70">{t.count}</span>
              </button>
            ))}
          </div>
        </header>

        {error && (
          <div className="flex items-center gap-sm rounded-lg border border-error/40 bg-error/10 px-md py-sm font-body-md text-sm text-error">
            <Icon name="error" size={18} />
            {error}
          </div>
        )}

        {/* Bảng */}
        <section className="panel overflow-hidden">
          {loading && volunteers.length === 0 ? (
            <SkeletonList rows={4} />
          ) : filtered.length === 0 ? (
            <EmptyState
              icon="person_off"
              title="Không có tình nguyện viên nào"
              hint={search ? 'Thử xoá từ khoá tìm kiếm.' : 'Chưa có ai đăng ký ở bộ lọc này.'}
            />
          ) : (
            <>
              {/* Desktop */}
              <div className="hidden overflow-x-auto md:block">
                <table className="data-table">
                  <thead>
                    <tr>
                      <th>Tình nguyện viên</th>
                      <th className="w-36">Số điện thoại</th>
                      <th className="w-36">eKYC</th>
                      <th className="w-36">Trạng thái</th>
                      <th className="w-28">Ngày ĐK</th>
                      <th className="w-48 text-center">Hành động</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filtered.map((vol) => (
                      <tr key={vol.id} className={!vol.admin_approved ? 'bg-warning/5' : ''}>
                        <td>
                          <div className="flex items-center gap-sm">
                            <span className="grid h-9 w-9 shrink-0 place-items-center rounded-full border border-outline-variant bg-surface-container-high font-label-sm text-[11px] font-bold text-on-surface-variant">
                              {(vol.full_name || 'TNV').trim().slice(0, 2).toUpperCase()}
                            </span>
                            <div className="min-w-0">
                              <p className="truncate font-body-md text-sm text-on-surface">
                                {vol.full_name || '(Chưa có tên)'}
                              </p>
                              <p className="font-label-sm text-[10px] text-on-surface-variant">
                                {vol.id?.slice(0, 8)}
                              </p>
                            </div>
                          </div>
                        </td>
                        <td className="font-label-sm text-xs text-on-surface">{vol.phone || '—'}</td>
                        <td>
                          {vol.cccd_verified ? (
                            <span className="chip bg-success/15 text-success">
                              <Icon name="verified" size={14} />
                              Đã xác thực
                            </span>
                          ) : (
                            <span className="chip bg-surface-bright text-on-surface-variant">
                              <Icon name="shield" size={14} />
                              Chưa có
                            </span>
                          )}
                        </td>
                        <td>
                          {vol.admin_approved ? (
                            <span className="chip bg-success/15 text-success">
                              <Icon name="check_circle" size={14} />
                              Đã duyệt
                            </span>
                          ) : (
                            <span className="chip bg-warning/15 text-warning">
                              <Icon name="schedule" size={14} />
                              Chờ duyệt
                            </span>
                          )}
                        </td>
                        <td className="font-label-sm text-[11px] text-on-surface-variant">
                          {vol.created_at
                            ? new Date(vol.created_at).toLocaleDateString('vi-VN')
                            : '—'}
                        </td>
                        <td>
                          <div className="flex items-center justify-center gap-xs">
                            {!vol.admin_approved ? (
                              <>
                                <button
                                  onClick={() => handleApprove(vol.id, true)}
                                  disabled={actionId === vol.id}
                                  className="btn-ghost border-success/40 px-sm py-xs text-success hover:bg-success/10 hover:text-success"
                                >
                                  <Icon name="check" size={16} />
                                  Duyệt
                                </button>
                                <button
                                  onClick={() => handleApprove(vol.id, false)}
                                  disabled={actionId === vol.id}
                                  className="btn-ghost border-error/40 px-sm py-xs text-error hover:bg-error/10 hover:text-error"
                                >
                                  <Icon name="close" size={16} />
                                  Từ chối
                                </button>
                              </>
                            ) : (
                              <button
                                onClick={() => handleApprove(vol.id, false)}
                                disabled={actionId === vol.id}
                                className="btn-ghost px-sm py-xs hover:border-error/40 hover:bg-error/10 hover:text-error"
                              >
                                Thu hồi
                              </button>
                            )}
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>

              {/* Mobile */}
              <ul className="space-y-sm p-sm md:hidden">
                {filtered.map((vol) => (
                  <li
                    key={vol.id}
                    className="rounded-lg border border-outline-variant/50 bg-surface-container-low p-md"
                  >
                    <div className="flex items-center gap-sm">
                      <span className="grid h-10 w-10 shrink-0 place-items-center rounded-full border border-outline-variant bg-surface-container-high font-label-sm text-xs font-bold text-on-surface-variant">
                        {(vol.full_name || 'TNV').trim().slice(0, 2).toUpperCase()}
                      </span>
                      <div className="min-w-0 flex-1">
                        <p className="truncate font-body-md text-sm text-on-surface">
                          {vol.full_name || '(Chưa có tên)'}
                        </p>
                        <p className="font-label-sm text-[11px] text-on-surface-variant">
                          {vol.phone || 'Chưa có SĐT'}
                        </p>
                      </div>
                    </div>

                    <div className="mt-sm flex flex-wrap gap-xs">
                      {vol.admin_approved ? (
                        <span className="chip bg-success/15 text-success">Đã duyệt</span>
                      ) : (
                        <span className="chip bg-warning/15 text-warning">Chờ duyệt</span>
                      )}
                      {vol.cccd_verified && <span className="chip bg-success/15 text-success">eKYC ✓</span>}
                    </div>

                    <div className="mt-sm flex gap-xs">
                      {!vol.admin_approved ? (
                        <>
                          <button
                            onClick={() => handleApprove(vol.id, true)}
                            disabled={actionId === vol.id}
                            className="btn-ghost flex-1 border-success/40 text-success"
                          >
                            Duyệt
                          </button>
                          <button
                            onClick={() => handleApprove(vol.id, false)}
                            disabled={actionId === vol.id}
                            className="btn-ghost flex-1 border-error/40 text-error"
                          >
                            Từ chối
                          </button>
                        </>
                      ) : (
                        <button
                          onClick={() => handleApprove(vol.id, false)}
                          disabled={actionId === vol.id}
                          className="btn-ghost w-full"
                        >
                          Thu hồi quyền
                        </button>
                      )}
                    </div>
                  </li>
                ))}
              </ul>
            </>
          )}
        </section>
      </div>
    </div>
  );
}
