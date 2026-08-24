/** @type {import('tailwindcss').Config} */

// Mọi màu đọc từ CSS variable (định nghĩa ở src/App.css) theo format
// "R G B" để Tailwind chèn được alpha: bg-primary/20 → rgb(var(--primary) / 0.2)
const c = (name) => `rgb(var(--${name}) / <alpha-value>)`;

export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  darkMode: "class",
  theme: {
    extend: {
      colors: {
        "background": c("background"),
        "on-background": c("on-background"),

        "surface": c("surface"),
        "on-surface": c("on-surface"),
        "on-surface-variant": c("on-surface-variant"),
        "surface-bright": c("surface-bright"),
        "surface-dim": c("surface-dim"),
        "surface-variant": c("surface-variant"),
        "surface-container-lowest": c("surface-container-lowest"),
        "surface-container-low": c("surface-container-low"),
        "surface-container": c("surface-container"),
        "surface-container-high": c("surface-container-high"),
        "surface-container-highest": c("surface-container-highest"),

        "primary": c("primary"),
        "on-primary": c("on-primary"),
        "primary-container": c("primary-container"),
        "on-primary-container": c("on-primary-container"),

        "secondary": c("secondary"),
        "on-secondary": c("on-secondary"),
        "secondary-container": c("secondary-container"),
        "on-secondary-container": c("on-secondary-container"),

        "tertiary": c("tertiary"),
        "on-tertiary": c("on-tertiary"),
        "tertiary-container": c("tertiary-container"),
        "on-tertiary-container": c("on-tertiary-container"),

        "outline": c("outline"),
        "outline-variant": c("outline-variant"),

        "error": c("error"),
        "on-error": c("on-error"),
        "error-container": c("error-container"),
        "on-error-container": c("on-error-container"),

        "success": c("success"),
        "on-success": c("on-success"),
        "success-container": c("success-container"),
        "on-success-container": c("on-success-container"),

        "warning": c("warning"),
        "on-warning": c("on-warning"),
        "warning-container": c("warning-container"),
        "on-warning-container": c("on-warning-container"),

        "inverse-surface": c("inverse-surface"),
        "inverse-on-surface": c("inverse-on-surface"),

        // Thang mức độ khẩn cấp 1..5 — dùng chung với marker bản đồ
        "urgency-1": c("urgency-1"),
        "urgency-2": c("urgency-2"),
        "urgency-3": c("urgency-3"),
        "urgency-4": c("urgency-4"),
        "urgency-5": c("urgency-5"),
      },
      borderRadius: {
        "DEFAULT": "0.375rem",
        "lg": "0.5rem",
        "xl": "0.75rem",
        "2xl": "1rem",
        "full": "9999px"
      },
      spacing: {
        "xs": "4px",
        "sm": "8px",
        "md": "16px",
        "lg": "24px",
        "xl": "40px",
        "2xl": "64px",
        "container-margin": "24px",
        "gutter": "16px"
      },
      fontFamily: {
        "h1": ["Inter", "system-ui", "sans-serif"],
        "h2": ["Inter", "system-ui", "sans-serif"],
        "display": ["Inter", "system-ui", "sans-serif"],
        "display-mobile": ["Inter", "system-ui", "sans-serif"],
        "body-lg": ["Inter", "system-ui", "sans-serif"],
        "body-md": ["Inter", "system-ui", "sans-serif"],
        "label-sm": ["Roboto Mono", "ui-monospace", "monospace"],
        "mono": ["Roboto Mono", "ui-monospace", "monospace"]
      },
      fontSize: {
        "h2": ["2rem", { "lineHeight": "1.3", "fontWeight": "600" }],
        "body-lg": ["1.125rem", { "lineHeight": "1.6", "fontWeight": "400" }],
        "display": ["4.5rem", { "lineHeight": "1.1", "letterSpacing": "-0.015em", "fontWeight": "600" }],
        "body-md": ["1rem", { "lineHeight": "1.6", "fontWeight": "400" }],
        "label-sm": ["0.75rem", { "lineHeight": "1", "letterSpacing": "0.04em", "fontWeight": "500" }],
        "display-mobile": ["3rem", { "lineHeight": "1.1", "fontWeight": "600" }],
        "h1": ["2.5rem", { "lineHeight": "1.2", "fontWeight": "600" }]
      },
      boxShadow: {
        "panel": "var(--shadow-panel)",
        "raised": "var(--shadow-raised)",
        "float": "var(--shadow-float)",
      },
      transitionTimingFunction: {
        "emphasized": "cubic-bezier(0.2, 0, 0, 1)",
      },
      keyframes: {
        "slide-in-right": {
          from: { transform: "translateX(16px)", opacity: "0" },
          to: { transform: "translateX(0)", opacity: "1" },
        },
        "fade-in": {
          from: { opacity: "0" },
          to: { opacity: "1" },
        },
      },
      animation: {
        "slide-in-right": "slide-in-right 0.25s cubic-bezier(0.2, 0, 0, 1)",
        "fade-in": "fade-in 0.2s ease-out",
      },
    },
  },
  plugins: [],
}
