import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../victim/otp_verification_screen.dart';
import 'volunteer_home_screen.dart';

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

  /// Kiểm tra đã authenticated chưa → bỏ qua nếu có
  Future<void> _checkExistingAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPhone = prefs.getString('user_phone');

    if (AuthService.isAuthenticated || (savedPhone != null && savedPhone.isNotEmpty)) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const VolunteerHomeScreen()),
        );
        return;
      }
    }

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
                onSuccess: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const VolunteerHomeScreen()),
                  );
                },
              ),
            ),
          );
        },
        onVerificationFailed: (e) {
          if (!mounted) return;
          setState(() => _isSendingOtp = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi gửi OTP: ${e.message}')),
          );
        },
        onCodeAutoRetrievalTimeout: (String verificationId) {},
        onVerificationCompleted: (credential) async {
          try {
            await AuthService.signInWithCredential(credential);
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const VolunteerHomeScreen()),
            );
          } catch (e) {
            print('[VolunteerPhoneScreen] auto sign in error: $e');
          }
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSendingOtp = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xảy ra lỗi khi gửi mã OTP')),
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
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 40),

              // ── Icon ──
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: const Center(
                  child: Text('🦺', style: TextStyle(fontSize: 40)),
                ),
              ),
              const SizedBox(height: 24),

              // ── Title ──
              Text(
                'Đăng nhập Tình nguyện viên',
                style: AppTypography.displayMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Xác thực SĐT để nhận ca cứu hộ.\nSĐT giúp nạn nhân liên lạc trực tiếp.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // ── Phone Input ──
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isValid
                        ? AppColors.primary
                        : AppColors.surfaceBorder,
                    width: _isValid ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '🇻🇳 +84',
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
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
                      const Icon(
                        Icons.check_circle,
                        color: AppColors.success,
                        size: 24,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Text(
                'Nhập đúng 10 số (bắt đầu bằng 0)',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 32),

              // ── Continue Button ──
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: (_isValid && !_isSendingOtp) ? _handleContinue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isValid
                        ? AppColors.primary
                        : AppColors.surfaceBorder,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: _isValid ? 4 : 0,
                    shadowColor: AppColors.primary.withOpacity(0.4),
                  ),
                  child: _isSendingOtp
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.verified_user, size: 20),
                            const SizedBox(width: 8),
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
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.15),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'SĐT được xác thực qua OTP một lần duy nhất. Lần sau mở app sẽ tự đăng nhập.',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
