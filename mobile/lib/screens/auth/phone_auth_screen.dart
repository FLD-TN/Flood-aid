import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/fcm_service.dart';
import '../../services/toast_service.dart';
import '../victim/otp_verification_screen.dart';
import '../victim/sos_screen.dart';
import '../volunteer/volunteer_home_screen.dart';
import '../volunteer/pending_approval_screen.dart';
import '../volunteer/ekyc_screen.dart';
import 'terms_screen.dart';

class PhoneAuthScreen extends StatefulWidget {
  final String role;

  const PhoneAuthScreen({super.key, required this.role});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isValid = false;
  bool _isLoading = true;
  bool _isSendingOtp = false;
  bool _agreedToTerms = false;

  @override
  void initState() {
    super.initState();
    _checkExistingPhone();
    _phoneController.addListener(() {
      final value = _phoneController.text;
      final cleaned = value.replaceAll(RegExp(r'\D'), '');
      setState(() {
        _isValid = cleaned.length == 10 && cleaned.startsWith('0');
      });
    });
  }

  Future<void> _checkExistingPhone() async {
    if (widget.role == 'victim') {
      final prefs = await SharedPreferences.getInstance();
      final savedPhone = prefs.getString('victim_phone');

      if (savedPhone != null && savedPhone.isNotEmpty) {
        // Kiểm tra Firebase user hiện tại có khớp victim_phone không
        // Nếu TNV vừa đăng nhập bằng số khác, Firebase user sẽ là của TNV
        final currentUser = AuthService.currentUser;
        String firebasePhone = '';
        if (currentUser?.phoneNumber != null) {
          firebasePhone = currentUser!.phoneNumber!;
          if (firebasePhone.startsWith('+84')) {
            firebasePhone = '0${firebasePhone.substring(3)}';
          }
        }

        if (firebasePhone == savedPhone) {
          // Firebase user khớp victim → vào SosScreen
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const SosScreen()),
            );
            return;
          }
        } else {
          // Firebase user là người khác (ví dụ TNV vừa đăng nhập)
          // Xóa victim_phone cũ để bắt buộc xác thực lại
          await prefs.remove('victim_phone');
        }
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _handleContinue() async {
    final phone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (phone.isEmpty) return;

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
                role: widget.role,
                onSuccess: () async {
                  if (widget.role == 'victim') {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const SosScreen()),
                    );
                  } else {
                    await _onVolunteerOtpSuccess(phone);
                  }
                },
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
            await AuthService.signInWithCredential(credential, role: widget.role);
            if (!mounted) return;
            if (widget.role == 'victim') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const SosScreen()),
              );
            } else {
              await _onVolunteerOtpSuccess(phone);
            }
          } catch (e) {
             debugPrint('[PhoneAuthScreen] auto sign in error: $e');
          }
        }
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

  Future<void> _onVolunteerOtpSuccess(String phone) async {
    final result = await ApiService.verifyPhoneAuth(phone: phone);
    final status = result['status'] as String? ?? '';
    final httpStatus = result['httpStatus'] as int? ?? 0;

    if (httpStatus == 200 && status == 'APPROVED') {
      final volunteerId = result['volunteerId']?.toString() ?? '';
      if (volunteerId.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('volunteer_id', volunteerId);
        await prefs.setString('volunteer_phone', phone);
        await FcmService.registerToken(volunteerId);
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const VolunteerHomeScreen()),
      );
    } else if (httpStatus == 403 && status == 'PENDING_APPROVAL') {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PendingApprovalScreen()),
      );
    } else if (httpStatus == 404 && status == 'NOT_REGISTERED') {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => EkycScreen(phone: phone)),
      );
    } else {
      if (!mounted) return;
      ToastService.show(
        context: context,
        type: ToastType.error,
        message: result['message'] ?? 'Đã xảy ra lỗi khi xác thực',
      );
    }
  }

  void _showConfirmationBottomSheet() {
    FocusScope.of(context).unfocus(); // Ẩn bàn phím
    final displayPhone = '(+84) ${_phoneController.text}';
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),
                SizedBox(height: 24.h),
                Text(
                  'Bạn có muốn tiếp tục?',
                  style: GoogleFonts.inter(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  'Chúng tôi sẽ gửi mã xác thực đến số điện thoại bạn đã nhập:',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  displayPhone,
                  style: GoogleFonts.inter(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 32.h),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          side: const BorderSide(color: Colors.black),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child: Text(
                          'Hủy',
                          style: GoogleFonts.inter(
                            color: Colors.black,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _handleContinue();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child: Text(
                          'Tiếp tục',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Colors.black),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 0, 
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 24.h),
              // Progress Indicator
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.black, size: 24.sp),
                    Container(width: 40.w, height: 2.h, color: Colors.black),
                    Icon(Icons.circle_outlined, color: Colors.black, size: 24.sp),
                  ],
                ),
              ),
              SizedBox(height: 48.h),
              
              Text(
                'Xác thực số điện thoại.',
                style: GoogleFonts.inter(
                  fontSize: 28.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  height: 1.2,
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'Bằng việc xác minh SĐT, bạn có thể đăng nhập hoặc tạo tài khoản.',
                style: GoogleFonts.inter(
                  fontSize: 15.sp,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              SizedBox(height: 40.h),
              
              Text(
                'Số điện thoại',
                style: GoogleFonts.inter(
                  fontSize: 13.sp,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 8.h),
              Container(
                height: 56.h,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: Colors.grey[400]!),
                ),
                child: Row(
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: Row(
                        children: [
                          Text(
                            '🇻🇳',
                            style: TextStyle(fontSize: 20.sp),
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            '+84',
                            style: GoogleFonts.inter(
                              fontSize: 16.sp,
                              color: Colors.black,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1.w,
                      height: 24.h,
                      color: Colors.grey[400],
                    ),
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        maxLength: 12,
                        style: GoogleFonts.inter(
                          color: Colors.black, 
                          fontSize: 16.sp,
                          letterSpacing: 1.5,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        decoration: InputDecoration(
                          hintText: '0901 234 567',
                          counterText: '',
                          hintStyle: GoogleFonts.inter(
                            color: Colors.grey[400], 
                            fontSize: 16.sp,
                            letterSpacing: 1.5,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16.w),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24.w,
                    height: 24.w,
                    child: Checkbox(
                      value: _agreedToTerms,
                      activeColor: Colors.black,
                      onChanged: (val) {
                        setState(() {
                          _agreedToTerms = val ?? false;
                        });
                      },
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsScreen()));
                      },
                      child: RichText(
                        text: TextSpan(
                          text: 'Tôi đồng ý với ',
                          style: GoogleFonts.inter(
                            fontSize: 13.sp,
                            color: Colors.grey[700],
                          ),
                          children: [
                            TextSpan(
                              text: 'Điều khoản & Chính sách',
                              style: GoogleFonts.inter(
                                fontSize: 13.sp,
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            const TextSpan(
                              text: ' của ứng dụng.',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              const Spacer(),
              
              // Bottom Buttons
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: Text(
                        'Quay lại',
                        style: GoogleFonts.inter(
                          color: Colors.black,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    flex: 1,
                    child: ElevatedButton(
                      onPressed: (_isValid && !_isSendingOtp) 
                          ? () {
                              if (!_agreedToTerms) {
                                ToastService.show(
                                  context: context,
                                  type: ToastType.warning,
                                  message: 'Vui lòng đồng ý với Điều khoản & Chính sách để tiếp tục',
                                );
                                return;
                              }
                              _showConfirmationBottomSheet();
                            }
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
                      child: _isSendingOtp
                          ? SizedBox(
                              width: 20.w,
                              height: 20.w,
                              child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              'Tiếp tục',
                              style: GoogleFonts.inter(
                                color: _isValid ? Colors.white : Colors.grey[500],
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24.h),
            ],
          ),
        ),
      ),
    );
  }
}
