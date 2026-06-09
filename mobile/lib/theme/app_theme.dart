import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// ══════════════════════════════════════════════════════
// FLOODAID DESIGN SYSTEM — Tactical Calm
// Nguồn: .agent/skills/skill-ui-mobile.md
// ══════════════════════════════════════════════════════

class AppColors {
  // ── Background (Light base) ──
  static const background = Color(0xFFF8F9FA); // Off-white
  static const surfaceCard = Color(0xFFFFFFFF); // Pure white
  static const surfaceElevated = Color(0xFFF3F4F5); // Slightly darker cho input
  static const surfaceBorder = Color(0xFFE1E3E4); // Border

  // ── Brand / Primary ──
  static const primary = Color(0xFF1E88E5); // Trust Blue
  static const primaryMuted = Color(0xFFD3E4FF); // Blue dim
  static const alertRed = Color(0xFFE53935); // Primary Alert Red (SOS)

  // ── Status Colors ──
  static const statusPending = Color(0xFFE53935); // Đỏ - Nguy hiểm, đang chờ
  static const statusResponding = Color(0xFFFB8C00); // Cam - Đang trên đường
  static const statusNear = Color(0xFFFB8C00); // Cam - Rất gần
  static const statusOnScene = Color(0xFF43A047); // Xanh lá - Đã đến nơi
  static const statusResolved = Color(0xFF6B7280); // Xám - Đã xử lý

  // ── Urgency Colors ──
  static const urgency1 = Color(0xFF22C55E); // green-500
  static const urgency2 = Color(0xFFEAB308); // yellow-500
  static const urgency3 = Color(0xFFF97316); // orange-500
  static const urgency4 = Color(0xFFEF4444); // red-500
  static const urgency5 = Color(0xFFB91C1C); // red-700

  // ── Text ──
  static const textPrimary = Color(0xFF191C1D); // Dark gray
  static const textSecondary = Color(0xFF5B403D); // Subtext
  static const textMuted = Color(0xFF906F6C); // Placeholder
  static const textOnPrimary = Color(0xFFFFFFFF); // White text trên nền đậm

  // ── Semantic ──
  static const danger = Color(0xFFBA1A1A); // Lỗi / cảnh báo
  static const success = Color(0xFF43A047); // Thành công
  static const info = Color(0xFF1E88E5); // Thông tin
}

// ══════════════════════════════════════════════════════
// TYPOGRAPHY — Inter (display & body) + Roboto Mono
// ══════════════════════════════════════════════════════

class AppTypography {
  // Display — số lớn, tiêu đề màn hình
  static TextStyle get displayLarge => GoogleFonts.inter(
        fontSize: 40.sp,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: AppColors.textPrimary,
        height: 1.1,
      );

  static TextStyle get displayMedium => GoogleFonts.inter(
        fontSize: 28.sp,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: AppColors.textPrimary,
        height: 1.2,
      );

  // Heading — section title, card header
  static TextStyle get headingLarge => GoogleFonts.inter(
        fontSize: 22.sp,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: AppColors.textPrimary,
      );

  static TextStyle get headingMedium => GoogleFonts.inter(
        fontSize: 18.sp,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: AppColors.textPrimary,
      );

  // Label — button text, tag, badge
  static TextStyle get labelLarge => GoogleFonts.inter(
        fontSize: 18.sp,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.5,
        color: AppColors.textPrimary,
      );

  static TextStyle get labelMedium => GoogleFonts.inter(
        fontSize: 14.sp,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.0,
        color: AppColors.textPrimary,
      );

  // Body — mô tả, nội dung SOS text
  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 16.sp,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.6,
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 14.sp,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.5,
      );

  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: 13.sp,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.4,
      );

  // Caption — timestamp, metadata
  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 12.sp,
        fontWeight: FontWeight.w400,
        color: AppColors.textMuted,
        letterSpacing: 0.3,
      );

  // Mono — tọa độ GPS, ID, số kỹ thuật
  static TextStyle get mono => GoogleFonts.robotoMono(
        fontSize: 13.sp,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        letterSpacing: 0.5,
      );
}

