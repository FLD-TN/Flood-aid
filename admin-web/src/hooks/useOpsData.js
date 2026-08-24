import { useCallback, useMemo } from 'react';
import { usePolling } from './usePolling';

/**
 * Gom toàn bộ dữ liệu vận hành về một chỗ.
 *
 * Trước đây mỗi component tự poll → cùng một endpoint bị gọi nhiều lần và các
 * panel lệch pha nhau (bảng đã cập nhật nhưng bản đồ thì chưa). Giờ trang cha
 * gọi hook này rồi truyền dữ liệu xuống, các component con thuần hiển thị.
 */
export function useOpsData() {
  const stats = usePolling('/api/admin/stats', 10000);
  const cases = usePolling('/api/admin/cases', 10000);
  const clusters = usePolling('/api/admin/case-clusters', 15000);
  const volunteers = usePolling('/api/volunteers', 15000);
  const volunteerLocations = usePolling('/api/volunteers/locations', 15000);

  const { refresh: refreshStats } = stats;
  const { refresh: refreshCases } = cases;
  const { refresh: refreshClusters } = clusters;
  const { refresh: refreshVolunteers } = volunteers;
  const { refresh: refreshVolunteerLocations } = volunteerLocations;

  const refreshAll = useCallback(
    () =>
      Promise.all([
        refreshStats(),
        refreshCases(),
        refreshClusters(),
        refreshVolunteers(),
        refreshVolunteerLocations(),
      ]),
    [refreshStats, refreshCases, refreshClusters, refreshVolunteers, refreshVolunteerLocations],
  );

  const metrics = useMemo(() => {
    const s = stats.data;
    if (!s) return null;
    const num = (v) => parseInt(v ?? 0, 10) || 0;

    const pending = num(s.cases?.pending_count);
    const responding = num(s.cases?.responding_count);
    const onScene = num(s.cases?.on_scene_count);
    const resolved = num(s.cases?.resolved_count);
    const totalVolunteers = num(s.volunteers?.total_volunteers);
    const availableVolunteers = num(s.volunteers?.available_count);

    return {
      pending,
      responding,
      onScene,
      resolved,
      activeSos: pending + responding + onScene,
      totalVolunteers,
      availableVolunteers,
      deployedVolunteers: Math.max(0, totalVolunteers - availableVolunteers),
    };
  }, [stats.data]);

  // Ca chưa đóng, ưu tiên khẩn cấp cao rồi tới chờ lâu nhất
  const activeCases = useMemo(() => {
    const list = (cases.data || []).filter((c) => c.status !== 'resolved');
    return list.sort(
      (a, b) =>
        (b.urgency_level ?? 0) - (a.urgency_level ?? 0) ||
        (b.minutes_waiting ?? 0) - (a.minutes_waiting ?? 0),
    );
  }, [cases.data]);

  const error =
    stats.error || cases.error || clusters.error || volunteers.error || volunteerLocations.error || null;

  return {
    metrics,
    statsLoading: stats.loading,

    allCases: cases.data || [],
    activeCases,
    casesLoading: cases.loading,

    clusters: clusters.data || [],
    volunteers: volunteers.data || [],
    volunteersLoading: volunteers.loading,
    volunteerLocations: volunteerLocations.data || [],

    error,
    refreshAll,
  };
}
