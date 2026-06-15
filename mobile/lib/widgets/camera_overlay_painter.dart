import 'dart:math';
import 'package:flutter/material.dart';

/// Custom Painter vẽ mặt nạ tối (overlay) với lỗ rỗng ở giữa (nét đứt).
/// Hỗ trợ 2 kiểu lỗ: [CutoutShape.rectangle] cho CCCD, [CutoutShape.oval] cho khuôn mặt.
enum CutoutShape { rectangle, oval }

class CameraOverlayPainter extends CustomPainter {
  final CutoutShape shape;
  final double cutoutWidthRatio;  // Tỷ lệ chiều rộng lỗ so với chiều rộng màn hình
  final double cutoutAspectRatio; // Tỷ lệ w:h của lỗ (VD: 8.5/5.4 cho CCCD)
  final Color overlayColor;
  final Color borderColor;
  final double borderWidth;
  final double dashLength;
  final double dashGap;
  final double borderRadius;

  CameraOverlayPainter({
    required this.shape,
    this.cutoutWidthRatio = 0.85,
    this.cutoutAspectRatio = 1.6, // mặc định CCCD ngang
    this.overlayColor = const Color(0x99000000),
    this.borderColor = Colors.white,
    this.borderWidth = 2.5,
    this.dashLength = 12,
    this.dashGap = 8,
    this.borderRadius = 16,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cutoutWidth = size.width * cutoutWidthRatio;
    final cutoutHeight = cutoutWidth / cutoutAspectRatio;

    final cutoutRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2 - 30), // Dịch lên 1 chút
      width: cutoutWidth,
      height: cutoutHeight,
    );

    // 1. Vẽ overlay tối xung quanh
    final overlayPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    if (shape == CutoutShape.rectangle) {
      overlayPath.addRRect(
        RRect.fromRectAndRadius(cutoutRect, Radius.circular(borderRadius)),
      );
    } else {
      overlayPath.addOval(cutoutRect);
    }

    overlayPath.fillType = PathFillType.evenOdd;
    canvas.drawPath(overlayPath, overlayPaint);

    // 2. Vẽ viền nét đứt
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round;

    if (shape == CutoutShape.rectangle) {
      _drawDashedRRect(canvas, cutoutRect, borderPaint);
    } else {
      _drawDashedOval(canvas, cutoutRect, borderPaint);
    }
  }

  /// Vẽ hình chữ nhật bo góc nét đứt
  void _drawDashedRRect(Canvas canvas, Rect rect, Paint paint) {
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));
    final path = Path()..addRRect(rrect);
    _drawDashedPath(canvas, path, paint);
  }

  /// Vẽ hình bầu dục nét đứt
  void _drawDashedOval(Canvas canvas, Rect rect, Paint paint) {
    final path = Path()..addOval(rect);
    _drawDashedPath(canvas, path, paint);
  }

  /// Vẽ nét đứt trên bất kỳ Path nào
  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final segmentLength = min(dashLength, metric.length - distance);
        final segment = metric.extractPath(distance, distance + segmentLength);
        canvas.drawPath(segment, paint);
        distance += dashLength + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CameraOverlayPainter oldDelegate) {
    return shape != oldDelegate.shape ||
        cutoutWidthRatio != oldDelegate.cutoutWidthRatio ||
        cutoutAspectRatio != oldDelegate.cutoutAspectRatio ||
        borderColor != oldDelegate.borderColor;
  }
}
