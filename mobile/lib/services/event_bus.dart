import 'dart:async';

/// Lightweight event bus cho phép các module giao tiếp mà không cần tham chiếu trực tiếp.
///
/// Dùng chính:
///   - FCM foreground handler (main.dart) gửi event 'new_sos'
///   - VolunteerHomeScreen lắng nghe → refresh list ngay lập tức thay vì chờ poll 15s
///
/// Sử dụng:
/// ```dart
/// // Gửi event:
/// EventBus.fire('new_sos', {'caseId': '123'});
///
/// // Lắng nghe:
/// final sub = EventBus.on('new_sos').listen((data) => _fetchCases());
/// // Nhớ cancel khi dispose!
/// sub.cancel();
/// ```
class EventBus {
  static final Map<String, StreamController<Map<String, dynamic>>> _controllers = {};

  /// Lắng nghe event theo tên
  static Stream<Map<String, dynamic>> on(String event) {
    _controllers[event] ??= StreamController<Map<String, dynamic>>.broadcast();
    return _controllers[event]!.stream;
  }

  /// Gửi event
  static void fire(String event, [Map<String, dynamic>? data]) {
    if (_controllers.containsKey(event)) {
      _controllers[event]!.add(data ?? {});
    }
  }
}
