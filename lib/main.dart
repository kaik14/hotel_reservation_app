// lib/main.dart
import 'package:flutter/material.dart';
// 导入你的 AuthGate
import 'package:hotel_reservation_app/auth_gate.dart'; 

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

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
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // 把 'home' 指向 AuthGate()
      // AuthGate 会自动决定该显示 AppShell 还是 LoginPage
      home: const AuthGate(), 
    );
  }
}