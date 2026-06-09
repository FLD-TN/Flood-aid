import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_theme.dart';
import 'victim/phone_input_screen.dart';
import 'volunteer/volunteer_phone_screen.dart';

/// Màn hình chọn vai trò: Nạn nhân hoặc Tình nguyện viên
/// Design concept: Tactical Calm — dark cockpit, amber brand
class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            children: [
              SizedBox(height: 56.h),

              // ── Logo ──
              _buildLogo(),
              SizedBox(height: 20.h),

              // ── Brand Title ──
              Text(
                'FloodAid',
                style: AppTypography.displayLarge.copyWith(
                  color: AppColors.primary,
                  letterSpacing: -1,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                'Nền tảng Điều phối Cứu trợ Lũ lụt',
                style: AppTypography.bodyMedium,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 4.h),
              Text(
                'MIỀN TRUNG VIỆT NAM',
                style: AppTypography.caption.copyWith(
                  letterSpacing: 2.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary.withValues(alpha: 0.7),
                ),
              ),

              // ── Divider ──
              Padding(
                padding: EdgeInsets.symmetric(vertical: 32.h),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 1,
                        color: AppColors.surfaceBorder,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: Text(
                        'CHỌN VAI TRÒ',
                        style: AppTypography.caption.copyWith(
                          letterSpacing: 2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: AppColors.surfaceBorder,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Victim Card ──
              _RoleCard(
                icon: '📍',
                title: 'TÔI CẦN CỨU HỘ',
                subtitle: 'Gửi tín hiệu SOS đến đội cứu hộ gần nhất',
                accentColor: AppColors.statusPending,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PhoneInputScreen()),
                ),
              ),
              SizedBox(height: 14.h),

              // ── Volunteer Card ──
              _RoleCard(
                icon: '🦺',
                title: 'TÔI LÀ TÌNH NGUYỆN VIÊN',
                subtitle: 'Nhận ca cứu hộ và hỗ trợ nạn nhân',
                accentColor: AppColors.primary,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const VolunteerPhoneScreen()),
                ),
              ),

              const Spacer(),

              // ── Footer ──
              Text(
                'Phiên bản 0.1.0 · KLTN 2026',
                style: AppTypography.caption,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 76.w,
      height: 76.w,
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Text(
          '⚡',
          style: TextStyle(fontSize: 36.sp),
        ),
      ),
    );
  }
}

class _RoleCard extends StatefulWidget {
  final String icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _pressed = true);
        _ctrl.forward();
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () {
        setState(() => _pressed = false);
        _ctrl.reverse();
      },
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (_, child) => Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: _pressed
                  ? widget.accentColor.withValues(alpha: 0.6)
                  : AppColors.surfaceBorder,
              width: _pressed ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.accentColor.withValues(alpha: _pressed ? 0.25 : 0.1),
                blurRadius: _pressed ? 20 : 10,
                spreadRadius: _pressed ? 2 : 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 52.w,
                height: 52.w,
                decoration: BoxDecoration(
                  color: widget.accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: widget.accentColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Center(
                  child: Text(
                    widget.icon,
                    style: TextStyle(fontSize: 26.sp),
                  ),
                ),
              ),
              SizedBox(width: 16.w),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 15.sp,
                        letterSpacing: 1.0,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      widget.subtitle,
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              // Arrow
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: widget.accentColor.withValues(alpha: 0.7),
                size: 16.r,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
