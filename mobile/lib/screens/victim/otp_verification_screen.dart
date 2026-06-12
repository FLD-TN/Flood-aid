import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/toast_service.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String initialVerificationId;
  /// Callback khi xác thực OTP thành công
  final VoidCallback onSuccess;
  /// Role: 'victim' hoặc 'volunteer' — để lưu SĐT vào key riêng
  final String role;

  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.initialVerificationId,
    required this.onSuccess,
    this.role = 'victim',
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  bool _isLoading = false;
  String _errorMessage = '';
  late String _verificationId;

  // Fix #3: Countdown timer chống spam gửi lại OTP
  int _resendCountdown = 60;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _verificationId = widget.initialVerificationId;
    _startResendTimer();
    // Auto focus when screen appears
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    _focusNode.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendCountdown = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        _resendCountdown--;
        if (_resendCountdown <= 0) {
          timer.cancel();
        }
      });
    });
  }

  Future<void> _verifyOtp(String smsCode) async {
    if (smsCode.length < 6) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await AuthService.verifyOtp(
        verificationId: _verificationId,
        smsCode: smsCode,
        role: widget.role,
      );
      
      if (!mounted) return;
      // Gọi callback thành công
      widget.onSuccess();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Mã OTP không đúng hoặc đã hết hạn. Vui lòng thử lại.';
        _otpController.clear();
        _focusNode.requestFocus();
      });
    }
  }

  Future<void> _resendOtp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await AuthService.sendOtp(
        phoneNumber: widget.phoneNumber,
        onCodeSent: (String verificationId, int? resendToken) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _isLoading = false;
            });
            ToastService.show(
              context: context,
              type: ToastType.success,
              message: 'Đã gửi lại mã OTP mới',
            );
            _startResendTimer();
          }
        },
        onVerificationFailed: (e) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage = e.message ?? 'Lỗi gửi lại OTP';
            });
          }
        },
        onCodeAutoRetrievalTimeout: (String verificationId) {
          if (mounted) {
            setState(() => _verificationId = verificationId);
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Đã xảy ra lỗi khi gửi lại mã';
        });
      }
    }
  }

  String _formatHiddenPhone(String phone) {
    if (phone.length >= 10) {
      return '${phone.substring(0, 4)}***${phone.substring(phone.length - 3)}';
    }
    return phone;
  }

  @override
  Widget build(BuildContext context) {
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
              SizedBox(height: 20.h),
              
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
                    Icons.message,
                    size: 40.r,
                    color: AppColors.primary,
                  ),
                ),
              ),
              SizedBox(height: 24.h),
              
              Text(
                'Nhập mã OTP',
                style: AppTypography.displayMedium,
              ),
              SizedBox(height: 8.h),
              
              Text(
                'Mã 6 số đã được gửi đến số\n${_formatHiddenPhone(widget.phoneNumber)}',
                style: AppTypography.bodyMedium,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 40.h),
              
              // Hidden TextField overlapping with custom UI
              Stack(
                alignment: Alignment.center,
                children: [
                  // Real textfield but hidden
                  Opacity(
                    opacity: 0.0,
                    child: TextField(
                      controller: _otpController,
                      focusNode: _focusNode,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      onChanged: (val) {
                        setState(() {});
                        if (val.length == 6) {
                          _verifyOtp(val);
                        }
                      },
                    ),
                  ),
                  
                  // Custom UI
                  GestureDetector(
                    onTap: () => _focusNode.requestFocus(),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(6, (index) {
                        String char = '';
                        if (_otpController.text.length > index) {
                          char = _otpController.text[index];
                        }
                        bool isFocused = _otpController.text.length == index && _focusNode.hasFocus;
                        
                        return Container(
                          width: 48.w,
                          height: 56.h,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceCard,
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(
                              color: isFocused ? AppColors.primary : AppColors.surfaceBorder,
                              width: isFocused ? 2 : 1,
                            ),
                          ),
                          child: Text(
                            char,
                            style: AppTypography.displayMedium,
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
              
              if (_errorMessage.isNotEmpty) ...[
                SizedBox(height: 16.h),
                Text(
                  _errorMessage,
                  style: AppTypography.bodySmall.copyWith(color: AppColors.danger),
                  textAlign: TextAlign.center,
                ),
              ],
              
              SizedBox(height: 32.h),
              
              if (_isLoading)
                const CircularProgressIndicator(color: AppColors.primary)
              else
                TextButton(
                  onPressed: _resendCountdown > 0 ? null : _resendOtp,
                  child: Text(
                    _resendCountdown > 0
                        ? 'Gửi lại mã OTP (${_resendCountdown}s)'
                        : 'Gửi lại mã OTP',
                    style: AppTypography.labelMedium.copyWith(
                      color: _resendCountdown > 0
                          ? AppColors.textMuted
                          : AppColors.primary,
                    ),
                  ),
                ),
                
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
