import 'package:flutter/material.dart';
import 'package:hotel_reservation_app/pages/search_page.dart';
import 'package:hotel_reservation_app/pages/service_page.dart';
import 'package:hotel_reservation_app/pages/booking_page.dart';
import 'package:hotel_reservation_app/pages/info_page.dart';
import 'package:hotel_reservation_app/pages/profile_page.dart';

class TaskStatusPage extends StatefulWidget {
  final int initialIndex;

  const TaskStatusPage({super.key, this.initialIndex = 0});

  @override
  TaskStatusPageState createState() => TaskStatusPageState();
}

class TaskStatusPageState extends State<TaskStatusPage> {
  late int _selectedIndex;

  // ✅ cache non-dynamic pages
  late final ServicePage _servicePage;
  late final BookingPage _bookingPage;
  late final InfoPage _infoPage;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;

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
      backgroundColor: Colors.white,
      extendBody: true, // 让内容延伸到底栏后方，避免露出白底
      appBar: AppBar(
        title: const Text('Task Status'),
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
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          Center(
            child: Text(
              'pending',
              style: TextStyle(color: Colors.black),
            ),
          ), // re-created
          Center(
            child: Text(
              'progress',
              style: TextStyle(color: Colors.black),
            ),
          ),
          Center(
            child: Text(
              'complete',
              style: TextStyle(color: Colors.black),
            ),
          ),
          Center(
            child: Text(
              'overdue',
              style: TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),

      // 只裁剪“上侧圆角”，底部不裁剪
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24), // ← 只保留上缘圆角
          topRight: Radius.circular(24),
        ),
        child: Material(
          color: Colors.transparent, // 防止有默认白色材质
          child: _ModernBottomBar(
            currentIndex: _selectedIndex,
            onChanged: _onItemTapped,
          ),
        ),
      ),
    );
  }
}

/// ---------------- Modern Bottom Bar (dark + ice blue) ----------------

class _ModernBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onChanged;

  const _ModernBottomBar({required this.currentIndex, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    // ====== 这些是你可以轻松“调高度”的位置 ======
    const double kTopPadding = 15; // ← 顶部内边距（增大=更高）
    const double kBottomExtra = 2; // ← 在系统安全区基础上的额外底边距（增大=更高）
    const double kIconBox = 42; // ← 圆角图标盒子尺寸（增大=更高）
    // =========================================

    final items = const [
      _NavItem('Pending', Icons.pending),
      _NavItem('Progress', Icons.linear_scale_outlined),
      _NavItem('Complete', Icons.check_circle_outline),
      _NavItem('Overdue', Icons.info_outline_rounded),
    ];

    return Container(
      decoration: BoxDecoration(
        color: _Palette.surface, // 深色真正背景
        // 只在上缘有圆角的视觉，底部不影响（裁剪已在外层 ClipRRect 做了）
        // 这里不写 radius 也行，保持纯色方形，由外层裁剪出圆角
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.35),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: kTopPadding, // ← 调这里可以“拉高”底栏
        // 系统安全区 + 你的额外高度
        bottom: MediaQuery.of(context).padding.bottom + kBottomExtra, // ← 调这里
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(items.length, (i) {
          final selected = i == currentIndex;
          final item = items[i];
          return _NavButton(
            icon: item.icon,
            label: item.label,
            selected: selected,
            onTap: () => onChanged(i),
            boxSize: kIconBox, // ← 传入图标盒尺寸，影响总高度
          );
        }),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double boxSize; // ← 新增：图标盒尺寸，方便统一调高

  const _NavButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.boxSize,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            height: boxSize,
            // ← 用参数控制
            width: boxSize,
            // ← 用参数控制
            decoration: BoxDecoration(
              color: selected
                  ? _Palette.accentBlue
                  : Colors.white.withOpacity(.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(selected ? 1 : .75),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: .2,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;

  const _NavItem(this.label, this.icon);
}

class _Palette {
  static const surface = Color(0xFF0F1722); // 深蓝黑
  static const accentBlue = Color.fromARGB(255, 59, 98, 166); // 选中底色
}
