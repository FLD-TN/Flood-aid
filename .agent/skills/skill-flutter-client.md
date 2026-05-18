# skill-flutter-client.md — Module 3: Flutter App & Adaptive GPS

> Đọc file này khi làm task liên quan đến: Flutter/Dart code, Adaptive GPS, Foreground Service, màn hình SOS, màn hình Bản đồ.

---

## Trách nhiệm

- Adaptive GPS Strategy (3 chế độ theo giai đoạn)
- Android Foreground Service khi TNV nhận ca
- Màn hình SOS cho Nạn nhân (nhập text + voice)
- Màn hình Bản đồ (2 marker: đỏ = victim, xanh = TNV)
- Polling 15s lấy vị trí TNV

---

## Pattern: Adaptive GPS Service

```dart
// services/adaptive_gps_service.dart

import 'package:geolocator/geolocator.dart';
import 'dart:async';

enum GpsMode { idle, movingFar, nearVictim, onScene }

class AdaptiveGpsService {
  static StreamSubscription<Position>? _posStream;
  static GpsMode _currentMode = GpsMode.idle;

  /// Chế độ 1: Idle — TNV chưa nhận ca
  /// Tắt hoàn toàn GPS stream, dùng cached position
  static Future<void> setIdleMode() async {
    await _posStream?.cancel();
    _posStream = null;
    _currentMode = GpsMode.idle;
  }

  /// Chế độ 2: Moving — TNV đang di chuyển đến nạn nhân
  /// distance-based trigger, accuracy.balanced để tiết kiệm pin
  static void setMovingMode({
    required Future<void> Function(Position) onUpdate,
    required double distanceToVictim,
  }) {
    _posStream?.cancel();

    final accuracy = distanceToVictim < 500
        ? LocationAccuracy.high       // < 500m: cần chính xác
        : LocationAccuracy.balanced;  // > 500m: tiết kiệm pin

    _posStream = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: 30, // chỉ emit khi di chuyển > 30m
      ),
    ).listen((pos) => onUpdate(pos));

    _currentMode = distanceToVictim < 500 ? GpsMode.nearVictim : GpsMode.movingFar;
  }

  /// Chế độ 3: On-scene — distance < 100m
  /// GPS tần suất thấp, chỉ xác nhận TNV vẫn còn tại chỗ
  static void setOnSceneMode({required Future<void> Function(Position) onUpdate}) {
    _posStream?.cancel();
    _posStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        distanceFilter: 100, // chỉ emit khi ra khỏi khu vực 100m
      ),
    ).listen((pos) => onUpdate(pos));
    _currentMode = GpsMode.onScene;
  }

  /// Gọi khi server trả về distance update — tự điều chỉnh mode
  static void adaptToDistance(double distanceM, {required Future<void> Function(Position) onUpdate}) {
    if (distanceM < 100 && _currentMode != GpsMode.onScene) {
      setOnSceneMode(onUpdate: onUpdate);
    } else if (distanceM < 500 && _currentMode == GpsMode.movingFar) {
      setMovingMode(onUpdate: onUpdate, distanceToVictim: distanceM);
    }
  }

  static GpsMode get currentMode => _currentMode;
}
```

---

## Pattern: Foreground Service (BẮBT BUỘC khi TNV nhận ca)

```dart
// services/foreground_service.dart

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class RescueForegroundService {
  
  static Future<void> start() async {
    await FlutterForegroundTask.startService(
      notificationTitle: 'FloodAid — Đang cứu hộ',
      notificationText: 'GPS đang hoạt động để điều phối cứu hộ',
      callback: _foregroundCallback,
    );
  }

  static Future<void> stop() async {
    await FlutterForegroundTask.stopService();
  }

  static void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'floodaid_rescue',
        channelName: 'FloodAid Cứu hộ',
        channelImportance: NotificationChannelImportance.HIGH,
        priority: NotificationPriority.HIGH,
        iconData: const NotificationIconData(
          resType: ResourceType.drawable,
          resPrefix: ResourcePrefix.ic,
          name: 'ic_rescue',
        ),
      ),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 7000, // GPS POST interval fallback
        isOnceEvent: false,
        autoRunOnBoot: false,
      ),
    );
  }
}

// Callback chạy trong isolate riêng (Android requirement)
@pragma('vm:entry-point')
void _foregroundCallback() {
  FlutterForegroundTask.setTaskHandler(_RescueTaskHandler());
}

class _RescueTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {
    // GPS update được handle bởi AdaptiveGpsService stream
    // TaskHandler này chỉ giữ service alive
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {}
}
```

