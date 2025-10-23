import 'package:flutter/material.dart';
// 导入你刚才创建的5个页面
import 'package:hotel_reservation_app/pages/search_page.dart'; // <-- 记得把 YOUR_APP_NAME 换成你的项目名
import 'package:hotel_reservation_app/pages/service_page.dart';
import 'package:hotel_reservation_app/pages/booking_page.dart';
import 'package:hotel_reservation_app/pages/info_page.dart';
import 'package:hotel_reservation_app/pages/profile_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  // 1. 状态变量：用于存储当前选中的页面索引
  int _selectedIndex = 0; 

  // 2. 页面列表：存放你所有的页面
  final List<Widget> _pages = <Widget>[
    SearchPage(),
    ServicePage(),
    BookingPage(),
    InfoPage(),
    ProfilePage(),
  ];

  // 3. 状态变更方法：当点击导航项时调用
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index; // 更新索引
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 4. 主体内容：根据 _selectedIndex 从 _pages 列表中选择要显示的页面
      body: Center(
        child: _pages.elementAt(_selectedIndex),
      ),
      
      // 5. 底部导航栏
      bottomNavigationBar: BottomNavigationBar(
        // 导航项列表
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.room_service), // 你可以换成更合适的图标
            label: 'Service',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book_online), // 你可以换成更合适的图标
            label: 'Booking',
          ),
           BottomNavigationBarItem(
            icon: Icon(Icons.info_outline),
            label: 'Info',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
        // 关键属性
        currentIndex: _selectedIndex,   // 告诉导航栏当前选中了哪一项
        onTap: _onItemTapped,           // 告诉导航栏，当用户点击时调用哪个方法
        
        // --- 样式美化 (可选，但推荐) ---
        // 默认情况下，超过3个项，类型会变为 'shifting'，背景会变白且图标会移动
        // 我们把它固定为 'fixed'，并设置颜色
        type: BottomNavigationBarType.fixed, // 固定类型
        selectedItemColor: Theme.of(context).colorScheme.primary, // 选中时的颜色
        unselectedItemColor: Colors.grey, // 未选中时的颜色
      ),
    );
  }
}