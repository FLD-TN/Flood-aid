import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../widgets/map_widget.dart';
import 'active_mission_screen.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class VolunteerHomeScreen extends StatefulWidget {
  const VolunteerHomeScreen({super.key});

  @override
  State<VolunteerHomeScreen> createState() => _VolunteerHomeScreenState();
}

class _VolunteerHomeScreenState extends State<VolunteerHomeScreen> {
  Timer? _pollTimer;
  List<Map<String, dynamic>> _cases = [];
  bool _isLoading = true;

  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  @override
  void initState() {
    super.initState();
    _fetchCases();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _fetchCases();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _sheetController.dispose();
    super.dispose();
  }

  Future<void> _fetchCases() async {
    final cases = await ApiService.getCases();
    if (mounted) {
      setState(() {
        _cases = cases;
        _isLoading = false;
      });
    }
  }

  // Lọc ra các case chưa resolved
  List<Map<String, dynamic>> get _activeCases {
    return _cases.where((c) {
      final status = c['status'] ?? '';
      return status == 'pending' || status == 'responding';
    }).toList();
  }

  Color _getUrgencyColor(int level) {
    switch (level) {
      case 5: return AppColors.urgency5;
      case 4: return AppColors.urgency4;
      case 3: return AppColors.urgency3;
      case 2: return AppColors.urgency2;
      default: return AppColors.urgency1;
    }
  }

  String _getUrgencyLabel(int level) {
    switch (level) {
      case 5: return 'CỰC KỲ NGUY HIỂM';
      case 4: return 'KHẨN CẤP';
      case 3: return 'CẦN HỖ TRỢ';
      case 2: return 'ƯU TIÊN THẤP';
      default: return 'THÔNG TIN';
    }
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];
    for (final c in _activeCases) {
      final lat = c['lat'];
      final lon = c['lon'];
      if (lat == null || lon == null) continue;

      final urgency = (c['urgency_level'] as num?)?.toInt() ?? 2;
      final color = _getUrgencyColor(urgency);

      markers.add(
        Marker(
          point: LatLng((lat as num).toDouble(), (lon as num).toDouble()),
          width: 100,
          height: 80,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.5),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '!',
                    style: const TextStyle(
                      color: Colors.white, fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  c['ai_summary'] != null
                      ? (c['ai_summary'] as String).length > 20
                          ? '${(c['ai_summary'] as String).substring(0, 20)}...'
                          : c['ai_summary'] as String
                      : 'SOS',
                  style: const TextStyle(
                    color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Stack(
                children: [
                  // ── Map (full area) ──
                  FloodAidMap(
                    initialCenter: LatLng(16.0544, 108.2022),
                    initialZoom: 11.0,
                    markers: _buildMarkers(),
                  ),
                  // ── Mode Pill ──
                  _buildModePill(),
                  // ── Draggable Bottom Sheet ──
                  _buildDraggableSheet(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          ),
          const Spacer(),
          Text(
            'Cứu Hộ Miền Trung',
            style: AppTypography.headingMedium.copyWith(
              color: AppColors.alertRed,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Text(
                'Live',
                style: AppTypography.caption.copyWith(
                  color: AppColors.alertRed,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.alertRed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModePill() {
    return Positioned(
      top: 16,
      left: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.volunteer_activism, color: AppColors.primary, size: 16),
            const SizedBox(width: 6),
            Text(
              'Chế độ: Tình nguyện viên',
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDraggableSheet() {
    final pendingCases = _activeCases.where((c) => c['status'] == 'pending').toList();

    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.42,
      minChildSize: 0.08,
      maxChildSize: 0.75,
      snap: true,
      snapSizes: const [0.08, 0.42, 0.75],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              // ── Header (always visible) ──
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    // Drag handle
                    Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Collapsed mini-header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Yêu cầu cứu trợ',
                            style: AppTypography.headingMedium.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.alertRed,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${pendingCases.length} chờ xử lý',
                                  style: const TextStyle(
                                    color: Colors.white, fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.keyboard_arrow_up, color: AppColors.textMuted, size: 20),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                  ],
                ),
              ),

              // ── Case List ──
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                )
              else if (_activeCases.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline, size: 48, color: AppColors.success.withOpacity(0.5)),
                        const SizedBox(height: 12),
                        Text(
                          'Chưa có ca SOS nào',
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final c = _activeCases[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildRequestCard(c),
                        );
                      },
                      childCount: _activeCases.length,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> caseData) {
    final urgency = (caseData['urgency_level'] as num?)?.toInt() ?? 2;
    final color = _getUrgencyColor(urgency);
    final label = _getUrgencyLabel(urgency);
    final summary = caseData['ai_summary'] as String? ?? caseData['description'] as String? ?? 'Yêu cầu cứu trợ';
    final status = caseData['status'] as String? ?? 'pending';
    final caseId = caseData['id']?.toString() ?? '';
    final createdAt = caseData['created_at'] as String?;

    String timeAgo = '';
    if (createdAt != null) {
      try {
        final dt = DateTime.parse(createdAt);
        final diff = DateTime.now().difference(dt);
        if (diff.inMinutes < 60) {
          timeAgo = '${diff.inMinutes} phút trước';
        } else {
          timeAgo = '${diff.inHours} giờ trước';
        }
      } catch (_) {}
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 2),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white, fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (timeAgo.isNotEmpty) ...[
                const SizedBox(width: 8),
                Icon(Icons.schedule, size: 12, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(timeAgo, style: AppTypography.caption),
              ],
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: status == 'pending'
                      ? AppColors.statusPending.withOpacity(0.1)
                      : AppColors.statusResponding.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  status == 'pending' ? 'Chờ' : 'Đang xử lý',
                  style: AppTypography.caption.copyWith(
                    color: status == 'pending'
                        ? AppColors.statusPending
                        : AppColors.statusResponding,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            summary,
            style: AppTypography.bodyLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ActiveMissionScreen(
                          caseId: caseId,
                          victimLat: (caseData['lat'] as num?)?.toDouble(),
                          victimLon: (caseData['lon'] as num?)?.toDouble(),
                          summary: summary,
                          urgencyLevel: urgency,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.person, color: Colors.white, size: 18),
                  label: const Text(
                    'Tôi sẽ đi cứu',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
