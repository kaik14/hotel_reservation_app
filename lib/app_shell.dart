import 'package:flutter/material.dart';
import 'package:hotel_reservation_app/pages/search_page.dart';
import 'package:hotel_reservation_app/pages/service_page.dart';
import 'package:hotel_reservation_app/pages/booking_page.dart';
import 'package:hotel_reservation_app/pages/info_page.dart';
import 'package:hotel_reservation_app/pages/profile_page.dart';

class AppShell extends StatefulWidget {
  final int initialIndex;

  const AppShell({super.key, this.initialIndex = 0});

  @override
  AppShellState createState() => AppShellState();
}

class AppShellState extends State<AppShell> {
  late int _selectedIndex;

  // ✅ 缓存非动态页面
  late final ServicePage _servicePage;
  late final BookingPage _bookingPage;
  late final InfoPage _infoPage;

  @override
  void initState() {
    super.initState();

    _selectedIndex = widget.initialIndex;

    // ✅ 只缓存不依赖外部数据的页面
    _servicePage = const ServicePage();
    _bookingPage = const BookingPage();
    _infoPage = const InfoPage();
  }

  void switchToInfoPage() {
    setState(() => _selectedIndex = 3);
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          /// ✅ SearchPage 每次重新创建（可更新偏好）
          SearchPage(),

          /// ✅ 缓存其它页面
          _servicePage,
          _bookingPage,
          _infoPage,

          /// ✅ ProfilePage 每次重新创建（保持干净）
          ProfilePage(),
        ],
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.room_service), label: 'Service'),
          BottomNavigationBarItem(icon: Icon(Icons.book_online), label: 'Booking'),
          BottomNavigationBarItem(icon: Icon(Icons.info_outline), label: 'Info'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
