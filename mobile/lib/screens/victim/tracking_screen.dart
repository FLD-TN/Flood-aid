import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
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
                  _buildMap(),
                  _buildSafeMapPill(),
                  _buildBottomSheet(),
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

  Widget _buildMap() {
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

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: LatLng(_victimLat, _victimLon),
        initialZoom: 15.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
        ),
        MarkerLayer(markers: markers),
      ],
    );
  }

  Widget _buildSafeMapPill() {
    return Positioned(
      top: 16,
      right: 16,
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
            const Icon(Icons.layers_outlined, color: AppColors.primary, size: 16),
            const SizedBox(width: 6),
            Text(
              'Bản đồ An toàn',
              style: AppTypography.labelMedium.copyWith(color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSheet() {
    final config = _statusConfig;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

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
    );
  }
}
