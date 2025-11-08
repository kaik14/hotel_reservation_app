// booking_edit_page.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hotel_reservation_app/data/info_data.dart';
import 'package:hotel_reservation_app/app_shell.dart';

class BookingEditPage extends StatefulWidget {
  final String bookingId;
  final Map<String, dynamic> data;

  const BookingEditPage({
    super.key,
    required this.bookingId,
    required this.data,
  });

  @override
  State<BookingEditPage> createState() => _BookingEditPageState();
}

class _BookingEditPageState extends State<BookingEditPage> {
  DateTime? _checkIn;
  DateTime? _checkOut;
  int _guests = 1;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _checkIn = (widget.data['checkIn'] as Timestamp?)?.toDate();
    _checkOut = (widget.data['checkOut'] as Timestamp?)?.toDate();
    _guests = widget.data['guests'] ?? 1;
  }

  Future<void> _pickDate(bool isCheckIn) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isCheckIn ? _checkIn : _checkOut) ?? now,
      firstDate: now,
      lastDate: DateTime(2026, 12, 31),
    );

    if (picked == null) return;

    setState(() {
      if (isCheckIn) {
        _checkIn = picked;
        if (_checkOut != null && !_checkOut!.isAfter(picked)) {
          _checkOut = picked.add(const Duration(days: 1));
        }
      } else {
        _checkOut = picked;
      }
    });
  }

  // ✅ 保存修改
  Future<void> _saveChanges() async {
    if (_checkIn == null || _checkOut == null) return;

    setState(() => _saving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in.");

      // ✅ 更新用户 booking
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('bookings')
          .doc(widget.bookingId)
          .update({
        'checkIn': Timestamp.fromDate(_checkIn!),
        'checkOut': Timestamp.fromDate(_checkOut!),
        'guests': _guests,
      });

      // ✅ 创建通知内容
      final msg = InfoMessage(
        title: "Booking Updated",
        message:
            "Your booking has been updated.\nNew date: ${DateFormat('dd MMM').format(_checkIn!)} -- ${DateFormat('dd MMM').format(_checkOut!)}\nGuests: $_guests",
        senderIcon: 'system',
        timestamp: DateTime.now(),
      );

      // ✅ 写入用户自己的 messages
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('messages')
          .add({
        'title': msg.title,
        'message': msg.message,
        'senderIcon': msg.senderIcon,
        'timestamp': Timestamp.fromDate(msg.timestamp),
      });

      // ✅ 显示蓝色通知（OverlayEntry，不受页面跳转影响）
      _showTopNotification(context, msg);

      Navigator.pop(context, true);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// ✅ 蓝色系统通知
  void _showTopNotification(BuildContext context, InfoMessage message) {
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => Positioned(
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

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd MMM yyyy');

    final imageName = widget.data['imageName'];
    final roomTypeId = widget.data['roomTypeId'] ?? "default";
    final imagePath = "assets/rooms/${imageName ?? "$roomTypeId.jpg"}";

    final title = widget.data['roomTypeTitle'] ?? 'Room';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Booking"),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                imagePath,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),

            Text(title,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            _dateField("Check-in", _checkIn, () => _pickDate(true), dateFmt),
            const SizedBox(height: 10),
            _dateField("Check-out", _checkOut, () => _pickDate(false), dateFmt),

            const SizedBox(height: 20),
            const Text("Guests",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("$_guests Guest${_guests > 1 ? 's' : ''}",
                    style: const TextStyle(fontSize: 15)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed:
                          _guests > 1 ? () => setState(() => _guests--) : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => setState(() => _guests++),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _saving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Save Changes",
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateField(
      String label, DateTime? date, VoidCallback onTap, DateFormat fmt) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
              date != null ? fmt.format(date) : "Select Date",
              style: const TextStyle(color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }
}

/// ✅ 蓝色通知浮层组件
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
              builder: (_) => const AppShell(initialIndex: 3), // ✅ 跳 Info 页面
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
