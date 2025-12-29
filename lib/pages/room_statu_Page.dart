import 'package:flutter/material.dart';

// ✅ 引入你现有的 StaffRoomPage（路径按你项目实际调整）
import 'package:hotel_reservation_app/pages/staff_room_page.dart';

/// ✅ 复用 BookingPage 的品牌配色（你原来的 _Brand 保留）
class _Brand {
  static const bg = Color.fromARGB(255, 222, 228, 236);
  static const bar = Color(0xFF313B53);
  static const accent = Color.fromARGB(255, 49, 59, 83);
}

class RoomStatuPage extends StatelessWidget {
  const RoomStatuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Brand.bg,
      appBar: AppBar(
        title: const Text('Room Status'),
        backgroundColor: _Brand.bar,
        foregroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      /// ✅ 内容完全换成 StaffRoomPage（和 staffroompage 一模一样）
      body: const StaffRoomPage(),
    );
  }
}
