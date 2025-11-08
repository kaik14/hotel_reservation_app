// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// ✅ 你的入口相关页面
import 'package:hotel_reservation_app/pages/splash_screen.dart';
import 'package:hotel_reservation_app/auth_gate.dart';
import 'package:hotel_reservation_app/pages/preference_page.dart';
import 'package:hotel_reservation_app/pages/booking_page.dart';

// ✅ 导入 AppShell
import 'package:hotel_reservation_app/app_shell.dart';

// ✅ 定义全局 key（给 SlideTransitionNotification 切换 Info 页用）
final GlobalKey<AppShellState> appShellKey = GlobalKey<AppShellState>();

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

      // ✅ 第一步：启动动画 → 然后跳 AuthGate → 然后去 AppShell
      home: const SplashScreen(),

      routes: {
        '/auth': (context) => const AuthGate(),
        '/preferences': (context) => const PreferencePage(),
        '/booking': (context) => const BookingPage(),

        // ✅ “所有页面最终都进入 AppShell”
        '/app': (context) => AppShell(key: appShellKey),
      },
    );
  }
}
