import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

// ═══════════════════════════════════════════════════════════
// VOLUNTEER HISTORY SCREEN — Lịch sử ca cứu trợ dành cho TNV
// Khác biệt so với Victim:
//   • Hero Stats Card (tổng ca, km, thời gian phản hồi TB)
//   • Mini Timeline mỗi card (nhận ca → hoàn thành)
//   • Hiển thị khoảng cách ban đầu (initial_distance_m)
//   • Response Time KPI
//   • Phân biệt completed vs revoked
//   • Blue primary tone (thành tích) thay vì SOS red
// ═══════════════════════════════════════════════════════════

// --- ASSIGNMENT STATUS ---
enum AssignmentStatus { completed, revoked, active }

AssignmentStatus _parseAssignmentStatus(String? raw) {
  switch (raw) {
    case 'completed':
      return AssignmentStatus.completed;
    case 'revoked':
      return AssignmentStatus.revoked;
    case 'active':
      return AssignmentStatus.active;
    default:
      return AssignmentStatus.active;
  }
}

// --- DATA MODEL ---
class VolunteerMission {
  final String caseId;
  final String caseStatus;
  final AssignmentStatus assignmentStatus;
  final int urgencyLevel;
  final List<String> tags;
  final String summary;
  final String description;
  final int? initialDistanceM;
  final DateTime? assignedAt;
  final DateTime? completedAt;
  final DateTime? revokedAt;
  final DateTime? caseCreatedAt;
  final DateTime? caseResolvedAt;
  final double? lat;
  final double? lon;
  final int? responseTimeMin;

  VolunteerMission({
    required this.caseId,
    required this.caseStatus,
    required this.assignmentStatus,
    required this.urgencyLevel,
    required this.tags,
    required this.summary,
    required this.description,
    this.initialDistanceM,
    this.assignedAt,
    this.completedAt,
    this.revokedAt,
    this.caseCreatedAt,
    this.caseResolvedAt,
    this.lat,
    this.lon,
    this.responseTimeMin,
  });

  factory VolunteerMission.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'];
    List<String> parsedTags = [];
    if (rawTags is List) {
      parsedTags = rawTags.map((e) => e.toString()).toList();
    }

    return VolunteerMission(
      caseId: json['case_id'] ?? '',
      caseStatus: json['case_status'] ?? '',
      assignmentStatus: _parseAssignmentStatus(json['assignment_status']),
      urgencyLevel: json['urgency_level'] ?? 3,
      tags: parsedTags,
      summary: json['summary'] ?? '',
      description: json['description'] ?? '',
      initialDistanceM: json['initial_distance_m'],
      assignedAt: json['assigned_at'] != null ? DateTime.tryParse(json['assigned_at'])?.toLocal() : null,
      completedAt: json['completed_at'] != null ? DateTime.tryParse(json['completed_at'])?.toLocal() : null,
      revokedAt: json['revoked_at'] != null ? DateTime.tryParse(json['revoked_at'])?.toLocal() : null,
      caseCreatedAt: json['case_created_at'] != null ? DateTime.tryParse(json['case_created_at'])?.toLocal() : null,
      caseResolvedAt: json['case_resolved_at'] != null ? DateTime.tryParse(json['case_resolved_at'])?.toLocal() : null,
      lat: (json['lat'] as num?)?.toDouble(),
      lon: (json['lon'] as num?)?.toDouble(),
      responseTimeMin: json['response_time_min'],
    );
  }
}

class VolunteerStats {
  final int totalMissions;
  final int completed;
  final int revoked;
  final double totalDistanceKm;
  final int avgResponseTimeMin;

  VolunteerStats({
    required this.totalMissions,
    required this.completed,
    required this.revoked,
    required this.totalDistanceKm,
    required this.avgResponseTimeMin,
  });

  factory VolunteerStats.fromJson(Map<String, dynamic> json) {
    return VolunteerStats(
      totalMissions: json['total_missions'] ?? 0,
      completed: json['completed'] ?? 0,
      revoked: json['revoked'] ?? 0,
      totalDistanceKm: (json['total_distance_km'] as num?)?.toDouble() ?? 0.0,
      avgResponseTimeMin: json['avg_response_time_min'] ?? 0,
    );
  }
}

// Tag display mapping
const Map<String, String> _tagLabels = {
  'y_te': 'Y tế',
  'tre_em': 'Trẻ em',
  'nguoi_gia': 'Người già',
  'ngap_noc': 'Ngập nóc',
  'phuong_tien': 'Cần thuyền',
};

// ═══════════════════════════════════════════════════════════
// SCREEN
// ═══════════════════════════════════════════════════════════

