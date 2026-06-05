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

  // Draggable sheet controller
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

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
    _sheetController.dispose();
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
                  // ── Map (full area) ──
                  FloodAidMap(
                    mapController: _mapController,
                    initialCenter: LatLng(_victimLat, _victimLon),
                    initialZoom: 14.0,
                    markers: _buildMarkers(),
                    onMyLocationTap: _centerOnMe,
                  ),
                  // ── SOS Legend ──
                  Positioned(
                    left: 16,
                    top: 16,
                    child: const SosLegendWidget(),
                  ),
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

  Widget _buildDraggableSheet() {
    final urgency = widget.urgencyLevel ?? 3;
    final urgencyColor = getUrgencyColor(urgency);
    final distKm = _distanceKm;

    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.35,
      minChildSize: 0.08,
      maxChildSize: 0.65,
      snap: true,
      snapSizes: const [0.08, 0.35, 0.65],
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
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            children: [
              // ── Drag handle ──
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Mini summary (visible when collapsed) — Fix #8: không trùng lặp ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: urgencyColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'MỨC $urgency',
                        style: const TextStyle(
                          color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (distKm != null)
                      Text(
                        distKm >= 1
                            ? 'Còn ${distKm.toStringAsFixed(1)}km'
                            : 'Còn ${(distKm * 1000).toInt()}m',
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    const Spacer(),
                    Text(
                      _accepted ? '✅ Đã nhận' : '⏳ Chưa nhận',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _accepted ? AppColors.success : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_up, color: AppColors.textMuted, size: 20),
                  ],
                ),
              ),

              const Divider(height: 1),

              // ── Full content ──
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Tóm tắt AI (không lặp badge MỨC — badge đã có ở mini summary)
                    Text(
                      widget.summary ?? 'Ca SOS',
                      style: AppTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Lời kêu cứu gốc (nguyên văn user nhập)
                    if (widget.description != null && widget.description!.isNotEmpty && widget.description != widget.summary)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border(
                              left: BorderSide(color: urgencyColor.withOpacity(0.5), width: 3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Lời kêu cứu gốc:',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '"${widget.description}"',
                                style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Khoảng cách + ETA
                    if (distKm != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            // Khoảng cách
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(Icons.straighten, size: 18, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    distKm >= 1
                                        ? '${distKm.toStringAsFixed(1)} km'
                                        : '${(distKm * 1000).toInt()}m',
                                    style: AppTypography.bodyMedium.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 20, color: Colors.grey.shade200),
                            const SizedBox(width: 12),
                            // ETA
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(Icons.timer_outlined, size: 18, color: Colors.orange.shade600),
                                  const SizedBox(width: 8),
                                  Builder(builder: (_) {
                                    final etaMins = (distKm! / 4 * 60).ceil();
                                    final etaStr = etaMins < 60
                                        ? '~$etaMins phút'
                                        : '~${(etaMins / 60).floor()}h${etaMins % 60 > 0 ? '${etaMins % 60}p' : ''}';
                                    return Text(
                                      etaStr,
                                      style: AppTypography.bodyMedium.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    // SĐT nạn nhân (ẩn/hiện theo trạng thái)
                    if (widget.victimPhone != null && widget.victimPhone!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: _accepted ? Colors.green.shade50 : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _accepted ? Icons.phone : Icons.phone_locked,
                                size: 16,
                                color: _accepted ? Colors.green.shade600 : Colors.grey.shade400,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _accepted
                                    ? widget.victimPhone!
                                    : _maskPhone(widget.victimPhone!),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _accepted ? Colors.green.shade700 : Colors.grey.shade500,
                                  letterSpacing: _accepted ? 0.5 : 1.5,
                                ),
                              ),
                              const Spacer(),
                              if (!_accepted)
                                Text(
                                  'Nhận ca để xem',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade400,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                    // Case ID
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.tag, size: 12, color: AppColors.textMuted),
                          const SizedBox(width: 6),
                          Text(
                            'Ca: ${widget.caseId.length > 8 ? widget.caseId.substring(0, 8).toUpperCase() : widget.caseId.toUpperCase()}',
                            style: AppTypography.mono.copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Action Buttons
                    if (!_accepted)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _handleAcceptCase,
                          icon: const Icon(Icons.check, color: Colors.white, size: 18),
                          label: const Text(
                            'Nhận ca cứu hộ',
                            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    if (_accepted) ...[
                      // Fix #7: Nút Gọi + Maps chỉ hiện SAU KHI accept
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
                              label: const Text(
                                'Gọi nạn nhân',
                                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade400,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
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
                                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade400,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Fix #5 + #6: Nút chính sau accept
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _handleReportObstacle,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: const BorderSide(color: AppColors.alertRed),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text(
                                'Báo chướng ngại',
                                style: TextStyle(
                                  color: AppColors.alertRed, fontSize: 12, fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isResolving ? null : _handleResolveWithConfirm,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isResolving ? Colors.grey : AppColors.success,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _isResolving
                                  ? const SizedBox(
                                      width: 18, height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Tiếp cận xong',
                                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // ── Nút Hủy Nhiệm Vụ ──
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isRevoking ? null : _handleRevokeMission,
                          icon: _isRevoking
                              ? const SizedBox(
                                  width: 14, height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey),
                                )
                              : Icon(Icons.cancel_outlined, size: 16, color: Colors.grey.shade600),
                          label: Text(
                            _isRevoking ? 'Đang hủy...' : 'Hủy nhiệm vụ',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            side: BorderSide(color: Colors.grey.shade400),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
