import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/toast_service.dart';
import 'pending_approval_screen.dart';

/// Màn hình Đăng ký Tình nguyện viên
/// Nhận dữ liệu eKYC (nếu có) để auto-fill → TNV xác nhận và gửi đăng ký
class VolunteerRegistrationScreen extends StatefulWidget {
  final String phone;
  final Map<String, dynamic>? ekycData;

  const VolunteerRegistrationScreen({
    super.key,
    required this.phone,
    this.ekycData,
  });

  @override
  State<VolunteerRegistrationScreen> createState() =>
      _VolunteerRegistrationScreenState();
}

class _VolunteerRegistrationScreenState
    extends State<VolunteerRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _cccdController = TextEditingController();
  bool _isSubmitting = false;


  @override
  void initState() {
    super.initState();
    _prefillFromEkyc();
  }

  /// Auto-fill dữ liệu từ eKYC (FPT.AI)
  void _prefillFromEkyc() {
    if (widget.ekycData == null) return;

    final data = widget.ekycData!;
    if (data['fullName'] != null && data['fullName'].toString().isNotEmpty) {
      _nameController.text = data['fullName'];
    }
    if (data['cccdNumber'] != null &&
        data['cccdNumber'].toString().isNotEmpty) {
      _cccdController.text = data['cccdNumber'];
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final result = await ApiService.registerVolunteer(
        phone: widget.phone,
        fullName: _nameController.text.trim(),
        cccdNumber: _cccdController.text.trim().isNotEmpty
            ? _cccdController.text.trim()
            : null,
      );

      if (!mounted) return;

      if (result != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PendingApprovalScreen()),
        );
      } else {
        setState(() => _isSubmitting = false);
        ToastService.show(
          context: context,
          type: ToastType.error,
          message: 'Đăng ký thất bại. Vui lòng thử lại.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ToastService.show(
        context: context,
        type: ToastType.error,
        message: 'Đã xảy ra lỗi: $e',
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cccdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasEkyc = widget.ekycData != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Đăng ký Tình nguyện viên',
          style: AppTypography.headingMedium,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 16.h),

                // ── eKYC Badge (nếu đã qua eKYC) ──
                if (hasEkyc)
                  Container(
                    width: double.infinity,
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.verified,
                            color: AppColors.success, size: 20.r),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Text(
                            'Thông tin đã được bóc tách từ CCCD. Vui lòng kiểm tra lại.',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (hasEkyc) SizedBox(height: 8.h),

                // ── Face Verified Badge ──
                if (hasEkyc && widget.ekycData?['faceVerified'] == true)
                  Container(
                    width: double.infinity,
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.face,
                            color: AppColors.success, size: 20.r),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Text(
                            'Khuôn mặt đã xác thực ✅ (${(widget.ekycData?['faceSimilarity'] as num?)?.toStringAsFixed(1) ?? ''}%)',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (hasEkyc && widget.ekycData?['faceVerified'] == false)
                  Container(
                    width: double.infinity,
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    decoration: BoxDecoration(
                      color: AppColors.statusResponding.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: AppColors.statusResponding.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.face,
                            color: AppColors.statusResponding, size: 20.r),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Text(
                            'Khuôn mặt chưa xác thực ⚠️',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.statusResponding,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (hasEkyc) SizedBox(height: 24.h),

                // ── Họ và tên ──
                Text(
                  'Họ và tên *',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.textPrimary,
                    letterSpacing: 0,
                  ),
                ),
                SizedBox(height: 8.h),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'VD: Nguyễn Văn A',
                    prefixIcon: Icon(Icons.person_outline, size: 22.r),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập họ và tên';
                    }
                    if (value.trim().length < 2) {
                      return 'Họ tên quá ngắn';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20.h),

                // ── Số CCCD ──
                Text(
                  'Số CCCD / CMND',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.textPrimary,
                    letterSpacing: 0,
                  ),
                ),
                SizedBox(height: 8.h),
                TextFormField(
                  controller: _cccdController,
                  keyboardType: TextInputType.number,
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textPrimary,
                    letterSpacing: 1,
                  ),
                  decoration: InputDecoration(
                    hintText: 'VD: 012345678901',
                    prefixIcon: Icon(Icons.badge_outlined, size: 22.r),
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Số CCCD giúp Admin xác minh danh tính nhanh hơn (không bắt buộc).',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                SizedBox(height: 24.h),

                // ── Số điện thoại (read-only) ──
                Text(
                  'Số điện thoại',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.textPrimary,
                    letterSpacing: 0,
                  ),
                ),
                SizedBox(height: 8.h),
                Container(
                  width: double.infinity,
                  padding:
                      EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.phone, size: 20.r, color: AppColors.textMuted),
                      SizedBox(width: 12.w),
                      Text(
                        widget.phone,
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppColors.textSecondary,
                          letterSpacing: 1,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.lock_outline,
                          size: 16.r, color: AppColors.textMuted),
                    ],
                  ),
                ),
                SizedBox(height: 40.h),

                // ── Submit Button ──
                SizedBox(
                  width: double.infinity,
                  height: 56.h,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _handleSubmit,
                    icon: _isSubmitting
                        ? SizedBox(
                            width: 22.w,
                            height: 22.w,
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Icon(Icons.send, size: 20.r),
                    label: Text(
                      _isSubmitting
                          ? 'ĐANG GỬI...'
                          : 'GỬI ĐĂNG KÝ TÌNH NGUYỆN VIÊN',
                      style: AppTypography.labelLarge.copyWith(
                        color: Colors.white,
                        fontSize: 14.sp,
                        letterSpacing: 1,
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
                SizedBox(height: 32.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
