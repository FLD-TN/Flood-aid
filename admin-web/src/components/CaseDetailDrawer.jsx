import CaseDetailPanel from './CaseDetailPanel';

/**
 * Vỏ bọc panel chi tiết.
 *
 * ≥ lg: là một cột thật trong flex row → đẩy bản đồ hẹp lại thay vì nằm đè lên.
 * < lg: là ngăn kéo trượt từ phải kèm lớp phủ.
 *
 * Bản cũ chọn ca xong không hiện gì cả vì CaseDetailPanel không được render ở đâu.
 */
export default function CaseDetailDrawer({ caseData, onClose, onResolved, className = '' }) {
  if (!caseData) return null;

  return (
    <>
      <div
        className="fixed inset-0 z-40 animate-fade-in bg-black/50 backdrop-blur-sm lg:hidden"
        onClick={onClose}
        aria-hidden="true"
      />

      {/* lg trở lên: là flex item nên chiều cao do `align-items: stretch` của
          hàng cha quyết định — không đặt h-full/calc để margin không làm tràn. */}
      <aside
        className={`
          fixed inset-y-0 right-0 z-50 flex w-full max-w-sm animate-slide-in-right
          overflow-hidden border-l border-outline-variant shadow-float
          lg:static lg:z-auto lg:w-[340px] lg:max-w-none lg:shrink-0
          lg:rounded-xl lg:border lg:shadow-panel xl:w-[380px]
          ${className}
        `}
        role="complementary"
        aria-label="Chi tiết ca SOS"
      >
        <CaseDetailPanel caseData={caseData} onClose={onClose} onResolved={onResolved} />
      </aside>
    </>
  );
}
