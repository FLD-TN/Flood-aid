import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/toast_service.dart';
import 'otp_verification_screen.dart';
import 'sos_screen.dart';

/// Màn hình nhập SĐT — thay thế OTP verification tạm thời
/// Lưu SĐT vào SharedPreferences, chỉ nhập 1 lần
class PhoneInputScreen extends StatefulWidget {
  const PhoneInputScreen({super.key});

  @override
  State<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends State<PhoneInputScreen> {
  final _phoneController = TextEditingController();
  bool _isValid = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkExistingPhone();
  }

  /// Kiểm tra xem đã có SĐT lưu sẵn chưa → bỏ qua nếu có
  Future<void> _checkExistingPhone() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPhone = prefs.getString('victim_phone');

    if (savedPhone != null && savedPhone.isNotEmpty) {
      if (mounted) {
        // Đã có SĐT → vào thẳng SOS screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SosScreen()),
        );
        return;
      }
    }

    setState(() => _isLoading = false);
  }

  void _onPhoneChanged(String value) {
    // Validate SĐT Việt Nam: 10 số, bắt đầu bằng 0
    final cleaned = value.replaceAll(RegExp(r'\D'), '');
    setState(() {
      _isValid = cleaned.length == 10 && cleaned.startsWith('0');
    });
  }

  Future<void> _handleContinue() async {
    final phone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (!_isValid) return;

    setState(() => _isLoading = true);

    try {
      await AuthService.sendOtp(
        phoneNumber: phone,
        onCodeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OtpVerificationScreen(
                phoneNumber: phone,
                initialVerificationId: verificationId,
                onSuccess: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const SosScreen()),
                  );
                },
              ),
            ),
          );
        },
        onVerificationFailed: (e) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          ToastService.show(
            context: context,
            type: ToastType.error,
            message: 'Lỗi gửi OTP: ${e.message}',
          );
        },
        onCodeAutoRetrievalTimeout: (String verificationId) {
          // Xử lý timeout nếu cần
        },
        onVerificationCompleted: (credential) async {
          // Tự động verify thành công trên Android (auto retrieval)
          try {
            await AuthService.signInWithCredential(credential);
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const SosScreen()),
            );
          } catch (e) {
             print('[FloodAid] auto sign in error: $e');
          }
        }
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ToastService.show(
        context: context,
        type: ToastType.error,
        message: 'Đã xảy ra lỗi khi gửi mã OTP',
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
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            children: [
              SizedBox(height: 60.h),

              // ── Icon ──
              Container(
                width: 80.w,
                height: 80.w,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.phone_android,
                    size: 40.r,
                    color: AppColors.primary,
                  ),
                ),
              ),
              SizedBox(height: 24.h),

              // ── Title ──
              Text(
                'Xác thực Số điện thoại',
                style: AppTypography.displayMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Nhập SĐT để định danh ca SOS của bạn.\nSĐT giúp đội cứu hộ liên lạc khi cần.',
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
                    width: _isValid ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                child: Row(
                  children: [
                    // Country prefix
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
                    // Phone input
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
                    // Checkmark
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

              // ── Helper text ──
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
                  onPressed: _isValid ? _handleContinue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isValid
                        ? AppColors.alertRed
                        : AppColors.surfaceBorder,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    elevation: _isValid ? 4 : 0,
                    shadowColor: AppColors.alertRed.withValues(alpha: 0.4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.arrow_forward, size: 20.r),
                      SizedBox(width: 8.w),
                      Text(
                        'TIẾP TỤC ĐẾN SOS',
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
                        'SĐT chỉ dùng để định danh ca SOS và liên lạc cứu hộ. Bạn chỉ cần nhập một lần.',
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
