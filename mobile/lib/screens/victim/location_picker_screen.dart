import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../theme/app_theme.dart';
import '../../services/toast_service.dart';

class LocationPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLon;

  const LocationPickerScreen({super.key, this.initialLat, this.initialLon});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late MapController _mapController;
  LatLng? _selectedLocation;
  final TextEditingController _searchController = TextEditingController();
  bool _isLoadingLocation = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    if (widget.initialLat != null && widget.initialLon != null) {
      _selectedLocation = LatLng(widget.initialLat!, widget.initialLon!);
    } else {
      _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          Position position = await Geolocator.getCurrentPosition();
          setState(() {
            _selectedLocation = LatLng(position.latitude, position.longitude);
            _mapController.move(_selectedLocation!, 15.0);
          });
        }
      }
    } catch (e) {
      // Ignore
    } finally {
      setState(() => _isLoadingLocation = false);
      if (_selectedLocation == null) {
        // Fallback location
        setState(() {
          _selectedLocation = const LatLng(16.0544, 108.2022); // Da Nang
          _mapController.move(_selectedLocation!, 13.0);
        });
      }
    }
  }

  Future<void> _searchLocation() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isSearching = true);
    FocusScope.of(context).unfocus();

    try {
      final response = await http.get(Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          setState(() {
            _selectedLocation = LatLng(lat, lon);
            _mapController.move(_selectedLocation!, 15.0);
          });
        } else {
          ToastService.show(
            context: context,
            type: ToastType.error,
            message: 'Không tìm thấy địa điểm.',
          );
        }
      }
    } catch (e) {
      ToastService.show(
        context: context,
        type: ToastType.error,
        message: 'Lỗi khi tìm kiếm địa điểm.',
      );
    } finally {
      setState(() => _isSearching = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chọn vị trí'),
        actions: [
          TextButton(
            onPressed: () {
              if (_selectedLocation != null) {
                Navigator.pop(context, _selectedLocation);
              }
            },
            child: Text(
              'Xong',
              style: AppTypography.labelLarge.copyWith(color: AppColors.primary),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm địa điểm...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _isSearching
                          ? Padding(
                              padding: EdgeInsets.all(12.w),
                              child: SizedBox(
                                width: 16.w,
                                height: 16.w,
                                child: const CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                              },
                            ),
                    ),
                    onSubmitted: (_) => _searchLocation(),
                  ),
                ),
                SizedBox(width: 8.w),
                IconButton(
                  onPressed: _getCurrentLocation,
                  icon: const Icon(Icons.my_location, color: AppColors.primary),
                  tooltip: 'Vị trí hiện tại',
                )
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                if (_selectedLocation != null)
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _selectedLocation!,
                      initialZoom: 15.0,
                      onTap: (tapPosition, point) {
                        setState(() {
                          _selectedLocation = point;
                        });
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.floodaid.mobile',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _selectedLocation!,
                            width: 80.w,
                            height: 80.w,
                            child: Icon(
                              Icons.location_on,
                              color: AppColors.alertRed,
                              size: 48.r,
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                else
                  const Center(child: CircularProgressIndicator()),
                if (_isLoadingLocation)
                  const Center(child: CircularProgressIndicator()),
                Positioned(
                  bottom: 16.h,
                  left: 16.w,
                  right: 16.w,
                  child: Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(8.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10.r,
                        )
                      ],
                    ),
                    child: Text(
                      'Chạm vào bản đồ để kéo thả ghim vị trí của bạn.',
                      style: AppTypography.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
