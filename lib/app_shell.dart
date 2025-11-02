import 'package:flutter/material.dart';

// 导入5个页面（⚠️ 路径要跟你的项目一致）
import 'package:hotel_reservation_app/pages/search_page.dart';
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
  int _selectedIndex = 0;

  // ❌ 不要写 const，不然会报 “Invalid constant value”
  final List<Widget> _pages = [
    const SearchPage(),   // 如果你的页面是 const 的，就写 const
    const ServicePage(),
    const BookingPage(),
    const InfoPage(),
    ProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.room_service),
            label: 'Service',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book_online),
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
      ),
    );
  }
}
