import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/local_notification_service.dart';
import '../../widgets/map_widget.dart';
import '../../widgets/sos_legend_widget.dart';
import '../../widgets/filter_bottom_sheet.dart';
import 'active_mission_screen.dart';
import 'volunteer_phone_screen.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

class VolunteerHomeScreen extends StatefulWidget {
  const VolunteerHomeScreen({super.key});

  @override
  State<VolunteerHomeScreen> createState() => _VolunteerHomeScreenState();
}

class _VolunteerHomeScreenState extends State<VolunteerHomeScreen> {
  Timer? _pollTimer;
  List<Map<String, dynamic>> _cases = [];
  bool _isLoading = true;
  FilterParams? _currentFilter;

  /// Lưu Set các caseId đã biết — dùng để Diffing phát hiện ca SOS mới
  Set<String> _knownCaseIds = {};
  /// Lần fetch đầu tiên không hiện notification (tránh spam khi vừa mở app)
  bool _isFirstFetch = true;

  // Tọa độ TNV hiện tại (mặc định Đà Nẵng nếu chưa có GPS)
  double _currentLat = 16.0544;
  double _currentLon = 108.2022;

  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    // Lấy GPS lần đầu (không block UI), sau đó fetch cases
    _updateGpsThenFetch();
    _startPolling();
    _sheetController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _updateGpsThenFetch();
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void dispose() {
    _stopPolling();
    _sheetController.dispose();
    super.dispose();
  }

  bool _isFetching = false;

  /// Lấy GPS trước (có timeout), sau đó gọi API.
  /// Nếu GPS chậm → dùng tọa độ cached để gọi API trước.
  Future<void> _updateGpsThenFetch() async {
    // Cập nhật GPS (non-blocking)
    _updateGps();
    // Gọi API ngay với tọa độ hiện có (có thể là cached)
    await _fetchCasesOnly();
  }

