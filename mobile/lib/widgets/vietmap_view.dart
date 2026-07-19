import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:vietmap_flutter_gl/vietmap_flutter_gl.dart' as vmgl;
import '../config/vietmap_config.dart';

/// Một điểm đánh dấu trên VietmapView: vị trí (latlong2) + widget hiển thị.
class VietmapMarker {
  final ll.LatLng position;
  final Widget child;
  final double width;
  final double height;
  const VietmapMarker({
    required this.position,
    required this.child,
    this.width = 44,
    this.height = 44,
  });
}

/// Bản đồ VietMap (vector GL) tái sử dụng cho FloodAid.
///
/// - Nền: style vector VietMap ([VietmapConfig.styleUrl]).
/// - [markers]: danh sách điểm (vị trí + widget con).
/// - [routePoints]: nếu có, vẽ polyline tuyến đường thật (đã decode từ Route v4).
/// - [onMapTap]: callback khi user chạm bản đồ (dùng cho màn chọn vị trí).
///
/// Nhận toạ độ ở dạng `latlong2.LatLng` (đồng bộ với phần còn lại của app);
/// bên trong tự convert sang `LatLng` của vietmap_flutter_gl.
class VietmapView extends StatefulWidget {
  final ll.LatLng initialCenter;
  final double initialZoom;
  final List<VietmapMarker> markers;
  final List<ll.LatLng>? routePoints;
  final void Function(ll.LatLng latLng)? onMapTap;
  final bool myLocationEnabled;

  const VietmapView({
    super.key,
    required this.initialCenter,
    this.initialZoom = 15.0,
    this.markers = const [],
    this.routePoints,
    this.onMapTap,
    this.myLocationEnabled = false,
  });

  @override
  State<VietmapView> createState() => _VietmapViewState();
}

class _VietmapViewState extends State<VietmapView> {
  vmgl.VietmapController? _controller;
  vmgl.Line? _routeLine;

  vmgl.LatLng _toVm(ll.LatLng p) => vmgl.LatLng(p.latitude, p.longitude);

  Future<void> _drawRoute() async {
    if (_controller == null) return;
    final points = widget.routePoints;
    // Xoá tuyến cũ trước khi vẽ lại
    if (_routeLine != null) {
      await _controller!.removePolyline(_routeLine!);
      _routeLine = null;
    }
    if (points == null || points.length < 2) return;
    _routeLine = await _controller!.addPolyline(
      vmgl.PolylineOptions(
        geometry: points.map(_toVm).toList(),
        polylineColor: Colors.blue,
        polylineWidth: 5.0,
        polylineOpacity: 0.85,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant VietmapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.routePoints != widget.routePoints) {
      _drawRoute();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        vmgl.VietmapGL(
          styleString: VietmapConfig.styleUrl,
          initialCameraPosition: vmgl.CameraPosition(
            target: _toVm(widget.initialCenter),
            zoom: widget.initialZoom,
          ),
          trackCameraPosition: true, // cần cho MarkerLayer render đúng vị trí
          myLocationEnabled: widget.myLocationEnabled,
          onMapCreated: (controller) {
            setState(() => _controller = controller);
          },
          onMapRenderedCallback: () {
            _drawRoute();
          },
          onMapClick: widget.onMapTap == null
              ? null
              : (point, latLng) {
                  widget.onMapTap!(ll.LatLng(latLng.latitude, latLng.longitude));
                },
        ),

        // MarkerLayer chỉ dựng được sau khi có controller
        if (_controller != null && widget.markers.isNotEmpty)
          vmgl.MarkerLayer(
            ignorePointer: true,
            mapController: _controller!,
            markers: widget.markers
                .map((m) => vmgl.Marker(
                      width: m.width,
                      height: m.height,
                      child: m.child,
                      latLng: _toVm(m.position),
                    ))
                .toList(),
          ),
      ],
    );
  }
}
