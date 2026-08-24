import { useTheme } from '../theme/themeContext';
import Icon from './ui/Icon';

/**
 * Công tắc sáng/tối.
 * variant="switch" — nút gạt có nhãn (dùng trong trang Cài đặt)
 * variant="icon"   — nút tròn gọn (dùng trên thanh trên cùng)
 */
export default function ThemeToggle({ variant = 'icon' }) {
  const { isDark, toggleTheme } = useTheme();
  const label = isDark ? 'Chuyển sang chế độ sáng' : 'Chuyển sang chế độ tối';

  if (variant === 'switch') {
    return (
      <button
        onClick={toggleTheme}
        role="switch"
        aria-checked={isDark}
        aria-label={label}
        className="flex w-full items-center justify-between gap-md rounded-lg border border-outline-variant/60 bg-surface-container-low px-md py-sm transition-colors hover:bg-surface-bright"
      >
        <span className="flex items-center gap-sm text-on-surface">
          <Icon name={isDark ? 'dark_mode' : 'light_mode'} size={20} className="text-primary" />
          <span className="font-body-md text-sm">{isDark ? 'Chế độ tối' : 'Chế độ sáng'}</span>
        </span>

        <span
          className={`relative h-6 w-11 shrink-0 rounded-full transition-colors ${isDark ? 'bg-primary' : 'bg-outline/40'}`}
        >
          <span
            className={`absolute top-1/2 h-5 w-5 -translate-y-1/2 rounded-full bg-surface shadow-raised transition-all duration-200 ${isDark ? 'left-[22px]' : 'left-[2px]'}`}
          />
        </span>
      </button>
    );
  }

  return (
    <button
      onClick={toggleTheme}
      title={label}
      aria-label={label}
      className="icon-btn h-9 w-9"
    >
      <Icon name={isDark ? 'light_mode' : 'dark_mode'} size={20} />
    </button>
  );
}
