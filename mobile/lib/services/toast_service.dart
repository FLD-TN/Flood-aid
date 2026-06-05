import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum ToastType {
  success,
  warning,
  error,
  action, // Dành cho SOS mới
  info
}

class ToastService {
  static OverlayEntry? _currentEntry;
  static Timer? _currentTimer;

  static void show({
    required BuildContext context,
    required String message,
    ToastType type = ToastType.info,
    String? actionText,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    // 1. Remove existing toast if any
    _removeCurrentToast();

    // 2. Create new OverlayEntry
    final overlayState = Overlay.of(context);
    
    _currentEntry = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        type: type,
        actionText: actionText,
        onAction: () {
          _removeCurrentToast();
          if (onAction != null) onAction();
        },
        onDismiss: _removeCurrentToast,
      ),
    );

    // 3. Insert and schedule removal
    overlayState.insert(_currentEntry!);
    
    // Nếu không phải là action bắt buộc, tự động tắt sau [duration]
    if (type != ToastType.action) {
      _currentTimer = Timer(duration, () {
        _removeCurrentToast();
      });
    }
  }

  static void _removeCurrentToast() {
    _currentTimer?.cancel();
    _currentTimer = null;

    if (_currentEntry != null) {
      _currentEntry?.remove();
      _currentEntry = null;
    }
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final ToastType type;
  final String? actionText;
  final VoidCallback? onAction;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    required this.type,
    this.actionText,
    this.onAction,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.0),
      end: const Offset(0.0, 0.0),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    _controller.reverse().then((_) {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    Color bgColor = Colors.white;
    Color borderColor = Colors.transparent;
    Color iconColor = AppColors.textPrimary;
    IconData icon = Icons.info_outline;

    switch (widget.type) {
      case ToastType.success:
        bgColor = const Color(0xFFEFFFF4); // Xanh nhạt
        borderColor = const Color(0xFFC7F3D6); // Xanh lá viền
        iconColor = const Color(0xFF1CB052);
        icon = Icons.check_circle_outline;
        break;
      case ToastType.warning:
        bgColor = const Color(0xFFFFF9EC); // Vàng nhạt
        borderColor = const Color(0xFFFBE1A6);
        iconColor = const Color(0xFFF2A30F);
        icon = Icons.wifi_off; // Cảnh báo mất mạng
        break;
      case ToastType.error:
        bgColor = const Color(0xFFFFF0F0); // Đỏ nhạt
        borderColor = const Color(0xFFFFD1D1);
        iconColor = AppColors.alertRed;
        icon = Icons.error_outline;
        break;
      case ToastType.action:
        bgColor = Colors.white;
        borderColor = const Color(0xFFE0E0E0);
        iconColor = const Color(0xFF4A4A4A);
        icon = Icons.info_outline;
        break;
      case ToastType.info:
        bgColor = Colors.white;
        borderColor = const Color(0xFFE0E0E0);
        iconColor = AppColors.primary;
        icon = Icons.info_outline;
        break;
    }

    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: SafeArea(
        child: Material(
          color: Colors.transparent,
          child: SlideTransition(
            position: _offsetAnimation,
            child: FadeTransition(
              opacity: _opacityAnimation,
              child: GestureDetector(
                onVerticalDragUpdate: (details) {
                  if (details.delta.dy < -5) {
                    _dismiss(); // Vuốt lên để tắt
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Nền icon tròn (tuỳ chọn)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: iconColor, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.message,
                          style: AppTypography.labelMedium.copyWith(
                            color: AppColors.textPrimary,
                            height: 1.3,
                          ),
                        ),
                      ),
                      if (widget.type == ToastType.action && widget.actionText != null) ...[
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: widget.onAction,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B), // Màu xanh đen đậm
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              widget.actionText!,
                              style: AppTypography.labelMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (widget.type == ToastType.action) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _dismiss,
                          child: const Icon(Icons.close, size: 16, color: Colors.grey),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
