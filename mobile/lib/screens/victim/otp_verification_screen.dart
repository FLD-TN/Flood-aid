import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/auth_service.dart';
import '../../services/toast_service.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String initialVerificationId;
  final VoidCallback onSuccess;
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

  int _resendCountdown = 60;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _verificationId = widget.initialVerificationId;
    _startResendTimer();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 8.h),
              // Progress Indicator
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.black, size: 24.sp),
                    Container(width: 40.w, height: 2.h, color: Colors.black),
                    Icon(Icons.check_circle, color: Colors.black, size: 24.sp),
                  ],
                ),
              ),
              SizedBox(height: 48.h),
              
              Text(
                'Nhập mã xác thực OTP.',
                style: GoogleFonts.inter(
                  fontSize: 28.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  height: 1.2,
                ),
              ),
              SizedBox(height: 16.h),
              
              RichText(
                text: TextSpan(
                  text: 'Mã xác thực đã được gửi đến số\n',
                  style: GoogleFonts.inter(
                    fontSize: 15.sp,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                  children: [
                    TextSpan(
                      text: '(+84) ${widget.phoneNumber}',
                      style: GoogleFonts.inter(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
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
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: isFocused ? Colors.black : Colors.grey[300]!,
                              width: isFocused ? 2 : 1,
                            ),
                          ),
                          child: Text(
                            char,
                            style: GoogleFonts.inter(
                              fontSize: 24.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
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
                  style: GoogleFonts.inter(color: Colors.red, fontSize: 13.sp),
                ),
              ],
              
              SizedBox(height: 32.h),
              
              Center(
                child: GestureDetector(
                  onTap: _resendCountdown > 0 ? null : _resendOtp,
                  child: RichText(
                    text: TextSpan(
                      text: "Chưa nhận được mã? ",
                      style: GoogleFonts.inter(
                        color: Colors.grey[600],
                        fontSize: 14.sp,
                      ),
                      children: [
                        TextSpan(
                          text: _resendCountdown > 0 
                            ? 'Gửi lại ( ${_resendCountdown}s )'
                            : 'Gửi lại',
                          style: GoogleFonts.inter(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 14.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
                
              const Spacer(),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _otpController.text.length == 6 && !_isLoading 
                      ? () => _verifyOtp(_otpController.text) 
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    disabledBackgroundColor: Colors.grey[300],
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 20.w,
                          height: 20.w,
                          child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          'Tiếp tục',
                          style: GoogleFonts.inter(
                            color: _otpController.text.length == 6 ? Colors.white : Colors.grey[500],
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              SizedBox(height: 24.h),
            ],
          ),
        ),
      ),
    );
  }
}
