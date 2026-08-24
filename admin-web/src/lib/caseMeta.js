/**
 * Nguồn duy nhất cho nhãn & màu của ca SOS.
 * Trước đây CaseList / CaseDetailPanel / LiveCommandMap mỗi nơi khai báo một
 * bảng khác nhau nên cùng một ca hiện màu khác nhau ở từng panel.
 */

export const URGENCY = {
  5: { label: 'Rất cao', short: 'Critical', token: 'urgency-5' },
  4: { label: 'Cao', short: 'Urgent', token: 'urgency-4' },
  3: { label: 'Trung bình', short: 'High', token: 'urgency-3' },
  2: { label: 'Thấp', short: 'Medium', token: 'urgency-2' },
  1: { label: 'Rất thấp', short: 'Low', token: 'urgency-1' },
};

export const STATUS = {
  pending: { label: 'Chờ cứu hộ', token: 'urgency-5', icon: 'pending' },
  responding: { label: 'TNV đang đến', token: 'urgency-3', icon: 'directions_run' },
  on_scene: { label: 'TNV tại chỗ', token: 'primary', icon: 'pin_drop' },
  resolved: { label: 'Đã đóng', token: 'success', icon: 'check_circle' },
};

export const TAG_LABELS = {
  y_te: '🩹 Y tế',
  tre_em: '👶 Trẻ em',
  nguoi_gia: '👴 Người già',
  can_xuong: '🚣 Cần xuồng',
  ngap_nha: '🏠 Ngập nhà',
};

/** Màu marker Leaflet — đọc token đang hiệu lực để marker đổi theo theme */
export function urgencyColor(level) {
  const token = URGENCY[level]?.token || 'urgency-3';
  const raw = getComputedStyle(document.documentElement).getPropertyValue(`--${token}`).trim();
  return raw ? `rgb(${raw})` : '#F59E0B';
}

export function urgencyMeta(level) {
  return URGENCY[level] || URGENCY[3];
}

export function statusMeta(status) {
  return STATUS[status] || STATUS.pending;
}

/** Ca quá 15 phút mà chưa TNV nào nhận */
export function isOrphanCase(c) {
  return (c?.minutes_waiting ?? 0) > 15 && (c?.responding_count ?? 0) === 0 && c?.status === 'pending';
}

export function formatWaiting(minutes) {
  const m = Math.round(minutes ?? 0);
  if (m < 60) return `${m} phút`;
  const h = Math.floor(m / 60);
  const rest = m % 60;
  return rest ? `${h}g ${rest}p` : `${h} giờ`;
}

export function shortId(id) {
  return (id || '').slice(0, 8).toUpperCase() || '--------';
}
