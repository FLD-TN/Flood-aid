# skill-ui-mobile.md — UI Design System: Flutter Mobile App

> File này định nghĩa design system cho toàn bộ Flutter app (Nạn nhân + TNV).
> AI Agent PHẢI đọc file này trước khi viết bất kỳ widget/screen nào.

---

## Định hướng thiết kế

**Tên concept:** *Tactical Calm* — Giao diện đủ sức chịu đựng trong khủng hoảng.

Người dùng đang hoảng loạn, tay ướt, màn hình mưa, pin sắp hết.
Mọi quyết định thiết kế phải phục vụ một mục tiêu duy nhất: **hành động đúng trong 3 giây**.

Không phải "emergency red UI" sặc sỡ thông thường.
Thay vào đó: tối, trầm, tương phản cao — như màn hình cockpit phi công trong điều kiện xấu.
Mọi thứ phải đọc được dưới ánh sáng chói hoặc bóng tối hoàn toàn.

---

## 1. Color System

```dart
// lib/theme/app_colors.dart

class AppColors {
  // ── Background (Dark base — không dùng màu trắng làm nền chính) ──
  static const background       = Color(0xFF0D1117);  // near-black, xanh rất đậm
  static const surfaceCard      = Color(0xFF161B22);  // card / bottom sheet
  static const surfaceElevated  = Color(0xFF21262D);  // input field, divider area
  static const surfaceBorder    = Color(0xFF30363D);  // stroke / separator

  // ── Brand / Primary (Amber — không dùng đỏ làm brand color) ──
  static const primary          = Color(0xFFE6A817);  // amber vàng đất — CTA, active
  static const primaryMuted     = Color(0xFF2D2208);  // amber dim — background chip

  // ── Status Colors ──
  static const statusPending    = Color(0xFFEF4444);  // đỏ — đang chờ, nguy hiểm
  static const statusResponding = Color(0xFFF59E0B);  // amber — có người đang đến
  static const statusNear       = Color(0xFFF97316);  // cam — < 300m
  static const statusOnScene    = Color(0xFF22C55E);  // xanh lá — đã đến nơi
  static const statusResolved   = Color(0xFF6B7280);  // xám — đã đóng ca

  // ── Urgency Colors (không dùng cho status — dùng cho urgency level) ──
  static const urgency1         = Color(0xFF3B82F6);  // xanh dương
  static const urgency2         = Color(0xFF22C55E);  // xanh lá
  static const urgency3         = Color(0xFFF59E0B);  // amber
  static const urgency4         = Color(0xFFF97316);  // cam
  static const urgency5         = Color(0xFFDC2626);  // đỏ đậm

  // ── Text ──
  static const textPrimary      = Color(0xFFF0F6FC);  // trắng xương — heading
  static const textSecondary    = Color(0xFF8B949E);  // xám nhạt — subtext
  static const textMuted        = Color(0xFF484F58);  // xám tối — placeholder
  static const textOnPrimary    = Color(0xFF0D1117);  // text trên nền amber

  // ── Semantic ──
  static const danger           = Color(0xFFFF6B6B);  // lỗi / cảnh báo nguy hiểm
  static const success          = Color(0xFF3FB950);  // thành công
  static const info             = Color(0xFF58A6FF);  // thông tin
}
```

---

## 2. Typography

```dart
// lib/theme/app_typography.dart
// Font: Rajdhani (display) + Noto Sans (body — hỗ trợ tiếng Việt đầy đủ)
// Import trong pubspec.yaml:
// fonts:
//   - family: Rajdhani
//     fonts: [{ asset: assets/fonts/Rajdhani-SemiBold.ttf, weight: 600 },
//             { asset: assets/fonts/Rajdhani-Bold.ttf, weight: 700 }]

class AppTypography {
  // Display — số lớn, tiêu đề màn hình
  static const displayLarge = TextStyle(
    fontFamily: 'Rajdhani',
    fontSize: 40,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
    height: 1.1,
  );

  static const displayMedium = TextStyle(
    fontFamily: 'Rajdhani',
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  // Heading — section title, card header
  static const headingLarge = TextStyle(
    fontFamily: 'Rajdhani',
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    color: AppColors.textPrimary,
  );

  // Label — button text, tag, badge
  static const labelLarge = TextStyle(
    fontFamily: 'Rajdhani',
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.5,     // tracking rộng cho button text
    color: AppColors.textPrimary,
  );

  // Body — mô tả, nội dung SOS text
  static const bodyLarge = TextStyle(
    fontFamily: 'Noto Sans',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.6,
  );

  static const bodyMedium = TextStyle(
    fontFamily: 'Noto Sans',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  // Caption — timestamp, metadata
  static const caption = TextStyle(
    fontFamily: 'Noto Sans',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
    letterSpacing: 0.3,
  );

  // Mono — tọa độ GPS, ID, số kỹ thuật
  static const mono = TextStyle(
    fontFamily: 'JetBrains Mono',
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    letterSpacing: 0.5,
  );
}
```

---

