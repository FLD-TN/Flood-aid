import { useState } from 'react';
import { usePolling } from '../hooks/usePolling';
import { approveVolunteer } from '../api';

/**
 * VolunteerManagement — Trang quản lý & phê duyệt TNV cho Admin
 * Hiển thị danh sách TNV với trạng thái eKYC, cho phép Approve/Reject.
 */
export default function VolunteerManagement() {
  const { data: allVols, refresh } = usePolling('/api/volunteers', 10000);
  const [filter, setFilter] = useState('all'); // all | pending | approved
  const [actionLoading, setActionLoading] = useState(null);

  const volunteers = allVols || [];

  const filtered = volunteers.filter((v) => {
    if (filter === 'pending') return !v.admin_approved;
    if (filter === 'approved') return v.admin_approved;
    return true;
  });

  const pendingCount = volunteers.filter((v) => !v.admin_approved).length;

  const handleApprove = async (id, approved) => {
    setActionLoading(id);
    try {
      await approveVolunteer(id, approved);
      await refresh();
    } catch (err) {
      console.error('Approve error:', err);
    } finally {
      setActionLoading(null);
    }
  };

  return (
    <div className="absolute inset-0 z-10 bg-background overflow-auto p-gutter">
      {/* Header */}
      <div className="flex flex-col md:flex-row items-start md:items-center justify-between gap-md mb-lg">
        <div>
          <h1 className="font-h1 text-2xl md:text-3xl text-on-surface flex items-center gap-md">
            <span className="material-symbols-outlined text-primary text-2xl md:text-3xl" data-icon="group">group</span>
            Quản lý Tình nguyện viên
          </h1>
          <p className="font-label-sm text-on-surface-variant mt-xs">
            {volunteers.length} TNV · {pendingCount} chờ duyệt
          </p>
        </div>

        {/* Filter Tabs */}
        <div className="flex flex-wrap gap-xs bg-surface-dim/40 p-xs rounded-xl w-full md:w-auto">
          {[
            { key: 'all', label: 'Tất cả' },
            { key: 'pending', label: `Chờ duyệt (${pendingCount})` },
            { key: 'approved', label: 'Đã duyệt' },
          ].map((tab) => (
            <button
              key={tab.key}
              onClick={() => setFilter(tab.key)}
              className={`flex-1 md:flex-none px-md md:px-lg py-sm rounded-lg font-label-sm text-xs transition-all ${
                filter === tab.key
                  ? 'bg-primary text-on-primary shadow-md'
                  : 'text-on-surface-variant hover:bg-surface-bright/30'
              }`}
            >
              {tab.label}
            </button>
          ))}
        </div>
      </div>

      {/* Table */}
      <div className="glass-panel rounded-xl border border-outline-variant/30 overflow-hidden">
        <div className="overflow-x-auto w-full">
          <table className="w-full min-w-[800px]">
            <thead>
              <tr className="border-b border-outline-variant/30 text-left">
                <th className="px-lg py-md font-label-sm text-[10px] text-on-surface-variant uppercase tracking-widest whitespace-nowrap">TNV</th>
                <th className="px-lg py-md font-label-sm text-[10px] text-on-surface-variant uppercase tracking-widest whitespace-nowrap">SĐT</th>
                <th className="px-lg py-md font-label-sm text-[10px] text-on-surface-variant uppercase tracking-widest whitespace-nowrap">eKYC</th>
                <th className="px-lg py-md font-label-sm text-[10px] text-on-surface-variant uppercase tracking-widest whitespace-nowrap">Kỹ năng</th>
                <th className="px-lg py-md font-label-sm text-[10px] text-on-surface-variant uppercase tracking-widest whitespace-nowrap">Trạng thái</th>
                <th className="px-lg py-md font-label-sm text-[10px] text-on-surface-variant uppercase tracking-widest whitespace-nowrap">Ngày ĐK</th>
                <th className="px-lg py-md font-label-sm text-[10px] text-on-surface-variant uppercase tracking-widest text-center whitespace-nowrap">Hành động</th>
              </tr>
          </thead>
          <tbody>
            {filtered.length === 0 ? (
              <tr>
                <td colSpan={7} className="text-center py-xl text-on-surface-variant font-label-sm">
                  Không có TNV nào.
                </td>
              </tr>
            ) : (
              filtered.map((vol) => (
                <tr
                  key={vol.id}
                  className={`border-b border-outline-variant/15 hover:bg-surface-bright/10 transition-colors ${
                    !vol.admin_approved ? 'bg-yellow-500/5' : ''
                  }`}
                >
                  {/* Tên */}
                  <td className="px-lg py-md">
                    <div className="flex items-center gap-sm">
                      <img
                        src={`https://ui-avatars.com/api/?name=${encodeURIComponent(vol.full_name || 'TNV')}&background=142637&color=E8F0F5&size=36`}
                        alt={vol.full_name}
                        className="w-9 h-9 rounded-full border border-outline-variant/30"
                      />
                      <div>
                        <p className="font-label-sm text-sm text-on-surface">{vol.full_name || '(Chưa có tên)'}</p>
                        <p className="font-label-sm text-[10px] text-on-surface-variant">{vol.id?.slice(0, 8)}...</p>
                      </div>
                    </div>
                  </td>

                  {/* SĐT */}
                  <td className="px-lg py-md">
                    <span className="font-label-sm text-xs text-on-surface font-mono">
                      {vol.phone || '***'}
                    </span>
                  </td>

                  {/* eKYC Status */}
                  <td className="px-lg py-md">
                    {vol.cccd_verified ? (
                      <span className="inline-flex items-center gap-xs px-sm py-xs bg-green-500/15 text-green-400 rounded-full text-[10px] font-label-sm">
                        <span className="material-symbols-outlined text-[14px]" data-icon="verified">verified</span>
                        Đã xác thực
                      </span>
                    ) : (
                      <span className="inline-flex items-center gap-xs px-sm py-xs bg-surface-dim/40 text-on-surface-variant rounded-full text-[10px] font-label-sm">
                        <span className="material-symbols-outlined text-[14px]" data-icon="shield">shield</span>
                        Chưa có
                      </span>
                    )}
                  </td>

                  {/* Skills */}
                  <td className="px-lg py-md">
                    <div className="flex flex-wrap gap-xs max-w-[200px]">
                      {vol.skills && vol.skills.length > 0 ? (
                        vol.skills.slice(0, 2).map((skill, i) => (
                          <span key={i} className="px-sm py-xs bg-primary/10 text-primary rounded-md text-[10px] font-label-sm whitespace-nowrap">
                            {skill}
                          </span>
                        ))
                      ) : (
                        <span className="text-[10px] text-on-surface-variant">—</span>
                      )}
                      {vol.skills && vol.skills.length > 2 && (
                        <span className="text-[10px] text-on-surface-variant">+{vol.skills.length - 2}</span>
                      )}
                    </div>
                  </td>

                  {/* Trạng thái */}
                  <td className="px-lg py-md">
                    {vol.admin_approved ? (
                      <span className="inline-flex items-center gap-xs px-sm py-xs bg-green-500/15 text-green-400 rounded-full text-[10px] font-label-sm">
                        ✅ Đã duyệt
                      </span>
                    ) : (
                      <span className="inline-flex items-center gap-xs px-sm py-xs bg-yellow-500/15 text-yellow-400 rounded-full text-[10px] font-label-sm animate-pulse">
                        ⏳ Chờ duyệt
                      </span>
                    )}
                  </td>

                  {/* Ngày ĐK */}
                  <td className="px-lg py-md">
                    <span className="font-label-sm text-[10px] text-on-surface-variant">
                      {vol.created_at
                        ? new Date(vol.created_at).toLocaleDateString('vi-VN', {
                            day: '2-digit',
                            month: '2-digit',
                            year: 'numeric',
                          })
                        : '—'}
                    </span>
                  </td>

                  {/* Actions */}
                  <td className="px-lg py-md text-center">
                    {!vol.admin_approved ? (
                      <div className="flex items-center justify-center gap-xs">
                        <button
                          onClick={() => handleApprove(vol.id, true)}
                          disabled={actionLoading === vol.id}
                          className="px-md py-sm bg-green-500/20 text-green-400 hover:bg-green-500/30 rounded-lg font-label-sm text-[11px] transition-colors disabled:opacity-50"
                        >
                          {actionLoading === vol.id ? '...' : '✓ Duyệt'}
                        </button>
                        <button
                          onClick={() => handleApprove(vol.id, false)}
                          disabled={actionLoading === vol.id}
                          className="px-md py-sm bg-red-500/15 text-red-400 hover:bg-red-500/25 rounded-lg font-label-sm text-[11px] transition-colors disabled:opacity-50"
                        >
                          ✕ Từ chối
                        </button>
                      </div>
                    ) : (
                      <button
                        onClick={() => handleApprove(vol.id, false)}
                        disabled={actionLoading === vol.id}
                        className="px-md py-sm bg-surface-dim/40 text-on-surface-variant hover:bg-red-500/15 hover:text-red-400 rounded-lg font-label-sm text-[11px] transition-colors disabled:opacity-50"
                      >
                        Thu hồi
                      </button>
                    )}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
        </div>
      </div>
    </div>
  );
}
