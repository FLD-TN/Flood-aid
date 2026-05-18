import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ══════════════════════════════════════════════════════
// SosActionButton — Nút hành động chính
// Touch target tối thiểu 72px height
// Full-width, glow shadow, Rajdhani labelLarge
// ══════════════════════════════════════════════════════

class SosActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? color;
  final double height;

  const SosActionButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.color,
    this.height = 72,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ?? AppColors.statusPending;
    final isDisabled = onPressed == null;

    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: isDisabled ? AppColors.surfaceElevated : bg,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: !isDisabled
              ? [
                  BoxShadow(
                    color: bg.withOpacity(0.45),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Text(
                  label,
                  style: AppTypography.labelLarge.copyWith(
                    color: isDisabled
                        ? AppColors.textMuted
                        : Colors.white,
                    fontSize: 20,
                    letterSpacing: 1.8,
                  ),
                  textAlign: TextAlign.center,
                ),
        ),
      ),
    );
  }
}