  /// Cập nhật GPS + đồng bộ vị trí lên Backend (để geoDispatch tìm thấy TNV)
  Future<void> _updateGps() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
          Position position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 3),
            ),
          );
          _currentLat = position.latitude;
          _currentLon = position.longitude;

          // Đồng bộ GPS lên Backend → cập nhật cột current_coords trong DB
          // Để geoDispatch có thể tìm thấy TNV này khi có ca SOS mới
          final prefs = await SharedPreferences.getInstance();
          final volunteerId = prefs.getString('volunteer_id');
          if (volunteerId != null) {
            ApiService.updateLocation(
              lat: position.latitude,
              lon: position.longitude,
              volunteerId: volunteerId,
            );
          }
        }
      }
    } catch (e) {
      // Dùng tọa độ cached, không cần log mỗi lần
    }
  }

  /// Gọi API lấy danh sách ca với tọa độ hiện có (KHÔNG chờ GPS)
  /// Có logic Diffing: so sánh list cũ vs mới → phát hiện ca SOS mới → hiện notification
  Future<void> _fetchCasesOnly() async {
    if (_isFetching) return; // Tránh gọi song song
    _isFetching = true;

    try {
      final cases = await ApiService.getNearbyCases(
        lat: _currentLat,
        lon: _currentLon,
        maxDistance: _currentFilter?.maxDistance ?? 10.0,
        urgencyLevels: _currentFilter?.urgencyLevels,
        tags: _currentFilter?.tags,
        sortBy: _currentFilter?.sortByDistance ?? 'distance_asc',
      );
      if (mounted) {
        // ── Diffing: Phát hiện ca SOS mới để hiện notification ──
        final newCaseIds = cases.map((c) => c['id']?.toString() ?? '').toSet();

        if (!_isFirstFetch) {
          // Tìm những ID có trong list mới mà CHƯA CÓ trong list cũ
          final brandNewIds = newCaseIds.difference(_knownCaseIds);
          for (final newId in brandNewIds) {
            final newCase = cases.firstWhere(
              (c) => c['id']?.toString() == newId,
              orElse: () => <String, dynamic>{},
            );
            if (newCase.isNotEmpty) {
              // Kích hoạt Local Notification banner cho TNV
              LocalNotificationService.showNewSosForVolunteer(
                caseId: newId,
                urgencyLevel: newCase['urgency_level'] as int? ?? 3,
                distanceM: (newCase['distance_km'] as num?)?.toInt(),
                summary: newCase['summary_1line'] as String?,
              );
              debugPrint('[VolunteerHome] 🔔 New SOS detected: $newId → notification fired');
            }
          }
        } else {
          _isFirstFetch = false;
        }

        // Cập nhật bộ nhớ đã biết
        _knownCaseIds = newCaseIds;

        setState(() {
          _cases = cases;
          _isLoading = false;
        });
      }
    } finally {
      _isFetching = false;
    }
  }

  /// Xóa 1 case khỏi danh sách local ngay lập tức (optimistic UI)
  void _removeLocalCase(String caseId) {
    setState(() {
      _cases.removeWhere((c) => c['id']?.toString() == caseId);
    });
  }

  Future<void> _handleAcceptFromCard(Map<String, dynamic> caseData) async {
    final caseId = caseData['id']?.toString() ?? '';
    if (caseId.isEmpty) return;

    // Optimistic UI: xóa ca khỏi danh sách ngay lập tức
    _removeLocalCase(caseId);

    // Tạm dừng poll khi TNV đang trong màn hình Active Mission
    _stopPolling();

    // Navigate to Active Mission and wait until it is popped
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActiveMissionScreen(
          caseId: caseId,
          victimLat: (caseData['lat'] as num?)?.toDouble(),
          victimLon: (caseData['lon'] as num?)?.toDouble(),
          summary: caseData['ai_summary'] as String? ?? caseData['summary_1line'] as String?,
          urgencyLevel: (caseData['urgency_level'] as num?)?.toInt(),
        ),
      ),
    );

    // Bật lại poll khi TNV quay lại trang chủ
    if (mounted) {
      // Gọi API ngay với GPS cached (KHÔNG chờ GPS) → UI cập nhật nhanh
      await _fetchCasesOnly();
      _startPolling();
    }
  }

  // Lọc ra các case chưa resolved
  List<Map<String, dynamic>> get _activeCases {
    return _cases.where((c) {
      final status = c['status'] ?? '';
      return status == 'pending' || status == 'responding';
    }).toList();
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: FilterBottomSheet(
          initialParams: _currentFilter,
          onApply: (params) {
            setState(() {
              _currentFilter = params;
              _isLoading = true; // Hiện loading ngay khi lọc
            });
            _fetchCasesOnly(); // Không chờ GPS → nhanh hơn
          },
        ),
      ),
    );
  }

  Color _getUrgencyColor(int level) {
    switch (level) {
      case 5:
        return AppColors.urgency5;
      case 4:
        return AppColors.urgency4;
      case 3:
        return AppColors.urgency3;
      case 2:
        return AppColors.urgency2;
      default:
        return AppColors.urgency1;
    }
  }

  String _getUrgencyLabel(int level) {
    switch (level) {
      case 5:
        return 'CỰC KỲ NGUY HIỂM';
      case 4:
        return 'KHẨN CẤP';
      case 3:
        return 'CẦN HỖ TRỢ';
      case 2:
        return 'ƯU TIÊN THẤP';
      default:
        return 'THÔNG TIN';
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
                width: 32,
                height: 32,
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
                      color: Colors.white,
                      fontSize: 16,
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
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  double sheetSize = 0.42;
                  if (_sheetController.isAttached) {
                    sheetSize = _sheetController.size;
                  }
                  final isExpanded = sheetSize > 0.25;

                  return Stack(
                    children: [
                      // ── Map (full area) ──
                      FloodAidMap(
                        mapController: _mapController,
                        initialCenter: LatLng(16.0544, 108.2022),
                        initialZoom: 11.0,
                        markers: _buildMarkers(),
                      ),
                      // ── SOS Legend ──
                      Positioned(
                        left: 16,
                        top: 70,
                        child: const SosLegendWidget(),
                      ),
                      // ── Mode Pill ──
                      _buildModePill(),
                      // ── Floating Arrow Button ──
                      Positioned(
                        right: 16,
                        bottom: constraints.maxHeight * sheetSize + 16,
                        child: GestureDetector(
                          onTap: () {
                            if (isExpanded) {
                              _sheetController.animateTo(
                                0.08,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            } else {
                              _sheetController.animateTo(
                                0.75,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              isExpanded
                                  ? Icons.keyboard_arrow_down
                                  : Icons.keyboard_arrow_up,
                              color: AppColors.alertRed,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                      // ── Draggable Bottom Sheet ──
                      _buildDraggableSheet(),
                    ],
                  );
                },
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
          GestureDetector(
            onTap: _showVolunteerProfile,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.person,
                color: AppColors.primary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showVolunteerProfile() async {
    final user = AuthService.currentUser;
    String phoneDisplay = 'Chưa xác thực';
    if (user?.phoneNumber != null) {
      String phone = user!.phoneNumber!;
      if (phone.startsWith('+84')) {
        phone = '0${phone.substring(3)}';
      }
      phoneDisplay = phone;
    }

    final prefs = await SharedPreferences.getInstance();
    final volunteerId = prefs.getString('volunteer_id') ?? '';

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Avatar
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.person,
                color: AppColors.primary,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'Tình nguyện viên',
              style: AppTypography.headingMedium,
            ),
            const SizedBox(height: 24),

            // Phone info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.verified,
                      color: AppColors.success,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Số điện thoại đã xác thực',
                          style: AppTypography.caption,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          phoneDisplay,
                          style: AppTypography.bodyLarge.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Cài đặt bán kính nhận thông báo ──
            if (volunteerId.isNotEmpty) RadiusSettingsWidget(volunteerId: volunteerId),
            if (volunteerId.isNotEmpty) const SizedBox(height: 24),

            // Logout button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx); // Đóng bottom sheet
                  await AuthService.signOut();
                  await prefs.remove('user_phone');
                  await prefs.remove('notification_radius_km'); // clear cache
                  if (!mounted) return;
                  // Quay về màn hình chọn role
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const VolunteerPhoneScreen(),
                    ),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.logout, size: 18),
                label: Text(
                  'Đăng xuất',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.danger,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
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
            const Icon(
              Icons.volunteer_activism,
              color: AppColors.primary,
              size: 16,
            ),
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
    final pendingCases = _activeCases
        .where((c) => c['status'] == 'pending')
        .toList();

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
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Collapsed mini-header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.alertRed,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  '${pendingCases.length} chờ xử lý',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _showFilterBottomSheet,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(color: AppColors.alertRed),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: const [
                                      Icon(Icons.tune, size: 14, color: AppColors.alertRed),
                                      SizedBox(width: 4),
                                      Text(
                                        '2 bộ lọc',
                                        style: TextStyle(
                                          color: AppColors.alertRed,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // Quick Filters Row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          _buildQuickFilter(5, '0.8km', true),
                          const SizedBox(width: 8),
                          _buildQuickFilter(5, '1.5km', false),
                          const SizedBox(width: 8),
                          _buildQuickFilter(4, '1.2km', false),
                          const SizedBox(width: 8),
                          _buildQuickFilter(1, '2.1km', false),
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
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (_activeCases.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 48,
                          color: AppColors.success.withOpacity(0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Chưa có ca SOS nào',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final c = _activeCases[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildRequestCard(c),
                      );
                    }, childCount: _activeCases.length),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickFilter(int urgency, String distance, bool isSelected) {
    final color = _getUrgencyColor(urgency);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            border: Border.all(color: color.withOpacity(0.8), width: 1.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Text(
                'Mức $urgency',
                style: TextStyle(color: color.withOpacity(0.9), fontWeight: FontWeight.bold, fontSize: 12),
              ),
              Text(
                distance,
                style: TextStyle(color: color.withOpacity(0.9), fontSize: 10),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        if (isSelected)
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          )
        else
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, shape: BoxShape.circle),
          ),
      ],
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> caseData) {
    final urgency = (caseData['urgency_level'] as num?)?.toInt() ?? 2;
    final color = _getUrgencyColor(urgency);
    final label = _getUrgencyLabel(urgency);
    final summary =
        caseData['ai_summary'] as String? ??
        caseData['summary_1line'] as String? ??
        caseData['description'] as String? ??
        'Yêu cầu cứu trợ';
    final createdAt = caseData['created_at'] as String?;

    // Real tags from backend
    final List<dynamic> rawTags = caseData['tags_vi'] ?? [];
    final List<String> tags = rawTags.map((e) => e.toString()).toList();

    final responderCount = caseData['responder_count'] ?? 0;
    
    // Real distance
    final distM = caseData['distance_m'] ?? 0;
    final distanceStr = distM > 1000 ? '${(distM / 1000).toStringAsFixed(1)} km' : '${distM}m';

    // Real time
    final mins = caseData['time_ago_minutes'] ?? 0;
    String timeAgo = mins < 60 ? '$mins phút trước' : '${(mins / 60).floor()} giờ trước';
    
    String timeSent = '';
    if (createdAt != null) {
      final dt = DateTime.tryParse(createdAt)?.toLocal();
      if (dt != null) {
        timeSent = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Red top border line matching design
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Mức khẩn cấp & Xem vị trí
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'MỨC $urgency — $label',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        final lat = (caseData['lat'] as num?)?.toDouble();
                        final lon = (caseData['lon'] as num?)?.toDouble();
                        if (lat != null && lon != null) {
                          _mapController.move(LatLng(lat, lon), 15.0);
                          _sheetController.animateTo(
                            0.08,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.location_on_outlined, size: 14, color: Colors.blue),
                          SizedBox(width: 4),
                          Text(
                            'Xem vị trí',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Row 2: Summary
                Text(
                  '"$summary"',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: Colors.black87,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 16),

                // Row 3: Details
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text('Cách bạn: $distanceStr', style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text('Gửi lúc: $timeSent ($timeAgo)', style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.group_outlined, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      'TNV đang đến: $responderCount người',
                      style: TextStyle(color: responderCount == 0 ? AppColors.alertRed : Colors.black87, fontSize: 14, fontWeight: responderCount == 0 ? FontWeight.bold : FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Tags
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: tags.map((tag) {
                    Color bgColor = Colors.grey.shade100;
                    Color textColor = Colors.grey.shade700;
                    if (tag.toLowerCase().contains('trẻ em') || tag.toLowerCase().contains('người già')) {
                      bgColor = AppColors.alertRed.withOpacity(0.1);
                      textColor = AppColors.alertRed;
                    } else if (tag.toLowerCase().contains('y tế')) {
                      bgColor = Colors.blue.withOpacity(0.1);
                      textColor = Colors.blue;
                    }
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Buttons
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _handleAcceptFromCard(caseData),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      backgroundColor: Colors.blue.shade400,
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.check, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Nhận ca',
                          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final phone = caseData['victim_phone'] ?? '0123456789';
                          final Uri url = Uri(scheme: 'tel', path: phone.toString());
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url);
                          }
                        },
                        icon: const Icon(Icons.phone_outlined, color: Colors.white, size: 18),
                        label: const Text(
                          'Gọi thẳng GSM',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade400,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final lat = caseData['lat']?.toString() ?? '16.0544';
                          final lon = caseData['lon']?.toString() ?? '108.2022';
                          final Uri url = Uri.parse(
                            'https://www.google.com/maps/search/?api=1&query=$lat,$lon',
                          );
                          if (await canLaunchUrl(url)) {
                            await launchUrl(
                              url,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                        icon: const Icon(Icons.map_outlined, color: Colors.white, size: 18),
                        label: const Text(
                          'Google Maps',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade400,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RadiusSettingsWidget extends StatefulWidget {
  final String volunteerId;
  const RadiusSettingsWidget({Key? key, required this.volunteerId}) : super(key: key);

  @override
  State<RadiusSettingsWidget> createState() => _RadiusSettingsWidgetState();
}

class _RadiusSettingsWidgetState extends State<RadiusSettingsWidget> {
  int _radiusKm = 5;
  bool _receiveAll = false;
  Timer? _debounce;
  bool _isLoading = true;
  late TextEditingController _radiusController;

  @override
  void initState() {
    super.initState();
    _radiusController = TextEditingController();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    // Load local settings, default to receive all (null/0)
    final savedRadius = prefs.getInt('notification_radius_km');
    setState(() {
      if (savedRadius == null || savedRadius == 0) {
        _receiveAll = true;
        _radiusKm = 5; // Default when disabled
      } else {
        _receiveAll = false;
        _radiusKm = savedRadius.clamp(1, 999);
      }
      _radiusController.text = _radiusKm.toString();
      _isLoading = false;
    });
  }

  void _onRadiusChanged(String value) {
    final parsed = int.tryParse(value);
    if (parsed != null && parsed > 0) {
      setState(() {
        _radiusKm = parsed;
        _receiveAll = false;
      });
      _debouncedSave();
    }
  }

  void _onReceiveAllChanged(bool value) {
    setState(() {
      _receiveAll = value;
      if (value) {
        // Clear focus if turning on receive all
        FocusScope.of(context).unfocus();
      }
    });
    _debouncedSave();
  }

  void _debouncedSave() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final prefs = await SharedPreferences.getInstance();
      final radiusToSave = _receiveAll ? 0 : _radiusKm;
      await prefs.setInt('notification_radius_km', radiusToSave);

      ApiService.updateNotificationRadius(
        volunteerId: widget.volunteerId,
        radiusKm: _receiveAll ? null : _radiusKm,
      );
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _radiusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.radar, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Phạm vi nhận ca cứu hộ',
                style: AppTypography.headingMedium,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Bán kính (km):',
                  style: AppTypography.bodyLarge.copyWith(
                    color: _receiveAll ? AppColors.textMuted : AppColors.textPrimary,
                  ),
                ),
              ),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _radiusController,
                  keyboardType: TextInputType.number,
                  enabled: !_receiveAll,
                  onChanged: _onRadiusChanged,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _receiveAll ? AppColors.textMuted : AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    isDense: true,
                    filled: true,
                    fillColor: _receiveAll ? AppColors.background : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.surfaceBorder),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Nhận mọi ca (Không giới hạn)',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              Switch(
                value: _receiveAll,
                onChanged: _onReceiveAllChanged,
                activeColor: AppColors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