---

## Pattern: SOS Screen

```dart
// screens/sos_screen.dart (structure)

class SosScreen extends StatefulWidget { ... }

class _SosScreenState extends State<SosScreen> {
  final _textController = TextEditingController();
  final _stt = SpeechToText();
  bool _isListening = false;
  bool _isSending = false;
  bool _savedOffline = false;

  @override
  void initState() {
    super.initState();
    // Lớp 1: Warm up GPS ngay khi vào màn hình SOS
    GpsColdStartHandler.warmUpOnSosScreen();
  }

  Future<void> _handleSend() async {
    if (_isSending) return;
    setState(() { _isSending = true; });

    // Lấy GPS tốt nhất có thể
    final pos = await GpsColdStartHandler.getBestAvailableLocation();

    final result = await OfflineQueueService.sendSos(
      text: _textController.text,
      lat: pos?.latitude ?? 0,
      lon: pos?.longitude ?? 0,
      phone: AuthService.currentPhone,
    );

    if (result == null) {
      // Đã lưu offline — KHÔNG hiển thị lỗi
      setState(() { _savedOffline = true; _isSending = false; });
      _showOfflineSavedBanner(); // "Tín hiệu đã lưu an toàn, sẽ tự động gửi khi có sóng"
    } else {
      Navigator.pushReplacementNamed(context, '/tracking', arguments: result);
    }
  }

  // Voice input: nhấn giữ để nói, thả để dừng
  Future<void> _startListening() async {
    await _stt.listen(
      onResult: (result) {
        if (result.hasConfidenceRating) {
          setState(() => _textController.text = result.recognizedWords);
        }
      },
      localeId: 'vi_VN', // Tiếng Việt
    );
    setState(() => _isListening = true);
  }

  Future<void> _stopListening() async {
    await _stt.stop();
    setState(() => _isListening = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade50,
      body: SafeArea(
        child: Column(
          children: [
            // Text input
            TextField(controller: _textController, ...),
            
            // Voice input button (nhấn giữ)
            GestureDetector(
              onLongPressStart: (_) => _startListening(),
              onLongPressEnd: (_) => _stopListening(),
              child: Container(
                decoration: BoxDecoration(
                  color: _isListening ? Colors.red : Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.mic, size: 40),
              ),
            ),

            // Nút SOS TO, màu đỏ, không confirm dialog
            ElevatedButton(
              onPressed: _isSending ? null : _handleSend,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                minimumSize: const Size(double.infinity, 70),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSending
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('🆘 GỬI TÍN HIỆU CỨU HỘ',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## Pattern: Tracking Screen (Nạn nhân theo dõi TNV)

```dart
// screens/tracking_screen.dart

class TrackingScreen extends StatefulWidget {
  final String caseId;
  const TrackingScreen({required this.caseId});
  ...
}

class _TrackingScreenState extends State<TrackingScreen> {
  Timer? _pollingTimer;
  LatLng? _tnvPosition;
  String _statusText = '🔴 Đang tìm người cứu hộ gần bạn...';
  String _caseStatus = 'pending';

  @override
  void initState() {
    super.initState();
    // Polling mỗi 15 giây — GPS nạn nhân TẮT sau khi gửi SOS
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _pollTnvLocation(),
    );
  }

  Future<void> _pollTnvLocation() async {
    try {
      final response = await ApiService.get('/api/case/${widget.caseId}/tnv-location');
      if (response == null) return; // không có TNV nhận ca

      final data = response.data;
      setState(() {
        _tnvPosition = LatLng(data['lat'], data['lon']);
        _caseStatus = data['status'];
        _statusText = _buildStatusText(data);
      });
    } catch (_) {}
  }

  String _buildStatusText(Map data) {
    final status = data['status'];
    final distanceM = data['distance_m'] as int?;

    if (status == 'pending') return '🔴 Đang tìm người cứu hộ gần bạn...';
    if (status == 'responding') {
      final km = ((distanceM ?? 0) / 1000).toStringAsFixed(1);
      return '🟡 Đã có người đang trên đường — cách bạn ~${km}km';
    }
    if (status == 'near') return '🟠 Người cứu hộ còn cách bạn ~300m, hãy ra hiệu!';
    if (status == 'on_scene') return '🟢 Người cứu hộ đã rất gần!';
    return '';
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
```
