import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/ws_gps_service.dart';
import '../../widgets/map_widget.dart';
import '../../widgets/sos_legend_widget.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class ActiveMissionScreen extends StatefulWidget {
  final String caseId;
  final double? victimLat;
  final double? victimLon;
  final String? summary;
  final int? urgencyLevel;

  const ActiveMissionScreen({
    super.key,
    required this.caseId,
    this.victimLat,
    this.victimLon,
    this.summary,
    this.urgencyLevel,
  });

  @override
  State<ActiveMissionScreen> createState() => _ActiveMissionScreenState();
}

class _ActiveMissionScreenState extends State<ActiveMissionScreen> {
  Timer? _gpsTimer;
  WsGpsService? _wsGpsService;
  final MapController _mapController = MapController();

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
  bool _wsConnected = false;
  bool _caseResolved = false; // ca đã bị đóng từ bên ngoài (SSE)

  // SSE subscription (lắng nghe trước khi accept)
  StreamSubscription? _sseSub;

  // Draggable sheet controller
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  @override
  void initState() {
    super.initState();
    _victimLat = widget.victimLat ?? 16.0544;
    _victimLon = widget.victimLon ?? 108.2022;

    // Load volunteer UUID from SharedPreferences
    _loadVolunteerId();

    // Get initial location once
    _getMyLocation();

    // Connect SSE ngay lập tức — lắng nghe case:resolved TRƯỚC khi accept
    _connectCaseSSE();
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    resolvedBy == 'victim'
                        ? 'Nạn nhân đã xác nhận được giúp đỡ. Ca đã đóng!'
                        : 'Ca đã được đóng bởi $resolvedBy.',
                  ),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 3),
                ),
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
  }

  @override
  void dispose() {
    _gpsTimer?.cancel();
    _wsGpsService?.dispose();
    _sseSub?.cancel();
    _sheetController.dispose();
    super.dispose();
  }

  /// Start GPS tracking via WebSocket (called after accepting case)
  void _startGpsTracking() {
    // Initialize WS GPS service
    _wsGpsService = WsGpsService(
      onConnectionChanged: (connected) {
        if (mounted) {
          setState(() => _wsConnected = connected);
        }
      },
      onCaseResolved: (data) {
        // Nạn nhân hoặc Admin đã đóng ca → TNV tự động thoát
        if (mounted) {
          final resolvedBy = data['resolvedBy'] ?? 'victim';
          _stopGpsTracking();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                resolvedBy == 'victim'
                    ? 'Nạn nhân đã xác nhận được giúp đỡ. Ca đã đóng!'
                    : 'Ca đã được đóng bởi $resolvedBy.',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
          Navigator.pop(context);
        }
      },
    );

    // Connect WebSocket with real volunteer UUID
    _wsGpsService!.connect(
      caseId: widget.caseId,
      role: 'volunteer',
      volunteerId: _volunteerId,
    );

    // Start GPS timer — send GPS via WS (or REST fallback) every 10s
    _gpsTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _getMyLocation();
    });
  }

  /// Stop GPS tracking (when case is resolved or cancelled)
  void _stopGpsTracking() {
    _gpsTimer?.cancel();
    _gpsTimer = null;
    _wsGpsService?.dispose();
    _wsGpsService = null;
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

        // Send GPS: prefer WebSocket, fallback to REST
        if (_wsGpsService != null && _wsGpsService!.isConnected) {
          _wsGpsService!.sendGps(pos.latitude, pos.longitude);
        } else if (_accepted && _volunteerId.isNotEmpty) {
          // REST fallback when WS is down
          await ApiService.updateLocation(
            volunteerId: _volunteerId,
            lat: pos.latitude,
            lon: pos.longitude,
          );
        }
      }
    } catch (e) {
      debugPrint('[ActiveMission] GPS error: $e');
    }
  }

  Future<void> _handleAcceptCase() async {
    // Pre-check: ca còn pending không?
    final status = await ApiService.getCaseStatus(widget.caseId);
    if (status != null && status != 'pending') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'resolved'
                  ? 'Ca này đã được xử lý rồi!'
                  : 'Ca này không còn khả dụng (trạng thái: $status)',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.pop(context);
      }
      return;
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nhận ca thất bại. Thử lại sau.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      } else if (mounted) {
        // Accept succeeded — start GPS tracking via WebSocket
        _startGpsTracking();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _accepted = false);
        _connectCaseSSE();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lỗi mạng. Thử lại sau.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      debugPrint('[ActiveMission] Accept error: $e');
    }
  }

  Future<void> _handleResolve() async {
    if (_isResolving) return;
    // Optimistic: show resolving state immediately
    setState(() => _isResolving = true);
    try {
      final success = await ApiService.resolveCase(widget.caseId, 'volunteer');
      if (success && mounted) {
        _stopGpsTracking();
        Navigator.pop(context, widget.caseId); // Trả caseId về cho HomeScreen xóa ngay
      } else if (mounted) {
        setState(() => _isResolving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đóng ca thất bại. Thử lại sau.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isResolving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lỗi mạng. Thử lại sau.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      debugPrint('[ActiveMission] Resolve error: $e');
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
    return Container(
      color: AppColors.alertRed,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _wsConnected ? 'Đang Ghi GPS — WS Live' : 'Đang Ghi GPS — Cứu hộ',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.close, color: Colors.white, size: 16),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          ),
          Text(
            'Nhiệm vụ Cứu hộ',
            style: AppTypography.headingMedium.copyWith(
              color: AppColors.alertRed,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 24),
        ],
      ),
    );
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

              // ── Mini summary (visible when collapsed) ──
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
                    Expanded(
                      child: Text(
                        widget.summary ?? 'Ca SOS',
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
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
                    // Urgency + summary
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: urgencyColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'MỨC $urgency',
                            style: const TextStyle(
                              color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.summary ?? 'Ca SOS',
                            style: AppTypography.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Distance
                    if (distKm != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.navigation, color: AppColors.primary, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              distKm >= 1
                                  ? 'Còn ${distKm.toStringAsFixed(1)}km đến nạn nhân'
                                  : 'Còn ${(distKm * 1000).toInt()}m đến nạn nhân',
                              style: AppTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
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
                    Row(
                      children: [
                        if (!_accepted)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _handleAcceptCase,
                              icon: const Icon(Icons.check, color: Colors.white, size: 18),
                              label: const Text(
                                'Nhận ca',
                                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        if (_accepted) ...[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {},
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: const BorderSide(color: AppColors.alertRed),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(
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
                              onPressed: _isResolving ? null : _handleResolve,
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
                      ],
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