class VolunteerHistoryScreen extends StatefulWidget {
  final String volunteerId;
  const VolunteerHistoryScreen({super.key, required this.volunteerId});

  @override
  State<VolunteerHistoryScreen> createState() => _VolunteerHistoryScreenState();
}

class _VolunteerHistoryScreenState extends State<VolunteerHistoryScreen> with SingleTickerProviderStateMixin {
  String _selectedFilter = 'Tất cả';
  final List<String> _filters = ['Tất cả', 'Hoàn thành', 'Đã hủy'];

  bool _isLoading = true;
  List<VolunteerMission> _allMissions = [];
  VolunteerStats? _stats;

  late AnimationController _statsAnimController;
  late Animation<double> _statsSlideAnim;
  late Animation<double> _statsFadeAnim;

  @override
  void initState() {
    super.initState();
    _statsAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _statsSlideAnim = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _statsAnimController, curve: Curves.easeOutCubic),
    );
    _statsFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _statsAnimController, curve: Curves.easeOut),
    );
    _loadHistory();
  }

  @override
  void dispose() {
    _statsAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getVolunteerHistory(widget.volunteerId);
      if (data != null) {
        final statsJson = data['stats'] as Map<String, dynamic>? ?? {};
        final missionsJson = data['missions'] as List<dynamic>? ?? [];
        _stats = VolunteerStats.fromJson(statsJson);
        _allMissions = missionsJson.map((json) => VolunteerMission.fromJson(json as Map<String, dynamic>)).toList();
        _statsAnimController.forward(from: 0);
      }
    } catch (e) {
      debugPrint('[VolunteerHistoryScreen] load error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  List<VolunteerMission> get _filteredMissions {
    if (_selectedFilter == 'Tất cả') return _allMissions;
    if (_selectedFilter == 'Hoàn thành') {
      return _allMissions.where((m) => m.assignmentStatus == AssignmentStatus.completed).toList();
    }
    if (_selectedFilter == 'Đã hủy') {
      return _allMissions.where((m) => m.assignmentStatus == AssignmentStatus.revoked).toList();
    }
    return _allMissions;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : RefreshIndicator(
                      onRefresh: _loadHistory,
                      color: AppColors.primary,
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          // Hero Stats Card
                          if (_stats != null)
                            SliverToBoxAdapter(child: _buildHeroStatsCard(_stats!)),

                          // Filter Chips
                          SliverToBoxAdapter(child: _buildFilters()),

                          // Mission Cards
                          if (_filteredMissions.isEmpty)
                            SliverFillRemaining(child: _buildEmptyState())
                          else
                            SliverPadding(
                              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) => _buildMissionCard(_filteredMissions[index]),
                                  childCount: _filteredMissions.length,
                                ),
                              ),
                            ),

                          // Bottom padding
                          SliverToBoxAdapter(child: SizedBox(height: 24.h)),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // APP BAR
  // ─────────────────────────────────────────
  Widget _buildAppBar() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
      child: Row(
        children: [
          IconButton(
            icon: Icon(LucideIcons.chevronLeft, color: AppColors.textPrimary, size: 26.r),
            onPressed: () => Navigator.pop(context),
          ),
          SizedBox(width: 4.w),
          Expanded(
            child: Text(
              'Lịch sử cứu trợ',
              style: AppTypography.headingLarge.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          // Badge count
          if (_stats != null)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Text(
                '${_stats!.totalMissions} ca',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.sp,
                ),
              ),
            ),
          SizedBox(width: 8.w),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // HERO STATS CARD — Đặc trưng TNV (Victim không có)
  // ─────────────────────────────────────────
  Widget _buildHeroStatsCard(VolunteerStats stats) {
    return AnimatedBuilder(
      animation: _statsAnimController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _statsSlideAnim.value),
          child: Opacity(
            opacity: _statsFadeAnim.value,
            child: child,
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1565C0), // Deep Blue
              Color(0xFF1E88E5), // Primary Blue
              Color(0xFF42A5F5), // Light Blue
            ],
          ),
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 20.r,
              offset: Offset(0, 8.h),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(LucideIcons.trophy, color: Colors.white, size: 20.r),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Thành tích cứu trợ',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        '${stats.completed} ca hoàn thành',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),

            // Stats Grid — 3 columns
            Container(
              padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 4.w),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: Row(
                children: [
                  _buildStatCell(
                    icon: LucideIcons.mapPin,
                    value: '${stats.totalDistanceKm}',
                    unit: 'km',
                    label: 'Tổng quãng đường',
                  ),
                  _buildStatDivider(),
                  _buildStatCell(
                    icon: LucideIcons.zap,
                    value: '${stats.avgResponseTimeMin}',
                    unit: 'phút',
                    label: 'Phản hồi TB',
                  ),
                  _buildStatDivider(),
                  _buildStatCell(
                    icon: LucideIcons.xCircle,
                    value: '${stats.revoked}',
                    unit: 'ca',
                    label: 'Đã hủy',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCell({
    required IconData icon,
    required String value,
    required String unit,
    required String label,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 16.r),
          SizedBox(height: 6.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: 1.h, left: 2.w),
                child: Text(
                  unit,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 10.sp,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 40.h,
      color: Colors.white.withValues(alpha: 0.2),
    );
  }

  // ─────────────────────────────────────────
  // FILTER CHIPS
  // ─────────────────────────────────────────
  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      child: Row(
        children: _filters.map((filter) {
          final isSelected = filter == _selectedFilter;
          return Padding(
            padding: EdgeInsets.only(right: 8.w),
            child: GestureDetector(
              onTap: () => setState(() => _selectedFilter = filter),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.white,
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.surfaceBorder,
                  ),
                  borderRadius: BorderRadius.circular(20.r),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            blurRadius: 8.r,
                            offset: Offset(0, 2.h),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  filter,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 14.sp,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─────────────────────────────────────────
  // MISSION CARD — Trọng tâm UI
  // ─────────────────────────────────────────
  Widget _buildMissionCard(VolunteerMission mission) {
    final isCompleted = mission.assignmentStatus == AssignmentStatus.completed;
    final isRevoked = mission.assignmentStatus == AssignmentStatus.revoked;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.surfaceBorder.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Color bar top ──
          Container(
            height: 3.h,
            decoration: BoxDecoration(
              color: isCompleted
                  ? AppColors.success
                  : isRevoked
                      ? const Color(0xFFF59E0B)
                      : AppColors.primary,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
            ),
          ),

          // ── Header: ID + Status Badge ──
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.hash, size: 14.r, color: AppColors.textMuted),
                    SizedBox(width: 4.w),
                    Text(
                      mission.caseId.length > 8
                          ? mission.caseId.substring(0, 8).toUpperCase()
                          : mission.caseId,
                      style: AppTypography.mono.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        fontSize: 13.sp,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    _buildUrgencyBadge(mission.urgencyLevel),
                  ],
                ),
                _buildAssignmentStatusBadge(mission.assignmentStatus),
              ],
            ),
          ),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Divider(height: 20.h, color: const Color(0xFFF0F0F0)),
          ),

          // ── Body: Summary + Metrics ──
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary
                if (mission.summary.isNotEmpty)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(LucideIcons.fileText, size: 16.r, color: AppColors.textMuted),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Text(
                          mission.summary,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                SizedBox(height: 12.h),

                // ── Metrics Row: Khoảng cách + Phản hồi ──
                Row(
                  children: [
                    if (mission.initialDistanceM != null) ...[
                      _buildMetricChip(
                        icon: LucideIcons.mapPin,
                        label: _formatDistance(mission.initialDistanceM!),
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 8.w),
                    ],
                    if (mission.responseTimeMin != null)
                      _buildMetricChip(
                        icon: LucideIcons.zap,
                        label: '${mission.responseTimeMin} phút phản hồi',
                        color: const Color(0xFFF59E0B),
                      ),
                  ],
                ),
                SizedBox(height: 12.h),

                // ── Tags ──
                if (mission.tags.isNotEmpty) ...[
                  Wrap(
                    spacing: 6.w,
                    runSpacing: 6.h,
                    children: mission.tags.map((tag) {
                      final label = _tagLabels[tag] ?? tag;
                      Color bgColor = Colors.grey.shade100;
                      Color textColor = Colors.grey.shade700;
                      if (label.toLowerCase().contains('trẻ em') || label.toLowerCase().contains('người già')) {
                        bgColor = AppColors.alertRed.withValues(alpha: 0.1);
                        textColor = AppColors.alertRed;
                      } else if (label.toLowerCase().contains('y tế')) {
                        bgColor = Colors.blue.withValues(alpha: 0.1);
                        textColor = Colors.blue;
                      }
                      return Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Text(
                          label,
                          style: AppTypography.bodySmall.copyWith(
                            color: textColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 11.sp,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 12.h),
                ],
              ],
            ),
          ),

          // ── Footer: Mini Timeline ──
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(16.r),
                bottomRight: Radius.circular(16.r),
              ),
            ),
            child: _buildMiniTimeline(mission),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // MINI TIMELINE — Đặc trưng TNV (Victim không có)
  // ─────────────────────────────────────────
  Widget _buildMiniTimeline(VolunteerMission mission) {
    final isCompleted = mission.assignmentStatus == AssignmentStatus.completed;
    final isRevoked = mission.assignmentStatus == AssignmentStatus.revoked;

    return Column(
      children: [
        // Step 1: Nhận ca
        _buildTimelineStep(
          icon: LucideIcons.logIn,
          iconColor: AppColors.primary,
          label: 'Nhận ca',
          time: mission.assignedAt,
          isFirst: true,
          isLast: false,
          lineColor: isCompleted ? AppColors.success : const Color(0xFFF59E0B),
        ),
        // Step 2: Hoàn thành / Đã hủy
        if (isCompleted)
          _buildTimelineStep(
            icon: LucideIcons.checkCircle2,
            iconColor: AppColors.success,
            label: 'Hoàn thành',
            time: mission.completedAt ?? mission.caseResolvedAt,
            isFirst: false,
            isLast: true,
            lineColor: AppColors.success,
          )
        else if (isRevoked)
          _buildTimelineStep(
            icon: LucideIcons.xCircle,
            iconColor: const Color(0xFFF59E0B),
            label: 'Đã hủy nhiệm vụ',
            time: mission.revokedAt,
            isFirst: false,
            isLast: true,
            lineColor: const Color(0xFFF59E0B),
          )
        else
          _buildTimelineStep(
            icon: LucideIcons.loader,
            iconColor: AppColors.primary,
            label: 'Đang thực hiện',
            time: null,
            isFirst: false,
            isLast: true,
            lineColor: AppColors.primary,
          ),
      ],
    );
  }

  Widget _buildTimelineStep({
    required IconData icon,
    required Color iconColor,
    required String label,
    required DateTime? time,
    required bool isFirst,
    required bool isLast,
    required Color lineColor,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline dot + line
          SizedBox(
            width: 28.w,
            child: Column(
              children: [
                Container(
                  width: 20.w,
                  height: 20.w,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: iconColor, width: 1.5.w),
                  ),
                  child: Icon(icon, size: 10.r, color: iconColor),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5.w,
                      color: lineColor.withValues(alpha: 0.3),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    time != null ? _formatDateTime(time) : '...',
                    style: AppTypography.mono.copyWith(
                      fontSize: 12.sp,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // BADGES
  // ─────────────────────────────────────────
  Widget _buildAssignmentStatusBadge(AssignmentStatus status) {
    Color bgColor;
    Color textColor;
    String label;
    IconData icon;

    switch (status) {
      case AssignmentStatus.completed:
        bgColor = const Color(0xFFDCFCE7);
        textColor = const Color(0xFF16A34A);
        label = 'Hoàn thành';
        icon = LucideIcons.checkCircle2;
        break;
      case AssignmentStatus.revoked:
        bgColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFFD97706);
        label = 'Đã hủy';
        icon = LucideIcons.xCircle;
        break;
      case AssignmentStatus.active:
        bgColor = const Color(0xFFDBEAFE);
        textColor = const Color(0xFF2563EB);
        label = 'Đang thực hiện';
        icon = LucideIcons.loader;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.r, color: textColor),
          SizedBox(width: 4.w),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrgencyBadge(int level) {
    Color color;
    String label;
    switch (level) {
      case 5:
        color = AppColors.urgency5;
        label = 'MỨC 5';
        break;
      case 4:
        color = AppColors.urgency4;
        label = 'MỨC 4';
        break;
      case 3:
        color = AppColors.urgency3;
        label = 'MỨC 3';
        break;
      case 2:
        color = AppColors.urgency2;
        label = 'MỨC 2';
        break;
      default:
        color = AppColors.urgency1;
        label = 'MỨC 1';
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // METRIC CHIP — Khoảng cách & Response time
  // ─────────────────────────────────────────
  Widget _buildMetricChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13.r, color: color),
          SizedBox(width: 5.w),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // EMPTY STATE
  // ─────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20.r,
                ),
              ],
            ),
            child: Icon(LucideIcons.history, size: 48.r, color: AppColors.textMuted),
          ),
          SizedBox(height: 24.h),
          Text(
            'Chưa có ca cứu trợ nào',
            style: AppTypography.headingMedium.copyWith(color: AppColors.textPrimary),
          ),
          SizedBox(height: 8.h),
          Text(
            _selectedFilter == 'Tất cả'
                ? 'Bạn chưa tham gia ca cứu trợ nào.'
                : 'Không có ca nào trong danh mục "$_selectedFilter".',
            style: AppTypography.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────
  String _formatDateTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$hour:$minute · $day/$month/${date.year}';
  }

  String _formatDistance(int meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters}m';
  }
}
