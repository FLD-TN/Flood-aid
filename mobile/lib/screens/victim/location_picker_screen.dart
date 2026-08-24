import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../config/vietmap_config.dart';

/// Kết quả trả về từ màn chọn vị trí: toạ độ + địa chỉ chữ (nếu có).
class LocationPickResult {
  final LatLng latLng;
  final String? address;
  const LocationPickResult(this.latLng, this.address);
}

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
  String? _selectedAddress;
  final TextEditingController _searchController = TextEditingController();
  bool _isLoadingLocation = false;

  // Gợi ý địa chỉ (VietMap Autocomplete)
  List<Map<String, dynamic>> _suggestions = [];
  bool _isSearching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    if (widget.initialLat != null && widget.initialLon != null) {
      _selectedLocation = LatLng(widget.initialLat!, widget.initialLon!);
      _reverseFill(_selectedLocation!);
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
          _reverseFill(_selectedLocation!);
        }
      }
    } catch (e) {
      // Ignore
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
      if (_selectedLocation == null) {
        setState(() {
          _selectedLocation = const LatLng(16.0544, 108.2022); // Da Nang
          _mapController.move(_selectedLocation!, 13.0);
        });
      }
    }
  }

  /// Reverse-geocode để điền địa chỉ khi user chạm bản đồ / lấy GPS.
  Future<void> _reverseFill(LatLng point) async {
    final addr = await ApiService.geoReverse(point.latitude, point.longitude);
    if (!mounted) return;
    if (addr != null) setState(() => _selectedAddress = addr);
  }

  /// Gõ tìm địa chỉ — debounce 300ms rồi gọi VietMap Autocomplete.
  void _onSearchChanged(String text) {
    _debounce?.cancel();
    if (text.trim().length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _isSearching = true);
      final results = await ApiService.geoAutocomplete(
        text,
        lat: _selectedLocation?.latitude,
        lon: _selectedLocation?.longitude,
      );
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _isSearching = false;
      });
    });
  }

  /// Chọn 1 gợi ý → Place v4 lấy toạ độ chính xác.
  Future<void> _selectSuggestion(Map<String, dynamic> s) async {
    FocusScope.of(context).unfocus();
    final refId = s['ref_id'] as String?;
    final display = s['display'] as String?;
    setState(() {
      _suggestions = [];
      _searchController.text = display ?? '';
      _selectedAddress = display;
    });
    if (refId == null) return;
    final place = await ApiService.geoPlace(refId);
    if (!mounted || place == null) return;
    final lat = (place['lat'] as num?)?.toDouble();
    final lng = (place['lng'] as num?)?.toDouble();
    if (lat != null && lng != null) {
      setState(() {
        _selectedLocation = LatLng(lat, lng);
        _selectedAddress = (place['display'] as String?) ?? display;
        _mapController.move(_selectedLocation!, 16.0);
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
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
                Navigator.pop(
                  context,
                  LocationPickResult(_selectedLocation!, _selectedAddress),
                );
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
                      hintText: 'Tìm địa chỉ (số nhà, đường, phường)...',
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
                                setState(() => _suggestions = []);
                              },
                            ),
                    ),
                    onChanged: _onSearchChanged,
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
                          _suggestions = [];
                        });
                        _reverseFill(point);
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://maps.vietmap.vn/maps/tiles/tm/{z}/{x}/{y}@2x.png?apikey=${VietmapConfig.mapApiKey}',
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

                // Panel địa chỉ đang chọn
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
                    child: Row(
                      children: [
                        Icon(Icons.location_on, color: AppColors.alertRed, size: 20.r),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            _selectedAddress ??
                                'Chạm vào bản đồ hoặc tìm địa chỉ ở trên.',
                            style: AppTypography.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Dropdown gợi ý địa chỉ (đè lên bản đồ)
                if (_suggestions.isNotEmpty)
                  Positioned(
                    top: 0,
                    left: 16.w,
                    right: 16.w,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(8.r),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: 260.h),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: _suggestions.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final s = _suggestions[i];
                            return ListTile(
                              dense: true,
                              leading: Icon(Icons.place, size: 20.r, color: AppColors.primary),
                              title: Text(
                                s['name']?.toString() ?? s['display']?.toString() ?? '',
                                style: AppTypography.bodyMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                s['address']?.toString() ?? '',
                                style: AppTypography.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => _selectSuggestion(s),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
