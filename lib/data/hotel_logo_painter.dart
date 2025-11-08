import 'package:flutter/material.dart';
import 'dart:math' as math;

class HotelLogoPainter extends CustomPainter {
  final double progress;

  HotelLogoPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Path fullPath = Path();

    double w = size.width;
    double h = size.height;

    // ======================================================
    // ✅ 外框（正方形）
    // ======================================================
// ✅ 外框：右下 ➜ 右上 ➜ 左上 ➜ 左下 ➜ 回到右下
fullPath.moveTo(w * 0.90, h * 0.90); // 起点：右下角
fullPath.lineTo(w * 0.90, h * 0.10); // 上到右上
fullPath.lineTo(w * 0.10, h * 0.10); // 左到左上
fullPath.lineTo(w * 0.10, h * 0.90); // 下到左下
fullPath.lineTo(w * 0.30, h * 0.90); // 


    // ======================================================
    // ======================================================
    fullPath.moveTo(w * 0.30, h * 0.90);
    fullPath.lineTo(w * 0.30, h * 0.50);

    fullPath.moveTo(w * 0.30, h * 0.50);
    fullPath.lineTo(w * 0.50, h * 0.30);

    fullPath.moveTo(w * 0.50, h * 0.30);
    fullPath.lineTo(w * 0.70, h * 0.50);

    fullPath.moveTo(w * 0.70, h * 0.50);
    fullPath.lineTo(w * 0.70, h * 0.85);

    // ======================================================
    // ======================================================
    fullPath.moveTo(w * 0.60, h * 0.85);
    fullPath.lineTo(w * 0.60, h * 0.30);
    fullPath.lineTo(w * 0.50, h * 0.20);
    

    // ======================================================
    // ======================================================
    fullPath.moveTo(w * 0.85, h * 0.90);
    fullPath.lineTo(w * 0.50, h * 0.90);
    fullPath.lineTo(w * 0.50, h * 0.20);


    // ======================================================
    // ======================================================

    fullPath.moveTo(w * 0.37, h * 0.90);
    fullPath.lineTo(w * 0.37, h * 0.50);

    fullPath.moveTo(w * 0.44, h * 0.90);
    fullPath.lineTo(w * 0.44, h * 0.45);

    // ======================================================
    // ✅ 动画（逐渐画出线条）
    // ======================================================
    final Path pathToDraw = Path();
    for (final metric in fullPath.computeMetrics()) {
      final extract = metric.extractPath(
        0,
        metric.length * progress,
      );
      pathToDraw.addPath(extract, Offset.zero);
    }

    canvas.drawPath(pathToDraw, paint);
  }

  @override
  bool shouldRepaint(covariant HotelLogoPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
