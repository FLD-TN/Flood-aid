import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/role_selection_screen.dart';
import 'services/local_notification_service.dart';
import 'services/fcm_service.dart';
import 'screens/volunteer/volunteer_home_screen.dart';

/// Global navigator key — dùng để navigate từ FCM callback (ngoài widget tree)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Background message handler — PHẢI là top-level function (không nằm trong class)
/// Xử lý FCM khi app đang tắt hoàn toàn hoặc ở background
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[FCM] Background message: ${message.messageId}');
  // Không cần hiện notification vì FCM tự hiện khi ở background
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Khởi tạo System Notification (giống Messenger/MBBank)
  await LocalNotificationService.initialize();

  // Khởi tạo FCM Push Notification
  await FcmService.requestPermission();
  FcmService.listenTokenRefresh();

  // Đăng ký background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Xử lý FCM khi app đang mở (foreground)
  // FCM không tự hiện notification khi foreground → dùng LocalNotification để hiện
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint('[FCM] Foreground message: ${message.notification?.title}');

    final data = message.data;
    if (data['type'] == 'NEW_SOS') {
      LocalNotificationService.showNewSosForVolunteer(
        caseId: data['caseId'] ?? '',
        urgencyLevel: int.tryParse(data['urgencyLevel'] ?? '3') ?? 3,
        summary: message.notification?.body,
      );
    }
  });

  // Deep link: Khi user bấm vào notification (app đang background)
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    debugPrint('[FCM] Notification tapped (background): ${message.data}');
    _handleNotificationTap(message.data);
  });

  // Deep link: Khi app được mở từ notification (app đang tắt hoàn toàn)
  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    debugPrint('[FCM] App opened from notification: ${initialMessage.data}');
    // Delay navigation vì Navigator chưa sẵn sàng lúc này
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleNotificationTap(initialMessage.data);
    });
  }

  // Lock orientation — portrait only cho mobile emergency app
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const FloodAidApp());
}

/// Xử lý khi user bấm vào notification → điều hướng đến màn hình phù hợp
void _handleNotificationTap(Map<String, dynamic> data) {
  final type = data['type'];
  if (type == 'NEW_SOS') {
    // TNV bấm notification ca SOS mới → nhảy thẳng đến bản đồ SOS
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const VolunteerHomeScreen()),
      (route) => false,
    );
  }
}

class FloodAidApp extends StatelessWidget {
  const FloodAidApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'FloodAid',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const RoleSelectionScreen(),
    );
  }
}
