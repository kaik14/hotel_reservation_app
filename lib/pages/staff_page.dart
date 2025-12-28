import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

import 'package:hotel_reservation_app/services/database_service.dart';

// ✅ 新增：两个页面（Room / Me）
import 'package:hotel_reservation_app/pages/staff_room_page.dart';
import 'package:hotel_reservation_app/pages/staff_me_page.dart';

class StaffPage extends StatefulWidget {
  const StaffPage({super.key});

  @override
  State<StaffPage> createState() => _StaffPageState();
}

// —— 员工端统一风格 —— //
class _Brand {
  static const bg = Color.fromARGB(255, 222, 228, 236); // 浅蓝灰
  static const bar = Color(0xFF0F1722); // 深色顶栏
  static const accent = Color.fromARGB(255, 49, 59, 83); // 品牌深蓝（可用于按钮）
  static const tabOn = Color.fromARGB(255, 110, 172, 205); // 员工端 Tab 蓝
  static const cardBorder = Color.fromARGB(255, 191, 214, 233); // 淡蓝边框
}

class _StaffPageState extends State<StaffPage> {
  // ✅ 新增：底部栏 index（0=Task, 1=Room, 2=Me）
  int _navIndex = 0;

  // —— 原来 Task（Staff）页逻辑保留 —— //
  int _tabIndex = 0; // 0 = All, 1 = Active

  String _formatDateRange(Map<String, dynamic> bookingData) {
    try {
      final Timestamp startTs = bookingData['startDate'];
      final Timestamp endTs = bookingData['endDate'];
      return '${DateFormat('MM/dd').format(startTs.toDate())} - ${DateFormat('MM/dd').format(endTs.toDate())}';
    } catch (_) {
      return 'Date N/A';
    }
  }

  bool _isActive(Map<String, dynamic> bookingData) {
    final status = (bookingData['status'] ?? 'Active').toString().toLowerCase();
    if (status.contains('cancel')) return false;
    if (status.contains('complete')) return false;
    if (status.contains('finished')) return false;
    return true;
  }

  String _actionText(Map<String, dynamic> bookingData) {
    final status = (bookingData['status'] ?? 'Active').toString().toLowerCase();
    if (status.contains('pending')) return 'Accept';
    if (status.contains('book')) return 'Open';
    if (status.contains('active')) return 'Handle';
    return 'View';
  }

