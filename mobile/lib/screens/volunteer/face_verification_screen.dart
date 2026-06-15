import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/toast_service.dart';
import 'volunteer_registration_screen.dart';

/// Màn hình Xác thực khuôn mặt — So sánh ảnh CCCD với ảnh selfie qua FPT.AI FaceMatch
/// Tự động mở camera trước khi vào màn hình để chụp selfie
class FaceVerificationScreen extends StatefulWidget {
  final String phone;
  final Map<String, dynamic> ekycData;
  final String cccdImageBase64; // Ảnh CCCD gốc để so sánh

  const FaceVerificationScreen({
    super.key,
    required this.phone,
    required this.ekycData,
    required this.cccdImageBase64,
  });

  @override
  State<FaceVerificationScreen> createState() => _FaceVerificationScreenState();
}

class _FaceVerificationScreenState extends State<FaceVerificationScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  File? _selfieImage;
  bool _isVerifying = false;
  bool _cameraOpened = false;

  // Kết quả xác thực
  bool? _isMatch;
  double? _similarity;
  String? _errorMessage;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Tự động mở camera trước khi vào màn hình
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openFrontCamera();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  /// Tự động mở camera trước để chụp selfie
  Future<void> _openFrontCamera() async {
    if (_cameraOpened) return;
    _cameraOpened = true;

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 85,
        maxWidth: 1920,
      );

      if (image == null) {
        // User cancelled camera — cho phép thử lại
        if (mounted) {
          setState(() => _cameraOpened = false);
        }
        return;
      }

      if (!mounted) return;

      setState(() {
        _selfieImage = File(image.path);
      });

      // Tự động gọi FaceMatch ngay sau khi chụp
      await _verifyFace();
    } catch (e) {
      if (!mounted) return;
      setState(() => _cameraOpened = false);
      ToastService.show(
        context: context,
        type: ToastType.error,
        message: 'Không thể mở camera: $e',
      );
    }
  }

  /// Gọi FPT.AI FaceMatch API
  Future<void> _verifyFace() async {
    if (_selfieImage == null) return;

    setState(() {
      _isVerifying = true;
      _isMatch = null;
      _similarity = null;
      _errorMessage = null;
    });

    try {
      final selfieBytes = await _selfieImage!.readAsBytes();
      final selfieBase64 = base64Encode(selfieBytes);

      final result = await ApiService.checkFace(
        base64Image1: widget.cccdImageBase64,
        base64Image2: selfieBase64,
      );

      if (!mounted) return;

      if (result == null) {
        setState(() {
          _isVerifying = false;
          _errorMessage = 'Không thể kết nối đến server. Vui lòng thử lại.';
        });
        return;
      }

      // Kiểm tra lỗi từ FPT.AI
      if (result.containsKey('error') && result.containsKey('fptCode')) {
        setState(() {
          _isVerifying = false;
          _errorMessage = result['error'] as String;
        });
        return;
      }

      final isMatch = result['isMatch'] == true;
      final similarity = (result['similarity'] as num?)?.toDouble() ?? 0;

      setState(() {
        _isVerifying = false;
        _isMatch = isMatch;
        _similarity = similarity;
      });

      if (isMatch) {
        // Khớp → Chờ 1.5s cho user thấy kết quả rồi chuyển sang Registration
        await Future.delayed(const Duration(milliseconds: 1500));
        if (!mounted) return;

        final enrichedData = Map<String, dynamic>.from(widget.ekycData);
        enrichedData['faceVerified'] = true;
        enrichedData['faceSimilarity'] = similarity;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => VolunteerRegistrationScreen(
              phone: widget.phone,
              ekycData: enrichedData,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _errorMessage = 'Đã xảy ra lỗi: $e';
      });
    }
  }

  /// Chụp lại selfie
  Future<void> _retakeSelfie() async {
    setState(() {
      _selfieImage = null;
      _isMatch = null;
      _similarity = null;
      _errorMessage = null;
      _cameraOpened = false;
    });
    await _openFrontCamera();
  }

  /// Bỏ qua face verification — cho phép đăng ký với cảnh báo
  void _skipFaceVerification() {
    final enrichedData = Map<String, dynamic>.from(widget.ekycData);
    enrichedData['faceVerified'] = false;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => VolunteerRegistrationScreen(
          phone: widget.phone,
          ekycData: enrichedData,
        ),
      ),
    );
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
        title: Text(
          'Xác thực khuôn mặt',
          style: AppTypography.headingMedium,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            children: [
              SizedBox(height: 24.h),

              // ── Icon ──
              _buildHeaderIcon(),
              SizedBox(height: 20.h),

              // ── Title ──
              Text(
                _getTitle(),
                style: AppTypography.displayMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8.h),
              Text(
                _getSubtitle(),
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32.h),

              // ── Preview / Result Area ──
              Expanded(
                child: _buildContentArea(),
              ),
              SizedBox(height: 24.h),

              // ── Action Buttons ──
              _buildActions(),
              SizedBox(height: 16.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderIcon() {
    if (_isVerifying) {
      return ScaleTransition(
        scale: _pulseAnimation,
        child: Container(
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
            child: Text('🔍', style: TextStyle(fontSize: 40.sp)),
          ),
        ),
      );
    }

    if (_isMatch == true) {
      return Container(
        width: 80.w,
        height: 80.w,
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: AppColors.success.withValues(alpha: 0.3),
            width: 1.5.w,
          ),
        ),
        child: Center(
          child: Text('✅', style: TextStyle(fontSize: 40.sp)),
        ),
      );
    }

    if (_isMatch == false || _errorMessage != null) {
      return Container(
        width: 80.w,
        height: 80.w,
        decoration: BoxDecoration(
          color: AppColors.alertRed.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: AppColors.alertRed.withValues(alpha: 0.3),
            width: 1.5.w,
          ),
        ),
        child: Center(
          child: Text('❌', style: TextStyle(fontSize: 40.sp)),
        ),
      );
    }

    return Container(
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
        child: Text('🤳', style: TextStyle(fontSize: 40.sp)),
      ),
    );
  }

  String _getTitle() {
    if (_isVerifying) return 'Đang xác thực...';
    if (_isMatch == true) return 'Xác thực thành công!';
    if (_isMatch == false) return 'Khuôn mặt không khớp';
    if (_errorMessage != null) return 'Không thể xác thực';
    return 'Xác thực khuôn mặt';
  }

  String _getSubtitle() {
    if (_isVerifying) {
      return 'Đang so sánh khuôn mặt với ảnh trên CCCD. Vui lòng đợi...';
    }
    if (_isMatch == true) {
      return 'Khuôn mặt khớp với CCCD (${_similarity?.toStringAsFixed(1)}%). Đang chuyển sang đăng ký...';
    }
    if (_isMatch == false) {
      return 'Khuôn mặt không trùng khớp với ảnh trên CCCD (${_similarity?.toStringAsFixed(1)}%). Vui lòng chụp lại hoặc bỏ qua.';
    }
    if (_errorMessage != null) {
      return _errorMessage!;
    }
    return 'Chụp ảnh selfie để so sánh với ảnh trên CCCD của bạn.';
  }

  Widget _buildContentArea() {
    if (_selfieImage != null) {
      return _buildSelfiePreview();
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: AppColors.surfaceBorder,
          width: 2.w,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.face_retouching_natural,
              size: 64.r,
              color: AppColors.textMuted.withValues(alpha: 0.4),
            ),
            SizedBox(height: 16.h),
            Text(
              'Ảnh selfie của bạn',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Camera trước sẽ tự động mở',
              style: AppTypography.caption.copyWith(
                color: AppColors.textMuted.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelfiePreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16.r),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            _selfieImage!,
            fit: BoxFit.cover,
          ),
          // Overlay kết quả
          if (_isMatch != null || _isVerifying)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: _isVerifying
                      ? Colors.black.withValues(alpha: 0.4)
                      : _isMatch == true
                          ? AppColors.success.withValues(alpha: 0.2)
                          : AppColors.alertRed.withValues(alpha: 0.2),
                ),
                child: Center(
                  child: _isVerifying
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 48.w,
                              height: 48.w,
                              child: const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            ),
                            SizedBox(height: 16.h),
                            Text(
                              'Đang so sánh khuôn mặt...',
                              style: AppTypography.labelMedium.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ],
                        )
                      : _isMatch == true
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(16.w),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withValues(alpha: 0.9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.check, color: Colors.white, size: 48.r),
                                ),
                                SizedBox(height: 16.h),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(24.r),
                                  ),
                                  child: Text(
                                    'Khớp ${_similarity?.toStringAsFixed(1)}%',
                                    style: AppTypography.labelLarge.copyWith(
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(16.w),
                                  decoration: BoxDecoration(
                                    color: AppColors.alertRed.withValues(alpha: 0.9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.close, color: Colors.white, size: 48.r),
                                ),
                                SizedBox(height: 16.h),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(24.r),
                                  ),
                                  child: Text(
                                    'Không khớp (${_similarity?.toStringAsFixed(1)}%)',
                                    style: AppTypography.labelLarge.copyWith(
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                ),
              ),
            ),
          // Bottom gradient
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 60.h,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent,
                  ],
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                _isVerifying ? 'Đang xử lý...' : 'Ảnh selfie',
                style: AppTypography.labelMedium.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    // Đang xác thực → không hiển thị nút
    if (_isVerifying) {
      return SizedBox(height: 56.h);
    }

    // Xác thực thành công → đang chuyển trang
    if (_isMatch == true) {
      return SizedBox(
        width: double.infinity,
        height: 56.h,
        child: ElevatedButton.icon(
          onPressed: null,
          icon: SizedBox(
            width: 22.w,
            height: 22.w,
            child: const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2.5,
            ),
          ),
          label: Text(
            'ĐANG CHUYỂN TRANG...',
            style: AppTypography.labelLarge.copyWith(
              color: Colors.white,
              letterSpacing: 1.5,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
            elevation: 4,
            shadowColor: AppColors.success.withValues(alpha: 0.4),
          ),
        ),
      );
    }

    // Chưa chụp selfie hoặc kết quả không khớp / lỗi → cho chụp lại
    return Column(
      children: [
        // Nút chụp lại / chụp selfie
        SizedBox(
          width: double.infinity,
          height: 56.h,
          child: ElevatedButton.icon(
            onPressed: _retakeSelfie,
            icon: Icon(
              _selfieImage == null ? Icons.camera_alt : Icons.refresh,
              size: 22.r,
            ),
            label: Text(
              _selfieImage == null ? 'CHỤP ẢNH SELFIE' : 'CHỤP LẠI',
              style: AppTypography.labelLarge.copyWith(
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
              elevation: 4,
              shadowColor: AppColors.primary.withValues(alpha: 0.4),
            ),
          ),
        ),
        SizedBox(height: 8.h),

        // Bỏ qua
        TextButton(
          onPressed: _skipFaceVerification,
          child: Text(
            'Bỏ qua xác thực khuôn mặt →',
            style: AppTypography.caption.copyWith(
              color: AppColors.textMuted,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}
