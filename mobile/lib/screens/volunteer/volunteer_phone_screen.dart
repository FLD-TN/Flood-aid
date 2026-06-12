import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/fcm_service.dart';
import '../../services/toast_service.dart';
import '../victim/otp_verification_screen.dart';
import 'volunteer_home_screen.dart';
import 'pending_approval_screen.dart';
import 'ekyc_screen.dart';

/// Màn hình nhập SĐT cho Tình nguyện viên — xác thực OTP Firebase
/// Nếu đã authenticated → vào thẳng VolunteerHomeScreen
class VolunteerPhoneScreen extends StatefulWidget {
  const VolunteerPhoneScreen({super.key});

  @override
  State<VolunteerPhoneScreen> createState() => _VolunteerPhoneScreenState();
}

class _VolunteerPhoneScreenState extends State<VolunteerPhoneScreen> {
  final _phoneController = TextEditingController();
  bool _isValid = false;
  bool _isLoading = true;
  bool _isSendingOtp = false;

  @override
  void initState() {
    super.initState();
    _checkExistingAuth();
  }

  /// TNV luôn phải xác thực OTP mỗi lần mở app
  Future<void> _checkExistingAuth() async {
    setState(() => _isLoading = false);
  }

  void _onPhoneChanged(String value) {
    final cleaned = value.replaceAll(RegExp(r'\D'), '');
    setState(() {
      _isValid = cleaned.length == 10 && cleaned.startsWith('0');
    });
  }

  Future<void> _handleContinue() async {
    final phone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (!_isValid) return;

    setState(() => _isSendingOtp = true);

    try {
      await AuthService.sendOtp(
        phoneNumber: phone,
        onCodeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;
          setState(() => _isSendingOtp = false);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OtpVerificationScreen(
                phoneNumber: phone,
                initialVerificationId: verificationId,
                role: 'volunteer',
                onSuccess: () => _onOtpSuccess(phone),
              ),
            ),
          );
        },
        onVerificationFailed: (e) {
          if (!mounted) return;
          setState(() => _isSendingOtp = false);
          ToastService.show(
            context: context,
            type: ToastType.error,
            message: 'Lỗi gửi OTP: ${e.message}',
          );
        },
        onCodeAutoRetrievalTimeout: (String verificationId) {},
        onVerificationCompleted: (credential) async {
          try {
            await AuthService.signInWithCredential(credential, role: 'volunteer');
            if (!mounted) return;
            await _onOtpSuccess(phone);
          } catch (e) {
            print('[VolunteerPhoneScreen] auto sign in error: $e');
          }
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSendingOtp = false);
      ToastService.show(
        context: context,
        type: ToastType.error,
        message: 'Đã xảy ra lỗi khi gửi mã OTP',
      );
    }
  }

  /// Sau khi OTP thành công → Kiểm tra trạng thái TNV trên Backend
  Future<void> _onOtpSuccess(String phone) async {
    final result = await ApiService.verifyPhoneAuth(phone: phone);
    final status = result['status'] as String? ?? '';
    final httpStatus = result['httpStatus'] as int? ?? 0;

    if (httpStatus == 200 && status == 'APPROVED') {
      // TH 1: TNV đã được Admin duyệt → Đăng nhập thành công
      final volunteerId = result['volunteerId']?.toString() ?? '';
      if (volunteerId.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('volunteer_id', volunteerId);
        await prefs.setString('volunteer_phone', phone);

        // Đăng ký FCM Token
        await FcmService.registerToken(volunteerId);
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const VolunteerHomeScreen()),
      );
    } else if (httpStatus == 403 && status == 'PENDING_APPROVAL') {
      // TH 2: TNV đã đăng ký nhưng chưa được duyệt → Màn hình chờ
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PendingApprovalScreen()),
      );
    } else if (httpStatus == 404 && status == 'NOT_REGISTERED') {
      // TH 3: Chưa từng đăng ký → Chuyển sang luồng eKYC
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => EkycScreen(phone: phone)),
      );
    } else {
      // Lỗi mạng hoặc lỗi không xác định
      if (!mounted) return;
      ToastService.show(
        context: context,
        type: ToastType.error,
        message: result['message'] ?? 'Đã xảy ra lỗi khi xác thực',
      );
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            children: [
              SizedBox(height: 40.h),

              // ── Icon ──
              Container(
                width: 80.w,
                height: 80.w,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 1.5.w,
                  ),
                ),
                child: Center(
                  child: Text('🦺', style: TextStyle(fontSize: 40.sp)),
                ),
              ),
              SizedBox(height: 24.h),

              // ── Title ──
              Text(
                'Đăng nhập Tình nguyện viên',
                style: AppTypography.displayMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Xác thực SĐT để nhận ca cứu hộ.\nSĐT giúp nạn nhân liên lạc trực tiếp.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 40.h),

              // ── Phone Input ──
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: _isValid
                        ? AppColors.primary
                        : AppColors.surfaceBorder,
                    width: _isValid ? 2.w : 1.w,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 16.r,
                      offset: Offset(0, 4.h),
                    ),
                  ],
                ),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 8.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        '🇻🇳 +84',
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        autofocus: true,
                        keyboardType: TextInputType.phone,
                        maxLength: 12,
                        onChanged: _onPhoneChanged,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        style: AppTypography.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          letterSpacing: 1.5,
                        ),
                        decoration: InputDecoration(
                          hintText: '0901 234 567',
                          hintStyle: AppTypography.bodyLarge.copyWith(
                            color: AppColors.textMuted,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          counterText: '',
                          filled: false,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    if (_isValid)
                      Icon(
                        Icons.check_circle,
                        color: AppColors.success,
                        size: 24.r,
                      ),
                  ],
                ),
              ),
              SizedBox(height: 12.h),

              Text(
                'Nhập đúng 10 số (bắt đầu bằng 0)',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              SizedBox(height: 32.h),

              // ── Continue Button ──
              SizedBox(
                width: double.infinity,
                height: 56.h,
                child: ElevatedButton(
                  onPressed: (_isValid && !_isSendingOtp) ? _handleContinue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isValid
                        ? AppColors.primary
                        : AppColors.surfaceBorder,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    elevation: _isValid ? 4 : 0,
                    shadowColor: AppColors.primary.withValues(alpha: 0.4),
                  ),
                  child: _isSendingOtp
                      ? SizedBox(
                          width: 24.w,
                          height: 24.w,
                          child: const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.verified_user, size: 20.r),
                            SizedBox(width: 8.w),
                            Text(
                              'XÁC THỰC SĐT',
                              style: AppTypography.labelLarge.copyWith(
                                color: Colors.white,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const Spacer(),

              // ── Info note ──
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18.r,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        'SĐT được xác thực qua OTP mỗi lần đăng nhập để đảm bảo an toàn.',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
            ],
          ),
        ),
      ),
    );
  }
}
