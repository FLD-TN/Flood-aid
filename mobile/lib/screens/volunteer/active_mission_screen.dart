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
import '../../widgets/slide_to_confirm.dart';

class ActiveMissionScreen extends StatefulWidget {
  final String caseId;
  final double? victimLat;
  final double? victimLon;
  final String? summary;
  final String? description;
  final int? urgencyLevel;
  final String? victimPhone;

  const ActiveMissionScreen({
    super.key,
    required this.caseId,
    this.victimLat,
    this.victimLon,
    this.summary,
    this.description,
    this.urgencyLevel,
    this.victimPhone,
  });

  @override
  State<ActiveMissionScreen> createState() => _ActiveMissionScreenState();
}

class _ActiveMissionScreenState extends State<ActiveMissionScreen> {
  final MapController _mapController = MapController();
  final ActiveMissionManager _manager = ActiveMissionManager();

  // TNV (volunteer) location — realtime GPS
  double? _myLat;
  double? _myLon;

  // Victim location
  late double _victimLat;
  late double _victimLon;

  // Volunteer UUID (loaded from SharedPreferences)
  String _volunteerId = '';

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

    // Timer local — chỉ để cập nhật vị trí TNV trên bản đồ (UI)
    _localGpsTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _getMyLocation();
    });
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
    final baseUrl = kIsWeb ? 'http://127.0.0.1:3000' : 'https://floodaid.onrender.com';
    final client = http.Client();
    final request = http.Request('GET', Uri.parse('$baseUrl/api/case/${widget.caseId}/stream'));
    
    client.send(request).then((response) {
      _sseSub = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
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
      }, onError: (e) {
        debugPrint('[ActiveMission] SSE error: $e');
      });
    }).catchError((e) {
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

    final result = await ApiService.checkMyAssignment(widget.caseId, volunteerId);
    if (result == null || !mounted) return;

    final isAssigned = result['isAssigned'] == true;
    final caseStatus = result['caseStatus'] as String? ?? '';

    if (isAssigned && caseStatus == 'responding') {
      // TNV đã nhận ca này trước đó → khôi phục trạng thái qua Manager
      debugPrint('[ActiveMission] Restored accepted state for case ${widget.caseId}');
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
      urgencyLevel: widget.urgencyLevel,
      victimPhone: widget.victimPhone,
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
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
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
    final assignment = await ApiService.checkMyAssignment(widget.caseId, _volunteerId);
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
      final success = await ApiService.acceptCase(
        widget.caseId,
        volunteerId,
        lat: _myLat,
        lon: _myLon,
      );
      if (!success && mounted) {
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
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

  /// Fix #6: Hiện confirmation dialog trước khi đóng ca
  void _handleResolveWithConfirm() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận đóng ca'),
        content: const Text(
          'Bạn đã tiếp cận và hỗ trợ nạn nhân thành công?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _handleResolve();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
            ),
            child: const Text(
              'Xác nhận đóng ca ✓',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /// Fix #5: Dialog tạm cho nút "Báo chướng ngại"
  void _handleReportObstacle() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.alertRed),
            SizedBox(width: 8),
            Text('Báo chướng ngại'),
          ],
        ),
        content: const Text(
          'Tính năng báo chướng ngại vật (đường ngập, cầu sập...) đang được phát triển.\n\n'
          'Hiện tại bạn có thể gọi điện trực tiếp cho nạn nhân để thông báo tình hình.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
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

  void _centerOnVictim() {
    _mapController.move(LatLng(_victimLat, _victimLon), 14.0);
  }

  void _centerOnMe() {
    if (_myLat != null && _myLon != null) {
      _mapController.move(LatLng(_myLat!, _myLon!), 15.0);
    }
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[
      // Victim marker (red)
      Marker(
        point: LatLng(_victimLat, _victimLon),
        width: 90,
        height: 90,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.alertRed,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.alertRed.withOpacity(0.5),
                    blurRadius: 14,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: const Icon(Icons.location_on, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.alertRed,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'NẠN NHÂN',
                style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
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
          width: 90,
          height: 90,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.5),
                      blurRadius: 14,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: const Icon(Icons.person_pin_circle, color: Colors.white, size: 20),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'BẠN',
                  style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
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
                  // ── Map (full area with padding) ──
                  Padding(
                    padding: EdgeInsets.only(bottom: _accepted ? 320 : 250),
                    child: FloodAidMap(
                      mapController: _mapController,
                      initialCenter: LatLng(_victimLat, _victimLon),
                      initialZoom: 14.0,
                      markers: _buildMarkers(),
                      onMyLocationTap: _centerOnMe,
                    ),
                  ),
                  // ── SOS Legend ──
                  Positioned(
                    left: 16,
                    top: 16,
                    child: const SosLegendWidget(),
                  ),
                  // ── Fixed Bottom Mission Board ──
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: _buildFixedMissionBoard(),
                  ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Nút back — pop tự do, GPS vẫn chạy ngầm
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          if (isTracking)
            Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
          if (isTracking) const SizedBox(width: 8),
          Expanded(
            child: Text(
              statusText,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

  /// Ẩn SĐT: 0901234567 → 090 •••• 567
  String _maskPhone(String phone) {
    if (phone.length >= 6) {
      return '${phone.substring(0, 3)} •••• ${phone.substring(phone.length - 3)}';
    }
    return '••••••••';
  }

  Widget _buildFixedMissionBoard() {
    final urgency = widget.urgencyLevel ?? 3;
    final urgencyColor = getUrgencyColor(urgency);
    final distKm = _distanceKm;

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.65,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Row (Status) ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: urgencyColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: urgencyColor.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: urgencyColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'MỨC ĐỘ KHẨN CẤP: $urgency',
                      style: AppTypography.labelMedium.copyWith(
                        color: urgencyColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Hồ sơ Chi tiết (Cuộn được nếu quá dài) ──
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title / Summary
                      Text(
                        widget.summary ?? 'Yêu cầu cứu hộ khẩn cấp',
                        style: AppTypography.headingMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: AppColors.textPrimary,
                          height: 1.3,
                        ),
                      ),
                      
                      // Full Description (nếu có và khác summary)
                      if (widget.description != null && widget.description!.isNotEmpty && widget.description != widget.summary)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(12),
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

                      const SizedBox(height: 20),

                      // Hero Metrics (Luôn hiển thị để TNV ước lượng)
                      if (distKm != null)
                        Row(
                          children: [
                            Expanded(
                              child: _buildMetricBox(
                                'Khoảng cách',
                                distKm >= 1 ? '${distKm.toStringAsFixed(1)} km' : '${(distKm * 1000).toInt()} m',
                                Colors.blue.shade700,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildMetricBox(
                                'Dự kiến tới',
                                _formatEta(distKm),
                                Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ),

                      const SizedBox(height: 20),

                      // ── Các nút liên lạc (CHỈ HIỂN THỊ KHI ĐÃ NHẬN CA) ──
                      if (_accepted) ...[
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final phone = widget.victimPhone ?? '';
                                  if (phone.isEmpty) return;
                                  final Uri url = Uri(scheme: 'tel', path: phone);
                                  if (await canLaunchUrl(url)) {
                                    await launchUrl(url);
                                  }
                                },
                                icon: const Icon(Icons.phone, color: Colors.white, size: 16),
                                label: Text(
                                  widget.victimPhone != null ? widget.victimPhone! : 'Gọi',
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade600,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final Uri url = Uri.parse(
                                    'https://www.google.com/maps/dir/?api=1&destination=$_victimLat,$_victimLon',
                                  );
                                  if (await canLaunchUrl(url)) {
                                    await launchUrl(url, mode: LaunchMode.externalApplication);
                                  }
                                },
                                icon: const Icon(Icons.directions, color: Colors.white, size: 16),
                                label: const Text(
                                  'Chỉ đường',
                                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade600,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Action Slider ──
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

              // ── Nút Hủy phụ khi đã nhận ca ──
              if (_accepted) ...[
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: _isRevoking ? null : _handleRevokeMission,
                    child: Text(
                      _isRevoking ? 'Đang hủy...' : 'Tôi không thể tiếp tục, hủy nhiệm vụ',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.1)),
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
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.displayMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }

  String _formatEta(double distKm) {
    final etaMins = (distKm / 4 * 60).ceil();
    if (etaMins < 60) return '$etaMins phút';
    return '${(etaMins / 60).floor()}h${etaMins % 60 > 0 ? '${etaMins % 60}p' : ''}';
  }
}
