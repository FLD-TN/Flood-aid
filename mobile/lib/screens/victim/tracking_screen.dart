import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/sse_service.dart';
import '../../services/ws_gps_service.dart';
import '../../widgets/map_widget.dart';
import '../../widgets/sos_legend_widget.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

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

  // Victim position
  late double _victimLat;
  late double _victimLon;

  // Draggable sheet controller
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  @override
  void initState() {
    super.initState();
    _victimLat = widget.victimLat ?? 16.0544;
    _victimLon = widget.victimLon ?? 108.2022;

    _sheetController.addListener(() {
      if (mounted) setState(() {});
    });

    // SSE: listen for case status changes (replaces status polling)
    _startSseListener();

    // Initial fetch of TNV location (one-time, then WS takes over)
    _fetchInitialTnvLocation();
  }

  @override
  void dispose() {
    _sseSubscription?.cancel();
    _wsGpsService?.dispose();
    _sheetController.dispose();
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Ca SOS đã được đóng.'),
                  backgroundColor: Colors.green,
                ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đóng ca thất bại. Thử lại sau.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = prevStatus;
          _isResolving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lỗi mạng. Thử lại sau.'),
            backgroundColor: Colors.redAccent,
          ),
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
        width: 90,
        height: 90,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.alertRed,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.alertRed.withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 18),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.alertRed,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Bạn',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
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
          width: 90,
          height: 90,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.directions_boat,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Cứu hộ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  double sheetSize = 0.35;
                  if (_sheetController.isAttached) {
                    sheetSize = _sheetController.size;
                  }

                  final isExpanded = sheetSize > 0.2;

                  return Stack(
                    children: [
                      // ── Map (full area) ──
                      FloodAidMap(
                        mapController: _mapController,
                        initialCenter: LatLng(_victimLat, _victimLon),
                        initialZoom: 15.0,
                        markers: _buildMarkers(),
                        onMyLocationTap: _centerOnVictim,
                      ),
                      // ── SOS Legend ──
                      Positioned(
                        left: 16,
                        top: 16,
                        child: const SosLegendWidget(),
                      ),
                      // ── Floating Arrow Button ──
                      Positioned(
                        right: 16,
                        bottom: constraints.maxHeight * sheetSize + 16,
                        child: GestureDetector(
                          onTap: () {
                            if (isExpanded) {
                              _sheetController.animateTo(
                                0.15,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            } else {
                              _sheetController.animateTo(
                                0.65,
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.alertRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.alertRed,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'LIVE',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.alertRed,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraggableSheet() {
    final config = _statusConfig;

    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.35,
      minChildSize: 0.15,
      maxChildSize: 0.65,
      snap: true,
      snapSizes: const [0.15, 0.35, 0.65],
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
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Full content ──
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Status banner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: config.color.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: config.color.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            config.emoji,
                            style: const TextStyle(fontSize: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              config.message,
                              style: AppTypography.bodyMedium.copyWith(
                                color: config.color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Distance info (only when volunteer assigned)
                    if (_hasVolunteer && _distanceM != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.directions_walk,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _distanceM! >= 1000
                                        ? 'Cứu hộ cách bạn ~${(_distanceM! / 1000).toStringAsFixed(1)}km'
                                        : 'Cứu hộ cách bạn ~${_distanceM}m',
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  // Fix #8: Hiển thị ETA ước tính
                                  // Tốc độ trung bình xuồng cứu hộ vùng ngập ~15km/h
                                  Text(
                                    _calculateEta(_distanceM!),
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Case ID
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.tag, size: 14, color: AppColors.textMuted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Ca: ${widget.caseId.substring(0, widget.caseId.length > 8 ? 8 : widget.caseId.length).toUpperCase()}',
                              style: AppTypography.mono.copyWith(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Resolve button — Fix #4: uses confirm dialog
                    ElevatedButton.icon(
                      onPressed: _isResolving ? null : _handleResolveWithConfirm,
                      icon: _isResolving
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.check_circle_outline,
                              color: Colors.white,
                            ),
                      label: Text(
                        _isResolving ? 'Đang xử lý...' : 'Tôi đã được giúp đỡ / An toàn',
                        style: AppTypography.labelLarge.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isResolving ? Colors.grey : AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
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
