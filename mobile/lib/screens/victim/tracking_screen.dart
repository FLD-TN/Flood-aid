import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_theme.dart';
import '../../services/toast_service.dart';
import '../../services/api_service.dart';
import '../../services/sse_service.dart';
import '../../services/ws_gps_service.dart';
import '../../widgets/map_widget.dart';
import '../../widgets/sos_legend_widget.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../widgets/slide_to_confirm.dart';
import 'package:lottie/lottie.dart' hide Marker;

class TrackingScreen extends StatefulWidget {
  final String caseId;
  final double? victimLat;
  final double? victimLon;

  const TrackingScreen({
    super.key,
    required this.caseId,
    this.victimLat,
    this.victimLon,
  });

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  StreamSubscription<SseEvent>? _sseSubscription;
  WsGpsService? _wsGpsService;
  final MapController _mapController = MapController();

  // State from API
  String _status = 'pending';
  int? _distanceM;
  double? _tnvLat;
  double? _tnvLon;
  bool _hasVolunteer = false;
  bool _isResolving = false;
  bool _isCancelling = false;
  bool _isExpanded = true;

  // Victim position
  late double _victimLat;
  late double _victimLon;

  @override
  void initState() {
    super.initState();
    _victimLat = widget.victimLat ?? 16.0544;
    _victimLon = widget.victimLon ?? 108.2022;

    // SSE: listen for case status changes (replaces status polling)
    _startSseListener();

    // Initial fetch of TNV location (one-time, then WS takes over)
    _fetchInitialTnvLocation();
  }

  @override
  void dispose() {
    _sseSubscription?.cancel();
    _wsGpsService?.dispose();
    super.dispose();
  }

  /// Fetch TNV location once on startup
  Future<void> _fetchInitialTnvLocation() async {
    final data = await ApiService.getTnvLocation(widget.caseId);
    if (data != null && mounted) {
      setState(() {
        _distanceM = data['distance_m'] != null
            ? (data['distance_m'] as num).toInt()
            : null;
        _tnvLat = data['lat'] != null ? (data['lat'] as num).toDouble() : null;
        _tnvLon = data['lon'] != null ? (data['lon'] as num).toDouble() : null;
        _hasVolunteer = data['has_volunteer'] == true;
        // Also update status from initial fetch
        final fetchedStatus = data['status'] as String?;
        if (fetchedStatus != null) {
          _status = fetchedStatus;
          // If already responding, start WS GPS immediately
          if (_status == 'responding' && _hasVolunteer) {
            _startWsGps();
          }
        }
      });
    }
  }

  /// Start WebSocket GPS receiver (called when case becomes 'responding')
  void _startWsGps() {
    if (_wsGpsService != null) return; // Already started

    _wsGpsService = WsGpsService(
      onGpsReceived: (data) {
        if (!mounted) return;
        setState(() {
          if (data['lat'] != null) {
            _tnvLat = (data['lat'] as num).toDouble();
          }
          if (data['lon'] != null) {
            _tnvLon = (data['lon'] as num).toDouble();
          }
          if (data['distance_m'] != null) {
            _distanceM = (data['distance_m'] as num).toInt();
          }
          _hasVolunteer = true;
        });
      },
      onConnectionChanged: (connected) {
        debugPrint('[TrackingScreen] WS GPS ${connected ? 'connected' : 'disconnected'}');
      },
    );

    _wsGpsService!.connect(
      caseId: widget.caseId,
      role: 'victim',
    );
  }

