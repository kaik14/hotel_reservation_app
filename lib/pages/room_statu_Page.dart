import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // 用于格式化日期

// 引入服务
import 'package:hotel_reservation_app/services/auth_service.dart';
import 'package:hotel_reservation_app/services/database_service.dart';
import 'package:star_rating/star_rating.dart';

class RoomStatuPage extends StatelessWidget {
  const RoomStatuPage({super.key});


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Room Status'),
        // title: const Text('Admin Dashboard'),
        leadingWidth: 48,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.white, size: 30),
          onPressed: () => Navigator.maybePop(context),
          tooltip: 'Back',
        ),
        centerTitle: true,
        backgroundColor: Colors.black,
        // 管理员用深色顶栏以示区别
        foregroundColor: Colors.white,

      ),
      // ✅ 使用 StreamBuilder 实时监听所有订单
      body:Container(),
    );
  }
}
