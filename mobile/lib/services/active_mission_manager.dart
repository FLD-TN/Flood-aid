import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'ws_gps_service.dart';
import 'api_service.dart';

/// Singleton global quản lý trạng thái nhiệm vụ cứu hộ đang active.
///
/// Mô hình Grab/Xanh SM: GPS + WebSocket chạy ngầm ngay cả khi TNV
/// thoát khỏi màn hình ActiveMissionScreen, đảm bảo Nạn nhân luôn
/// thấy vị trí TNV di chuyển.
class ActiveMissionManager extends ChangeNotifier {
  // ── Singleton ──
  static final ActiveMissionManager _instance = ActiveMissionManager._();
  factory ActiveMissionManager() => _instance;
  ActiveMissionManager._();

  // ── State ──
  String? _activeCaseId;
  String? _volunteerId;
  double? _victimLat;
  double? _victimLon;
  String? _summary;
  String? _description;
  int? _urgencyLevel;
  String? _victimPhone;

  // ── GPS Service (chạy ngầm) ──
  WsGpsService? _wsGpsService;
  Timer? _gpsTimer;
  bool _wsConnected = false;

  // ── Public Getters ──
  String? get activeCaseId => _activeCaseId;
  String? get volunteerId => _volunteerId;
  double? get victimLat => _victimLat;
  double? get victimLon => _victimLon;
  String? get summary => _summary;
  String? get description => _description;
  int? get urgencyLevel => _urgencyLevel;
  String? get victimPhone => _victimPhone;
  bool get hasActiveMission => _activeCaseId != null;
  bool get wsConnected => _wsConnected;
  WsGpsService? get wsGpsService => _wsGpsService;

  // Callback khi ca bị đóng từ bên ngoài (victim resolve / admin cancel)
  // Screen đang hiện sẽ listen cái này để pop ra
  VoidCallback? onMissionEndedExternally;

  /// Gọi khi TNV accept ca thành công.
  /// Khởi tạo GPS tracking global.
  void startMission({
    required String caseId,
    required String volunteerId,
    required double victimLat,
    required double victimLon,
    String? summary,
    String? description,
    int? urgencyLevel,
    String? victimPhone,
  }) {
    // Nếu đang có mission cũ → dọn dẹp
    if (_activeCaseId != null && _activeCaseId != caseId) {
      _cleanup();
    }

    _activeCaseId = caseId;
    _volunteerId = volunteerId;
    _victimLat = victimLat;
    _victimLon = victimLon;
    _summary = summary;
    _description = description;
    _urgencyLevel = urgencyLevel;
    _victimPhone = victimPhone;

    // Khởi tạo WsGpsService global
    _wsGpsService = WsGpsService(
      onConnectionChanged: (connected) {
        _wsConnected = connected;
        notifyListeners();
      },
      onCaseResolved: (data) {
        debugPrint('[ActiveMissionManager] Case resolved externally');
        onMissionEndedExternally?.call();
        endMission();
      },
    );

    _wsGpsService!.connect(
      caseId: caseId,
      role: 'volunteer',
      volunteerId: volunteerId,
    );

    // Start GPS timer — gửi tọa độ mỗi 10s
    _gpsTimer?.cancel();
    _gpsTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _sendGps();
    });
    // Gửi ngay lần đầu
    _sendGps();

    notifyListeners();
    debugPrint('[ActiveMissionManager] Mission started for case $caseId');
  }

  /// Gửi GPS position qua WS (hoặc REST fallback)
  Future<void> _sendGps() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      if (_wsGpsService != null && _wsGpsService!.isConnected) {
        _wsGpsService!.sendGps(pos.latitude, pos.longitude);
      } else if (_volunteerId != null && _volunteerId!.isNotEmpty) {
        // REST fallback
        await ApiService.updateLocation(
          volunteerId: _volunteerId!,
          lat: pos.latitude,
          lon: pos.longitude,
        );
      }
    } catch (e) {
      debugPrint('[ActiveMissionManager] GPS error: $e');
    }
  }

  /// Gọi khi TNV hoàn thành ca (Tiếp cận xong) hoặc ca bị đóng.
  void endMission() {
    debugPrint('[ActiveMissionManager] Mission ended for case $_activeCaseId');
    _cleanup();
    notifyListeners();
  }

  /// Gọi khi TNV chủ động hủy ca (Revoke).
  Future<bool> revokeMission() async {
    if (_activeCaseId == null || _volunteerId == null) return false;

    try {
      final success = await ApiService.revokeCase(_activeCaseId!, _volunteerId!);
      if (success) {
        debugPrint('[ActiveMissionManager] Mission revoked for case $_activeCaseId');
        _cleanup();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[ActiveMissionManager] Revoke error: $e');
      return false;
    }
  }

  void _cleanup() {
    _gpsTimer?.cancel();
    _gpsTimer = null;
    _wsGpsService?.dispose();
    _wsGpsService = null;
    _wsConnected = false;
    _activeCaseId = null;
    _volunteerId = null;
    _victimLat = null;
    _victimLon = null;
    _summary = null;
    _description = null;
    _urgencyLevel = null;
    _victimPhone = null;
    onMissionEndedExternally = null;
  }
}
