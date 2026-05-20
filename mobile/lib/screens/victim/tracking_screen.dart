import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../widgets/map_widget.dart';
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
  Timer? _pollTimer;
  final MapController _mapController = MapController();

  // State from API
  String _status = 'pending';
  int? _distanceM;
  double? _tnvLat;
  double? _tnvLon;
  bool _hasVolunteer = false;

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

    // Start polling every 15s
    _pollTnvLocation();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _pollTnvLocation();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _sheetController.dispose();
    super.dispose();
  }

  Future<void> _pollTnvLocation() async {
    final data = await ApiService.getTnvLocation(widget.caseId);
    if (data != null && mounted) {
      setState(() {
        _status = data['status'] ?? 'pending';
        _distanceM = data['distance_m'] != null
            ? (data['distance_m'] as num).toInt()
            : null;
        _tnvLat = data['lat'] != null ? (data['lat'] as num).toDouble() : null;
        _tnvLon = data['lon'] != null ? (data['lon'] as num).toDouble() : null;
        _hasVolunteer = data['has_volunteer'] == true;
      });
    }
  }

  Future<void> _handleResolve() async {
    final success = await ApiService.resolveCase(widget.caseId, 'victim');
    if (success && mounted) {
      Navigator.pop(context);
    }
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
              width: 36, height: 36,
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
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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
                width: 36, height: 36,
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
                child: const Icon(Icons.directions_boat, color: Colors.white, size: 18),
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
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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
                    mapController: _mapController,
                    initialCenter: LatLng(_victimLat, _victimLon),
                    initialZoom: 15.0,
                    markers: _buildMarkers(),
                    onMyLocationTap: _centerOnVictim,
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
                  width: 6, height: 6,
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

              // ── Collapsed mini-status (visible when minimized) ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Text(config.emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        config.message,
                        style: AppTypography.bodyMedium.copyWith(
                          color: config.color,
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
                    // Status banner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: config.color.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: config.color.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Text(config.emoji, style: const TextStyle(fontSize: 22)),
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
                              child: const Icon(Icons.directions_walk, color: AppColors.primary, size: 20),
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
                                  Text(
                                    'Cập nhật mỗi 15 giây',
                                    style: AppTypography.caption,
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

                    // Resolve button
                    ElevatedButton.icon(
                      onPressed: _handleResolve,
                      icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                      label: Text(
                        'Tôi đã được giúp đỡ / An toàn',
                        style: AppTypography.labelLarge.copyWith(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
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
