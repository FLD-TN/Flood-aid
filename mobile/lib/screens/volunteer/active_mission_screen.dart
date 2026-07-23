import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/toast_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/active_mission_manager.dart';
import '../../widgets/map_widget.dart';
import '../../widgets/sos_legend_widget.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../widgets/slide_to_confirm.dart';
import '../chat/chat_screen.dart';

class ActiveMissionScreen extends StatefulWidget {
  final String caseId;
  final double? victimLat;
  final double? victimLon;
  final String? summary;
  final String? description;
  final String? address;
  final int? urgencyLevel;
  final String? victimPhone;
  final int?
  initialDistanceM; // khoảng cách chim bay từ màn danh sách (để khớp số khi chưa nhận ca)

  const ActiveMissionScreen({
    super.key,
    required this.caseId,
    this.victimLat,
    this.victimLon,
    this.summary,
    this.description,
    this.address,
    this.urgencyLevel,
    this.victimPhone,
    this.initialDistanceM,
  });

  @override
  State<ActiveMissionScreen> createState() => _ActiveMissionScreenState();
}

class _ActiveMissionScreenState extends State<ActiveMissionScreen> {
  final MapController _mapController = MapController();
  final ActiveMissionManager _manager = ActiveMissionManager();

  // Chiều cao nghỉ của sheet — đặt cao để lộ sẵn nút trượt (nhận/đóng ca) ngay khi mở.
  double get _initSheet => _accepted ? 0.6 : 0.62;
  static const double _minSheet = 0.12;
  static const double _maxSheet = 0.9;

  // TNV (volunteer) location — realtime GPS
  double? _myLat;
  double? _myLon;

  // Quãng đường + ETA THẬT theo đường đi (Route v4), đọc từ cache backend qua getCaseById.
  int? _routeDistanceM;
  int? _etaSec;

  // Hình học tuyến đường (Route v4) để vẽ polyline; throttle gọi lại tối đa 1 lần/20s.
  List<LatLng> _routePoints = [];
  DateTime? _lastRouteFetchAt;

  // Victim location
  late double _victimLat;
  late double _victimLon;

  // Volunteer UUID (loaded from SharedPreferences)
  String _volunteerId = '';

  // SĐT nạn nhân — lấy từ acceptCase response
  String? _victimPhone;

  // Case state
  bool _accepted = false;
  bool _isResolving = false;
  bool _isRevoking = false;
  bool _wsConnected = false;
  bool _caseResolved = false; // ca đã bị đóng từ bên ngoài (SSE)

  // SSE subscription (lắng nghe trước khi accept)
  StreamSubscription? _sseSub;

  // GPS timer — chỉ dùng để cập nhật _myLat/_myLon cho UI bản đồ
  Timer? _localGpsTimer;

