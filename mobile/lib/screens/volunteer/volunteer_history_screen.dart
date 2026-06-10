import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

// ═══════════════════════════════════════════════════════════
// VOLUNTEER HISTORY SCREEN — Anti-SLOP / Premium Linear Aesthetic
// ═══════════════════════════════════════════════════════════

enum AssignmentStatus { completed, revoked, active }

AssignmentStatus _parseAssignmentStatus(String? raw) {
  switch (raw) {
    case 'completed': return AssignmentStatus.completed;
    case 'revoked': return AssignmentStatus.revoked;
    case 'active': return AssignmentStatus.active;
    default: return AssignmentStatus.active;
  }
}

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
    if (rawTags is List) parsedTags = rawTags.map((e) => e.toString()).toList();

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

const Map<String, String> _tagLabels = {
  'y_te': 'Y TẾ',
  'tre_em': 'TRẺ EM',
  'nguoi_gia': 'NGƯỜI GIÀ',
  'ngap_noc': 'NGẬP NÓC',
  'phuong_tien': 'THUYỀN',
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

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _loadHistory();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getVolunteerHistory(widget.volunteerId);
      if (data != null) {
        _stats = VolunteerStats.fromJson(data['stats'] ?? {});
        _allMissions = (data['missions'] as List? ?? []).map((j) => VolunteerMission.fromJson(j)).toList();
        _animController.forward(from: 0);
      }
    } catch (e) {
      debugPrint('[VolunteerHistoryScreen] load error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  List<VolunteerMission> get _filteredMissions {
    if (_selectedFilter == 'Tất cả') return _allMissions;
    if (_selectedFilter == 'Hoàn thành') return _allMissions.where((m) => m.assignmentStatus == AssignmentStatus.completed).toList();
    if (_selectedFilter == 'Đã hủy') return _allMissions.where((m) => m.assignmentStatus == AssignmentStatus.revoked).toList();
    return _allMissions;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA), // Crisp light background
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF111111)))
                  : RefreshIndicator(
                      onRefresh: _loadHistory,
                      color: const Color(0xFF111111),
                      backgroundColor: Colors.white,
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          if (_stats != null) SliverToBoxAdapter(child: _buildBespokeHeroCard(_stats!)),
                          SliverToBoxAdapter(child: _buildMinimalFilters()),
                          if (_filteredMissions.isEmpty)
                            SliverFillRemaining(child: _buildEmptyState())
                          else
                            SliverPadding(
                              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) => _buildMinimalMissionCard(_filteredMissions[index]),
                                  childCount: _filteredMissions.length,
                                ),
                              ),
                            ),
                          SliverToBoxAdapter(child: SizedBox(height: 32.h)),
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
  // MINIMAL HEADER
  // ─────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(8.w, 12.h, 16.w, 12.h),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFA),
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(LucideIcons.arrowLeft, color: const Color(0xFF111111), size: 24.r),
            onPressed: () => Navigator.pop(context),
            splashRadius: 24.r,
          ),
          SizedBox(width: 8.w),
          Text(
            'Lịch sử cứu trợ',
            style: AppTypography.headingLarge.copyWith(
              color: const Color(0xFF111111),
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          if (_stats != null)
            Text(
              '${_stats!.totalMissions} CA',
              style: AppTypography.labelMedium.copyWith(
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF666666),
                letterSpacing: 1.2,
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // BESPOKE HERO CARD (Anti-Slop Dark Mode Vercel Style)
  // ─────────────────────────────────────────
  Widget _buildBespokeHeroCard(VolunteerStats stats) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        margin: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 16.h),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A), // Deep brutalist black
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: const Color(0xFF222222), width: 1),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF000000).withValues(alpha: 0.1),
              blurRadius: 30.r,
              offset: Offset(0, 10.h),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16.r),
          child: Stack(
            children: [
              // Subtle top-right glow for premium feel without being "slop"
              Positioned(
                right: -40.w,
                top: -40.h,
                child: Container(
                  width: 120.w,
                  height: 120.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.03),
                    backgroundBlendMode: BlendMode.screen,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(24.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TỔNG QUAN THÀNH TÍCH',
                      style: AppTypography.labelMedium.copyWith(
                        color: const Color(0xFF888888),
                        fontSize: 10.sp,
                        letterSpacing: 2.0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 24.h),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${stats.completed}',
                          style: AppTypography.displayLarge.copyWith(
                            color: Colors.white,
                            fontSize: 48.sp,
                            height: 1.0,
                            letterSpacing: -2.0,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Padding(
                          padding: EdgeInsets.only(bottom: 6.h),
                          child: Text(
                            'ca hoàn thành',
                            style: AppTypography.bodyMedium.copyWith(
                              color: const Color(0xFFAAAAAA),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 32.h),
                    // Divider
                    Container(height: 1, color: const Color(0xFF222222)),
                    SizedBox(height: 20.h),
                    Row(
                      children: [
                        _buildHeroMetric('QUÃNG ĐƯỜNG', '${stats.totalDistanceKm} km'),
                        _buildHeroMetric('ĐÃ HỦY', '${stats.revoked}', isDanger: true),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroMetric(String label, String value, {bool isDanger = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.labelMedium.copyWith(
              color: const Color(0xFF666666),
              fontSize: 10.sp,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            value,
            style: AppTypography.labelMedium.copyWith(
              color: isDanger ? const Color(0xFFEF4444) : const Color(0xFFEFEFEF),
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // MINIMAL FILTERS
  // ─────────────────────────────────────────
  Widget _buildMinimalFilters() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(
        children: _filters.map((filter) {
          final isSelected = filter == _selectedFilter;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = filter),
            child: Container(
              margin: EdgeInsets.only(right: 8.w),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF111111) : Colors.transparent,
                borderRadius: BorderRadius.circular(8.r), // Sharp 8px radius
                border: Border.all(
                  color: isSelected ? const Color(0xFF111111) : const Color(0xFFE5E5E5),
                ),
              ),
              child: Text(
                filter,
                style: AppTypography.bodyMedium.copyWith(
                  color: isSelected ? Colors.white : const Color(0xFF666666),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 13.sp,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─────────────────────────────────────────
  // LINEAR MISSION CARD
  // ─────────────────────────────────────────
  Widget _buildMinimalMissionCard(VolunteerMission mission) {
    final isCompleted = mission.assignmentStatus == AssignmentStatus.completed;
    final isRevoked = mission.assignmentStatus == AssignmentStatus.revoked;

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE5E5E5), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.02),
            blurRadius: 10.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top Header Section ──
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '#${mission.caseId.length > 8 ? mission.caseId.substring(0, 8).toUpperCase() : mission.caseId}',
                          style: AppTypography.labelMedium.copyWith(
                            color: const Color(0xFF888888),
                            fontWeight: FontWeight.w700,
                            fontSize: 12.sp,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        _buildSeverityDot(mission.urgencyLevel),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    SizedBox(
                      width: 200.w, // Limit width to allow badge on right
                      child: Text(
                        mission.summary.isEmpty ? 'Không có mô tả' : mission.summary,
                        style: AppTypography.headingMedium.copyWith(
                          color: const Color(0xFF111111),
                          fontSize: 15.sp,
                          height: 1.4,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                _buildStatusPill(mission.assignmentStatus),
              ],
            ),
          ),

          // ── Data Row (Metrics + Tags) ──
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
            child: Row(
              children: [
                if (mission.initialDistanceM != null) ...[
                  _buildDataPoint(LucideIcons.mapPin, _formatDistance(mission.initialDistanceM!)),
                  SizedBox(width: 16.w),
                ],
              ],
            ),
          ),

          // ── Tags ──
          if (mission.tags.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
              child: Wrap(
                spacing: 6.w,
                runSpacing: 6.h,
                children: mission.tags.map((tag) {
                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(4.r), // Sharp corners for tags
                      border: Border.all(color: const Color(0xFFEEEEEE)),
                    ),
                    child: Text(
                      _tagLabels[tag] ?? tag.toUpperCase(),
                      style: AppTypography.labelMedium.copyWith(
                        color: const Color(0xFF666666),
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          // ── Minimal Timeline ──
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: const BoxDecoration(
              color: Color(0xFFFAFAFA),
              border: Border(top: BorderSide(color: Color(0xFFE5E5E5), width: 1)),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(11)),
            ),
            child: _buildLinearTimeline(mission, isCompleted, isRevoked),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // LINEAR TIMELINE (Bespoke Node Design)
  // ─────────────────────────────────────────
  Widget _buildLinearTimeline(VolunteerMission mission, bool isCompleted, bool isRevoked) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Start Node
        _buildTimelineNode(
          label: 'NHẬN CA',
          time: mission.assignedAt,
          isActive: true,
          color: const Color(0xFF111111),
        ),
        
        // Connector Line
        Expanded(
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 12.w),
            height: 1,
            color: isCompleted ? const Color(0xFF10B981) : (isRevoked ? const Color(0xFFEF4444) : const Color(0xFFE5E5E5)),
          ),
        ),
        
        // End Node
        _buildTimelineNode(
          label: isCompleted ? 'HOÀN THÀNH' : (isRevoked ? 'ĐÃ HỦY' : 'ĐANG XỬ LÝ'),
          time: isCompleted ? (mission.completedAt ?? mission.caseResolvedAt) : mission.revokedAt,
          isActive: isCompleted || isRevoked,
          color: isCompleted ? const Color(0xFF10B981) : (isRevoked ? const Color(0xFFEF4444) : const Color(0xFF999999)),
          alignRight: true,
        ),
      ],
    );
  }

  Widget _buildTimelineNode({
    required String label,
    required DateTime? time,
    required bool isActive,
    required Color color,
    bool alignRight = false,
  }) {
    return Column(
      crossAxisAlignment: alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!alignRight) ...[
              Container(
                width: 6.r, height: 6.r,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              SizedBox(width: 6.w),
            ],
            Text(
              label,
              style: AppTypography.labelMedium.copyWith(
                fontSize: 10.sp,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 1.0,
              ),
            ),
            if (alignRight) ...[
              SizedBox(width: 6.w),
              Container(
                width: 6.r, height: 6.r,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ],
          ],
        ),
        SizedBox(height: 4.h),
        Text(
          time != null ? _formatDateTime(time) : '--:--',
          style: AppTypography.labelMedium.copyWith(
            fontSize: 11.sp,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF888888),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────
  // UI HELPERS (Badges & Data Points)
  // ─────────────────────────────────────────
  Widget _buildSeverityDot(int level) {
    Color color;
    switch (level) {
      case 5: color = const Color(0xFFB91C1C); break;
      case 4: color = const Color(0xFFEF4444); break;
      case 3: color = const Color(0xFFF97316); break;
      case 2: color = const Color(0xFFEAB308); break;
      default: color = const Color(0xFF22C55E); break;
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Text(
        'MỨC $level',
        style: AppTypography.labelMedium.copyWith(
          color: color,
          fontSize: 11.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildStatusPill(AssignmentStatus status) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case AssignmentStatus.completed:
        bgColor = const Color(0xFFECFDF5); // emerald-50
        textColor = const Color(0xFF10B981); // emerald-500
        label = 'Hoàn thành';
        break;
      case AssignmentStatus.revoked:
        bgColor = const Color(0xFFFEF2F2); // red-50
        textColor = const Color(0xFFEF4444); // red-500
        label = 'Đã hủy';
        break;
      case AssignmentStatus.active:
        bgColor = const Color(0xFFEFF6FF); // blue-50
        textColor = const Color(0xFF3B82F6); // blue-500
        label = 'Đang xử lý';
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(99.r),
        border: Border.all(color: textColor.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: AppTypography.bodySmall.copyWith(
          color: textColor,
          fontSize: 11.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDataPoint(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14.r, color: const Color(0xFF999999)),
        SizedBox(width: 4.w),
        Text(
          text,
          style: AppTypography.labelMedium.copyWith(
            color: const Color(0xFF666666),
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────
  // EMPTY STATE & FORMATTING
  // ─────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.ghost, size: 48.r, color: const Color(0xFFDDDDDD)),
          SizedBox(height: 16.h),
          Text(
            'CHƯA CÓ DỮ LIỆU',
            style: AppTypography.labelMedium.copyWith(
              color: const Color(0xFF111111),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            _selectedFilter == 'Tất cả'
                ? 'Bạn chưa có dữ liệu cứu trợ.'
                : 'Không có ca nào khớp với "$_selectedFilter".',
            style: AppTypography.bodyMedium.copyWith(color: const Color(0xFF888888)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$hour:$minute · $day/$month';
  }

  String _formatDistance(int meters) {
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)}km';
    return '${meters}m';
  }
}
