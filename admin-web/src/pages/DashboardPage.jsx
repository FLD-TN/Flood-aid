import CaseList from '../components/CaseList';
import LiveCommandMap from '../components/LiveCommandMap';
import VolunteerPanel from '../components/VolunteerPanel';
import CaseDetailDrawer from '../components/CaseDetailDrawer';
import StatCard from '../components/ui/StatCard';
import Icon from '../components/ui/Icon';

/**
 * Trang tổng quan.
 *
 * Toàn bộ bố cục dùng flex/grid trong luồng tài liệu. Bản cũ xếp chồng các
 * panel bằng `absolute` với toạ độ cứng (top-[170px], left-[340px]) nên chỉ cần
 * đổi chiều cao cửa sổ là các khối đè lên nhau và bị thanh trên cùng cắt mất.
 */
export default function DashboardPage({ ops, selectedCase, onSelectCase, onCloseCase, onNavigate }) {
  const { metrics, statsLoading, activeCases, casesLoading, clusters, volunteers, volunteerLocations, error } = ops;

  const selectedPosition =
    selectedCase?.cluster_center
      ? [selectedCase.cluster_center.lat, selectedCase.cluster_center.lon]
      : selectedCase?.lat != null && selectedCase?.lon != null
        ? [selectedCase.lat, selectedCase.lon]
        : null;

  return (
    <div className="flex h-full min-h-0 flex-col gap-md p-md">
      {error && (
        <div className="flex shrink-0 items-center gap-sm rounded-lg border border-error/40 bg-error/10 px-md py-sm font-body-md text-sm text-error">
          <Icon name="cloud_off" size={18} />
          Không lấy được dữ liệu từ máy chủ: {error}
        </div>
      )}

      {/* Hàng số liệu — lưới nên các thẻ luôn bằng nhau và tự xuống dòng */}
      <div className="grid shrink-0 grid-cols-1 gap-md sm:grid-cols-2 xl:grid-cols-4">
        <StatCard
          icon="emergency"
          label="Ca SOS đang mở"
          value={metrics?.activeSos ?? 0}
          hint={metrics ? `${metrics.pending} chờ · ${metrics.responding} đang tới` : undefined}
          tone="danger"
          loading={statsLoading && !metrics}
        />
        <StatCard
          icon="groups"
          label="TNV đang triển khai"
          value={metrics?.deployedVolunteers ?? 0}
          hint={metrics ? `${metrics.availableVolunteers}/${metrics.totalVolunteers} đang rảnh` : undefined}
          tone="warning"
          loading={statsLoading && !metrics}
        />
        <StatCard
          icon="pin_drop"
          label="TNV tại hiện trường"
          value={metrics?.onScene ?? 0}
          tone="primary"
          loading={statsLoading && !metrics}
        />
        <StatCard
          icon="health_and_safety"
          label="Ca đã xử lý xong"
          value={metrics?.resolved ?? 0}
          tone="success"
          loading={statsLoading && !metrics}
        />
      </div>

      {/* Vùng làm việc chính */}
      <div className="flex min-h-0 flex-1 flex-col gap-md lg:flex-row">
        {/* Danh sách ca — trên mobile cao cố định, desktop kéo dài hết cột */}
        <div className="h-[42vh] min-h-0 shrink-0 lg:h-auto lg:w-80 xl:w-96">
          <CaseList
            cases={activeCases}
            loading={casesLoading}
            onCaseSelect={onSelectCase}
            selectedCaseId={selectedCase?.id}
            onViewAll={() => onNavigate('alerts')}
          />
        </div>

        {/* Bản đồ + dải TNV */}
        <div className="flex min-h-0 flex-1 flex-col gap-md">
          <div className="min-h-[280px] flex-1 overflow-hidden rounded-xl border border-outline-variant/60 shadow-panel">
            <LiveCommandMap
              clusters={clusters}
              volunteers={volunteerLocations}
              onCaseSelect={onSelectCase}
              selectedCaseId={selectedCase?.id}
              selectedPosition={selectedPosition}
            />
          </div>

          <div className="shrink-0">
            <VolunteerPanel volunteers={volunteers} />
          </div>
        </div>

        {/* Chi tiết ca */}
        <CaseDetailDrawer caseData={selectedCase} onClose={onCloseCase} onResolved={ops.refreshAll} />
      </div>
    </div>
  );
}