  @override
  void initState() {
    super.initState();
    _victimLat = widget.victimLat ?? 16.0544;
    _victimLon = widget.victimLon ?? 108.2022;

    // Kiểm tra Manager xem đã có mission đang chạy cho ca này chưa
    if (_manager.hasActiveMission && _manager.activeCaseId == widget.caseId) {
      // Re-entry: TNV quay lại từ HomeScreen → khôi phục state
      _accepted = true;
      _volunteerId = _manager.volunteerId ?? '';
      _victimPhone = _manager.victimPhone;
      _wsConnected = _manager.wsConnected;
      // Đăng ký callback khi ca bị đóng từ bên ngoài
      _manager.onMissionEndedExternally = _onMissionEndedExternally;
      // Listen manager changes cho WS status
      _manager.addListener(_onManagerChanged);
    } else {
      // Lần đầu vào — chưa accept
      _connectCaseSSE();
    }

    // Load volunteer UUID
    _loadVolunteerId();

    // Get initial location once
    _getMyLocation();

    // Timer local — cập nhật vị trí TNV trên bản đồ (UI) + đọc quãng đường/ETA thật từ backend
    _localGpsTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _getMyLocation();
      _fetchRouteCache();
      _fetchRouteLine();
    });
    _fetchRouteCache();
    _fetchRouteLine();
  }

  /// Lấy hình học tuyến đường (Route v4) từ vị trí TNV → nạn nhân để vẽ polyline.
  /// Throttle tối đa 1 lần/20s để không tốn nhiều transaction.
  Future<void> _fetchRouteLine() async {
    if (_myLat == null || _myLon == null) return;
    final now = DateTime.now();
    if (_lastRouteFetchAt != null && now.difference(_lastRouteFetchAt!).inSeconds < 20) return;
    _lastRouteFetchAt = now;
    final data = await ApiService.geoRoute(
      fromLat: _myLat!,
      fromLon: _myLon!,
      toLat: _victimLat,
      toLon: _victimLon,
    );
    if (!mounted || data == null) return;
    final raw = data['points'] as List?;
    if (raw == null || raw.isEmpty) return;
    setState(() {
      _routePoints = raw
          .map((p) => LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()))
          .toList();
    });
  }

  /// Đọc quãng đường + ETA THẬT (Route v4) từ cache backend.
  /// CHỈ dùng khi mình ĐÃ nhận ca — vì cache tnv_route_distance_m gắn với TNV được gán
  /// (nếu chưa nhận, đó có thể là số của TNV khác). Chưa nhận → dùng khoảng cách chim bay
  /// giống hệt màn danh sách để 2 màn khớp số.
  Future<void> _fetchRouteCache() async {
    // chưa nhận ca thì không đọc cache route (tránh lệch/nhầm TNV)
    if (!_accepted) return;
    final data = await ApiService.getCaseById(widget.caseId);
    if (data == null || !mounted) return;
    setState(() {
      if (data['tnv_route_distance_m'] != null) {
        _routeDistanceM = (data['tnv_route_distance_m'] as num).toInt();
      }
      if (data['tnv_eta_sec'] != null) {
        _etaSec = (data['tnv_eta_sec'] as num).toInt();
      }
    });
  }

  /// Chuẩn hóa SĐT: +84XXXXXXXXX → 0XXXXXXXXX
  String _normalizePhone(String phone) {
    if (phone.startsWith('+84')) return '0${phone.substring(3)}';
    return phone;
  }

  void _onManagerChanged() {
    if (mounted) {
      setState(() {
        _wsConnected = _manager.wsConnected;
      });
    }
  }

  void _onMissionEndedExternally() {
    if (mounted) {
      ToastService.show(
        context: context,
        type: ToastType.success,
        message: 'Nạn nhân đã xác nhận được giúp đỡ. Ca đã đóng!',
      );
      Navigator.pop(context);
    }
  }

  /// Connect SSE cho case này để phát hiện ca bị đóng trước khi accept
  void _connectCaseSSE() {
    final baseUrl = kIsWeb
        ? 'http://127.0.0.1:3000'
        : 'https://floodaid.onrender.com';
    final client = http.Client();
    final request = http.Request(
      'GET',
      Uri.parse('$baseUrl/api/case/${widget.caseId}/stream'),
    );

    client
        .send(request)
        .then((response) {
          _sseSub = response.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())
              .listen(
                (line) {
                  if (line.startsWith('data: ') && mounted && !_caseResolved) {
                    try {
                      final data = json.decode(line.substring(6));
                      final status = data['status'] as String?;
                      if (status == 'resolved' || status == 'cancelled') {
                        _caseResolved = true;
                        final resolvedBy = data['resolvedBy'] ?? 'victim';
                        _stopGpsTracking();
                        _sseSub?.cancel();
                        ToastService.show(
                          context: context,
                          type: ToastType.success,
                          message: resolvedBy == 'victim'
                              ? 'Nạn nhân đã xác nhận được giúp đỡ. Ca đã đóng!'
                              : 'Ca đã được đóng bởi $resolvedBy.',
                        );
                        Navigator.pop(context);
                      }
                    } catch (_) {}
                  }
                },
                onError: (e) {
                  debugPrint('[ActiveMission] SSE error: $e');
                },
              );
        })
        .catchError((e) {
          debugPrint('[ActiveMission] SSE connect error: $e');
        });
  }

  Future<void> _loadVolunteerId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('volunteer_id') ?? '';
    if (mounted) {
      setState(() => _volunteerId = id);
    }

    // Sau khi có volunteerId → kiểm tra xem TNV này đã accept ca chưa
    if (id.isNotEmpty) {
      _checkExistingAssignment(id);
    }
  }

  /// Kiểm tra TNV đã được assign vào ca này chưa (xử lý re-entry)
  Future<void> _checkExistingAssignment(String volunteerId) async {
    // Nếu Manager đã biết rồi thì không cần hỏi API
    if (_manager.hasActiveMission && _manager.activeCaseId == widget.caseId) {
      return; // Đã xử lý trong initState
    }

    final result = await ApiService.checkMyAssignment(
      widget.caseId,
      volunteerId,
    );
    if (result == null || !mounted) return;

    final isAssigned = result['isAssigned'] == true;
    final caseStatus = result['caseStatus'] as String? ?? '';

    if (isAssigned && caseStatus == 'responding') {
      // TNV đã nhận ca này trước đó → khôi phục trạng thái qua Manager
      debugPrint(
        '[ActiveMission] Restored accepted state for case ${widget.caseId}',
      );
      setState(() => _accepted = true);
      _sseSub?.cancel();
      _startGpsTracking();
    } else if (caseStatus == 'resolved' || caseStatus == 'cancelled') {
      if (mounted) {
        ToastService.show(
          context: context,
          type: ToastType.warning,
          message: 'Ca này đã được đóng.',
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _localGpsTimer?.cancel();
    _sseSub?.cancel();
    _manager.removeListener(_onManagerChanged);
    // KHÔNG dispose _manager.wsGpsService ở đây!
    // GPS chạy ngầm ngay cả khi screen bị pop (giống Grab)
    super.dispose();
  }

  /// Start GPS tracking via Manager (global singleton)
  void _startGpsTracking() {
    _manager.startMission(
      caseId: widget.caseId,
      volunteerId: _volunteerId,
      victimLat: _victimLat,
      victimLon: _victimLon,
      summary: widget.summary,
      description: widget.description,
      address: widget.address,
      urgencyLevel: widget.urgencyLevel,
      victimPhone: _victimPhone ?? widget.victimPhone,
    );
    _manager.onMissionEndedExternally = _onMissionEndedExternally;
    _manager.addListener(_onManagerChanged);
  }

  /// Stop GPS tracking — delegate cho Manager
  void _stopGpsTracking() {
    _manager.endMission();
  }

  Future<void> _getMyLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (mounted) {
        setState(() {
          _myLat = pos.latitude;
          _myLon = pos.longitude;
        });
        // GPS gửi qua Manager (global), screen chỉ cập nhật UI
      }
    } catch (e) {
      debugPrint('[ActiveMission] GPS error: $e');
    }
  }

  Future<void> _handleAcceptCase() async {
    // Pre-check: kiểm tra trạng thái ca VÀ assignment
    final assignment = await ApiService.checkMyAssignment(
      widget.caseId,
      _volunteerId,
    );
    if (assignment != null) {
      final caseStatus = assignment['caseStatus'] as String? ?? '';
      final isAssigned = assignment['isAssigned'] == true;

      if (caseStatus == 'resolved' || caseStatus == 'cancelled') {
        if (mounted) {
          ToastService.show(
            context: context,
            type: ToastType.warning,
            message: 'Ca này đã được đóng.',
          );
          Navigator.pop(context);
        }
        return;
      }

      if (caseStatus == 'responding' && isAssigned) {
        // TNV này đã nhận ca → khôi phục trạng thái (idempotent)
        setState(() => _accepted = true);
        _sseSub?.cancel();
        _startGpsTracking();
        return;
      }

      if (caseStatus == 'responding' && !isAssigned) {
        if (mounted) {
          ToastService.show(
            context: context,
            type: ToastType.warning,
            message: 'Ca này đã được TNV khác nhận.',
          );
          Navigator.pop(context);
        }
        return;
      }
    }

    // Optimistic UI: update immediately
    setState(() => _accepted = true);

    // Hủy SSE (WebSocket sẽ tiếp quản sau khi accept)
    _sseSub?.cancel();

    try {
      // Use _volunteerId already loaded from SharedPreferences
      final volunteerId = _volunteerId;
      final result = await ApiService.acceptCase(
        widget.caseId,
        volunteerId,
        lat: _myLat,
        lon: _myLon,
      );
      if (result == null && mounted) {
        // Rollback on failure
        setState(() => _accepted = false);
        // Reconnect SSE vì accept thất bại
        _connectCaseSSE();
        ToastService.show(
          context: context,
          type: ToastType.error,
          message: 'Nhận ca thất bại. Thử lại sau.',
        );
      } else if (mounted) {
        // Lưu SĐT nạn nhân từ response
        final phone = result?['victimPhone'] as String?;
        debugPrint(
          '[ActiveMission] acceptCase response victimPhone="$phone", full=$result',
        );
        setState(() => _victimPhone = phone);
        // Accept succeeded — start GPS tracking via WebSocket
        _startGpsTracking();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _accepted = false);
        _connectCaseSSE();
        ToastService.show(
          context: context,
          type: ToastType.error,
          message: 'Lỗi mạng. Thử lại sau.',
        );
      }
      debugPrint('[ActiveMission] Accept error: $e');
    }
  }

  Future<void> _handleResolve() async {
    if (_isResolving) return;
    setState(() => _isResolving = true);
    try {
      final success = await ApiService.resolveCase(widget.caseId, 'volunteer');
      if (success && mounted) {
        _manager.endMission();
        Navigator.pop(context, widget.caseId);
      } else if (mounted) {
        setState(() => _isResolving = false);
        ToastService.show(
          context: context,
          type: ToastType.error,
          message: 'Đóng ca thất bại. Thử lại sau.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isResolving = false);
        ToastService.show(
          context: context,
          type: ToastType.error,
          message: 'Lỗi mạng. Thử lại sau.',
        );
      }
      debugPrint('[ActiveMission] Resolve error: $e');
    }
  }

  /// TNV chủ động hủy nhiệm vụ
  Future<void> _handleRevokeMission() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy nhiệm vụ cứu hộ?'),
        content: const Text(
          'Nạn nhân vẫn đang mắc kẹt và chờ đợi bạn.\n\n'
          'Nếu bạn hủy, ca này sẽ được trả về bản đồ cho TNV khác nhận.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text(
              'Tiếp tục nhiệm vụ',
              style: TextStyle(color: Colors.white),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Xác nhận hủy',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isRevoking = true);
    final success = await _manager.revokeMission();
    if (mounted) {
      setState(() => _isRevoking = false);
      if (success) {
        ToastService.show(
          context: context,
          type: ToastType.warning,
          message: 'Đã hủy nhiệm vụ. Ca đã được trả về bản đồ.',
        );
        Navigator.pop(context);
      } else {
        ToastService.show(
          context: context,
          type: ToastType.error,
          message: 'Hủy thất bại. Thử lại sau.',
        );
      }
    }
  }

  double? get _distanceKm {
    if (_myLat == null || _myLon == null) return null;
    final d = const Distance();
    final m = d.as(
      LengthUnit.Meter,
      LatLng(_myLat!, _myLon!),
      LatLng(_victimLat, _victimLon),
    );
    return m / 1000;
  }

  void _centerOnMe() {
    if (_myLat != null && _myLon != null) {
      _mapController.move(LatLng(_myLat!, _myLon!), 15.0);
    }
  }

  List<Marker> _buildMarkers() {
    // Màu ping nạn nhân theo mức khẩn cấp (đồng bộ với màn danh sách), không cố định đỏ
    final victimColor = getUrgencyColor(widget.urgencyLevel ?? 3);
    final markers = <Marker>[
      // Victim marker (màu theo mức SOS)
      Marker(
        point: LatLng(_victimLat, _victimLon),
        width: 90.w,
        height: 90.w,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36.w,
              height: 36.w,
              decoration: BoxDecoration(
                color: victimColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3.w),
                boxShadow: [
                  BoxShadow(
                    color: victimColor.withValues(alpha: 0.5),
                    blurRadius: 14.r,
                    spreadRadius: 3.r,
                  ),
                ],
              ),
              child: Icon(Icons.location_on, color: Colors.white, size: 20.r),
            ),
            SizedBox(height: 4.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: victimColor,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Text(
                'NẠN NHÂN',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    ];

    // Volunteer marker (blue) — my location
    if (_myLat != null && _myLon != null) {
      markers.add(
        Marker(
          point: LatLng(_myLat!, _myLon!),
          width: 90.w,
          height: 90.w,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36.w,
                height: 36.w,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3.w),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.5),
                      blurRadius: 14.r,
                      spreadRadius: 3.r,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.person_pin_circle,
                  color: Colors.white,
                  size: 20.r,
                ),
              ),
              SizedBox(height: 4.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  'BẠN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8.sp,
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
    // Không chặn Back — TNV pop tự do, GPS vẫn chạy ngầm (ActiveMissionManager)
    // Việc hủy nhiệm vụ có nút riêng (_handleRevokeMission)
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildRecordingStatusBar(),
            _buildHeader(),
            Expanded(
              child: Stack(
                children: [
                  // ── Map full-bleed (nằm sau sheet — kéo sheet xuống lộ map, hết khoảng trắng) ──
                  FloodAidMap(
                    mapController: _mapController,
                    initialCenter: LatLng(_victimLat, _victimLon),
                    initialZoom: 14.0,
                    markers: _buildMarkers(),
                    polylines: _routePoints.length >= 2
                        ? [
                            Polyline(
                              points: _routePoints,
                              color: AppColors.primary,
                              strokeWidth: 4.0,
                            ),
                          ]
                        : null,
                    onMyLocationTap: _centerOnMe,
                  ),
                  // ── SOS Legend ──
                  Positioned(
                    left: 16.w,
                    top: 16.h,
                    child: const SosLegendWidget(),
                  ),
                  // ── Draggable Bottom Mission Board ──
                  _buildDraggableMissionBoard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingStatusBar() {
    // Fix #4: Chỉ hiện GPS recording khi đã accept
    final isTracking = _accepted;
    final bgColor = isTracking ? AppColors.alertRed : AppColors.primary;
    final statusText = isTracking
        ? (_wsConnected ? 'Đang Ghi GPS — WS Live' : 'Đang Ghi GPS — Cứu hộ')
        : '📋 Xem trước ca — Chưa nhận';

    return Container(
      color: bgColor,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(
        children: [
          // Nút back — pop tự do, GPS vẫn chạy ngầm
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Icon(Icons.arrow_back, color: Colors.white, size: 18.r),
          ),
          SizedBox(width: 12.w),
          if (isTracking)
            Container(
              width: 8.w,
              height: 8.w,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
          if (isTracking) SizedBox(width: 8.w),
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Nhiệm vụ Cứu hộ',
            style: AppTypography.headingMedium.copyWith(
              color: AppColors.alertRed,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraggableMissionBoard() {
    final urgency = widget.urgencyLevel ?? 3;
    final urgencyColor = getUrgencyColor(urgency);
    final distKm = _distanceKm;

    return DraggableScrollableSheet(
      initialChildSize: _initSheet,
      minChildSize: _minSheet,
      maxChildSize: _maxSheet,
      snap: true,
      snapSizes: [_minSheet, _initSheet, _maxSheet],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 24.r,
                offset: Offset(0, -8.h),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 24.h),
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  margin: EdgeInsets.only(bottom: 16.h),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBorder,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),

              // ── Header Row (Status) ──
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: urgencyColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(100.r),
                    border: Border.all(
                      color: urgencyColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8.w,
                        height: 8.w,
                        decoration: BoxDecoration(
                          color: urgencyColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'MỨC ĐỘ KHẨN CẤP: $urgency',
                        style: AppTypography.labelMedium.copyWith(
                          color: urgencyColor,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16.h),

              // Title / Summary
              Text(
                widget.summary ?? 'Yêu cầu cứu hộ khẩn cấp',
                style: AppTypography.headingMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 20.sp,
                  color: AppColors.textPrimary,
                  height: 1.3,
                ),
              ),

              // Địa chỉ nạn nhân (reverse-geocode / user nhập)
              if (widget.address != null && widget.address!.trim().isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 12.h),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 18.r,
                        color: AppColors.alertRed,
                      ),
                      SizedBox(width: 6.w),
                      Expanded(
                        child: Text(
                          widget.address!,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Full Description (nếu có và khác summary)
              if (widget.description != null &&
                  widget.description!.isNotEmpty &&
                  widget.description != widget.summary)
                Padding(
                  padding: EdgeInsets.only(top: 12.h),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: Text(
                      '"${widget.description}"',
                      style: AppTypography.bodyMedium.copyWith(
                        fontStyle: FontStyle.italic,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),

              SizedBox(height: 20.h),

              // Hero Metrics (Luôn hiển thị để TNV ước lượng) — ưu tiên quãng đường/ETA thật
              if (_displayDistanceText(distKm) != null)
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricBox(
                        'Khoảng cách',
                        _displayDistanceText(distKm)!,
                        Colors.blue.shade700,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: _buildMetricBox(
                        'Dự kiến tới',
                        _displayEtaText(distKm) ?? '—',
                        Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),

              SizedBox(height: 20.h),

              // ── Các nút liên lạc (CHỈ HIỂN THỊ KHI ĐÃ NHẬN CA) ──
              if (_accepted) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Nút Gọi điện
                    _buildCircleButton(
                      icon: Icons.phone_in_talk,
                      color: Colors.green.shade600,
                      iconColor: Colors.white,
                      tooltip: 'Gọi nạn nhân',
                      onTap: () async {
                        final raw = _victimPhone ?? widget.victimPhone ?? '';
                        debugPrint('[ActiveMission] Gọi điện: phone="$raw"');
                        if (raw.isEmpty) {
                          if (mounted) {
                            ToastService.show(
                              context: context,
                              type: ToastType.warning,
                              message: 'Chưa có số điện thoại nạn nhân.',
                            );
                          }
                          return;
                        }
                        final phone = _normalizePhone(raw);
                        final uri = Uri.parse('tel:$phone');
                        try {
                          await launchUrl(uri);
                        } catch (e) {
                          debugPrint('[ActiveMission] launchUrl error: $e');
                        }
                      },
                    ),
                    SizedBox(width: 20.w),
                    // Nút Chat
                    _buildCircleButton(
                      icon: Icons.chat_bubble_outline_rounded,
                      color: AppColors.primary,
                      iconColor: Colors.white,
                      tooltip: 'Chat',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            caseId: widget.caseId,
                            myRole: 'volunteer',
                            myId: _volunteerId,
                            peerPhone: _victimPhone ?? widget.victimPhone,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 20.w),
                    // Nút Chỉ đường
                    _buildCircleButton(
                      icon: Icons.directions,
                      color: Colors.amber.shade300,
                      iconColor: Colors.black87,
                      tooltip: 'Chỉ đường',
                      onTap: () async {
                        final Uri url = Uri.parse(
                          'https://www.google.com/maps/dir/?api=1&destination=$_victimLat,$_victimLon',
                        );
                        if (await canLaunchUrl(url)) {
                          await launchUrl(
                            url,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              const SizedBox(height: 16),

              // ── Action Slider (nằm trong ListView, cuộn/kéo cùng nội dung) ──
              if (!_accepted)
                SlideToConfirm(
                  key: const ValueKey('slider_accept'),
                  text: 'TRƯỢT ĐỂ NHẬN CA',
                  isLoading: _accepted,
                  onConfirm: _handleAcceptCase,
                ),
              if (_accepted)
                SlideToConfirm(
                  key: const ValueKey('slider_resolve'),
                  text: 'TRƯỢT ĐỂ ĐÓNG CA',
                  isLoading: _isResolving,
                  onConfirm: () async {
                    await _handleResolve();
                  },
                ),
              if (_accepted) ...[
                SizedBox(height: 16.h),
                Center(
                  child: TextButton(
                    onPressed: _isRevoking ? null : _handleRevokeMission,
                    child: Text(
                      _isRevoking
                          ? 'Đang hủy...'
                          : 'Tôi không thể tiếp tục, hủy nhiệm vụ',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12.sp,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricBox(String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: AppTypography.displayMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 20.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required Color color,
    required Color iconColor,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 50.w,
        height: 50.w,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            shape: const CircleBorder(),
            padding: EdgeInsets.zero,
            elevation: 2,
          ),
          child: Icon(icon, color: iconColor, size: 24.r),
        ),
      ),
    );
  }

  String _formatEta(double distKm) {
    final etaMins = (distKm / 4 * 60).ceil();
    if (etaMins < 60) return '$etaMins phút';
    return '${(etaMins / 60).floor()}h${etaMins % 60 > 0 ? '${etaMins % 60}p' : ''}';
  }

  /// Quãng đường (mét) dùng để hiển thị, theo thứ tự ưu tiên:
  /// 1) Đã nhận ca + có route thật (Route v4) → quãng đường theo đường đi.
  /// 2) Có số chim bay từ màn danh sách (initialDistanceM) → dùng để KHỚP với list.
  /// 3) Tự tính chim bay từ GPS hiện tại (fallback cuối).
  int? _effectiveDistanceM(double? distKm) {
    if (_accepted && _routeDistanceM != null) return _routeDistanceM;
    if (widget.initialDistanceM != null) return widget.initialDistanceM;
    if (distKm != null) return (distKm * 1000).round();
    return null;
  }

  /// Chuỗi khoảng cách hiển thị (khớp màn danh sách khi chưa nhận ca).
  String? _displayDistanceText(double? distKm) {
    final m = _effectiveDistanceM(distKm);
    if (m == null) return null;
    return m >= 1000 ? '${(m / 1000).toStringAsFixed(1)} km' : '$m m';
  }

  /// Chuỗi ETA hiển thị: ưu tiên thời gian THẬT (Route v4) khi đã nhận ca,
  /// còn lại ước tính từ cùng khoảng cách + cùng công thức với màn danh sách.
  String? _displayEtaText(double? distKm) {
    if (_accepted && _etaSec != null) {
      final m = (_etaSec! / 60).round();
      if (m < 1) return 'Sắp tới';
      if (m < 60) return '$m phút';
      return '${m ~/ 60}h${m % 60 > 0 ? '${m % 60}p' : ''}';
    }
    final distM = _effectiveDistanceM(distKm);
    if (distM != null) return _formatEta(distM / 1000);
    return null;
  }
}
