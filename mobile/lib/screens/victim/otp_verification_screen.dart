import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String initialVerificationId;
  /// Callback khi xác thực OTP thành công
  final VoidCallback onSuccess;

  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.initialVerificationId,
    required this.onSuccess,
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

  @override
  void initState() {
    super.initState();
    _verificationId = widget.initialVerificationId;
    // Auto focus when screen appears
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    _focusNode.dispose();
    super.dispose();
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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Đã gửi lại mã OTP mới')),
            );
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
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              
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
                  child: Icon(
                    Icons.message,
                    size: 40,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              Text(
                'Nhập mã OTP',
                style: AppTypography.displayMedium,
              ),
              const SizedBox(height: 8),
              
              Text(
                'Mã 6 số đã được gửi đến số\n${_formatHiddenPhone(widget.phoneNumber)}',
                style: AppTypography.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              
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
                          width: 48,
                          height: 56,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceCard,
                            borderRadius: BorderRadius.circular(8),
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
                const SizedBox(height: 16),
                Text(
                  _errorMessage,
                  style: AppTypography.bodySmall.copyWith(color: AppColors.danger),
                  textAlign: TextAlign.center,
                ),
              ],
              
              const SizedBox(height: 32),
              
              if (_isLoading)
                const CircularProgressIndicator(color: AppColors.primary)
              else
                TextButton(
                  onPressed: _resendOtp,
                  child: Text(
                    'Gửi lại mã OTP',
                    style: AppTypography.labelMedium.copyWith(color: AppColors.primary),
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
