import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hotel_reservation_app/services/database_service.dart';

import 'package:hotel_reservation_app/app_shell.dart';
import 'package:hotel_reservation_app/pages/login_page.dart';
import 'package:hotel_reservation_app/pages/preference_page.dart';
import 'package:hotel_reservation_app/pages/staff_page.dart';
import 'package:hotel_reservation_app/pages/admin_Page.dart'; // 注意文件名大小写

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        // 1. 等待 Auth 初始化
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // 2. 用户已登录
        if (authSnapshot.hasData && authSnapshot.data != null) {
          User user = authSnapshot.data!;

          // ✅ 3. 改用 StreamBuilder 监听用户信息
          // 这样一旦 'isSetup' 字段变成 true，页面会自动刷新进入主页
          return StreamBuilder<DocumentSnapshot>(
            stream: DatabaseService().getUserDataStream(user.uid),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                    body: Center(child: CircularProgressIndicator()));
              }

              // 获取用户数据
              String role = 'customer';
              bool isSetup = false; // 默认为 false

              if (userSnapshot.hasData &&
                  userSnapshot.data != null &&
                  userSnapshot.data!.exists) {
                final data = userSnapshot.data!.data() as Map<String, dynamic>;
                role = data['role'] ?? 'customer';
                // 检查是否有 isSetup 标记
                isSetup = data['isSetup'] == true;
              }

              // 4. 路由分流逻辑
              if (role == 'admin') {
                return const AdminPage();
              } else if (role == 'staff') {
                return const StaffPage();
              } else {
                // 普通用户逻辑
                if (!isSetup) {
                  // 没设置过 -> 去偏好页
                  return const PreferencePage();
                } else {
                  // 设置过了 -> 去主页
                  return const AppShell();
                }
              }
            },
          );
        }

        // 3. 未登录
        return const LoginPage();
      },
    );
  }
}