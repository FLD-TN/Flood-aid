/**
 * Bọc Material Symbols để mọi nơi khai báo kích thước theo cùng một cách,
 * thay vì rải text-[18px] / text-[20px] / text-[24px] khắp file.
 */
export default function Icon({ name, size = 20, className = '', filled = false, ...rest }) {
  return (
    <span
      aria-hidden="true"
      className={`material-symbols-outlined shrink-0 ${className}`}
      style={{
        fontSize: `${size}px`,
        width: `${size}px`,
        height: `${size}px`,
        fontVariationSettings: `'FILL' ${filled ? 1 : 0}, 'wght' 400, 'GRAD' 0, 'opsz' ${size}`,
      }}
      data-icon={name}
      {...rest}
    >
      {name}
    </span>
  );
}
