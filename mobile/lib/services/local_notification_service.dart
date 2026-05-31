import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Service quản lý System Notification thật (giống Messenger, MBBank).
///
/// Thông báo này:
/// - Hiện ở ngoài màn hình chính (dù app đang đóng)
/// - Nằm trong khay thông báo khi vuốt xuống
/// - Bấm vào được → mở app
/// - Vuốt ngang để xóa thông báo
/// - Có rung + âm thanh
class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// Khởi tạo notification service (gọi 1 lần trong main.dart)
  static Future<void> initialize() async {
    if (_initialized) return;

    // Android: dùng icon mặc định của app (@mipmap/ic_launcher)
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    const settings = InitializationSettings(
      android: androidSettings,
    );

    await _plugin.initialize(
      settings,
      // Callback khi user bấm vào thông báo
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('[Notification] User tapped: ${response.payload}');
        // Có thể navigate tới màn hình cụ thể dựa vào payload
      },
    );

    // Tạo notification channel cho Android (bắt buộc từ Android 8+)
    const channel = AndroidNotificationChannel(
      'floodaid_sos',           // ID
      'Cứu Hộ SOS',            // Tên hiển thị trong Settings
      description: 'Thông báo về các ca SOS và cứu hộ khẩn cấp',
      importance: Importance.high,  // Hiện heads-up banner (như Messenger)
      playSound: true,
      enableVibration: true,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Xin quyền thông báo (Android 13+)
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
    debugPrint('[Notification] Service initialized');
  }

  /// Hiển thị thông báo SOS thành công
  /// Đây là System Notification thật — giống hệt Messenger trong ảnh.
  static Future<void> showSosSuccess({
    required String caseId,
    String? summary,
  }) async {
    await _show(
      id: caseId.hashCode,
      title: 'Cứu Hộ Miền Trung 🚨',
      body: summary ?? 'Ca SOS đã được gửi thành công! Đang tìm tình nguyện viên gần bạn...',
      payload: 'sos_created:$caseId',
    );
  }

  /// Hiển thị thông báo có TNV nhận ca
  static Future<void> showVolunteerAccepted({
    required String caseId,
    int? distanceM,
  }) async {
    final distText = distanceM != null ? ' (cách ${distanceM}m)' : '';
    await _show(
      id: caseId.hashCode + 1,
      title: 'Có người đến cứu bạn! 🙌',
      body: 'Tình nguyện viên đã nhận ca$distText. Hãy giữ bình tĩnh, họ đang trên đường đến.',
      payload: 'volunteer_accepted:$caseId',
    );
  }

  /// Hiển thị thông báo có ca SOS mới (cho TNV)
  static Future<void> showNewSosForVolunteer({
    required String caseId,
    required int urgencyLevel,
    int? distanceM,
    String? summary,
  }) async {
    final distText = distanceM != null
        ? (distanceM > 1000
            ? '${(distanceM / 1000).toStringAsFixed(1)}km'
            : '${distanceM}m')
        : 'gần bạn';
    await _show(
      id: caseId.hashCode + 2,
      title: '⚠️ Ca SOS mức $urgencyLevel — cách $distText',
      body: summary ?? 'Có người cần được cứu hộ khẩn cấp. Bấm để xem chi tiết.',
      payload: 'new_sos:$caseId',
    );
  }

  /// Hàm gửi notification nội bộ
  static Future<void> _show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'floodaid_sos',             // channel ID (phải khớp với channel đã tạo)
      'Cứu Hộ SOS',              // channel name
      channelDescription: 'Thông báo về các ca SOS và cứu hộ khẩn cấp',
      importance: Importance.high,  // Hiện heads-up notification (banner trên cùng)
      priority: Priority.high,     // Ưu tiên cao
      ticker: 'FloodAid SOS',
      styleInformation: BigTextStyleInformation(body), // Cho phép nội dung dài
      icon: '@mipmap/ic_launcher', // Icon app
      playSound: true,
      enableVibration: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
    );

    await _plugin.show(id, title, body, details, payload: payload);
  }
}
