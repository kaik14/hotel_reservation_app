// lib/auth_gate.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 导入主页面与登录页面
import 'package:hotel_reservation_app/app_shell.dart';
import 'package:hotel_reservation_app/pages/login_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // 使用 StreamBuilder 监听 Firebase 登录状态
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 🔄 正在等待 Firebase 响应
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // ✅ 用户已登录 → 进入主页面
        if (snapshot.hasData) {
          return const AppShell();
        }

        // 🚪 未登录 → 跳转到登录页
        return const LoginPage();
      },
    );
  }
}
