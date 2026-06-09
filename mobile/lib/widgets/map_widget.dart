import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_theme.dart';

/// Enum for available map tile styles
enum MapTileStyle {
  standard,
  satellite,
  dark,
  terrain,
}

/// A reusable map widget with:
/// - Multiple tile layer options (Standard, Satellite, Dark, Terrain)
/// - Zoom in/out controls
/// - My-location button
/// - Layer switcher FAB
class FloodAidMap extends StatefulWidget {
  final MapController? mapController;
  final LatLng initialCenter;
  final double initialZoom;
  final List<Marker> markers;
  final List<Polyline>? polylines;
  final List<CircleMarker>? circles;
  final VoidCallback? onMyLocationTap;
  final MapTileStyle initialStyle;

  const FloodAidMap({
    super.key,
    this.mapController,
    required this.initialCenter,
    this.initialZoom = 14.0,
    this.markers = const [],
    this.polylines,
    this.circles,
    this.onMyLocationTap,
    this.initialStyle = MapTileStyle.standard,
  });

  @override
  State<FloodAidMap> createState() => _FloodAidMapState();
}

class _FloodAidMapState extends State<FloodAidMap>
    with SingleTickerProviderStateMixin {
  late MapController _mapController;
  late MapTileStyle _currentStyle;
  bool _showLayerPicker = false;

  @override
  void initState() {
    super.initState();
    _mapController = widget.mapController ?? MapController();
    _currentStyle = widget.initialStyle;
  }

  String get _tileUrl {
    switch (_currentStyle) {
      case MapTileStyle.standard:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      case MapTileStyle.satellite:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      case MapTileStyle.dark:
        return 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';
      case MapTileStyle.terrain:
        return 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png';
    }
  }

  List<String> get _subdomains {
    switch (_currentStyle) {
      case MapTileStyle.standard:
      case MapTileStyle.satellite:
        return [];
      case MapTileStyle.dark:
        return ['a', 'b', 'c', 'd'];
      case MapTileStyle.terrain:
        return ['a', 'b', 'c'];
    }
  }

  String get _attribution {
    switch (_currentStyle) {
      case MapTileStyle.standard:
        return '© OpenStreetMap';
      case MapTileStyle.satellite:
        return '© Esri';
      case MapTileStyle.dark:
        return '© CARTO';
      case MapTileStyle.terrain:
        return '© OpenTopoMap';
    }
  }

  String _getStyleLabel(MapTileStyle style) {
    switch (style) {
      case MapTileStyle.standard:
        return 'Bản đồ';
      case MapTileStyle.satellite:
        return 'Vệ tinh';
      case MapTileStyle.dark:
        return 'Tối';
      case MapTileStyle.terrain:
        return 'Địa hình';
    }
  }

  IconData _getStyleIcon(MapTileStyle style) {
    switch (style) {
      case MapTileStyle.standard:
        return Icons.map_outlined;
      case MapTileStyle.satellite:
        return Icons.satellite_alt;
      case MapTileStyle.dark:
        return Icons.dark_mode_outlined;
      case MapTileStyle.terrain:
        return Icons.terrain;
    }
  }

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(
      _mapController.camera.center,
      (currentZoom + 1).clamp(2.0, 18.0),
    );
  }

  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(
      _mapController.camera.center,
      (currentZoom - 1).clamp(2.0, 18.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Map ──
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: widget.initialCenter,
            initialZoom: widget.initialZoom,
            minZoom: 3.0,
            maxZoom: 18.0,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
            onTap: (_, _) {
              if (_showLayerPicker) {
                setState(() => _showLayerPicker = false);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: _tileUrl,
              subdomains: _subdomains,
              maxZoom: 18,
              userAgentPackageName: 'com.floodaid.mobile',
            ),
            if (widget.circles != null && widget.circles!.isNotEmpty)
              CircleLayer(circles: widget.circles!),
            if (widget.polylines != null && widget.polylines!.isNotEmpty)
              PolylineLayer(polylines: widget.polylines!),
            MarkerLayer(markers: widget.markers),
            // Attribution
            RichAttributionWidget(
              alignment: AttributionAlignment.bottomLeft,
              attributions: [
                TextSourceAttribution(_attribution),
              ],
            ),
          ],
        ),

        // ── Zoom Controls (top-right) ──
        Positioned(
          right: 12,
          top: 12,
          child: Column(
            children: [
              _buildControlButton(
                icon: Icons.add,
                onTap: _zoomIn,
                tooltip: 'Phóng to',
              ),
              const SizedBox(height: 2),
              _buildControlButton(
                icon: Icons.remove,
                onTap: _zoomOut,
                tooltip: 'Thu nhỏ',
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
            ],
          ),
        ),

        // ── My Location Button ──
        if (widget.onMyLocationTap != null)
          Positioned(
            right: 12,
            top: 108,
            child: _buildControlButton(
              icon: Icons.my_location,
              onTap: widget.onMyLocationTap!,
              tooltip: 'Vị trí của tôi',
              color: AppColors.primary,
            ),
          ),

        // ── Layer Switcher Button ──
        Positioned(
          right: 12,
          top: widget.onMyLocationTap != null ? 158 : 108,
          child: _buildControlButton(
            icon: Icons.layers,
            onTap: () => setState(() => _showLayerPicker = !_showLayerPicker),
            tooltip: 'Đổi lớp bản đồ',
            color: _showLayerPicker ? AppColors.primary : null,
          ),
        ),

        // ── Layer Picker Overlay ──
        if (_showLayerPicker)
          Positioned(
            right: 56,
            top: widget.onMyLocationTap != null ? 158 : 108,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              shadowColor: Colors.black26,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: MapTileStyle.values.map((style) {
                    final isActive = style == _currentStyle;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _currentStyle = style;
                            _showLayerPicker = false;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 60,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.primary.withOpacity(0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: isActive
                                ? Border.all(
                                    color: AppColors.primary, width: 1.5)
                                : Border.all(
                                    color: Colors.grey.shade200, width: 1),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getStyleIcon(style),
                                size: 22,
                                color: isActive
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _getStyleLabel(style),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isActive
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isActive
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
    Color? color,
    BorderRadius? borderRadius,
  }) {
    return Material(
      elevation: 3,
      borderRadius: borderRadius ?? BorderRadius.circular(8),
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius ?? BorderRadius.circular(8),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: borderRadius ?? BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
