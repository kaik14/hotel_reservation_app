import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

import 'package:hotel_reservation_app/data/info_data.dart';
import 'package:hotel_reservation_app/pages/booking_edit_page.dart';
import 'package:hotel_reservation_app/app_shell.dart';

// —— 统一配色 —— //
class _Brand {
  static const bg = Color.fromARGB(255, 222, 228, 236); // 浅蓝灰背景
  static const bar = Color(0xFF0F1722); // 顶栏/底栏深色
  static const accent = Color.fromARGB(255, 49, 59, 83); // 品牌按钮色
}

class BookingDetailPage extends StatefulWidget {
  final String bookingId;
  final Map<String, dynamic> data;

  const BookingDetailPage({
    super.key,
    required this.bookingId,
    required this.data,
  });

  @override
  State<BookingDetailPage> createState() => _BookingDetailPageState();
}

class _BookingDetailPageState extends State<BookingDetailPage> {
  bool _isCancelling = false;

  // 顶部系统通知
  void _showTopNotification(BuildContext context, InfoMessage message) {
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: 50,
        left: 20,
        right: 20,
        child: SlideTransitionNotification(message: message),
      ),
    );
    Overlay.of(context).insert(entry);
    Future.delayed(const Duration(seconds: 5), () => entry.remove());
  }

  // 取消预定（逻辑不变）
  Future<void> _cancelBooking(Map<String, dynamic> data) async {
    final docId = data['roomTypeId'];
    final roomNo = data['roomNo'];
    final checkIn = (data['checkIn'] as Timestamp).toDate();
    final checkOut = (data['checkOut'] as Timestamp).toDate();
    final isoFmt = DateFormat('yyyy-MM-dd');

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text("Cancel Booking"),
        content: const Text("Are you sure you want to cancel this booking?"),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("No"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Yes, Cancel",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    setState(() => _isCancelling = true);

    try {
      final roomDoc = FirebaseFirestore.instance.collection('rooms').doc(docId);

      // 回滚房型 bookedDates
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(roomDoc);
        if (!snap.exists) return;
        final raw = snap.data() as Map<String, dynamic>;
        final List<dynamic> rooms = List.from(raw['rooms'] ?? []);
        final idx = rooms.indexWhere(
          (r) => (r['roomNo'] ?? '').toString() == roomNo.toString(),
        );
        if (idx < 0) return;

        final Map<String, dynamic> room = Map<String, dynamic>.from(rooms[idx]);
        final List<String> booked = List<String>.from(
          room['bookedDates'] ?? [],
        );

        DateTime d = checkIn;
        while (!d.isAfter(checkOut.subtract(const Duration(days: 1)))) {
          booked.remove(isoFmt.format(d));
          d = d.add(const Duration(days: 1));
        }

        room['bookedDates'] = booked;
        rooms[idx] = room;
        tx.update(roomDoc, {'rooms': rooms});
      });

      // 删除用户 booking
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('bookings')
            .doc(widget.bookingId)
            .delete();
      }

      // 系统推送
      final cancelMsg = InfoMessage(
        title: "Booking Cancelled",
        message:
            "Your booking for ${data['roomTypeTitle']} (Room $roomNo) has been cancelled.",
        senderIcon: 'system',
        timestamp: DateTime.now(),
      );

      if (!mounted) return;
      _showTopNotification(context, cancelMsg);

      // 返回列表
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  // 实时监听（逻辑不变）
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text("Not logged in")));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('bookings')
          .doc(widget.bookingId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.data!.exists) {
          return const Scaffold(body: Center(child: Text("Booking removed")));
        }
        final data = snapshot.data!.data() as Map<String, dynamic>;
        return _buildDetailUI(context, data);
      },
    );
  }

  // —— UI —— //
  Widget _buildDetailUI(BuildContext context, Map<String, dynamic> data) {
    final price = data['priceText'] ?? "RM -";
    final desc = data['description'] ?? data['roomDesc'] ?? "per night";

    final imageName = data['imageName'] ?? "${data['roomTypeId']}.jpg";
    final imagePath = "assets/rooms/$imageName";

    final checkIn = (data['checkIn'] as Timestamp?)?.toDate();
    final checkOut = (data['checkOut'] as Timestamp?)?.toDate();
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

    final guests = data['guests'] ?? 1;
    final roomNo = data['roomNo'] ?? '-';
    final title = data['roomTypeTitle'] ?? 'Room';

    final nights =
        data['nights'] ??
        (checkIn != null && checkOut != null
            ? checkOut.difference(checkIn).inDays
            : 1);

    final dateFmt = DateFormat('dd MMM yyyy');
    final createdFmt = DateFormat('dd MMM yyyy – HH:mm');

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isCheckedIn = checkIn != null && checkIn.isBefore(today);

    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: _Brand.bg,

      // 顶栏：加“<”返回按钮；无底部分割线
      appBar: AppBar(
        backgroundColor: _Brand.bar,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 8, // 让返回键与标题更近一些
        toolbarHeight: 97, // 与你的全局规范一致
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: _Brand.bar,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        leadingWidth: 48,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.white, size: 30),
          onPressed: () => Navigator.maybePop(context),
          tooltip: 'Back',
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
      ),

      // ✅ 底部栏：无图标无功能版“AppBar”——同色、同高度、上圆角
      bottomNavigationBar: Container(
        height: 75 + bottomSafe,
        decoration: const BoxDecoration(
          color: _Brand.bar, // ← 保留纯色
          // borderRadius: BorderRadius.vertical(top: Radius.circular(24)), // ← 删掉这行
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, // 左对齐
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: Image.asset(
                  imagePath,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),

              // 内容
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, // 左对齐
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      price,
                      style: const TextStyle(fontSize: 15, color: Colors.grey),
                    ),
                    const SizedBox(height: 10),

                    if (desc.isNotEmpty)
                      Text(
                        desc,
                        style: const TextStyle(fontSize: 15, height: 1.5),
                      ),
                    const SizedBox(height: 14),

                    _infoRow("Room No", roomNo),
                    _infoRow("Guests", "$guests"),
                    _infoRow(
                      "Check-in",
                      checkIn != null ? dateFmt.format(checkIn) : "-",
                    ),
                    _infoRow(
                      "Check-out",
                      checkOut != null ? dateFmt.format(checkOut) : "-",
                    ),
                    _infoRow("Nights", "$nights"),
                    _infoRow(
                      "Created",
                      createdAt != null ? createdFmt.format(createdAt) : "-",
                    ),

                    const SizedBox(height: 20),

                    // 操作区：两个等宽按钮、同色同尺寸
                    if (!isCheckedIn)
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(
                                Icons.edit_calendar_outlined,
                                color: Colors.white,
                              ),
                              label: const Text(
                                "Edit Booking",
                                style: TextStyle(color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _Brand.accent,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                shadowColor: _Brand.accent.withOpacity(.25),
                                elevation: 4,
                                minimumSize: const Size(0, 48),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => BookingEditPage(
                                      bookingId: widget.bookingId,
                                      data: data,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _isCancelling
                                ? const SizedBox(
                                    height: 48,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                      ),
                                    ),
                                  )
                                : ElevatedButton.icon(
                                    icon: const Icon(
                                      Icons.cancel_outlined,
                                      color: Colors.white,
                                    ),
                                    label: const Text(
                                      "Cancel Booking",
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _Brand.accent,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      shadowColor: _Brand.accent.withOpacity(
                                        .25,
                                      ),
                                      elevation: 4,
                                      minimumSize: const Size(0, 48),
                                    ),
                                    onPressed: () => _cancelBooking(data),
                                  ),
                          ),
                        ],
                      ),

                    if (isCheckedIn)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          "Checked-in bookings cannot be modified or cancelled.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.black87, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// 顶部通知（保持不变）
class SlideTransitionNotification extends StatefulWidget {
  final InfoMessage message;
  const SlideTransitionNotification({super.key, required this.message});

  @override
  State<SlideTransitionNotification> createState() =>
      _SlideTransitionNotificationState();
}

class _SlideTransitionNotificationState
    extends State<SlideTransitionNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: const Offset(0, 0),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _offsetAnimation,
      child: GestureDetector(
        onTap: () {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const AppShell(initialIndex: 3)),
            (route) => false,
          );
        },
        child: Material(
          color: _Brand.accent,
          elevation: 6,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: const [
                Icon(Icons.notifications_active, color: Colors.white),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "New Message",
                    style: TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
