import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

/// FCM Service — Quản lý Push Notification token & gửi lên Backend.
///
/// Luồng:
///   1. TNV đăng nhập → registerToken() lấy FCM token → gửi lên Backend
///   2. Backend lưu vào cột fcm_token của bảng volunteers
///   3. Khi có SOS mới, geoDispatch gọi fcmService.sendFcmToVolunteer()
///   4. Google FCM push notification xuống điện thoại TNV
class FcmService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Xin quyền notification (bắt buộc Android 13+, iOS)
  static Future<void> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('[FcmService] Permission: ${settings.authorizationStatus}');
  }

  /// Lấy FCM Token và gửi lên Backend cho volunteer.
  /// Gọi sau khi TNV đăng nhập thành công.
  static Future<void> registerToken(String volunteerId) async {
    try {
      final token = await _messaging.getToken();
      if (token == null) {
        debugPrint('[FcmService] Failed to get FCM token');
        return;
      }

      debugPrint('[FcmService] FCM Token: ${token.substring(0, 20)}...');

      // Gửi token lên Backend
      await ApiService.updateFcmToken(
        volunteerId: volunteerId,
        fcmToken: token,
      );

      // Lưu local để biết đã đăng ký rồi
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', token);

      debugPrint('[FcmService] Token registered for volunteer $volunteerId');
    } catch (e) {
      debugPrint('[FcmService] registerToken error: $e');
    }
  }

  /// Lắng nghe khi Google refresh FCM Token (hiếm khi xảy ra).
  /// Gọi 1 lần trong main.dart.
  static void listenTokenRefresh() {
    _messaging.onTokenRefresh.listen((newToken) async {
      debugPrint('[FcmService] Token refreshed: ${newToken.substring(0, 20)}...');

      final prefs = await SharedPreferences.getInstance();
      final volunteerId = prefs.getString('volunteer_id');
      if (volunteerId != null) {
        await ApiService.updateFcmToken(
          volunteerId: volunteerId,
          fcmToken: newToken,
        );
        await prefs.setString('fcm_token', newToken);
      }
    });
  }
}
