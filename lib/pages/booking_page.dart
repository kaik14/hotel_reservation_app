import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hotel_reservation_app/pages/booking_detail_page.dart';
import 'package:hotel_reservation_app/pages/room_detail_page.dart';
import 'package:flutter/services.dart';

class _Brand {
  static const bg = Color.fromARGB(255, 222, 228, 236);
  static const bar = Color(0xFF0F1722);
  static const accent = Color.fromARGB(255, 49, 59, 83);
}

class BookingPage extends StatefulWidget {
  const BookingPage({super.key});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {

  Future<void> _handleCancelBooking(String bookingId, DateTime checkInDate) async {
    final now = DateTime.now();
    if (now.isAfter(checkInDate.subtract(const Duration(hours: 24)))) {
      _showTopNotification("Cancellation failed: You can only cancel up to 24 hours before check-in.", Colors.red);
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('bookings')
          .doc(bookingId)
          .delete();

      _showTopNotification("Booking cancelled and refund processed successfully.", Colors.green);

    } catch (e) {
      _showTopNotification("An error occurred while cancelling: $e", Colors.red);
    }
  }

  void _showTopNotification(String message, Color color) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 50,
        left: 20,
        right: 20,
        child: SlideTransitionNotification(message: message, color: color),
      ),
    );

    overlay.insert(overlayEntry);

    Future.delayed(const Duration(seconds: 4), () {
      overlayEntry.remove();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text("Not logged in")));
    }

    final CollectionReference bookingsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('bookings');

    return Scaffold(
      backgroundColor: _Brand.bg,
      appBar: AppBar(
        backgroundColor: _Brand.bar,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        toolbarHeight: 97,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: _Brand.bar,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('My Bookings', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
            SizedBox(height: 4),
            Text('Review your stays at a glance.', style: TextStyle(color: Color(0x99FFFFFF), fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: Colors.white.withOpacity(0.08)),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: bookingsRef.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No bookings yet.', style: TextStyle(fontSize: 16, color: Colors.grey)));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;

              final title = data['roomTypeTitle'] ?? 'Unknown';
              final imageName = data['imageName'] ?? "${data['roomTypeId']}.jpg";
              final image = "assets/rooms/$imageName";
              final checkIn = (data['checkIn'] as Timestamp?)?.toDate();
              final checkOut = (data['checkOut'] as Timestamp?)?.toDate();
              final guests = data['guests'] ?? 1;
              final price = data['priceText'] ?? "RM-";
              final roomNo = data['roomNo'] ?? '-';
              final roomTypeId = data['roomTypeId'] ?? '';
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final dateFmt = DateFormat('dd MMM yyyy');

              // ✅✅✅ Restored Status Logic ✅✅✅
              String status;
              Color bgColor;
              Color textColor;

              if (checkIn == null) {
                status = "Pending";
                bgColor = Colors.grey[200]!;
                textColor = Colors.black54;
              } else if (checkIn.isBefore(today)) {
                status = "Checked In";
                bgColor = Colors.green[100]!;
                textColor = Colors.green[800]!;
              } else {
                status = "Not Checked In";
                bgColor = Colors.orange[100]!;
                textColor = Colors.orange[800]!;
              }

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BookingDetailPage(bookingId: doc.id, data: data),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8))],
                  ),
                  child: Stack(
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                            child: Image.asset(image, height: 100, width: 120, fit: BoxFit.cover),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: .1)),
                                  const SizedBox(height: 6),
                                  Text("${checkIn != null ? dateFmt.format(checkIn) : '?'} → ${checkOut != null ? dateFmt.format(checkOut) : '?'}", style: const TextStyle(fontSize: 13, color: Colors.black54)),
                                  const SizedBox(height: 4),
                                  Text("Room $roomNo • Guests: $guests", style: const TextStyle(fontSize: 13)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      Positioned(
                        right: 12,
                        bottom: 10,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
                              child: Text(status, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                            const SizedBox(width: 8),
                            if (status == "Not Checked In")
                              GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext dialogContext) {
                                      return AlertDialog(
                                        title: const Text('Confirm Cancellation'),
                                        content: const Text('Are you sure you want to cancel this booking? This action cannot be undone.'),
                                        actions: <Widget>[
                                          TextButton(child: const Text('Back'), onPressed: () => Navigator.of(dialogContext).pop()),
                                          TextButton(
                                            child: const Text('Confirm', style: TextStyle(color: Colors.red)),
                                            onPressed: () {
                                              Navigator.of(dialogContext).pop();
                                              _handleCancelBooking(doc.id, checkIn!);
                                            },
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(color: Colors.red[700], borderRadius: BorderRadius.circular(10)),
                                  child: const Text("Cancel", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ),
                            if (status == "Checked In")
  GestureDetector(
    onTap: () {
      // 从预订记录里取楼层，如果没有就默认 8F
      final String floorId = (data['floorId'] ?? '8F').toString();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RoomDetailPage(
            docId: roomTypeId,
            title: title,
            imageUrl: image,
            price: price,
            description: data['description'] ?? '',
            imageName: imageName,
            // 👇 必须补上这一行
            floorId: floorId,
            // 这里初始 check-in / out 随你要不要传，留空也可以：
            // initialCheckIn: checkIn,
            // initialCheckOut: checkOut,
          ),
        ),
      );
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _Brand.accent,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: _Brand.accent.withOpacity(0.22),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Text(
        "Rebook",
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
                          ),
                          ),

                              
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class SlideTransitionNotification extends StatefulWidget {
  final String message;
  final Color color;
  const SlideTransitionNotification({super.key, required this.message, required this.color});

  @override
  State<SlideTransitionNotification> createState() => _SlideTransitionNotificationState();
}

class _SlideTransitionNotificationState extends State<SlideTransitionNotification> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _offsetAnimation = Tween<Offset>(begin: const Offset(0, -1.5), end: const Offset(0, 0)).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _offsetAnimation,
      child: Material(
        color: widget.color,
        elevation: 6,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.notifications_active, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(widget.message, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600))),
            ],
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
