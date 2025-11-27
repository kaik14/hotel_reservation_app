import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hotel_reservation_app/pages/booking_edit_page.dart';

// ✅✅✅ Using the CORRECT Notification Widget ✅✅✅
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


class _Brand {
  static const bg = Color.fromARGB(255, 222, 228, 236);
  static const bar = Color(0xFF0F1722);
  static const accent = Color.fromARGB(255, 49, 59, 83);
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

  // ✅✅✅ Using the CORRECT Refund Logic ✅✅✅
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
      
      if(mounted) Navigator.of(context).pop();

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
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!snapshot.data!.exists) {
          return const Scaffold(body: Center(child: Text("Booking has been removed.")));
        }
        final data = snapshot.data!.data() as Map<String, dynamic>;
        return _buildDetailUI(context, data);
      },
    );
  }

  Widget _buildDetailUI(BuildContext context, Map<String, dynamic> data) {
     final checkIn = (data['checkIn'] as Timestamp?)?.toDate();
     final isCheckedIn = checkIn != null && checkIn.isBefore(DateTime.now());

    // Re-declaring all the variables from the original code to ensure correctness
    final price = data['priceText'] ?? "RM -";
    final desc = data['description'] ?? data['roomDesc'] ?? "per night";
    final imageName = data['imageName'] ?? "${data['roomTypeId']}.jpg";
    final imagePath = "assets/rooms/$imageName";
    final checkOut = (data['checkOut'] as Timestamp?)?.toDate();
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final guests = data['guests'] ?? 1;
    final roomNo = data['roomNo'] ?? '-';
    final title = data['roomTypeTitle'] ?? 'Room';
    final nights = data['nights'] ?? (checkIn != null && checkOut != null ? checkOut.difference(checkIn).inDays : 1);
    final dateFmt = DateFormat('dd MMM yyyy');
    final createdFmt = DateFormat('dd MMM yyyy – HH:mm');
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: _Brand.bg,
      appBar: AppBar(
        backgroundColor: _Brand.bar,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 8,
        toolbarHeight: 97,
        systemOverlayStyle: SystemUiOverlayStyle(
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Booking Details', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
            SizedBox(height: 4),
            Text('Review and manage your reservation.', style: TextStyle(color: Color(0x99FFFFFF), fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        height: 75 + bottomSafe,
        decoration: const BoxDecoration(color: _Brand.bar),
      ),
       body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, 
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.asset(imagePath, height: 220, width: double.infinity, fit: BoxFit.cover),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, 
                  children: [
                    Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(price, style: const TextStyle(fontSize: 15, color: Colors.grey)),
                    const SizedBox(height: 10),
                    if (desc.isNotEmpty) Text(desc, style: const TextStyle(fontSize: 15, height: 1.5)),
                    const SizedBox(height: 14),
                    _infoRow("Room No", roomNo),
                    _infoRow("Guests", "$guests"),
                    _infoRow("Check-in", checkIn != null ? dateFmt.format(checkIn) : "-"),
                    _infoRow("Check-out", checkOut != null ? dateFmt.format(checkOut) : "-"),
                    _infoRow("Nights", "$nights"),
                    _infoRow("Created", createdAt != null ? createdFmt.format(createdAt) : "-"),
                    const SizedBox(height: 20),
                    if (!isCheckedIn)
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.edit_calendar_outlined, color: Colors.white),
                              label: const Text("Edit Booking", style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _Brand.accent,
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                shadowColor: _Brand.accent.withOpacity(.25),
                                elevation: 4,
                                minimumSize: const Size(0, 48),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => BookingEditPage(bookingId: widget.bookingId, data: data),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                                    icon: const Icon(Icons.cancel_outlined, color: Colors.white),
                                    label: const Text("Cancel Booking", style: TextStyle(color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red[700], 
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      elevation: 4,
                                      minimumSize: const Size(0, 48),
                                    ),
                                    onPressed: () {
                                        showDialog(
                                        context: context,
                                        builder: (BuildContext dialogContext) {
                                          return AlertDialog(
                                            title: const Text('Confirm Cancellation'),
                                            content: const Text('Are you sure you want to cancel this booking?'),
                                            actions: <Widget>[
                                              TextButton(
                                                child: const Text('Back'),
                                                onPressed: () => Navigator.of(dialogContext).pop(),
                                              ),
                                              TextButton(
                                                child: const Text('Confirm', style: TextStyle(color: Colors.red)),
                                                onPressed: () {
                                                  Navigator.of(dialogContext).pop();
                                                  _handleCancelBooking(widget.bookingId, checkIn!);
                                                },
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },
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
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          Text(value, style: const TextStyle(color: Colors.black87, fontSize: 14)),
        ],
      ),
    );
  }
}