  // ✅ AppBar 标题跟随底部栏切换（可选，但更像员工端）
  String get _appTitle {
    switch (_navIndex) {
      case 0:
        return 'HotelEase';
      case 1:
        return 'Room';
      case 2:
        return 'Me';
      default:
        return 'HotelEase';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Brand.bg,

      appBar: AppBar(
        backgroundColor: _Brand.bar,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 97,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        title: Text(
          _appTitle,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 22,
            letterSpacing: -0.2,
          ),
        ),

        // ✅ 顶部 logout 去掉（只在 Me 页面保留）
        actions: const [SizedBox(width: 8)],

        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: Colors.white.withOpacity(0.08)),
        ),
      ),

      // ✅ 用 IndexedStack 切换 3 个页面，避免 Navigator / AuthGate 出错
      body: SafeArea(
        child: IndexedStack(
          index: _navIndex,
          children: [
            // =====================
            // Page 0：Task（就是你原来的 Staff 内容）
            // =====================
            StreamBuilder<QuerySnapshot>(
              stream: DatabaseService().getAllBookingsStream(),
              builder: (context, snapshot) {
                // 1) 错误
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                // 2) 加载中
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // 3) 空数据
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.assignment_turned_in_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No active bookings.',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                // 4) 数据准备
                final allDocs = snapshot.data!.docs;

                // tab 过滤：All / Active
                final filteredDocs = allDocs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  if (_tabIndex == 0) return true;
                  return _isActive(data);
                }).toList();

                final taskCount = filteredDocs.length;

                // ✅ 只显示 3 条
                final displayDocs = filteredDocs.take(3).toList();

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // —— 今日任务 —— //
                      Row(
                        children: [
                          Expanded(
                            child: _InfoPill(
                              title: 'Today Tasks',
                              value: taskCount.toString(),
                              icon: Icons.checklist_rounded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _InfoPill(
                              title: 'View',
                              value: _tabIndex == 0 ? 'All' : 'Active',
                              icon: Icons.dashboard_rounded,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // —— 分段 Tab —— //
                      _SegmentTabs(
                        leftText: 'All Bookings',
                        rightText: 'Active Only',
                        index: _tabIndex,
                        onChanged: (i) => setState(() => _tabIndex = i),
                      ),

                      const SizedBox(height: 16),

                      // —— 固定展示三条的高度 —— //
                      _FixedThreeCards(
                        docs: displayDocs,
                        hasMore: filteredDocs.length > 3,
                        buildCard: (doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final roomName = (data['roomName'] ?? 'Room')
                              .toString();
                          final status = (data['status'] ?? 'Active')
                              .toString();
                          final dateRange = _formatDateRange(data);
                          final price = (data['totalPrice']?.toString() ?? '0')
                              .toString();
                          final userId = (data['userId'] ?? '-').toString();

                          return _StaffTaskCard(
                            title: roomName,
                            subtitleLeft: dateRange,
                            subtitleRight: '\$$price',
                            footnote: 'Guest ID: $userId',
                            status: status,
                            actionText: _actionText(data),
                            onAction: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Action: ${_actionText(data)}'),
                                ),
                              );
                            },
                          );
                        },
                      ),

                      if (filteredDocs.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            'No items in this view.',
                            style: TextStyle(
                              color: Colors.black.withOpacity(0.5),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                      if (filteredDocs.isNotEmpty && displayDocs.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            filteredDocs.length > 3
                                ? 'Showing 3 of $taskCount'
                                : 'Showing $taskCount',
                            style: TextStyle(
                              color: Colors.black.withOpacity(0.45),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),

            // =====================
            // Page 1：Room（新页面）
            // =====================
            const StaffRoomPage(),

            // =====================
            // Page 2：Me（新页面，含 logout）
            // =====================
            const StaffMePage(),
          ],
        ),
      ),

      // ✅ 底部栏：加高 + Home 改 Task
      bottomNavigationBar: SizedBox(
        height: 97, // 想更高可改 88/92
        child: Container(
          decoration: BoxDecoration(
            color: _Brand.bar,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: _navIndex,
            onTap: (i) => setState(() => _navIndex = i),
            backgroundColor: _Brand.bar,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.white.withOpacity(0.65),
            showUnselectedLabels: true,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.checklist_outlined),
                activeIcon: Icon(Icons.checklist_rounded),
                label: 'Task',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.grid_view_outlined),
                activeIcon: Icon(Icons.grid_view_rounded),
                label: 'Room',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Me',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- UI 小组件（原样保留） ----------------

class _InfoPill extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _InfoPill({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.65),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.7)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _Brand.bar.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _Brand.accent, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentTabs extends StatelessWidget {
  final String leftText;
  final String rightText;
  final int index;
  final ValueChanged<int> onChanged;

  const _SegmentTabs({
    required this.leftText,
    required this.rightText,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.65)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegBtn(
              text: leftText,
              selected: index == 0,
              onTap: () => onChanged(0),
            ),
          ),
          Expanded(
            child: _SegBtn(
              text: rightText,
              selected: index == 1,
              onTap: () => onChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegBtn extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _SegBtn({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _Brand.tabOn : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}

class _FixedThreeCards extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  final bool hasMore;
  final Widget Function(QueryDocumentSnapshot doc) buildCard;

  const _FixedThreeCards({
    required this.docs,
    required this.hasMore,
    required this.buildCard,
  });

  @override
  Widget build(BuildContext context) {
    const double itemHeight = 86;
    const double spacing = 14;
    final double fixedHeight = itemHeight * 3 + spacing * 2;

    return SizedBox(
      height: fixedHeight,
      child: Column(
        children: [
          for (int i = 0; i < docs.length; i++) ...[
            SizedBox(height: itemHeight, child: buildCard(docs[i])),
            if (i != docs.length - 1) const SizedBox(height: spacing),
          ],
          if (docs.length < 3)
            Expanded(
              child: Container(
                alignment: Alignment.center,
                child: Text(
                  hasMore ? '' : 'No more items',
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.35),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StaffTaskCard extends StatelessWidget {
  final String title;
  final String subtitleLeft;
  final String subtitleRight;
  final String footnote;
  final String status;
  final String actionText;
  final VoidCallback onAction;

  const _StaffTaskCard({
    required this.title,
    required this.subtitleLeft,
    required this.subtitleRight,
    required this.footnote,
    required this.status,
    required this.actionText,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _Brand.cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.blueAccent),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: Colors.blue[800],
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.date_range, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        subtitleLeft,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      subtitleRight,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  footnote,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.black.withOpacity(0.45),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 34,
            child: ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: _Brand.tabOn,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                actionText,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
