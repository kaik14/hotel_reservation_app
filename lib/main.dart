// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// 入口相关页面
import 'package:hotel_reservation_app/pages/splash_screen.dart';  // ✅ 启动动画页
import 'package:hotel_reservation_app/auth_gate.dart';            // ✅ 登录判断页
import 'package:hotel_reservation_app/pages/preference_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hotel Reservation App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),

      // ✅ 一开始先进启动页，启动页会再跳到 AuthGate
      home: const SplashScreen(),

      // ✅ 这里先把会用到的页面注册起来
      routes: {
        '/auth': (context) => const AuthGate(),
        '/preferences': (context) => const PreferencePage(),
        // 以后我们加：'/roomDetail': (...) 和 '/bookings': (...) 就行
      },
    );
  }
}
