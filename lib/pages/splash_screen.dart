import 'package:flutter/material.dart';
import 'dart:async';
import 'package:hotel_reservation_app/auth_gate.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // 1️⃣ 初始化动画控制器
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), // 动画持续 2 秒
    );

    // 2️⃣ 定义淡入 + 放大动画
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    // 启动动画
    _controller.forward();

    // 3️⃣ 动画播放完后 3 秒跳转到 AuthGate
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
    final screenSize = MediaQuery.of(context).size;
    final logoSize = screenSize.width * 0.45; // 自动根据屏幕宽度调整 logo 尺寸

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 24, 23, 24), // 💜 紫色背景（可改）
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Image.asset(
              'assets/HRMSlogo.jpg', // ✅ 确保 pubspec.yaml 有正确注册
              width: logoSize,
              height: logoSize,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
