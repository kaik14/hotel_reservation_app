import 'package:flutter/material.dart';

class BookingPage extends StatelessWidget {
  const BookingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 1. 设置背景色为白色
      backgroundColor: Colors.white, 
      
      // 2. 恢复 AppBar，并设置样式与 InfoPage 一致
      appBar: AppBar(
        title: const Text('Booking'), // 标题改为 'Booking'
        backgroundColor: Colors.white, // (让 AppBar 也变白)
        elevation: 0, // (移除 AppBar 的阴影)
        // (可选) 确保标题是黑色
        titleTextStyle: TextStyle(
          color: Colors.black, 
          fontSize: 20, 
          fontWeight: FontWeight.w500
        ),
      ),
      
      body: Center(
        child: Text(
          'This is the Booking Page', // 3. UI 文本为英文
          style: TextStyle(fontSize: 24, color: Colors.grey[800]), 
        ),
      ),
    );
  }
}

