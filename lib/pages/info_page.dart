// lib/pages/info_page.dart
import 'package:flutter/material.dart';

class InfoPage extends StatelessWidget {
  const InfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // <-- 加上这一行
      appBar: AppBar(
        title: const Text('Info'), // (我也帮你改成了英文)
        backgroundColor: Colors.white, // (让 AppBar 也变白)
        elevation: 0, // (移除 AppBar 的阴影)
      ),
      body: const Center(
        child: Text(
          'This is the Info Page', // (改成了英文)
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}