import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:hotel_reservation_app/auth_gate.dart';
import 'package:hotel_reservation_app/data/hotel_logo_painter.dart';

// ✅ 可爱风“星芒插画”
class StarBurstPainter extends CustomPainter {
  final Color color;
  final int spikes;
  final double innerRatio;

  StarBurstPainter(
    this.color, {
    this.spikes = 12,
    this.innerRatio = 0.45,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final cx = size.width / 2;
    final cy = size.height / 2;
    final outerR = size.width / 2;
    final innerR = outerR * innerRatio;
    final totalPoints = spikes * 2;

    for (int i = 0; i < totalPoints; i++) {
      final isOuter = i.isEven;
      final r = isOuter ? outerR : innerR;
      final theta = (i * (math.pi * 2) / totalPoints) - math.pi / 2;

      final x = cx + r * math.cos(theta);
      final y = cy + r * math.sin(theta);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ✅ 小组件封装
class StarBurst extends StatelessWidget {
  final double size;
  final Color color;

  const StarBurst({
    super.key,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: StarBurstPainter(color.withOpacity(0.35)),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..forward();

    Timer(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthGate()),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: Stack(
        children: [
          // ✅ 背景插画碎片（可爱风）
         // ✅ 背景彩色插画星星（更多、更丰富）
Positioned(
  top: -40,
  left: -30,
  child: StarBurst(size: 120, color: const Color.fromARGB(255, 129, 223, 128)), // 淡绿
),
Positioned(
  top: 60,
  right: -20,
  child: StarBurst(size: 150, color: const Color.fromARGB(255, 184, 137, 239)), // 淡紫
),
Positioned(
  top: 180,
  left: 40,
  child: StarBurst(size: 60, color: const Color.fromARGB(255, 238, 125, 168)), // 粉
),
Positioned(
  bottom: 200,
  right: 40,
  child: StarBurst(size: 75, color: const Color.fromARGB(255, 227, 195, 112)), // 淡黄
),
Positioned(
  bottom: 80,
  left: -15,
  child: StarBurst(size: 85, color: const Color.fromARGB(255, 127, 188, 232)), // 天蓝
),
Positioned(
  top: 260,
  right: 80,
  child: StarBurst(size: 120, color: const Color.fromARGB(255, 232, 133, 93)), // 珊瑚橘
),
Positioned(
  bottom: 260,
  right: -10,
  child: StarBurst(size: 110, color: const Color.fromARGB(255, 115, 221, 193)), // 青绿色
),
Positioned(
  bottom: 260,
  right: 250,
  child: StarBurst(size: 110, color: const Color.fromARGB(255, 118, 239, 111)), // 绿色
),

          // ✅ 中间 Logo + 下方文字（都带动画）
Center(
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      // ✅ Logo 动画
      AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: 0.7 + _controller.value * 0.3,
            child: CustomPaint(
              painter: HotelLogoPainter(_controller.value),
              size: const Size(200, 200),
            ),
          );
        },
      ),

      const SizedBox(height: 12),

      // ✅ Logo 下方文字渐出动画
      FadeTransition(
        opacity: CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
        ),
        child: const Text(
          "HotelEase",
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            letterSpacing: 0.5,
          ),
        ),
      ),
    ],
  ),
),


          // ✅ 底部文本
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Column(
              children: const [
                Text(
                  "Welcome to HotelEase",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "Find rooms, book stays, enjoy comfort",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
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
