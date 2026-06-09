import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_theme.dart';

// ══════════════════════════════════════════════════════
// StatusBanner — Dải trạng thái animated
// Hiển thị phía trên bản đồ tracking
// border-left 4px, animated container 400ms
// ══════════════════════════════════════════════════════

class StatusBanner extends StatelessWidget {
  final String caseStatus;
  final int? distanceM;

  const StatusBanner({
    super.key,
    required this.caseStatus,
    this.distanceM,
  });

  @override
  Widget build(BuildContext context) {
    final config = getStatusConfig(caseStatus, distanceM: distanceM);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.12),
        border: Border(
          left: BorderSide(color: config.color, width: 4.w),
        ),
      ),
      child: Row(
        children: [
          Text(config.emoji, style: TextStyle(fontSize: 22.sp)),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              config.message,
              style: AppTypography.bodyLarge.copyWith(
                color: config.color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Pulse dot indicator
          _PulseDot(color: config.color),
        ],
      ),
    );
  }
}

// Animated pulse dot — visual feedback trạng thái đang cập nhật
class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) => Container(
        width: 8.w,
        height: 8.w,
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: _anim.value),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.4 * _anim.value),
              blurRadius: 6.r,
              spreadRadius: 2.r,
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
// UrgencyBadge — Badge hiển thị mức độ khẩn cấp
// ══════════════════════════════════════════════════════

class UrgencyBadge extends StatelessWidget {
  final int level;
  final bool large;

  const UrgencyBadge({
    super.key,
    required this.level,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = getUrgencyColor(level);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: (large ? 12 : 8).w,
        vertical: (large ? 6 : 3).h,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        'MỨC $level',
        style: AppTypography.labelMedium.copyWith(
          color: color,
          fontSize: (large ? 13 : 11).sp,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
// StatusChip — Chip hiển thị tag SOS (y_te, tre_em, v.v.)
// ══════════════════════════════════════════════════════

class StatusChip extends StatelessWidget {
  final String label;
  final Color? color;

  const StatusChip({
    super.key,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: c,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
// OnlineStatusBadge — Góc trên phải hiển thị online/offline
// ══════════════════════════════════════════════════════

class OnlineStatusBadge extends StatelessWidget {
  final bool isOnline;

  const OnlineStatusBadge({super.key, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    final color = isOnline ? AppColors.success : AppColors.textMuted;
    final text = isOnline ? 'ONLINE' : 'OFFLINE';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6.w,
            height: 6.w,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 5.w),
          Text(
            text,
            style: AppTypography.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 10.sp,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
