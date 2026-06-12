import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static User? get currentUser => _auth.currentUser;
  static bool get isAuthenticated => currentUser != null;

  /// Gửi OTP đến số điện thoại
  /// [onCodeSent] sẽ nhận được `verificationId` để dùng cho bước verifyOTP
  static Future<void> sendOtp({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(FirebaseAuthException e) onVerificationFailed,
    required Function(String verificationId) onCodeAutoRetrievalTimeout,
    Function(PhoneAuthCredential credential)? onVerificationCompleted,
  }) async {
    // Firebase yêu cầu format E.164 (+84...)
    String formattedPhone = phoneNumber;
    if (formattedPhone.startsWith('0')) {
      formattedPhone = '+84${formattedPhone.substring(1)}';
    }


    await _auth.verifyPhoneNumber(
      phoneNumber: formattedPhone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) {
        if (onVerificationCompleted != null) {
          onVerificationCompleted(credential);
        }
      },
      verificationFailed: onVerificationFailed,
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: onCodeAutoRetrievalTimeout,
    );
  }

  /// Xác thực mã OTP người dùng nhập vào
  /// [role] = 'victim' hoặc 'volunteer' để lưu SĐT vào key riêng biệt
  static Future<UserCredential?> verifyOtp({
    required String verificationId,
    required String smsCode,
    String role = 'victim',
  }) async {
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      
      // Lưu lại SĐT gốc vào SharedPreferences theo role
      if (userCredential.user?.phoneNumber != null) {
        final prefs = await SharedPreferences.getInstance();
        String phone = userCredential.user!.phoneNumber!;
        if (phone.startsWith('+84')) {
          phone = '0${phone.substring(3)}';
        }
        // Lưu vào key riêng theo role (victim_phone / volunteer_phone)
        final key = '${role}_phone';
        await prefs.setString(key, phone);
      }
      
      return userCredential;
    } catch (e) {
      print('[AuthService] verifyOtp error: $e');
      rethrow;
    }
  }

  /// SignIn directly with credential (for auto retrieval)
  /// [role] = 'victim' hoặc 'volunteer' để lưu SĐT vào key riêng biệt
  static Future<UserCredential> signInWithCredential(
    PhoneAuthCredential credential, {
    String role = 'victim',
  }) async {
     final userCredential = await _auth.signInWithCredential(credential);
      if (userCredential.user?.phoneNumber != null) {
        final prefs = await SharedPreferences.getInstance();
        String phone = userCredential.user!.phoneNumber!;
        if (phone.startsWith('+84')) {
          phone = '0${phone.substring(3)}';
        }
        final key = '${role}_phone';
        await prefs.setString(key, phone);
      }
      return userCredential;
  }

  /// Lấy ID token JWT (để gửi lên backend)
  static Future<String?> getIdToken() async {
    try {
      if (currentUser == null) return null;
      return await currentUser!.getIdToken();
    } catch (e) {
      print('[AuthService] getIdToken error: $e');
      return null;
    }
  }

  /// Đăng xuất — xóa tất cả phone keys
  static Future<void> signOut() async {
    await _auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('victim_phone');
    await prefs.remove('volunteer_phone');
  }
}
