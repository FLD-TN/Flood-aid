import Icon from './Icon';

const TONES = {
  primary: 'border-l-primary bg-primary/10 text-primary',
  danger: 'border-l-urgency-5 bg-urgency-5/10 text-urgency-5',
  warning: 'border-l-warning bg-warning/10 text-warning',
  success: 'border-l-success bg-success/10 text-success',
  neutral: 'border-l-outline bg-surface-bright text-on-surface-variant',
};

/**
 * Ô số liệu ở đầu trang. Mọi thẻ dùng cùng một khung nên chiều cao luôn bằng
 * nhau kể cả khi nhãn dài ngắn khác nhau.
 */
export default function StatCard({ icon, label, value, hint, tone = 'primary', loading = false }) {
  const toneClass = TONES[tone] || TONES.primary;
  const [borderClass, bgClass, textClass] = toneClass.split(' ');

  return (
    <div
      className={`panel flex min-w-0 items-center gap-md border-l-4 px-md py-sm sm:px-lg sm:py-md ${borderClass}`}
    >
      <div className={`grid h-10 w-10 shrink-0 place-items-center rounded-lg ${bgClass} ${textClass}`}>
        <Icon name={icon} size={22} />
      </div>

      <div className="min-w-0 flex-1">
        <p className="section-label truncate">{label}</p>
        <p className="font-h1 text-2xl leading-tight text-on-surface sm:text-3xl">
          {loading ? <span className="text-on-surface-variant/50">—</span> : value}
        </p>
        {hint && <p className="truncate font-label-sm text-[10px] text-on-surface-variant">{hint}</p>}
      </div>
    </div>
  );
}
