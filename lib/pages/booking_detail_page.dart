// ✅ 完整版 booking_detail_page.dart （可直接复制）
// ✅ 支持：Edit 后立即刷新、Cancel 后立即返回、系统推送正常

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hotel_reservation_app/data/info_data.dart';
import 'package:hotel_reservation_app/pages/booking_edit_page.dart';
import 'package:hotel_reservation_app/app_shell.dart';

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

  /// ✅ 顶部系统通知
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

    Future.delayed(const Duration(seconds: 5), () {
      entry.remove();
    });
  }

  /// ✅ 取消预定（立即回滚房间 & 删除用户 booking）
  Future<void> _cancelBooking(Map<String, dynamic> data) async {
    final docId = data['roomTypeId'];
    final roomNo = data['roomNo'];
    final checkIn = (data['checkIn'] as Timestamp).toDate();
    final checkOut = (data['checkOut'] as Timestamp).toDate();
    final isoFmt = DateFormat('yyyy-MM-dd');

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Cancel Booking"),
        content: const Text("Are you sure you want to cancel this booking?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("No"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Yes, Cancel"),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    setState(() => _isCancelling = true);

    try {
      final roomDoc =
          FirebaseFirestore.instance.collection('rooms').doc(docId);

      // ✅ 回滚房型 bookedDates
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(roomDoc);
        if (!snap.exists) return;

        final raw = snap.data() as Map<String, dynamic>;
        final List<dynamic> rooms = List.from(raw['rooms'] ?? []);

        final idx = rooms.indexWhere(
            (r) => (r['roomNo'] ?? '').toString() == roomNo.toString());
        if (idx < 0) return;

        final Map<String, dynamic> room =
            Map<String, dynamic>.from(rooms[idx]);
        final List<String> booked =
            List<String>.from(room['bookedDates'] ?? []);

        DateTime d = checkIn;
        while (!d.isAfter(checkOut.subtract(const Duration(days: 1)))) {
          booked.remove(isoFmt.format(d));
          d = d.add(const Duration(days: 1));
        }

        room['bookedDates'] = booked;
        rooms[idx] = room;

        tx.update(roomDoc, {'rooms': rooms});
      });

      /// ✅ 删除用户 booking
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('bookings')
            .doc(widget.bookingId)
            .delete();
      }

      /// ✅ 系统推送
      final cancelMsg = InfoMessage(
        title: "Booking Cancelled",
        message:
            "Your booking for ${data['roomTypeTitle']} (Room $roomNo) has been cancelled.",
        senderIcon: 'system',
        timestamp: DateTime.now(),
      );

      if (!mounted) return;

      _showTopNotification(context, cancelMsg);

      /// ✅ 删除后立即返回 Booking 列表
      Navigator.pop(context);

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  // ✅ ✅ ✅ StreamBuilder：实时监听 Booking（解决 Edit 后不刷新）
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Not logged in")),
      );
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
          return const Scaffold(
            body: Center(child: Text("Booking removed")),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;

        return _buildDetailUI(context, data);
      },
    );
  }

  // ✅ 你的原始 UI 全部移到这里（保持不变）
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

    final nights = data['nights'] ??
        (checkIn != null && checkOut != null
            ? checkOut.difference(checkIn).inDays
            : 1);

    final dateFmt = DateFormat('dd MMM yyyy');
    final createdFmt = DateFormat('dd MMM yyyy – HH:mm');

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isCheckedIn = checkIn != null && checkIn.isBefore(today);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Booking Details'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.asset(
                  imagePath,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),

              /// ✅ ========== 内容（你的 UI 原样保留）==========
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),

                    Text(price,
                        style:
                            const TextStyle(fontSize: 15, color: Colors.grey)),
                    const SizedBox(height: 10),

                    if (desc.isNotEmpty)
                      Text(desc,
                          style: const TextStyle(fontSize: 15, height: 1.5)),
                    const SizedBox(height: 14),

                    _infoRow("Room No", roomNo),
                    _infoRow("Guests", "$guests"),
                    _infoRow("Check-in",
                        checkIn != null ? dateFmt.format(checkIn) : "-"),
                    _infoRow("Check-out",
                        checkOut != null ? dateFmt.format(checkOut) : "-"),
                    _infoRow("Nights", "$nights"),
                    _infoRow(
                        "Created",
                        createdAt != null
                            ? createdFmt.format(createdAt)
                            : "-"),

                    const SizedBox(height: 24),

                    Center(
                      child: isCheckedIn
                          ? const Text(
                              "Checked-in bookings cannot be modified or cancelled.",
                              style: TextStyle(color: Colors.grey),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton.icon(
                                  icon: const Icon(
                                      Icons.edit_calendar_outlined,
                                      color: Colors.white),
                                  label: const Text("Edit Booking",
                                      style: TextStyle(color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        const Color.fromARGB(255, 159, 207, 246),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 22, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => BookingEditPage(
                                          bookingId: widget.bookingId,
                                          data: data, // ✅ 最新数据
                                        ),
                                      ),
                                    );
                                  },
                                ),

                                const SizedBox(width: 12),

                                _isCancelling
                                    ? const CircularProgressIndicator(
                                        color: Colors.redAccent)
                                    : ElevatedButton.icon(
                                        icon: const Icon(
                                            Icons.cancel_outlined,
                                            color: Colors.white),
                                        label: const Text("Cancel Booking",
                                            style:
                                                TextStyle(color: Colors.white)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color.fromARGB(255, 229, 179, 179),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 22, vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                        ),
                                        onPressed: () => _cancelBooking(data),
                                      ),
                              ],
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
          Text(label,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
          Text(value,
              style: const TextStyle(color: Colors.black87, fontSize: 14)),
        ],
      ),
    );
  }
}

/// ✅ 顶部蓝色推送（点击跳 Info Page）
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
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

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
            MaterialPageRoute(
              builder: (_) => const AppShell(initialIndex: 3),
            ),
            (route) => false,
          );
        },
        child: Material(
          color: Colors.blueAccent,
          elevation: 6,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(Icons.notifications_active, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "New Message: ${widget.message.title}",
                    style: const TextStyle(color: Colors.white, fontSize: 15),
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
