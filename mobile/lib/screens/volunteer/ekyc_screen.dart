import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/toast_service.dart';
import '../../widgets/camera_overlay_painter.dart';
import 'face_verification_screen.dart';
import 'volunteer_registration_screen.dart';

/// Màn hình eKYC — Custom Camera UI với khung chữ nhật nét đứt
/// Hướng dẫn TNV chụp CCCD mặt trước → gọi FPT.AI → chuyển sang FaceMatch
class EkycScreen extends StatefulWidget {
  final String phone;

  const EkycScreen({super.key, required this.phone});

  @override
  State<EkycScreen> createState() => _EkycScreenState();
}

class _EkycScreenState extends State<EkycScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  bool _isCameraReady = false;
  bool _isProcessing = false;
  bool _isTakingPicture = false;
  File? _capturedImage;
  String? _base64Image; // Lưu lại để truyền sang FaceMatch

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  /// Xử lý app lifecycle — tắt/bật camera khi ẩn/mở app
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _cameraController?.dispose();
      setState(() => _isCameraReady = false);
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  /// Khởi tạo camera sau
  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          ToastService.show(
            context: context,
            type: ToastType.error,
            message: 'Không tìm thấy camera trên thiết bị.',
          );
        }
        return;
      }

      // Ưu tiên camera sau
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() => _isCameraReady = true);
      }
    } catch (e) {
      if (mounted) {
        ToastService.show(
          context: context,
          type: ToastType.error,
          message: 'Không thể khởi tạo camera: $e',
        );
      }
    }
  }

  /// Chụp ảnh
  Future<void> _takePicture() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isTakingPicture) return;

    setState(() => _isTakingPicture = true);

    try {
      final xFile = await _cameraController!.takePicture();
      final file = File(xFile.path);

      // Chuyển sang base64 ngay
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);

      if (mounted) {
        setState(() {
          _capturedImage = file;
          _base64Image = base64Image;
          _isTakingPicture = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isTakingPicture = false);
        ToastService.show(
          context: context,
          type: ToastType.error,
          message: 'Lỗi chụp ảnh: $e',
        );
      }
    }
  }

  /// Gọi FPT.AI nhận diện CCCD
  Future<void> _processImage() async {
    if (_base64Image == null) return;

    setState(() => _isProcessing = true);

    try {
      final result = await ApiService.recognizeId(base64Image: _base64Image!);

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
            cccdImageBase64: _base64Image!,
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

  /// Chụp lại — reset trạng thái
  void _retake() {
    setState(() {
      _capturedImage = null;
      _base64Image = null;
    });
  }

  /// Bỏ qua eKYC — đăng ký thủ công
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
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _capturedImage != null ? _buildPreviewMode() : _buildCameraMode(),
      ),
    );
  }

  // ═══════════════════════════════════════
  // CHẾ ĐỘ CAMERA — Live Preview + Overlay
  // ═══════════════════════════════════════

  Widget _buildCameraMode() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Camera Preview ──
        if (_isCameraReady && _cameraController != null)
          Center(
            child: CameraPreview(_cameraController!),
          )
        else
          const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),

        // ── Overlay mặt nạ + khung nét đứt ──
        CustomPaint(
          size: Size.infinite,
          painter: CameraOverlayPainter(
            shape: CutoutShape.rectangle,
            cutoutWidthRatio: 0.88,
            cutoutAspectRatio: 8.56 / 5.398, // Tỷ lệ chuẩn thẻ CCCD
            overlayColor: const Color(0xAA000000),
            borderColor: Colors.white,
            borderWidth: 2.5,
            dashLength: 14,
            dashGap: 8,
            borderRadius: 14,
          ),
        ),

        // ── Top Bar ──
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.white, size: 24.r),
                  onPressed: () => Navigator.pop(context),
                ),
                const Spacer(),
                Text(
                  'Xác thực CCCD',
                  style: AppTypography.headingMedium.copyWith(
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                SizedBox(width: 48.w), // Balance
              ],
            ),
          ),
        ),

        // ── Hướng dẫn phía trên khung ──
        Positioned(
          top: MediaQuery.of(context).size.height * 0.18,
          left: 0,
          right: 0,
          child: Column(
            children: [
              Text(
                '🪪  Đưa CCCD vào trong khung hình',
                style: AppTypography.labelMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        // ── Tips phía dưới khung ──
        Positioned(
          bottom: 160.h,
          left: 24.w,
          right: 24.w,
          child: Column(
            children: [
              _buildTip('Tránh chụp bị lóa sáng hoặc bóng đổ'),
              SizedBox(height: 6.h),
              _buildTip('Đảm bảo thẻ nằm gọn trong khung'),
              SizedBox(height: 6.h),
              _buildTip('Không để ngón tay che viền thẻ'),
            ],
          ),
        ),

        // ── Bottom bar — Nút chụp + Bỏ qua ──
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.only(bottom: 24.h, top: 16.h),
            child: Column(
              children: [
                // Nút chụp
                GestureDetector(
                  onTap: _isCameraReady ? _takePicture : null,
                  child: Container(
                    width: 72.w,
                    height: 72.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.5),
                        width: 4.w,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 58.w,
                        height: 58.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isTakingPicture
                              ? Colors.grey.shade300
                              : Colors.white,
                          border: Border.all(
                            color: Colors.black.withValues(alpha: 0.1),
                            width: 2.w,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                // Bỏ qua
                TextButton(
                  onPressed: _skipEkyc,
                  child: Text(
                    'Bỏ qua, đăng ký thủ công →',
                    style: AppTypography.caption.copyWith(
                      color: Colors.white.withValues(alpha: 0.6),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTip(String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 4.w,
          height: 4.w,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 8.w),
        Text(
          text,
          style: AppTypography.caption.copyWith(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11.sp,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════
  // CHẾ ĐỘ PREVIEW — Xem lại ảnh đã chụp
  // ═══════════════════════════════════════

  Widget _buildPreviewMode() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Ảnh đã chụp
        Image.file(
          _capturedImage!,
          fit: BoxFit.cover,
        ),

        // Gradient overlay trên và dưới
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 120.h,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.7),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Top bar
        Positioned(
          top: 8.h,
          left: 8.w,
          child: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white, size: 24.r),
            onPressed: () => Navigator.pop(context),
          ),
        ),

        Positioned(
          top: 16.h,
          left: 0,
          right: 0,
          child: Text(
            'Kiểm tra ảnh CCCD',
            style: AppTypography.headingMedium.copyWith(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),

        // Bottom actions
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 32.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.85),
                  Colors.transparent,
                ],
              ),
            ),
            child: Column(
              children: [
                // Nút xác thực
                SizedBox(
                  width: double.infinity,
                  height: 56.h,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _processImage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      elevation: 4,
                      shadowColor: AppColors.primary.withValues(alpha: 0.4),
                    ),
                    child: _isProcessing
                        ? SizedBox(
                            width: 22.w,
                            height: 22.w,
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            'XÁC THỰC CCCD',
                            style: AppTypography.labelLarge.copyWith(
                              color: Colors.white,
                              letterSpacing: 1.5,
                            ),
                          ),
                  ),
                ),
                SizedBox(height: 12.h),
                // Nút chụp lại
                SizedBox(
                  width: double.infinity,
                  height: 48.h,
                  child: TextButton.icon(
                    onPressed: _isProcessing ? null : _retake,
                    icon: Icon(Icons.refresh, size: 20.r, color: Colors.white),
                    label: Text(
                      'Chụp lại',
                      style: AppTypography.labelMedium.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
