import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/toast_service.dart';
import '../../widgets/camera_overlay_painter.dart';
import 'volunteer_registration_screen.dart';

/// Màn hình Xác thực khuôn mặt — Custom Camera UI
/// Mở camera trước, khung bầu dục đứng nét đứt, chụp selfie → gọi FPT.AI FaceMatch
class FaceVerificationScreen extends StatefulWidget {
  final String phone;
  final Map<String, dynamic> ekycData;
  final String cccdImageBase64;

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
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  bool _isCameraReady = false;
  bool _isTakingPicture = false;
  bool _isVerifying = false;
  File? _selfieImage;

  // Kết quả
  bool? _isMatch;
  double? _similarity;
  String? _errorMessage;

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

  /// Khởi tạo camera trước (Front camera)
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

      // Ưu tiên camera trước cho selfie
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
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

  /// Chụp selfie
  Future<void> _takeSelfie() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isTakingPicture) return;

    setState(() => _isTakingPicture = true);

    try {
      final xFile = await _cameraController!.takePicture();
      final file = File(xFile.path);

      if (mounted) {
        setState(() {
          _selfieImage = file;
          _isTakingPicture = false;
        });
      }

      // Tự động gọi FaceMatch ngay sau khi chụp
      await _verifyFace();
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

  /// Gọi FPT.AI FaceMatch
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

      // Lỗi từ FPT.AI
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
        // Khớp → Chờ 1.5s rồi chuyển sang Registration
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

  /// Chụp lại
  void _retake() {
    setState(() {
      _selfieImage = null;
      _isMatch = null;
      _similarity = null;
      _errorMessage = null;
    });
  }

  /// Bỏ qua face verification
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
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _selfieImage != null ? _buildResultMode() : _buildCameraMode(),
      ),
    );
  }

  // ═══════════════════════════════════════
  // CHẾ ĐỘ CAMERA — Camera trước + Oval
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

        // ── Overlay mặt nạ + khung bầu dục nét đứt ──
        CustomPaint(
          size: Size.infinite,
          painter: CameraOverlayPainter(
            shape: CutoutShape.oval,
            cutoutWidthRatio: 0.62,
            cutoutAspectRatio: 0.72, // Bầu dục đứng (cao hơn rộng)
            overlayColor: const Color(0xAA000000),
            borderColor: Colors.white,
            borderWidth: 2.5,
            dashLength: 12,
            dashGap: 8,
          ),
        ),

        // ── Top bar ──
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
                  'Xác thực khuôn mặt',
                  style: AppTypography.headingMedium.copyWith(
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                SizedBox(width: 48.w),
              ],
            ),
          ),
        ),

        // ── Hướng dẫn phía trên khung ──
        Positioned(
          top: MediaQuery.of(context).size.height * 0.14,
          left: 24.w,
          right: 24.w,
          child: Text(
            '🤳  Đưa khuôn mặt vào trong khung hình',
            style: AppTypography.labelMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        // ── Tips phía dưới ──
        Positioned(
          bottom: 160.h,
          left: 24.w,
          right: 24.w,
          child: Column(
            children: [
              _buildTip('Giữ khuôn mặt ngang tầm camera'),
              SizedBox(height: 6.h),
              _buildTip('Đảm bảo đủ ánh sáng, không lóa'),
              SizedBox(height: 6.h),
              _buildTip('Không đeo khẩu trang hoặc kính râm'),
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
                // Nút chụp selfie
                GestureDetector(
                  onTap: _isCameraReady ? _takeSelfie : null,
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
                TextButton(
                  onPressed: _skipFaceVerification,
                  child: Text(
                    'Bỏ qua xác thực khuôn mặt →',
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
  // CHẾ ĐỘ RESULT — Hiển thị kết quả
  // ═══════════════════════════════════════

  Widget _buildResultMode() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Ảnh selfie
        Image.file(
          _selfieImage!,
          fit: BoxFit.cover,
        ),

        // Overlay kết quả
        if (_isVerifying || _isMatch != null || _errorMessage != null)
          Positioned.fill(
            child: Container(
              color: _isVerifying
                  ? Colors.black.withValues(alpha: 0.5)
                  : _isMatch == true
                      ? AppColors.success.withValues(alpha: 0.25)
                      : AppColors.alertRed.withValues(alpha: 0.25),
              child: Center(
                child: _isVerifying
                    ? _buildVerifyingIndicator()
                    : _isMatch == true
                        ? _buildMatchResult()
                        : _buildMismatchResult(),
              ),
            ),
          ),

        // Top bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 100.h,
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
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.white, size: 24.r),
                  onPressed: () => Navigator.pop(context),
                ),
                const Spacer(),
                Text(
                  _getTitle(),
                  style: AppTypography.headingMedium.copyWith(
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                SizedBox(width: 48.w),
              ],
            ),
          ),
        ),

        // Bottom actions (nếu không khớp hoặc lỗi)
        if (!_isVerifying && _isMatch != true)
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
                  SizedBox(
                    width: double.infinity,
                    height: 56.h,
                    child: ElevatedButton(
                      onPressed: _retake,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        elevation: 4,
                      ),
                      child: Text(
                        'CHỤP LẠI',
                        style: AppTypography.labelLarge.copyWith(
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  TextButton(
                    onPressed: _skipFaceVerification,
                    child: Text(
                      'Bỏ qua xác thực khuôn mặt →',
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

  String _getTitle() {
    if (_isVerifying) return 'Đang xác thực...';
    if (_isMatch == true) return 'Xác thực thành công!';
    if (_isMatch == false) return 'Không khớp';
    if (_errorMessage != null) return 'Lỗi xác thực';
    return 'Xác thực khuôn mặt';
  }

  Widget _buildVerifyingIndicator() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 56.w,
          height: 56.w,
          child: const CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 3,
          ),
        ),
        SizedBox(height: 20.h),
        Text(
          'Đang so sánh khuôn mặt...',
          style: AppTypography.labelMedium.copyWith(color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildMatchResult() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.9),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check, color: Colors.white, size: 56.r),
        ),
        SizedBox(height: 20.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
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
        SizedBox(height: 8.h),
        Text(
          'Đang chuyển sang đăng ký...',
          style: AppTypography.caption.copyWith(
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildMismatchResult() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: AppColors.alertRed.withValues(alpha: 0.9),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.close, color: Colors.white, size: 56.r),
        ),
        SizedBox(height: 20.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(24.r),
          ),
          child: Text(
            _errorMessage ?? 'Không khớp (${_similarity?.toStringAsFixed(1)}%)',
            style: AppTypography.labelMedium.copyWith(
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
