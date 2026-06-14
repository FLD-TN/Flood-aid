import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';
import 'auth/phone_auth_screen.dart';

/// Màn hình chọn vai trò: Nạn nhân hoặc Tình nguyện viên
/// Design concept: Trust & Empathy - Bright, clean, premium UI
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _titleOpacity;
  late Animation<Offset> _titleSlide;

  late Animation<double> _victimOpacity;
  late Animation<Offset> _victimSlide;

  late Animation<double> _volunteerOpacity;
  late Animation<Offset> _volunteerSlide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.0, 0.5, curve: Curves.easeOut)),
    );
    _titleSlide =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic)),
    );

    _victimOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.2, 0.7, curve: Curves.easeOut)),
    );
    _victimSlide =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.2, 0.7, curve: Curves.easeOutCubic)),
    );

    _volunteerOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.4, 0.9, curve: Curves.easeOut)),
    );
    _volunteerSlide =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.4, 0.9, curve: Curves.easeOutCubic)),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Background Gradient ──
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.05),
                    AppColors.background,
                    AppColors.background,
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),

          // ── Hero Illustration ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.45,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Hero(
                  tag: 'splash_image',
                  child: Image.asset(
                    'assets/images/hero_illustration.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                ),
                // Gradient overlay to blend image smoothly into background
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.background.withValues(alpha: 0.0),
                          AppColors.background.withValues(alpha: 0.3),
                          AppColors.background,
                        ],
                        stops: const [0.4, 0.75, 1.0],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Content ──
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.32),

                        // ── Brand Title (Animated) ──
                        FadeTransition(
                          opacity: _titleOpacity,
                          child: SlideTransition(
                            position: _titleSlide,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(8.w),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(12.r),
                                      ),
                                      child: Icon(
                                        LucideIcons.droplets,
                                        color: AppColors.primary,
                                        size: 28.sp,
                                      ),
                                    ),
                                    SizedBox(width: 12.w),
                                    Text(
                                      'FloodAid',
                                      style: AppTypography.displayLarge
                                          .copyWith(
                                        color: AppColors.primary,
                                        letterSpacing: -1,
                                        fontSize: 36.sp,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12.h),
                                Text(
                                  'Nền tảng Điều phối Cứu trợ Lũ lụt',
                                  style: AppTypography.headingMedium.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 8.h),
                                Text(
                                  'Hỗ trợ khẩn cấp tại miền Trung Việt Nam. Chọn vai trò của bạn để bắt đầu.',
                                  style: AppTypography.bodyLarge.copyWith(
                                    color: AppColors.textSecondary,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(height: 32.h),

                        // ── Victim Card (Animated) ──
                        FadeTransition(
                          opacity: _victimOpacity,
                          child: SlideTransition(
                            position: _victimSlide,
                            child: _RoleCard(
                              icon: LucideIcons.lifeBuoy,
                              title: 'TÔI CẦN CỨU HỘ',
                              subtitle:
                                  'Gửi tín hiệu SOS khẩn cấp đến đội cứu hộ gần nhất',
                              accentColor: AppColors.statusPending,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const PhoneAuthScreen(role: 'victim')),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 16.h),

                        // ── Volunteer Card (Animated) ──
                        FadeTransition(
                          opacity: _volunteerOpacity,
                          child: SlideTransition(
                            position: _volunteerSlide,
                            child: _RoleCard(
                              icon: LucideIcons.shieldCheck,
                              title: 'TÔI LÀ TÌNH NGUYỆN VIÊN',
                              subtitle:
                                  'Tham gia cứu trợ, nhận ca SOS và hỗ trợ nạn nhân',
                              accentColor: AppColors.primary,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const PhoneAuthScreen(role: 'volunteer')),
                              ),
                            ),
                          ),
                        ),

                        const Spacer(),

                        // ── Footer ──
                        SafeArea(
                          top: false,
                          child: Padding(
                            padding: EdgeInsets.only(bottom: 24.h),
                            child: Center(
                              child: Text(
                                'Phiên bản 0.1.0 · KLTN 2026',
                                style: AppTypography.caption,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatefulWidget {
  final IconData icon;
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
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutQuart),
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
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: _pressed
                  ? widget.accentColor.withValues(alpha: 0.5)
                  : widget.accentColor.withValues(alpha: 0.1),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.accentColor
                    .withValues(alpha: _pressed ? 0.15 : 0.05),
                blurRadius: _pressed ? 24 : 12,
                spreadRadius: _pressed ? 2 : 0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20.r),
            child: Stack(
              children: [
                // Subtle gradient background
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          widget.accentColor.withValues(alpha: 0.08),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // Content
                Padding(
                  padding: EdgeInsets.all(20.w),
                  child: Row(
                    children: [
                      // Icon container
                      Container(
                        width: 56.w,
                        height: 56.w,
                        decoration: BoxDecoration(
                          color: widget.accentColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            widget.icon,
                            color: widget.accentColor,
                            size: 28.sp,
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
                                color: widget.accentColor,
                                fontSize: 16.sp,
                                letterSpacing: 0.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 6.h),
                            Text(
                              widget.subtitle,
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8.w),
                      // Arrow
                      Container(
                        width: 32.w,
                        height: 32.w,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.surfaceBorder,
                          ),
                        ),
                        child: Icon(
                          LucideIcons.chevronRight,
                          color: AppColors.textMuted,
                          size: 18.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
