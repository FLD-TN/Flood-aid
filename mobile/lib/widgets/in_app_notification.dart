import 'dart:ui';
import 'package:flutter/material.dart';

/// In-App Notification Banner — giống hệt Push Notification của hệ thống.
/// Trượt xuống từ trên cùng, có hiệu ứng kính mờ (frosted glass),
/// icon app, tiêu đề, nội dung, và tự biến mất sau vài giây.
///
/// Sử dụng:
/// ```dart
/// InAppNotification.show(
///   context,
///   title: 'Cứu Hộ Miền Trung',
///   body: 'Ca SOS đã được gửi thành công! Đang tìm tình nguyện viên...',
///   icon: Icons.send,
///   onTap: () => print('Bấm vào thông báo'),
/// );
/// ```
class InAppNotification {
  static OverlayEntry? _currentEntry;

  static void show(
    BuildContext context, {
    required String title,
    required String body,
    IconData icon = Icons.send,
    Color iconBackgroundColor = const Color(0xFF2AABEE),
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onTap,
  }) {
    // Dismiss any existing notification
    _currentEntry?.remove();
    _currentEntry = null;

    final overlay = Overlay.of(context);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _NotificationBanner(
        title: title,
        body: body,
        icon: icon,
        iconBackgroundColor: iconBackgroundColor,
        duration: duration,
        onTap: onTap,
        onDismiss: () {
          entry.remove();
          if (_currentEntry == entry) {
            _currentEntry = null;
          }
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }
}

class _NotificationBanner extends StatefulWidget {
  final String title;
  final String body;
  final IconData icon;
  final Color iconBackgroundColor;
  final Duration duration;
  final VoidCallback? onTap;
  final VoidCallback onDismiss;

  const _NotificationBanner({
    required this.title,
    required this.body,
    required this.icon,
    required this.iconBackgroundColor,
    required this.duration,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<_NotificationBanner> createState() => _NotificationBannerState();
}

class _NotificationBannerState extends State<_NotificationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    // Slide in
    _animController.forward();

    // Auto dismiss
    Future.delayed(widget.duration, () {
      if (mounted) _dismiss();
    });
  }

  void _dismiss() {
    _animController.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnim,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: GestureDetector(
            onTap: () {
              widget.onTap?.call();
              _dismiss();
            },
            onVerticalDragUpdate: (details) {
              if (details.primaryDelta != null && details.primaryDelta! < -5) {
                _dismiss(); // Vuốt lên để tắt (giống notification thật)
              }
            },
            child: Container(
              margin: EdgeInsets.only(
                top: topPadding + 8,
                left: 12,
                right: 12,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      // Nền kính mờ giống notification iOS
                      color: Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.grey.withOpacity(0.2),
                        width: 0.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── App Icon (giống MBBank trong ảnh) ──
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: widget.iconBackgroundColor,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: widget.iconBackgroundColor.withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            widget.icon,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),

                        // ── Text Content ──
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      widget.title,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1A1A1A),
                                        height: 1.2,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    'bây giờ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.body,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