## 3. Spacing & Layout

```dart
// lib/theme/app_spacing.dart

class AppSpacing {
  // Base unit: 4px
  static const double xs   = 4;
  static const double sm   = 8;
  static const double md   = 16;
  static const double lg   = 24;
  static const double xl   = 32;
  static const double xxl  = 48;
  static const double xxxl = 64;

  // Touch targets — TỐI THIỂU 56px cho mọi interactive element
  static const double touchMin = 56;

  // Screen padding
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 24);
  static const EdgeInsets cardPadding   = EdgeInsets.all(16);
  static const EdgeInsets chipPadding   = EdgeInsets.symmetric(horizontal: 12, vertical: 6);
}

class AppRadius {
  static const double sm   = 8;
  static const double md   = 12;
  static const double lg   = 16;
  static const double xl   = 24;
  static const double full = 999; // pill shape
}
```

---

## 4. Components

### 4.1 SOS Button (Nút hành động chính)

```dart
// Nút TO, chiếm chiều ngang, không confirm dialog
// Touch target tối thiểu 72px height
class SosActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? color;

  const SosActionButton({
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ?? AppColors.statusPending;

    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        height: 72,
        decoration: BoxDecoration(
          color: onPressed == null ? AppColors.surfaceElevated : bg,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          // Glow effect khi active
          boxShadow: onPressed != null ? [
            BoxShadow(color: bg.withOpacity(0.4), blurRadius: 20, spreadRadius: 2),
          ] : [],
        ),
        child: Center(
          child: isLoading
            ? SizedBox(
                width: 28, height: 28,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
            : Text(label, style: AppTypography.labelLarge.copyWith(
                color: Colors.white,
                fontSize: 20,
              )),
        ),
      ),
    );
  }
}
```

### 4.2 Status Banner

```dart
// Dải trạng thái — hiển thị phía trên bản đồ tracking
class StatusBanner extends StatelessWidget {
  final String caseStatus;
  final int? distanceM;

  const StatusBanner({required this.caseStatus, this.distanceM});

  @override
  Widget build(BuildContext context) {
    final config = _getConfig(caseStatus, distanceM);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: config.color.withOpacity(0.15),
        border: Border(
          left: BorderSide(color: config.color, width: 4),
        ),
      ),
      child: Row(
        children: [
          Text(config.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(config.message,
              style: AppTypography.bodyLarge.copyWith(
                color: config.color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  _StatusConfig _getConfig(String status, int? dist) {
    switch (status) {
      case 'pending':
        return _StatusConfig(AppColors.statusPending, '🔴', 'Đang tìm người cứu hộ gần bạn...');
      case 'responding':
        final km = dist != null ? '~${(dist/1000).toStringAsFixed(1)}km' : '...';
        return _StatusConfig(AppColors.statusResponding, '🟡', 'Đã có người đang trên đường — cách bạn $km');
      case 'near':
        return _StatusConfig(AppColors.statusNear, '🟠', 'Người cứu hộ còn ~300m, hãy ra hiệu!');
      case 'on_scene':
        return _StatusConfig(AppColors.statusOnScene, '🟢', 'Người cứu hộ đã rất gần!');
      default:
        return _StatusConfig(AppColors.textMuted, '⚪', status);
    }
  }
}

class _StatusConfig {
  final Color color;
  final String emoji;
  final String message;
  _StatusConfig(this.color, this.emoji, this.message);
}
```

### 4.3 Voice Input Button

```dart
// Nhấn giữ để nói — animation pulse khi đang nghe
class VoiceInputButton extends StatefulWidget {
  final bool isListening;
  final VoidCallback onStart;
  final VoidCallback onStop;
  ...
}

class _VoiceInputButtonState extends State<VoiceInputButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnimation = Tween(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => widget.onStart(),
      onLongPressEnd: (_) => widget.onStop(),
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (_, child) {
          return Transform.scale(
            scale: widget.isListening ? _pulseAnimation.value : 1.0,
            child: child,
          );
        },
        child: Container(
          width: 68, height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isListening ? AppColors.statusPending : AppColors.surfaceElevated,
            border: Border.all(
              color: widget.isListening ? AppColors.statusPending : AppColors.surfaceBorder,
              width: 2,
            ),
            boxShadow: widget.isListening ? [
              BoxShadow(
                color: AppColors.statusPending.withOpacity(0.5),
                blurRadius: 24, spreadRadius: 4,
              ),
            ] : [],
          ),
          child: Icon(
            widget.isListening ? Icons.mic : Icons.mic_none_rounded,
            color: widget.isListening ? Colors.white : AppColors.textSecondary,
            size: 30,
          ),
        ),
      ),
    );
  }
}
```

### 4.4 Map Marker (Google Maps custom marker)