  /// SSE listener for case status events (case:accepted, case:resolved, etc.)
  void _startSseListener() {
    _sseSubscription = SseService.listenCaseEvents(widget.caseId).listen(
      (event) {
        if (!mounted) return;
        switch (event.event) {
          case 'case:accepted':
            setState(() {
              _status = 'responding';
              _hasVolunteer = true;
              if (event.data['initialDistance'] != null) {
                _distanceM = (event.data['initialDistance'] as num).toInt();
              }
            });
            // Start WS GPS to receive TNV location in real-time
            _startWsGps();
            break;
          case 'case:resolved':
            // Another party resolved the case — navigate back
            _wsGpsService?.dispose();
            if (mounted) {
              ToastService.show(
                context: context,
                type: ToastType.success,
                message: 'Ca SOS đã được đóng.',
              );
              Navigator.pop(context);
            }
            break;
          case 'case:revoked':
            // TNV đã hủy nhiệm vụ
            final remainingCount = event.data['remainingCount'] as int? ?? 0;
            final newStatus = event.data['status'] as String? ?? 'pending';
            if (remainingCount == 0) {
              // Không còn TNV nào → trở về trạng thái chờ
              _wsGpsService?.dispose();
              _wsGpsService = null;
              setState(() {
                _status = newStatus; // 'pending'
                _hasVolunteer = false;
                _tnvLat = null;
                _tnvLon = null;
                _distanceM = null;
              });
              if (mounted) {
                ToastService.show(
                  context: context,
                  type: ToastType.warning,
                  message: 'Tình nguyện viên đã hủy. Đang tìm người khác...',
                );
              }
            }
            break;
          case 'case:cancelled':
            // Ca bị huỷ (từ thiết bị khác hoặc Admin)
            _wsGpsService?.dispose();
            if (mounted) {
              ToastService.show(
                context: context,
                type: ToastType.warning,
                message: 'Ca SOS đã bị huỷ.',
              );
              Navigator.pop(context);
            }
            break;
          case 'case:orphaned':
            setState(() {
              _status = 'orphaned';
            });
            break;
        }
      },
      onError: (e) {
        print('[TrackingScreen] SSE error: $e');
      },
    );
  }

