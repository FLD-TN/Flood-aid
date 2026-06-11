import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_theme.dart';

/// Màn hình thông báo cho TNV rằng hồ sơ đang chờ Admin phê duyệt.
/// TNV bị giữ ở đây cho tới khi được duyệt.
class PendingApprovalScreen extends StatelessWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32.w),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── Animated Icon ──
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: child,
                  );
                },
                child: Container(
                  width: 120.w,
                  height: 120.w,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.15),
                        AppColors.primary.withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(30.r),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 2.w,
                    ),
                  ),
                  child: Center(
                    child: Text('⏳', style: TextStyle(fontSize: 56.sp)),
                  ),
                ),
              ),
              SizedBox(height: 40.h),

              // ── Title ──
              Text(
                'Đang chờ phê duyệt',
                style: AppTypography.displayMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16.h),

              // ── Description ──
              Text(
                'Hồ sơ đăng ký Tình nguyện viên của bạn đã được gửi thành công.\n\n'
                'Ban Quản Trị sẽ xem xét và phê duyệt trong thời gian sớm nhất. '
                'Sau khi được duyệt, bạn có thể đăng nhập lại bằng số điện thoại đã đăng ký để bắt đầu nhận nhiệm vụ cứu hộ.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.7,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 40.h),

              // ── Status Card ──
              Container(
                padding: EdgeInsets.all(20.w),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 16.r,
                      offset: Offset(0, 4.h),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildStatusRow(
                      icon: Icons.check_circle_outline,
                      color: AppColors.success,
                      text: 'Xác thực số điện thoại',
                      done: true,
                    ),
                    SizedBox(height: 12.h),
                    _buildStatusRow(
                      icon: Icons.check_circle_outline,
                      color: AppColors.success,
                      text: 'Gửi hồ sơ đăng ký',
                      done: true,
                    ),
                    SizedBox(height: 12.h),
                    _buildStatusRow(
                      icon: Icons.hourglass_top,
                      color: AppColors.statusResponding,
                      text: 'Admin phê duyệt',
                      done: false,
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 2),

              // ── Back Button ──
              SizedBox(
                width: double.infinity,
                height: 56.h,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.arrow_back, size: 20.r),
                  label: Text(
                    'Quay lại',
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
              SizedBox(height: 24.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusRow({
    required IconData icon,
    required Color color,
    required String text,
    required bool done,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22.r),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodyMedium.copyWith(
              color: done ? AppColors.textPrimary : AppColors.textMuted,
              fontWeight: done ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
        ),
        if (done)
          Icon(Icons.done, color: AppColors.success, size: 18.r),
      ],
    );
  }
}