```dart
// Tạo custom marker bitmap — không dùng default pin đỏ generic
Future<BitmapDescriptor> createVictimMarker(int urgencyLevel) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final size = const Size(56, 56);

  final colors = {
    5: AppColors.urgency5,
    4: AppColors.urgency4,
    3: AppColors.urgency3,
    2: AppColors.urgency2,
    1: AppColors.urgency1,
  };
  final color = colors[urgencyLevel] ?? AppColors.urgency3;

  // Outer ring (pulse effect — static version cho bitmap)
  canvas.drawCircle(
    Offset(size.width/2, size.height/2),
    26,
    Paint()..color = color.withOpacity(0.2),
  );
  // Inner circle
  canvas.drawCircle(
    Offset(size.width/2, size.height/2),
    18,
    Paint()..color = color,
  );
  // Viền trắng
  canvas.drawCircle(
    Offset(size.width/2, size.height/2),
    18,
    Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 3,
  );
  // Level number
  final tp = TextPainter(
    text: TextSpan(text: '$urgencyLevel',
      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, Offset((size.width - tp.width)/2, (size.height - tp.height)/2));

  final img = await recorder.endRecording().toImage(size.width.toInt(), size.height.toInt());
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
}
```

---

## 5. Screen Layout Specs

### SOS Screen

```
┌────────────────────────────────────┐
│ StatusBar (dark)                   │
├────────────────────────────────────┤
│                                    │
│  [Logo nhỏ + "FloodAid"]  [Mức độ]│  ← Header 56px
│                                    │
├────────────────────────────────────┤
│                                    │
│  "Mô tả tình trạng của bạn"        │  ← Label
│                                    │
│  ┌──────────────────────────────┐  │
│  │                              │  │
│  │    TextField (multiline)     │  │  ← Input 120px min height
│  │    placeholder: "VD: Nhà     │  │    background: surfaceElevated
│  │    ngập tới nóc, có trẻ em"  │  │    border: surfaceBorder
│  │                              │  │
│  └──────────────────────────────┘  │
│                                    │
│  [🎤 Nhấn giữ để nói]             │  ← Voice button + hint
│                                    │
│  ─────────────── hoặc ───────────  │  ← Divider
│                                    │
│  [📍 Kéo ghim để chỉnh tọa độ]   │  ← Map pin option (secondary)
│                                    │
├────────────────────────────────────┤
│                                    │
│  ┌──────────────────────────────┐  │
│  │   🆘 GỬI TÍN HIỆU CỨU HỘ   │  │  ← SosActionButton 72px
│  └──────────────────────────────┘  │    color: statusPending
│                                    │    FULL WIDTH, glow shadow
└────────────────────────────────────┘
```

### Tracking Screen

```
┌────────────────────────────────────┐
│  StatusBanner (full width)         │  ← animated status, border-left 4px
├────────────────────────────────────┤
│                                    │
│  ┌──────────────────────────────┐  │
│  │                              │  │
│  │       Google Maps            │  │  ← Map chiếm 50% height
│  │   📍 victim (red)            │  │
│  │         🔵 tnv (moving)      │  │
│  │                              │  │
│  └──────────────────────────────┘  │
│                                    │
├────────────────────────────────────┤
│                                    │
│  [Case ID #abc1] [Mức 4] [y_te]   │  ← Metadata chips
│                                    │
│  "Nhà cấp 4 ngập tới nóc, có      │  ← SOS text (body)
│   trẻ em và người già"             │
│                                    │
│  ┌──────────────────────────────┐  │
│  │  ✅ Tôi đã được giúp đỡ     │  │  ← Resolve button
│  └──────────────────────────────┘  │    color: statusOnScene
│                                    │
└────────────────────────────────────┘
```

---

## 6. Theme Setup

```dart
// lib/theme/app_theme.dart

ThemeData buildAppTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      primary:    AppColors.primary,
      surface:    AppColors.surfaceCard,
      background: AppColors.background,
      error:      AppColors.danger,
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
      hintStyle: AppTypography.bodyLarge.copyWith(color: AppColors.textMuted),
      contentPadding: const EdgeInsets.all(AppSpacing.md),
    ),
    // App bar
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      elevation: 0,
      titleTextStyle: AppTypography.headingLarge,
      iconTheme: IconThemeData(color: AppColors.textPrimary),
    ),
  );
}
```

---

## 7. UX Rules (Không được vi phạm)

```
1. Touch target tối thiểu 56px — mọi button, icon, link
2. KHÔNG có confirm dialog trước hành động khẩn cấp
3. KHÔNG hiển thị lỗi kỹ thuật với người dùng (chỉ message thân thiện)
4. KHÔNG dùng màu trắng làm nền chính — mắt mỏi trong tình huống căng thẳng
5. Mọi màu status PHẢI có cả text label (không chỉ dựa vào màu — color blind)
6. Animation tối đa 400ms — người dùng không có thời gian chờ
7. Font size tối thiểu 14px — đọc được trong điều kiện ánh sáng xấu
8. Offline state PHẢI hiển thị rõ ràng, không im lặng thất bại
9. Nút SOS: luôn full-width, không bao giờ bị disabled hoàn toàn
10. Map: KHÔNG load skeleton trắng — dùng background color AppColors.surfaceCard
```