  Future<void> _handleResolve() async {
    if (_isResolving) return;
    // Optimistic: show resolved state immediately
    final prevStatus = _status;
    setState(() {
      _status = 'resolved';
      _isResolving = true;
    });
    try {
      final success = await ApiService.resolveCase(widget.caseId, 'victim');
      if (success && mounted) {
        Navigator.pop(context);
      } else if (mounted) {
        // Rollback
        setState(() {
          _status = prevStatus;
          _isResolving = false;
        });
        ToastService.show(
          context: context,
          type: ToastType.error,
          message: 'Đóng ca thất bại. Thử lại sau.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = prevStatus;
          _isResolving = false;
        });
        ToastService.show(
          context: context,
          type: ToastType.error,
          message: 'Lỗi mạng. Thử lại sau.',
        );
      }
    }
  }

  /// Fix #4: Confirmation dialog trước khi nạn nhân đóng ca
  void _handleResolveWithConfirm() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận an toàn'),
        content: Text(
          _hasVolunteer
              ? 'Đội cứu hộ đang trên đường đến bạn.\n\nBạn chắc chắn đã an toàn và không cần hỗ trợ nữa?'
              : 'Bạn xác nhận đã an toàn và không cần hỗ trợ nữa?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tôi vẫn cần giúp đỡ'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _handleResolve();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text(
              'Xác nhận — Tôi đã an toàn ✓',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /// Huỷ ca SOS — Gọi API cancel
  Future<void> _handleCancel({String? reason}) async {
    if (_isCancelling) return;
    setState(() => _isCancelling = true);
    try {
      final success = await ApiService.cancelSos(widget.caseId, reason: reason);
      if (success && mounted) {
        _wsGpsService?.dispose();
        ToastService.show(
          context: context,
          type: ToastType.info,
          message: 'Đã huỷ tín hiệu SOS.',
        );
        Navigator.pop(context);
      } else if (mounted) {
        setState(() => _isCancelling = false);
        ToastService.show(
          context: context,
          type: ToastType.error,
          message: 'Huỷ ca thất bại. Thử lại sau.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCancelling = false);
        ToastService.show(
          context: context,
          type: ToastType.error,
          message: 'Lỗi mạng. Thử lại sau.',
        );
      }
    }
  }

  /// Popup xác nhận huỷ ca SOS (2 bước an toàn)
  void _handleCancelWithConfirm() {
    final hasVolunteerWarning = _hasVolunteer && _status == 'responding';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.alertRed, size: 24),
            const SizedBox(width: 8),
            const Text('Huỷ tín hiệu SOS?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasVolunteerWarning) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFBBF24)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.directions_boat, color: Color(0xFFD97706), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Đội cứu hộ đang trên đường đến bạn!',
                        style: TextStyle(
                          color: const Color(0xFF92400E),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              hasVolunteerWarning
                ? 'Nếu bạn huỷ bây giờ, đội cứu hộ sẽ ngừng di chuyển đến vị trí của bạn.\n\nBạn có chắc chắn muốn huỷ?'
                : 'Tín hiệu SOS sẽ bị gỡ khỏi hệ thống.\n\nNếu bạn cần giúp đỡ lại, hãy tạo tín hiệu mới.',
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Giữ lại',
              style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _handleCancel(reason: hasVolunteerWarning ? 'Huỷ khi TNV đang đến' : 'Nạn nhân tự huỷ');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.alertRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text(
              'Xác nhận huỷ',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  /// Fix #5: Guard nút back khi TNV đang đến
  Future<bool> _onWillPop() async {
    if (_status == 'responding' && _hasVolunteer) {
      final shouldPop = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Đội cứu hộ đang đến!'),
          content: const Text(
            'Tình nguyện viên đang trên đường đến bạn.\n\n'
            'Nếu rời trang này, bạn sẽ không theo dõi được vị trí cứu hộ. '
            'Bạn có chắc muốn rời đi?',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.alertRed,
              ),
              child: const Text(
                'Ở lại theo dõi',
                style: TextStyle(color: Colors.white),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Rời đi'),
            ),
          ],
        ),
      );
      return shouldPop ?? false;
    }
    return true;
  }

  StatusConfig get _statusConfig {
    if (_status == 'responding' && _distanceM != null && _distanceM! < 100) {
      return getStatusConfig('on_scene');
    }
    if (_status == 'responding' && _distanceM != null && _distanceM! < 300) {
      return getStatusConfig('near');
    }
    return getStatusConfig(_status, distanceM: _distanceM);
  }

  void _centerOnVictim() {
    _mapController.move(LatLng(_victimLat, _victimLon), 15.0);
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[
      // Victim marker (red)
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
                color: AppColors.alertRed,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.alertRed.withValues(alpha: 0.4),
                    blurRadius: 12.r,
                    spreadRadius: 2.r,
                  ),
                ],
              ),
              child: Icon(Icons.person, color: AppColors.alertRed, size: 20.r),
            ),
            SizedBox(height: 6.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4.r,
                    offset: Offset(0, 2.h),
                  ),
                ],
              ),
              child: Text(
                'Vị trí của bạn',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    ];

    // TNV marker (blue) — only show when volunteer is assigned
    if (_hasVolunteer && _tnvLat != null && _tnvLon != null) {
      markers.add(
        Marker(
          point: LatLng(_tnvLat!, _tnvLon!),
          width: 90.w,
          height: 110.w,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 52.w,
                height: 52.w,
                child: Image.asset(
                  'assets/images/tnv_boat.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.local_shipping_rounded,
                      color: AppColors.primary,
                      size: 24.r,
                    );
                  },
                ),
              ),
              SizedBox(height: 6.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20.r),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 6.r,
                      offset: Offset(0, 2.h),
                    ),
                  ],
                ),
                child: Text(
                  'Đội Cứu Hộ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.sp,
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

  /// Fix #8: Tính ETA ước tính dựa trên khoảng cách
  /// Tốc độ trung bình xuồng cứu hộ vùng ngập ~15km/h
  String _calculateEta(int distanceMeters) {
    const double avgSpeedKmh = 15.0; // km/h trung bình vùng ngập
    final double distanceKm = distanceMeters / 1000.0;
    final double etaMinutes = (distanceKm / avgSpeedKmh) * 60;

    if (etaMinutes < 1) {
      return '⏱ Sắp đến nơi!';
    } else if (etaMinutes < 60) {
      return '⏱ Ước tính ~${etaMinutes.ceil()} phút nữa';
    } else {
      final hours = (etaMinutes / 60).floor();
      final mins = (etaMinutes % 60).ceil();
      return '⏱ Ước tính ~${hours}h${mins > 0 ? '${mins}p' : ''} nữa';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !(_status == 'responding' && _hasVolunteer),
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final canPop = await _onWillPop();
        if (canPop && mounted) Navigator.pop(context);
      },
      child: Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Stack(
                children: [
                  // ── Map (full screen) ──
                  FloodAidMap(
                    mapController: _mapController,
                    initialCenter: LatLng(_victimLat, _victimLon),
                    initialZoom: 15.0,
                    markers: _buildMarkers(),
                    onMyLocationTap: _centerOnVictim,
                  ),
                  // ── SOS Legend ──
                  Positioned(
                    left: 16.w,
                    top: 16.h,
                    child: const SosLegendWidget(),
                  ),
                  // ── Fixed Bottom Status Board ──
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(right: 16.w, bottom: 16.h),
                          child: GestureDetector(
                            onTap: () => setState(() => _isExpanded = !_isExpanded),
                            child: Container(
                              width: 44.w,
                              height: 44.w,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 8.r,
                                    offset: Offset(0, 2.h),
                                  ),
                                ],
                              ),
                              child: Icon(
                                _isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                                color: AppColors.alertRed,
                                size: 28.r,
                              ),
                            ),
                          ),
                        ),
                        _buildFixedStatusBoard(),
                      ],
                    ),
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

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              // Fix #5: Guard back button
              final canPop = await _onWillPop();
              if (canPop && mounted) Navigator.pop(context);
            },
            child: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          ),
          const Spacer(),
          Text(
            'Theo dõi Ca SOS',
            style: AppTypography.headingMedium.copyWith(
              color: AppColors.alertRed,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          // Live indicator
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: AppColors.alertRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6.w,
                  height: 6.w,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.alertRed,
                  ),
                ),
                SizedBox(width: 4.w),
                Text(
                  'LIVE',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.alertRed,
                    fontWeight: FontWeight.bold,
                    fontSize: 10.sp,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFixedStatusBoard() {
    final config = _statusConfig;
    
    // Tạo Icon tương ứng với status thay vì dùng Emoji
    IconData statusIcon = Icons.search;
    if (_status == 'pending') statusIcon = Icons.radar;
    if (_status == 'responding' || _status == 'near' || _status == 'on_scene') statusIcon = Icons.local_shipping_rounded;
    if (_status == 'resolved') statusIcon = Icons.check_circle_rounded;

    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! > 0) {
            // Dragged down -> collapse
            if (_isExpanded) setState(() => _isExpanded = false);
          } else if (details.primaryVelocity! < 0) {
            // Dragged up -> expand
            if (!_isExpanded) setState(() => _isExpanded = true);
          }
        }
      },
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.5,
        ),
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
        child: ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 24.h),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Drag Handle ──
                    Center(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 16.h),
                        child: Container(
                          width: 40.w,
                          height: 5.h,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                        ),
                      ),
                    ),

                    if (!_hasVolunteer) ...[
                      // Lottie animation centered
                      if (_isExpanded) ...[
                        Center(
                          child: Lottie.asset(
                            'assets/lottie/waiting_sos.json',
                            width: 110.w,
                            height: 110.w,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 120.w,
                                height: 120.w,
                                decoration: BoxDecoration(
                                  color: AppColors.alertRed.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.sos, size: 50.w, color: AppColors.alertRed),
                              );
                            },
                          ),
                        ),
                        SizedBox(height: 16.h),
                      ],
                      
                      Text(
                        'Đang tìm kiếm Đội Cứu Hộ...',
                        style: AppTypography.headingLarge.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      if (_isExpanded) ...[
                        SizedBox(height: 8.h),
                        Text(
                          'Hệ thống đang quét các đội cứu hộ gần nhất trong khu vực.',
                          style: AppTypography.bodyMedium.copyWith(height: 1.5, color: AppColors.textMuted),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 24.h),
                        SlideToConfirm(
                          text: 'VUỐT ĐỂ HUỶ SOS',
                          isLoading: _isCancelling,
                          onConfirm: () async {
                            _handleCancelWithConfirm();
                          },
                        ),
                      ],
                    ] else ...[
                      // ── Status Badge ──
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                        decoration: BoxDecoration(
                          color: config.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(100.r),
                          border: Border.all(color: config.color.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, color: config.color, size: 20.r),
                            SizedBox(width: 8.w),
                            Text(
                              _status == 'pending' ? 'Đang tìm kiếm cứu hộ' : 'Đội cứu hộ đang đến',
                              style: AppTypography.labelMedium.copyWith(
                                color: config.color,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24.h),

                      // ── Hero Metrics (Chỉ hiện khi có TNV) ──
                      if (_hasVolunteer && _distanceM != null)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Thời gian dự kiến',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.textMuted,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    _calculateEta(_distanceM!).replaceAll('⏱ ', '').replaceAll(' Ước tính ~', ''),
                                    style: AppTypography.displayMedium.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 32.sp,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Khoảng cách',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  _distanceM! >= 1000
                                      ? '${(_distanceM! / 1000).toStringAsFixed(1)} km'
                                      : '$_distanceM m',
                                  style: AppTypography.headingLarge.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                      if (_isExpanded) ...[
                        const SizedBox(height: 32),

                        // ── Resolve Slider ──
                        SlideToConfirm(
                          text: 'VUỐT ĐỂ XÁC NHẬN AN TOÀN',
                          isLoading: _isResolving,
                          onConfirm: () async {
                            await _handleResolve();
                          },
                        ),

                        SizedBox(height: 16.h),

                        // ── Cancel Button ──
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: _isCancelling ? null : _handleCancelWithConfirm,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 14.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                            child: _isCancelling
                              ? SizedBox(
                                  width: 20.w, height: 20.w,
                                  child: const CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(
                                  'Huỷ tín hiệu SOS',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14.sp,
                                  ),
                                ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
