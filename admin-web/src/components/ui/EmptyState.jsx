import Icon from './Icon';

/** Trạng thái rỗng / đang tải / lỗi — dùng chung để mọi panel nhìn giống nhau. */
export default function EmptyState({ icon = 'inbox', title, hint, tone = 'muted', action }) {
  const color = tone === 'error' ? 'text-error' : 'text-on-surface-variant';

  return (
    <div className="flex flex-col items-center justify-center gap-sm px-md py-xl text-center">
      <Icon name={icon} size={32} className={`${color} opacity-60`} />
      <p className={`font-label-sm text-xs ${color}`}>{title}</p>
      {hint && <p className="max-w-[36ch] font-body-md text-xs text-on-surface-variant/80">{hint}</p>}
      {action}
    </div>
  );
}

/** Skeleton xám thay cho chữ "Loading..." trần. */
export function SkeletonList({ rows = 3 }) {
  return (
    <div className="space-y-sm p-sm">
      {Array.from({ length: rows }).map((_, i) => (
        <div key={i} className="animate-pulse rounded-lg border border-outline-variant/40 bg-surface-container p-md">
          <div className="mb-sm h-3 w-1/3 rounded bg-on-surface/10" />
          <div className="mb-xs h-4 w-2/3 rounded bg-on-surface/10" />
          <div className="h-8 w-full rounded bg-on-surface/5" />
        </div>
      ))}
    </div>
  );
}
