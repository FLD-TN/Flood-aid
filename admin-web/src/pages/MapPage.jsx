import { useState } from 'react';
import LiveCommandMap from '../components/LiveCommandMap';
import CaseList from '../components/CaseList';
import CaseDetailDrawer from '../components/CaseDetailDrawer';
import Icon from '../components/ui/Icon';

/**
 * Bản đồ điều phối toàn màn hình.
 * Danh sách ca là một panel thu gọn được, không phải lớp phủ đè lên bản đồ.
 */
export default function MapPage({ ops, selectedCase, onSelectCase, onCloseCase }) {
  const [listOpen, setListOpen] = useState(true);
  const { clusters, volunteerLocations, activeCases, casesLoading } = ops;

  const selectedPosition =
    selectedCase?.cluster_center
      ? [selectedCase.cluster_center.lat, selectedCase.cluster_center.lon]
      : selectedCase?.lat != null && selectedCase?.lon != null
        ? [selectedCase.lat, selectedCase.lon]
        : null;

  return (
    <div className="flex h-full min-h-0">
      {/* Panel danh sách */}
      <div
        className={`
          hidden shrink-0 overflow-hidden transition-[width] duration-300 ease-emphasized md:block
          ${listOpen ? 'w-80 p-md pr-0 xl:w-96' : 'w-0'}
        `}
      >
        <div className={`h-full ${listOpen ? '' : 'invisible'}`}>
          <CaseList
            cases={activeCases}
            loading={casesLoading}
            onCaseSelect={onSelectCase}
            selectedCaseId={selectedCase?.id}
          />
        </div>
      </div>

      {/* Bản đồ */}
      <div className="relative min-w-0 flex-1 p-md">
        <div className="h-full overflow-hidden rounded-xl border border-outline-variant/60 shadow-panel">
          <LiveCommandMap
            clusters={clusters}
            volunteers={volunteerLocations}
            onCaseSelect={onSelectCase}
            selectedCaseId={selectedCase?.id}
            selectedPosition={selectedPosition}
          />
        </div>

        {/* Nút thu/mở danh sách — bám mép trái bản đồ */}
        <button
          onClick={() => setListOpen((v) => !v)}
          className="glass-panel icon-btn absolute left-md top-1/2 z-10 hidden h-14 w-6 -translate-y-1/2 rounded-l-none rounded-r-lg md:flex"
          title={listOpen ? 'Ẩn danh sách ca' : 'Hiện danh sách ca'}
          aria-label={listOpen ? 'Ẩn danh sách ca' : 'Hiện danh sách ca'}
        >
          <Icon name={listOpen ? 'chevron_left' : 'chevron_right'} size={18} />
        </button>
      </div>

      <CaseDetailDrawer
        caseData={selectedCase}
        onClose={onCloseCase}
        onResolved={ops.refreshAll}
        className="lg:my-md lg:mr-md"
      />
    </div>
  );
}
