import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/local_notification_service.dart';
import '../../services/event_bus.dart';
import '../../widgets/map_widget.dart';
import '../../widgets/sos_legend_widget.dart';
import '../../widgets/filter_bottom_sheet.dart';
import '../../services/active_mission_manager.dart';
import 'active_mission_screen.dart';
import 'volunteer_phone_screen.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/services.dart';

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
  /// Chỉ addAll(), không bao giờ ghi đè → tránh spam khi đổi bộ lọc
  Set<String> _knownCaseIds = {};
  /// Lần fetch đầu tiên không hiện notification (tránh spam khi vừa mở app)
  bool _isFirstFetch = true;
  /// Skip notification cho lần fetch ngay sau khi user đổi bộ lọc
  bool _skipNextNotification = false;

  // Tọa độ TNV hiện tại (mặc định Đà Nẵng nếu chưa có GPS)
  double _currentLat = 16.0544;
  double _currentLon = 108.2022;

  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  final MapController _mapController = MapController();

  /// Lắng nghe FCM push ca SOS mới → refresh list ngay lập tức
  StreamSubscription? _newSosSub;

  /// SSE subscription — lắng nghe case:resolved real-time
  StreamSubscription? _sseSub;

  @override
  void initState() {
    super.initState();
    // Lấy GPS lần đầu (không block UI), sau đó fetch cases
    _updateGpsThenFetch();
    _startPolling();
    _sheetController.addListener(() {
      if (mounted) setState(() {});
    });

    // Lắng nghe FCM push ca SOS mới → refresh list ngay (không chờ poll)
    _newSosSub = EventBus.on('new_sos').listen((data) {
      final caseId = data['caseId'] as String?;
      if (caseId != null && caseId.isNotEmpty) {
        _knownCaseIds.add(caseId);
      }
      _fetchCasesOnly();
    });

    // Connect SSE volunteer-feed — lắng nghe case:resolved real-time
    _connectVolunteerFeed();
  }

  /// Connect SSE để nhận event case:resolved ngay lập tức
  void _connectVolunteerFeed() {
    final baseUrl = kIsWeb ? 'http://127.0.0.1:3000' : 'https://floodaid.onrender.com';
    final client = http.Client();
    final request = http.Request('GET', Uri.parse('$baseUrl/api/sse/volunteer-feed'));
    
    client.send(request).then((response) {
      _sseSub = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        if (line.startsWith('data: ')) {
          try {
            final data = json.decode(line.substring(6));
            final caseId = data['caseId'] as String?;
            if (caseId != null && mounted) {
              // Xóa ca khỏi list ngay lập tức (optimistic removal)
              setState(() {
                _cases.removeWhere((c) => c['id']?.toString() == caseId);
              });
              debugPrint('[VolunteerHome] SSE: Case $caseId resolved, removed from list');
            }
          } catch (_) {}
        }
      }, onError: (e) {
        debugPrint('[VolunteerHome] SSE error: $e');
        // Reconnect sau 5s nếu mất kết nối
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) _connectVolunteerFeed();
        });
      });
    }).catchError((e) {
      debugPrint('[VolunteerHome] SSE connect error: $e');
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) _connectVolunteerFeed();
      });
    });
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
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
    _newSosSub?.cancel();
    _sseSub?.cancel();
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
        // Chỉ notification khi ca THỰC SỰ MỚI từ server, không phải do đổi bộ lọc
        final newCaseIds = cases.map((c) => c['id']?.toString() ?? '').toSet();

        if (!_isFirstFetch && !_skipNextNotification) {
          // Tìm những ID có trong list mới mà CHƯA TỪNG BIẾT
          final brandNewIds = newCaseIds.difference(_knownCaseIds);
          if (brandNewIds.isNotEmpty) {
            // Kiểm tra TNV có bật thông báo không (setting trong Profile)
            final prefs = await SharedPreferences.getInstance();
            final notifEnabled = prefs.getBool('notification_enabled') ?? true;

            if (notifEnabled) {
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
              debugPrint('[VolunteerHome] 🔕 ${brandNewIds.length} new SOS detected but notifications OFF → skipped');
            }
          }
        } else {
          _isFirstFetch = false;
        }
        _skipNextNotification = false;

        // Cập nhật bộ nhớ: chỉ THÊM, không xóa → ca đã biết sẽ không bị
        // coi là "mới" khi user đổi bộ lọc mở rộng rồi thu hẹp rồi mở lại
        _knownCaseIds.addAll(newCaseIds);

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

  Future<void> _handleViewCase(Map<String, dynamic> caseData) async {
    final caseId = caseData['id']?.toString() ?? '';
    if (caseId.isEmpty) return;

    // Tạm dừng poll khi TNV đang trong màn hình Active Mission
    _stopPolling();

    // Navigate to Active Mission and wait until it is popped
    final resolvedCaseId = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => ActiveMissionScreen(
          caseId: caseId,
          victimLat: (caseData['lat'] as num?)?.toDouble(),
          victimLon: (caseData['lon'] as num?)?.toDouble(),
          summary: caseData['ai_summary'] as String? ?? caseData['summary_1line'] as String?,
          description: caseData['description'] as String?,
          urgencyLevel: (caseData['urgency_level'] as num?)?.toInt(),
          victimPhone: caseData['victim_phone']?.toString(),
        ),
      ),
    );

    // Bật lại poll khi TNV quay lại trang chủ
    if (mounted) {
      // Optimistic UI: xóa ca resolved ngay trước khi fetch API
      if (resolvedCaseId != null) {
        _removeLocalCase(resolvedCaseId);
      }
      _skipNextNotification = true;
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
              _skipNextNotification = true; // Đổi filter ≠ ca mới → skip notification
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
            // ── Banner nhiệm vụ đang active (nếu có) ──
            _buildActiveMissionBanner(),
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
                        top: 16,
                        child: const SosLegendWidget(),
                      ),
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

  /// Banner nhắc nhở TNV đang có nhiệm vụ chưa hoàn thành
  Widget _buildActiveMissionBanner() {
    final manager = ActiveMissionManager();
    if (!manager.hasActiveMission) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        // Navigate lại ActiveMissionScreen với thông tin từ Manager
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ActiveMissionScreen(
              caseId: manager.activeCaseId!,
              victimLat: manager.victimLat,
              victimLon: manager.victimLon,
              summary: manager.summary,
              description: manager.description,
              urgencyLevel: manager.urgencyLevel,
              victimPhone: manager.victimPhone,
            ),
          ),
        ).then((_) {
          // Refresh khi quay về
          if (mounted) setState(() {});
        });
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.alertRed, AppColors.alertRed.withOpacity(0.85)],
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.6),
                    blurRadius: 6,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                '🔴 Bạn đang có 1 nhiệm vụ chưa hoàn thành',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
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
            if (volunteerId.isNotEmpty) NotificationSettingsWidget(volunteerId: volunteerId),
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
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Shimmer.fromColors(
                          baseColor: Colors.grey.shade200,
                          highlightColor: Colors.white,
                          child: Container(
                            height: 180,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      );
                    }, childCount: 3),
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
        'Yêu cầu cứu trợ';
    final description = caseData['description'] as String?;
    final createdAt = caseData['created_at'] as String?;
    final victimPhone = caseData['victim_phone']?.toString();

    // Real tags from backend
    final List<dynamic> rawTags = caseData['tags_vi'] ?? [];
    final List<String> tags = rawTags.map((e) => e.toString()).toList();

    final responderCount = caseData['responder_count'] ?? 0;
    
    // Real distance
    final distM = (caseData['distance_m'] as num?)?.toDouble() ?? 0;
    final distanceStr = distM > 1000 ? '${(distM / 1000).toStringAsFixed(1)} km' : '${distM.toInt()}m';

    // ETA: ước tính đi bộ ~4km/h (vùng ngập chậm hơn bình thường)
    final etaMinutes = (distM / 1000 / 4 * 60).ceil();
    final etaStr = etaMinutes < 60
        ? '~$etaMinutes phút'
        : '~${(etaMinutes / 60).floor()}h${etaMinutes % 60 > 0 ? '${etaMinutes % 60}p' : ''}';

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

    // Ẩn SĐT: 0901234567 → 090 •••• 567
    String maskedPhone = '';
    if (victimPhone != null && victimPhone.length >= 6) {
      maskedPhone = '${victimPhone.substring(0, 3)} •••• ${victimPhone.substring(victimPhone.length - 3)}';
    } else if (victimPhone != null) {
      maskedPhone = '••••••••';
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
          // Thanh màu trên cùng
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
                // ── Row 1: Badge mức + Thời gian ──
                Row(
                  children: [
                    // Badge mức khẩn cấp (DUY NHẤT, không lặp)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      timeSent.isNotEmpty ? '$timeSent · $timeAgo' : timeAgo,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Row 2: Tóm tắt AI ──
                Text(
                  summary,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Colors.black87,
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                // ── Row 2b: Lời kêu cứu gốc (nếu có và khác summary) ──
                if (description != null && description.isNotEmpty && description != summary)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border(
                          left: BorderSide(color: color.withOpacity(0.5), width: 3),
                        ),
                      ),
                      child: Text(
                        '"$description"',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),

                const SizedBox(height: 14),

                // ── Row 3: Khoảng cách + ETA + Số TNV (Grid 3 cột) ──
                Row(
                  children: [
                    // Khoảng cách
                    Expanded(
                      child: _buildStatItem(
                        icon: Icons.straighten,
                        iconColor: AppColors.primary,
                        value: distanceStr,
                        label: 'khoảng cách',
                      ),
                    ),
                    Container(width: 1, height: 32, color: Colors.grey.shade200),
                    // ETA
                    Expanded(
                      child: _buildStatItem(
                        icon: Icons.timer_outlined,
                        iconColor: Colors.orange.shade600,
                        value: etaStr,
                        label: 'di chuyển',
                      ),
                    ),
                    Container(width: 1, height: 32, color: Colors.grey.shade200),
                    // Số TNV
                    Expanded(
                      child: _buildStatItem(
                        icon: Icons.people_alt_outlined,
                        iconColor: responderCount == 0 ? AppColors.alertRed : AppColors.success,
                        value: '$responderCount',
                        label: 'TNV đến',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // ── Row 4: SĐT nạn nhân (ẩn) ──
                if (maskedPhone.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.phone_locked, size: 16, color: Colors.grey.shade400),
                        const SizedBox(width: 8),
                        Text(
                          maskedPhone,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade500,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Nhận ca để gọi',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade400,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Tags ──
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                const SizedBox(height: 16),

                // ── Nút Xem ca ──
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _handleViewCase(caseData);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      side: BorderSide(color: Colors.blue.shade400, width: 1.5),
                    ),
                    child: Text(
                      'Xem chi tiết  ▸',
                      style: TextStyle(color: Colors.blue.shade400, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Widget nhỏ hiển thị 1 chỉ số thống kê (Khoảng cách / ETA / Số TNV)
  Widget _buildStatItem({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.black87),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
        ),
      ],
    );
  }
}

class NotificationSettingsWidget extends StatefulWidget {
  final String volunteerId;
  const NotificationSettingsWidget({Key? key, required this.volunteerId}) : super(key: key);

  @override
  State<NotificationSettingsWidget> createState() => _NotificationSettingsWidgetState();
}

class _NotificationSettingsWidgetState extends State<NotificationSettingsWidget> {
  bool _enabled = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    // notification_enabled: true = nhận thông báo, false = tắt
    // Mặc định true nếu chưa từng cài đặt
    final saved = prefs.getBool('notification_enabled') ?? true;
    setState(() {
      _enabled = saved;
      _isLoading = false;
    });
  }

  void _onToggle(bool value) async {
    setState(() => _enabled = value);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notification_enabled', value);

    ApiService.updateNotificationSetting(
      volunteerId: widget.volunteerId,
      enabled: value,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));

    return Container(
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _enabled
                  ? AppColors.primary.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _enabled ? Icons.notifications_active : Icons.notifications_off,
              color: _enabled ? AppColors.primary : AppColors.textMuted,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nhận thông báo ca SOS mới',
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _enabled
                      ? 'Bạn sẽ được thông báo khi có ca cứu hộ mới'
                      : 'Bạn sẽ không nhận thông báo (vẫn xem được danh sách)',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _enabled,
            onChanged: _onToggle,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
