import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import 'package:hotel_reservation_app/pages/staff_room_page.dart';
import 'package:hotel_reservation_app/pages/staff_me_page.dart';

class StaffPage extends StatefulWidget {
  const StaffPage({super.key});

  @override
  State<StaffPage> createState() => _StaffPageState();
}

// —— 员工端统一风格 —— //
class _Brand {
  static const bg = Color.fromARGB(255, 222, 228, 236);
  static const bar = Color(0xFF0F1722);
  static const accent = Color.fromARGB(255, 49, 59, 83);
  static const tabOn = Color.fromARGB(255, 110, 172, 205);
  static const cardBorder = Color.fromARGB(255, 191, 214, 233);
  static const muted = Color.fromARGB(255, 150, 160, 175);
}

class _StaffPageState extends State<StaffPage> {
  // 0=Task, 1=Room, 2=Me
  int _navIndex = 0;

  // Task 内部 tab：0=All, 1=Active
  int _tabIndex = 0;

  // 任务类型 tab：0=Service Tasks, 1=Room Tasks
  int _taskTypeIndex = 0;

  // 入场视频 overlay
  bool _showIntro = true;
  late final VideoPlayerController _introController;
  Timer? _introTimer;

  @override
  void initState() {
    super.initState();

    _introController =
        VideoPlayerController.asset('assets/videos/staff_intro.mp4')
          ..initialize().then((_) {
            if (!mounted) return;
            setState(() {});
            _introController.setLooping(false);
            _introController.play();
          });

    _introTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() => _showIntro = false);
    });
  }

  @override
  void dispose() {
    _introTimer?.cancel();
    _introController.dispose();
    super.dispose();
  }

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

  // -------------------------
  // 分类：服务任务 / 房间任务
  // -------------------------
  static const _serviceTypes = <String>{
    'spa',
    'conference',
    'conferencehall',
    'taxi',
    'laundry',
  };

  bool _isRoomTask(Map<String, dynamic> data) {
    final st = (data['serviceType'] ?? '').toString().toLowerCase().trim();
    return st == 'housekeeping';
  }

  bool _isServiceTask(Map<String, dynamic> data) {
    final st = (data['serviceType'] ?? '').toString().toLowerCase().trim();
    return _serviceTypes.contains(st);
  }

  // -------------------------
  // Active 判定：只要没被取消/完成/结束/接取，就算 Active
  // -------------------------
  bool _isActive(Map<String, dynamic> bookingData) {
    // ✅ 接取后就不算 active
    if (_isHandled(bookingData)) return false;

    final status = (bookingData['status'] ?? '').toString().toLowerCase();
    if (status.contains('cancel')) return false;
    if (status.contains('complete')) return false;
    if (status.contains('finished')) return false;
    return true;
  }

  bool _isHandled(Map<String, dynamic> data) {
    // 兼容两种：handled:true 或 status: handled/accepted
    final handledFlag = (data['handled'] ?? false) == true;
    if (handledFlag) return true;

    final status = (data['status'] ?? '').toString().toLowerCase();
    if (status.contains('handled')) return true;
    if (status.contains('accepted')) return true;
    if (status.contains('taken')) return true;
    return false;
  }

  // -------------------------
  // 标题：更像任务
  // -------------------------
  String _taskTitle(Map<String, dynamic> data) {
    final serviceType = (data['serviceType'] ?? '').toString().trim();
    final serviceName = (data['serviceName'] ?? '').toString().trim();

    if (_isRoomTask(data)) {
      final roomNo = (data['roomNumber'] ?? data['roomNo'] ?? '').toString();
      final label = roomNo.isNotEmpty ? 'Room $roomNo' : 'Room';
      return '$label - Housekeeping';
    }

    if (serviceName.isNotEmpty) return serviceName;

    if (serviceType.isNotEmpty) {
      final t = serviceType.toLowerCase();
      if (t == 'conferencehall') return 'Conference Hall';
      if (t == 'taxi') return 'Airport Taxi';
      if (t == 'laundry') return 'Laundry & Ironing';
      return '${serviceType[0].toUpperCase()}${serviceType.substring(1)}';
    }

    final roomType = (data['roomTypeTitle'] ?? data['roomName'] ?? 'Booking')
        .toString();
    return roomType;
  }

  // -------------------------
  // 时间显示：兼容 service / room
  // -------------------------
  String _taskTimeText(Map<String, dynamic> data) {
    try {
      final ts = data['serviceStart'] as Timestamp?;
      if (ts != null) {
        final dt = ts.toDate();
        return DateFormat('dd MMM • HH:mm').format(dt);
      }

      final dateTs = data['serviceDate'] as Timestamp?;
      final timeStr =
          (data['serviceTime'] ?? data['startTime'] ?? data['pickupTime'])
              ?.toString();
      if (dateTs != null) {
        final d = dateTs.toDate();
        if (timeStr != null && timeStr.contains(':')) {
          return '${DateFormat('dd MMM').format(d)} • $timeStr';
        }
        return DateFormat('dd MMM').format(d);
      }
    } catch (_) {}

    try {
      final ci = (data['checkIn'] as Timestamp?)?.toDate();
      final co = (data['checkOut'] as Timestamp?)?.toDate();
      if (ci != null && co != null) {
        return '${DateFormat('MM/dd').format(ci)} - ${DateFormat('MM/dd').format(co)}';
      }
    } catch (_) {}

    return 'Time N/A';
  }

  String _guestIdText(QueryDocumentSnapshot doc, Map<String, dynamic> data) {
    final direct = (data['userId'] ?? '').toString().trim();
    if (direct.isNotEmpty) return direct;
    return doc.reference.parent.parent?.id ?? '-';
  }

  // ✅ collectionGroup 拉全酒店订单（所有 users/*/bookings/*）
  Stream<QuerySnapshot> _allBookingsStream() {
    return FirebaseFirestore.instance.collectionGroup('bookings').snapshots();
  }

  // ✅ 接取任务：写回 Firestore
  Future<void> _handleTakeTask(QueryDocumentSnapshot doc) async {
    try {
      await doc.reference.update({
        'handled': true,
        'status': 'handled',
        'handledAt': Timestamp.now(),
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to handle task: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 用 Stack 把 overlay 压在 Scaffold 之上，覆盖 AppBar + BottomNav
    return Stack(
      children: [
        Scaffold(
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
            actions: const [SizedBox(width: 8)],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(0.5),
              child: Container(
                height: 0.5,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          body: SafeArea(
            child: IndexedStack(
              index: _navIndex,
              children: [
                _buildTaskPage(),
                const StaffRoomPage(),
                const StaffMePage(),
              ],
            ),
          ),
          bottomNavigationBar: SizedBox(
            height: 97,
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
        ),

        // ✅ 全屏覆盖 intro（包含底部栏）
        if (_showIntro)
          Positioned.fill(
            child: _FullScreenIntroOverlay(
              controller: _introController,
              text: "Ready to make someone's day?",
            ),
          ),
      ],
    );
  }

  // =========================
  // Task Page（✅显示全部任务）
  // =========================
  Widget _buildTaskPage() {
    return StreamBuilder<QuerySnapshot>(
      stream: _allBookingsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
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
                  'No tasks yet.',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs.cast<QueryDocumentSnapshot>();

        // createdAt newest first（没有 createdAt 的放后）
        final sorted = [...docs];
        sorted.sort((a, b) {
          final ad = (a.data() as Map<String, dynamic>);
          final bd = (b.data() as Map<String, dynamic>);
          final at = (ad['createdAt'] as Timestamp?)?.toDate();
          final bt = (bd['createdAt'] as Timestamp?)?.toDate();
          if (at == null && bt == null) return 0;
          if (at == null) return 1;
          if (bt == null) return -1;
          return bt.compareTo(at);
        });

        final serviceDocs = sorted
            .where((d) => _isServiceTask(d.data() as Map<String, dynamic>))
            .toList();
        final roomDocs = sorted
            .where((d) => _isRoomTask(d.data() as Map<String, dynamic>))
            .toList();

        final currentDocs = (_taskTypeIndex == 0) ? serviceDocs : roomDocs;

        final filteredDocs = currentDocs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          if (_tabIndex == 0) return true;
          return _isActive(data);
        }).toList();

        final taskCount = filteredDocs.length;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部统计
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
                      title: 'Type',
                      value: _taskTypeIndex == 0 ? 'Service' : 'Room',
                      icon: Icons.dashboard_rounded,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // 任务类型：Service / Room
              _SegmentTabs(
                leftText: 'Service Tasks',
                rightText: 'Room Tasks',
                index: _taskTypeIndex,
                onChanged: (i) => setState(() => _taskTypeIndex = i),
              ),

              const SizedBox(height: 12),

              // All / Active
              _SegmentTabs(
                leftText: 'All',
                rightText: 'Active',
                index: _tabIndex,
                onChanged: (i) => setState(() => _tabIndex = i),
              ),

              const SizedBox(height: 16),

              // ✅ 显示全部任务（可滚动）
              Expanded(
                child: ListView.separated(
                  itemCount: filteredDocs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final title = _taskTitle(data);
                    final timeText = _taskTimeText(data);
                    final guestId = _guestIdText(doc, data);
                    final handled = _isHandled(data);

                    return SizedBox(
                      height: 127, // ✅ 按你要求
                      child: _StaffTaskCard(
                        title: title,
                        subtitleLeft: timeText,
                        footnote: 'Guest ID: $guestId',
                        onTapDetail: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StaffTaskDetailPage(
                                doc: doc,
                                data: data,
                                title: title,
                              ),
                            ),
                          );
                        },
                        handled: handled,
                        onHandle: () async {
                          if (handled) return;
                          await _handleTakeTask(doc);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// ✅ 全屏 intro：覆盖整个屏幕（包含底部栏）
class _FullScreenIntroOverlay extends StatelessWidget {
  final VideoPlayerController controller;
  final String text;

  const _FullScreenIntroOverlay({required this.controller, required this.text});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: SizedBox(
                width: double.infinity,
                height: 300,
                child: controller.value.isInitialized
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: FittedBox(
                          fit: BoxFit.cover,
                          clipBehavior: Clip.hardEdge,
                          child: SizedBox(
                            width: controller.value.size.width,
                            height: controller.value.size.height,
                            child: VideoPlayer(controller),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 127),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 650),
                curve: Curves.easeOutCubic,
                builder: (context, v, child) {
                  return Opacity(
                    opacity: v,
                    child: Transform.translate(
                      offset: Offset(0, (1 - v) * 10),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.black.withOpacity(0.65),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }
}

// =========================
// ✅ 详情页（只展示重点信息 + 图片）
// =========================
class StaffTaskDetailPage extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final Map<String, dynamic> data;
  final String title;

  const StaffTaskDetailPage({
    super.key,
    required this.doc,
    required this.data,
    required this.title,
  });

  String _fmtDate(DateTime dt) => DateFormat('dd MMM yyyy').format(dt);
  String _fmtTime(DateTime dt) => DateFormat('HH:mm').format(dt);
  String _fmtDateTime(DateTime dt) =>
      DateFormat('dd MMM yyyy • HH:mm').format(dt);

  DateTime? _serviceStartAt(Map<String, dynamic> data) {
    final ts = data['serviceStart'] as Timestamp?;
    if (ts != null) return ts.toDate();

    final dateTs = data['serviceDate'] as Timestamp?;
    if (dateTs == null) return null;
    final d = dateTs.toDate();

    final timeStr =
        (data['serviceTime'] ?? data['startTime'] ?? data['pickupTime'])
            ?.toString();

    if (timeStr == null || !timeStr.contains(':')) {
      return DateTime(d.year, d.month, d.day);
    }

    final parts = timeStr.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return DateTime(d.year, d.month, d.day, h, m);
  }

  DateTime? _serviceEndAt(Map<String, dynamic> data) {
    final ts = data['serviceEnd'] as Timestamp?;
    if (ts != null) return ts.toDate();

    final dateTs = data['serviceDate'] as Timestamp?;
    if (dateTs == null) return null;
    final d = dateTs.toDate();

    final endStr = (data['endTime'] ?? data['returnTime'])?.toString();
    if (endStr == null || !endStr.contains(':')) return null;

    final parts = endStr.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;

    final start = _serviceStartAt(data);
    final endDT = DateTime(d.year, d.month, d.day, h, m);
    if (start != null && endDT.isBefore(start)) {
      return endDT.add(const Duration(days: 1));
    }
    return endDT;
  }

  String _serviceType() =>
      (data['serviceType'] ?? '').toString().toLowerCase().trim();

  String _headerImageForType(String type) {
    switch (type) {
      case 'spa':
        return 'assets/services/spa.jpg';
      case 'laundry':
        return 'assets/services/laundry.jpg';
      case 'taxi':
        return 'assets/services/taxi.jpg';
      case 'conferencehall':
      case 'conference':
        return 'assets/services/conference.jpg';
      case 'housekeeping':
        return 'assets/services/housekeeping.jpg';
      case 'gym':
        return 'assets/services/gym.jpg';
      case 'swimming':
        return 'assets/services/swimming.jpg';
      default:
        return 'assets/services/service.jpg'; // 你可以自己放一个通用图
    }
  }

  List<Widget> _importantRows(BuildContext context) {
    final type = _serviceType();

    final guestId = (data['userId'] ?? doc.reference.parent.parent?.id ?? '-')
        .toString();

    final startAt = _serviceStartAt(data);
    final endAt = _serviceEndAt(data);

    final status = (data['status'] ?? 'pending').toString();
    final handled = (data['handled'] ?? false) == true;

    final roomNo = (data['roomNumber'] ?? data['roomNo'] ?? '')
        .toString()
        .trim();

    final rows = <Widget>[];

    rows.add(_infoRow('Guest ID', guestId));
    rows.add(_infoRow('Status', handled ? 'Handled' : status));

    if (startAt != null) {
      rows.add(_infoRow('Date', _fmtDate(startAt)));
      final timeText = endAt == null
          ? _fmtTime(startAt)
          : '${_fmtTime(startAt)}–${_fmtTime(endAt)}';
      rows.add(_infoRow('Time', timeText));
    } else {
      rows.add(_infoRow('Date', '-'));
      rows.add(_infoRow('Time', '-'));
    }

    if (roomNo.isNotEmpty) {
      rows.add(_infoRow('Room No', roomNo));
    }

    // —— 按服务类型补充少量重点字段 —— //
    if (type == 'laundry') {
      final items =
          (data['items'] ?? data['clothesCount'] ?? data['numberOfItems'] ?? '')
              .toString();
      final pickup = (data['pickupTime'] ?? data['startTime'] ?? '').toString();
      final ret = (data['returnTime'] ?? data['endTime'] ?? '').toString();
      if (items.trim().isNotEmpty) rows.add(_infoRow('Items', items));
      if (pickup.trim().isNotEmpty) rows.add(_infoRow('Pickup', pickup));
      if (ret.trim().isNotEmpty) rows.add(_infoRow('Return', ret));
    }

    if (type == 'taxi') {
      final ride = (data['rideLabel'] ?? data['rideKey'] ?? '').toString();
      final pax = (data['passengers'] ?? data['guests'] ?? '').toString();
      if (ride.trim().isNotEmpty) rows.add(_infoRow('Ride Type', ride));
      if (pax.trim().isNotEmpty) rows.add(_infoRow('Passengers', pax));
    }

    if (type == 'conferencehall' || type == 'conference') {
      final roomType = (data['roomLabel'] ?? data['roomKey'] ?? '').toString();
      if (roomType.trim().isNotEmpty) rows.add(_infoRow('Room Type', roomType));
    }

    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final handledAt = (data['handledAt'] as Timestamp?)?.toDate();

    if (createdAt != null)
      rows.add(_infoRow('Created', _fmtDateTime(createdAt)));
    if (handledAt != null)
      rows.add(_infoRow('Handled At', _fmtDateTime(handledAt)));

    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final type = _serviceType();
    final headerImage = _headerImageForType(type);
    final subtitle = (data['serviceName'] ?? data['serviceType'] ?? 'Task')
        .toString();

    return Scaffold(
      backgroundColor: _Brand.bg,
      appBar: AppBar(
        backgroundColor: _Brand.bar,
        elevation: 0,
        centerTitle: false,
        toolbarHeight: 97,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.white, size: 30),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Booking Details',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Review and manage your reservation.',
              style: TextStyle(
                color: Color(0x99FFFFFF),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: Colors.white.withOpacity(0.08)),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Container(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                  child: Image.asset(
                    headerImage,
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 220,
                      color: Colors.black.withOpacity(0.06),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.image_not_supported_outlined,
                        size: 34,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 14),
                      ..._importantRows(context).expand((w) sync* {
                        yield w;
                        yield const SizedBox(height: 10);
                      }).toList(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.black87, fontSize: 14),
          ),
        ),
      ],
    );
  }
}

// ---------------- UI 小组件 ----------------

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

class _StaffTaskCard extends StatelessWidget {
  final String title;
  final String subtitleLeft;
  final String footnote;

  final VoidCallback onTapDetail;

  final bool handled;
  final VoidCallback onHandle;

  const _StaffTaskCard({
    required this.title,
    required this.subtitleLeft,
    required this.footnote,
    required this.onTapDetail,
    required this.handled,
    required this.onHandle,
  });

  static const double _btnH = 40;
  static const double _btnW = 92;

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
                // 标题
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.1,
                  ),
                ),

                const SizedBox(height: 10),

                Row(
                  children: [
                    Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        subtitleLeft,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                Text(
                  footnote,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.black.withOpacity(0.45),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // ✅ 右侧：Detail + Handle 同一行、同尺寸
          Row(
            children: [
              SizedBox(
                height: _btnH,
                width: _btnW,
                child: OutlinedButton(
                  onPressed: onTapDetail,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: Colors.blueAccent,
                      width: 1.2,
                    ),
                    foregroundColor: Colors.blue[800],
                    backgroundColor: Colors.blue[50],
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Detail',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: _btnH,
                width: _btnW,
                child: ElevatedButton(
                  onPressed: handled ? null : onHandle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: handled ? _Brand.muted : _Brand.tabOn,
                    disabledBackgroundColor: _Brand.muted,
                    elevation: 0,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    handled ? 'Handled' : 'Handle',
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
        ],
      ),
    );
  }
}
