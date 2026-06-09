import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_theme.dart';

class SlideToConfirm extends StatefulWidget {
  final Future<void> Function() onConfirm;
  final String text;
  final bool isLoading;

  const SlideToConfirm({
    super.key,
    required this.onConfirm,
    this.text = 'Trượt để xác nhận',
    this.isLoading = false,
  });

  @override
  State<SlideToConfirm> createState() => _SlideToConfirmState();
}

class _SlideToConfirmState extends State<SlideToConfirm>
    with SingleTickerProviderStateMixin {
  double _dragPosition = 0.0;
  bool _isConfirmed = false;
  double get _thumbSize => 56.0.w;

  @override
  void didUpdateWidget(covariant SlideToConfirm oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset slider state khi widget được rebuild với text/loading khác
    // (ví dụ chuyển từ "NHẬN CA" → "ĐÓNG CA")
    if (oldWidget.text != widget.text || oldWidget.isLoading != widget.isLoading) {
      _dragPosition = 0.0;
      _isConfirmed = false;
    }
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details, double maxWidth) {
    if (_isConfirmed || widget.isLoading) return;
    
    setState(() {
      _dragPosition += details.delta.dx;
      if (_dragPosition < 0) {
        _dragPosition = 0;
      } else if (_dragPosition > maxWidth - _thumbSize) {
        _dragPosition = maxWidth - _thumbSize;
      }
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details, double maxWidth) async {
    if (_isConfirmed || widget.isLoading) return;

    // Nếu trượt qua 75%, tính là thành công
    if (_dragPosition > (maxWidth - _thumbSize) * 0.75) {
      setState(() {
        _dragPosition = maxWidth - _thumbSize;
        _isConfirmed = true;
      });
      HapticFeedback.mediumImpact();
      
      try {
        await widget.onConfirm();
      } catch (e) {
        // Reset nếu lỗi
        if (mounted) {
          setState(() {
            _isConfirmed = false;
            _dragPosition = 0.0;
          });
        }
      }
    } else {
      // Snap back
      setState(() {
        _dragPosition = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        
        return Container(
          height: _thumbSize,
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(_thumbSize / 2),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Stack(
            children: [
              // Background Progress
              AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width: _dragPosition + _thumbSize,
                height: _thumbSize,
                decoration: BoxDecoration(
                  color: widget.isLoading ? Colors.grey : AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(_thumbSize / 2),
                ),
              ),
              
              // Text Content
              Center(
                child: Opacity(
                  opacity: (1.0 - (_dragPosition / (maxWidth - _thumbSize))).clamp(0.0, 1.0),
                  child: Text(
                    widget.isLoading ? 'Đang xử lý...' : widget.text,
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.textPrimary.withOpacity(0.6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              // Success Text (Hiển thị khi kéo gần tới đích)
              Center(
                child: Opacity(
                  opacity: (_dragPosition / (maxWidth - _thumbSize)).clamp(0.0, 1.0),
                  child: Text(
                    'Xác nhận!',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // Draggable Thumb
              AnimatedPositioned(
                duration: _dragPosition == 0 ? const Duration(milliseconds: 250) : Duration.zero,
                curve: Curves.easeOutBack,
                left: _dragPosition,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) => _onHorizontalDragUpdate(details, maxWidth),
                  onHorizontalDragEnd: (details) => _onHorizontalDragEnd(details, maxWidth),
                  child: Container(
                    width: _thumbSize,
                    height: _thumbSize,
                    decoration: BoxDecoration(
                      color: widget.isLoading ? Colors.grey : AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (widget.isLoading ? Colors.grey : AppColors.primary).withValues(alpha: 0.3),
                          blurRadius: 10.r,
                          offset: Offset(0, 2.h),
                        ),
                      ],
                    ),
                    child: Center(
                      child: widget.isLoading 
                          ? SizedBox(
                              width: 20.w, height: 20.w,
                              child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Icon(
                              Icons.keyboard_double_arrow_right_rounded,
                              color: Colors.white,
                              size: 28.r,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
