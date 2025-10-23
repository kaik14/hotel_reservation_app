// lib/auth_gate.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 导入你的两个主要页面
import 'package:hotel_reservation_app/app_shell.dart';     // 你的主页 (导航栏)
import 'package:hotel_reservation_app/pages/login_page.dart'; // 你的登录页

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // StreamBuilder 会持续监听一个 Stream（数据流）
    return StreamBuilder<User?>(
      // 监听 Firebase Auth 的认证状态变化
      // 这就是我们刚才在 AuthService 里定义的那个 Stream
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        
        // 1. 检查连接状态
        if (snapshot.connectionState == ConnectionState.waiting) {
          // 如果还在等待 Firebase 响应，显示一个加载动画
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 2. 检查是否有数据 (用户对象)
        if (snapshot.hasData) {
          // snapshot.hasData 为 true 意味着用户已登录
          // snapshot.data 就是那个 User 对象
          return const AppShell(); // 显示 App 主壳（你的5个导航页）
        }
        
        // 3. 如果没有数据
        // snapshot.hasData 为 false 意味着用户未登录 (stream 返回 null)
        return const LoginPage(); // 显示登录页
      },
    );
  }
}