// ══════════════════════════════════════════════════════
// SPACING & LAYOUT
// ══════════════════════════════════════════════════════

class AppSpacing {
  // Base unit: 4px
  static double get xs => 4.w;
  static double get sm => 8.w;
  static double get md => 16.w;
  static double get lg => 24.w;
  static double get xl => 32.w;
  static double get xxl => 48.w;
  static double get xxxl => 64.w;

  // Touch targets — TỐI THIỂU 56px cho mọi interactive element
  static double get touchMin => 56.h;
  static double get touchLarge => 72.h; // SOS button

  // Screen padding
  static EdgeInsets get screenPadding => EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h);
  static EdgeInsets get cardPadding => EdgeInsets.all(16.w);
  static EdgeInsets get chipPadding => EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h);
}

class AppRadius {
  static double get sm => 8.r;
  static double get md => 12.r;
  static double get lg => 16.r;
  static double get xl => 24.r;
  static double get full => 999.r; // pill shape
}

// ══════════════════════════════════════════════════════
// THEME
// ══════════════════════════════════════════════════════

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      surface: AppColors.surfaceCard,
      error: AppColors.danger,
    ),
    // Input decoration global
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceElevated,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.surfaceBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.surfaceBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      hintStyle: GoogleFonts.inter(
        color: AppColors.textMuted,
        fontSize: 14.sp,
      ),
      contentPadding: EdgeInsets.all(AppSpacing.md),
    ),
    // App bar
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      elevation: 0,
      titleTextStyle: AppTypography.headingLarge,
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
    ),
    // Text theme base — Inter
    textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme)
        .copyWith(
      displayLarge: AppTypography.displayLarge,
      displayMedium: AppTypography.displayMedium,
      headlineLarge: AppTypography.headingLarge,
      headlineMedium: AppTypography.headingMedium,
      bodyLarge: AppTypography.bodyLarge,
      bodyMedium: AppTypography.bodyMedium,
      bodySmall: AppTypography.bodySmall,
      labelLarge: AppTypography.labelLarge,
      labelMedium: AppTypography.labelMedium,
    ),
  );
}

// ══════════════════════════════════════════════════════
// STATUS HELPERS
// ══════════════════════════════════════════════════════

class StatusConfig {
  final Color color;
  final String emoji;
  final String message;

  const StatusConfig({
    required this.color,
    required this.emoji,
    required this.message,
  });
}

StatusConfig getStatusConfig(String status, {int? distanceM}) {
  switch (status) {
    case 'pending':
      return const StatusConfig(
        color: AppColors.statusPending,
        emoji: '🔴',
        message: 'Đang tìm người cứu hộ gần bạn...',
      );
    case 'responding':
      final km = distanceM != null
          ? '~${(distanceM / 1000).toStringAsFixed(1)}km'
          : '...';
      return StatusConfig(
        color: AppColors.statusResponding,
        emoji: '🟡',
        message: 'Đã có người đang trên đường — cách bạn $km',
      );
    case 'near':
      return const StatusConfig(
        color: AppColors.statusNear,
        emoji: '🟠',
        message: 'Người cứu hộ còn ~300m, hãy ra hiệu!',
      );
    case 'on_scene':
      return const StatusConfig(
        color: AppColors.statusOnScene,
        emoji: '🟢',
        message: 'Người cứu hộ đã rất gần!',
      );
    case 'resolved':
      return const StatusConfig(
        color: AppColors.statusResolved,
        emoji: '✅',
        message: 'Ca đã được giải quyết.',
      );
    default:
      return StatusConfig(
        color: AppColors.textMuted,
        emoji: '⚪',
        message: status,
      );
  }
}

Color getUrgencyColor(int level) {
  switch (level) {
    case 1:
      return AppColors.urgency1;
    case 2:
      return AppColors.urgency2;
    case 3:
      return AppColors.urgency3;
    case 4:
      return AppColors.urgency4;
    case 5:
      return AppColors.urgency5;
    default:
      return AppColors.urgency3;
  }
}
