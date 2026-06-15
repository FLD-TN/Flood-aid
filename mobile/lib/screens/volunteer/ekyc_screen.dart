import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/toast_service.dart';
import 'face_verification_screen.dart';
import 'volunteer_registration_screen.dart';

/// Màn hình eKYC — Hướng dẫn TNV chụp ảnh CCCD (Mặt trước)
/// Gọi FPT.AI qua Backend để nhận diện → Truyền dữ liệu sang Form Đăng ký
class EkycScreen extends StatefulWidget {
  final String phone;

  const EkycScreen({super.key, required this.phone});

  @override
  State<EkycScreen> createState() => _EkycScreenState();
}

class _EkycScreenState extends State<EkycScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _capturedImage;
  bool _isProcessing = false;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (image == null) return;

      setState(() {
        _capturedImage = File(image.path);
      });
    } catch (e) {
      if (!mounted) return;
      ToastService.show(
        context: context,
        type: ToastType.error,
        message: 'Không thể chọn ảnh: $e',
      );
    }
  }

  Future<void> _processImage() async {
    if (_capturedImage == null) return;

    setState(() => _isProcessing = true);

    try {
      // Chuyển ảnh sang base64
      final bytes = await _capturedImage!.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Gọi API nhận diện CCCD
      final result = await ApiService.recognizeId(base64Image: base64Image);

      if (!mounted) return;

      if (result == null) {
        setState(() => _isProcessing = false);
        ToastService.show(
          context: context,
          type: ToastType.error,
          message: 'Không thể nhận diện CCCD. Vui lòng chụp lại ảnh rõ nét hơn.',
        );
        return;
      }

      // CCCD hợp lệ → Tự động chuyển sang xác thực khuôn mặt
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => FaceVerificationScreen(
            phone: widget.phone,
            ekycData: result,
            cccdImageBase64: base64Image,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ToastService.show(
        context: context,
        type: ToastType.error,
        message: 'Đã xảy ra lỗi: $e',
      );
    }
  }

  /// Bỏ qua eKYC — cho phép TNV đăng ký thủ công (không có CCCD)
  void _skipEkyc() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => VolunteerRegistrationScreen(
          phone: widget.phone,
          ekycData: null,
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
          'Xác thực CCCD',
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
                  child: Text('🪪', style: TextStyle(fontSize: 40.sp)),
                ),
              ),
              SizedBox(height: 20.h),

              // ── Title ──
              Text(
                'Xác minh danh tính',
                style: AppTypography.displayMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8.h),
              Text(
                'Chụp ảnh mặt trước CCCD/CMND để tự động điền thông tin đăng ký.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32.h),

              // ── Preview Area ──
              Expanded(
                child: _capturedImage != null
                    ? _buildPreview()
                    : _buildPlaceholder(),
              ),
              SizedBox(height: 24.h),

              // ── Action Buttons ──
              if (_capturedImage == null) ...[
                // Chụp ảnh hoặc chọn từ thư viện
                SizedBox(
                  width: double.infinity,
                  height: 56.h,
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: Icon(Icons.camera_alt, size: 22.r),
                    label: Text(
                      'CHỤP ẢNH CCCD',
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
                SizedBox(height: 12.h),
                SizedBox(
                  width: double.infinity,
                  height: 48.h,
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: Icon(Icons.photo_library_outlined, size: 20.r),
                    label: Text(
                      'CHỌN TỪ THƯ VIỆN',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        width: 1.5.w,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                // Đã chụp ảnh → Xử lý hoặc chụp lại
                SizedBox(
                  width: double.infinity,
                  height: 56.h,
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _processImage,
                    icon: _isProcessing
                        ? SizedBox(
                            width: 22.w,
                            height: 22.w,
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Icon(Icons.auto_awesome, size: 22.r),
                    label: Text(
                      _isProcessing ? 'ĐANG NHẬN DIỆN...' : 'XÁC THỰC CCCD',
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
                SizedBox(height: 12.h),
                SizedBox(
                  width: double.infinity,
                  height: 48.h,
                  child: TextButton.icon(
                    onPressed: _isProcessing
                        ? null
                        : () {
                            setState(() => _capturedImage = null);
                          },
                    icon: Icon(Icons.refresh, size: 20.r),
                    label: Text(
                      'Chụp lại',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
              SizedBox(height: 8.h),

              // ── Skip Link ──
              TextButton(
                onPressed: _isProcessing ? null : _skipEkyc,
                child: Text(
                  'Bỏ qua, đăng ký thủ công →',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textMuted,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              SizedBox(height: 16.h),
            ],
          ),
        ),
      ),
    );
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
              Icons.credit_card,
              size: 64.r,
              color: AppColors.textMuted.withValues(alpha: 0.4),
            ),
            SizedBox(height: 16.h),
            Text(
              'Mặt trước CCCD/CMND',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Đảm bảo ảnh rõ nét, đủ sáng',
              style: AppTypography.caption.copyWith(
                color: AppColors.textMuted.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16.r),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            _capturedImage!,
            fit: BoxFit.cover,
          ),
          // Overlay gradient
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
                'Ảnh đã sẵn sàng',
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
}
