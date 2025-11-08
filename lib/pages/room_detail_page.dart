import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:hotel_reservation_app/data/booking_data.dart';
import 'package:hotel_reservation_app/data/info_data.dart';
import 'package:hotel_reservation_app/pages/booking_success_page.dart';

class RoomDetailPage extends StatefulWidget {
  final String docId;
  final String title;
  final String imageUrl;
  final String price;
  final String description;
  final String imageName;

  final DateTime? initialCheckIn;
  final DateTime? initialCheckOut;

  const RoomDetailPage({
    super.key,
    required this.docId,
    required this.title,
    required this.imageUrl,
    required this.price,
    required this.description,
    required this.imageName,
    this.initialCheckIn,
    this.initialCheckOut,
  });

  @override
  State<RoomDetailPage> createState() => _RoomDetailPageState();
}

class _RoomDetailPageState extends State<RoomDetailPage> {
  DateTime? checkInDate;
  DateTime? checkOutDate;
  int guests = 1;

  List<String> availableRooms = [];
  String? selectedRoom;

  final DateFormat _isoDay = DateFormat('yyyy-MM-dd');
  final DateFormat _uiFmt = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    checkInDate = widget.initialCheckIn;
    checkOutDate = widget.initialCheckOut;

    if (checkInDate != null && checkOutDate != null) {
      _filterAvailableRooms();
    }
  }

  Future<void> _filterAvailableRooms() async {
    if (checkInDate == null || checkOutDate == null) {
      setState(() {
        availableRooms = [];
        selectedRoom = null;
      });
      return;
    }

    final snap = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.docId)
        .get();

    if (!snap.exists) return;

    final data = snap.data();
    final List<dynamic> rooms = data?['rooms'] ?? [];
    final List<String> free = [];

    for (final r in rooms) {
      final String roomNo = (r['roomNo'] ?? '').toString();
      final List<dynamic> bookedRaw = List.from(r['bookedDates'] ?? []);
      final Set<String> booked = bookedRaw.map((e) => e.toString()).toSet();

      bool overlap = false;
      DateTime d = checkInDate!;
      while (!d.isAfter(checkOutDate!.subtract(const Duration(days: 1)))) {
        if (booked.contains(_isoDay.format(d))) {
          overlap = true;
          break;
        }
        d = d.add(const Duration(days: 1));
      }

      if (!overlap) free.add(roomNo);
    }

    setState(() {
      availableRooms = free;
      selectedRoom = free.isNotEmpty ? free.first : null;
    });
  }

  Future<void> _selectDate(BuildContext context, bool isCheckIn) async {
    final today = DateTime.now();
    DateTime initial = today;
    DateTime first = today;

    if (!isCheckIn && checkInDate != null) {
      first = checkInDate!.add(const Duration(days: 1));
      initial = first;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime(2026, 12, 31),
    );

    if (picked == null) return;

    setState(() {
      if (isCheckIn) {
        checkInDate = picked;
        if (checkOutDate == null ||
            !checkOutDate!.isAfter(checkInDate!)) {
          checkOutDate = checkInDate!.add(const Duration(days: 1));
        }
      } else {
        checkOutDate = picked;
      }
    });

    await _filterAvailableRooms();
  }

  /// ✅ Confirm Booking
  Future<void> _confirmBooking() async {
    if (checkInDate == null || checkOutDate == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Please select dates.")));
      return;
    }
    if (selectedRoom == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("No rooms available.")));
      return;
    }

    final docRef =
        FirebaseFirestore.instance.collection('rooms').doc(widget.docId);

    try {
      // ✅ Reserve Room (Transaction)
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (!snap.exists) throw Exception("Room type not found.");

        final data = snap.data() as Map<String, dynamic>;
        final List<dynamic> rooms = List.from(data['rooms'] ?? []);

        final idx = rooms.indexWhere(
            (r) => (r['roomNo'] ?? '').toString() == selectedRoom);

        if (idx < 0) throw Exception("Room not found.");

        final Map<String, dynamic> room = Map<String, dynamic>.from(rooms[idx]);

        final Set<String> booked = Set<String>.from(
          List.from(room['bookedDates'] ?? []).map((e) => e.toString()),
        );

        final List<String> toAdd = [];
        DateTime d = checkInDate!;
        while (!d.isAfter(checkOutDate!.subtract(const Duration(days: 1)))) {
          final key = _isoDay.format(d);
          if (booked.contains(key)) throw Exception("Room just booked.");
          toAdd.add(key);
          d = d.add(const Duration(days: 1));
        }

        booked.addAll(toAdd);

        room['bookedDates'] = booked.toList()..sort();
        rooms[idx] = room;

        tx.update(docRef, {'rooms': rooms});
      });

      final nights = checkOutDate!.difference(checkInDate!).inDays;

      // ✅ ✅ Save booking to users/{uid}/bookings
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('bookings')
            .add({
          'roomTypeId': widget.docId,
          'roomTypeTitle': widget.title,
          'roomNo': selectedRoom,
          'priceText': widget.price,
          'description': widget.description,
          'guests': guests,
          'checkIn': checkInDate,
          'checkOut': checkOutDate,
          'nights': nights,
          'imageName': widget.imageName,
          'createdAt': Timestamp.fromDate(DateTime.now()),
        });
      }

      // ✅ System Push Message
      final newMsg = InfoMessage(
        title: "Booking Confirmed",
        message:
            "Your booking for ${widget.title} is confirmed.\nStay: ${_uiFmt.format(checkInDate!)} -- ${_uiFmt.format(checkOutDate!)}\nRoom: $selectedRoom",
        senderIcon: "system",
        timestamp: DateTime.now(),
      );

      // ✅ Save message to users/{uid}/messages
      if (currentUser != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('messages')
            .add({
          'title': newMsg.title,
          'message': newMsg.message,
          'senderIcon': newMsg.senderIcon,
          'timestamp': Timestamp.fromDate(newMsg.timestamp),
        });
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => BookingSuccessPage(message: newMsg)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
      _filterAvailableRooms();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/rooms/${widget.imageName}',
                width: double.infinity,
                height: 240,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),

            Text(widget.title,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            Text(widget.price,
                style: const TextStyle(fontSize: 15, color: Colors.grey)),
            const SizedBox(height: 10),

            Text(widget.description,
                style: const TextStyle(fontSize: 15, height: 1.5)),
            const SizedBox(height: 24),

            const Text("Booking Details",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildRow("Check-in", _formatDate(checkInDate),
                      () => _selectDate(context, true)),
                  const Divider(),
                  _buildRow("Check-out", _formatDate(checkOutDate),
                      () => _selectDate(context, false)),
                  const Divider(),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Guests",
                          style: TextStyle(fontWeight: FontWeight.w500)),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: guests > 1
                                ? () => setState(() => guests--)
                                : null,
                          ),
                          Text('$guests',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () => setState(() => guests++),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const Divider(),

                  if (checkInDate != null && checkOutDate != null)
                    DropdownButtonFormField<String>(
                      value: selectedRoom,
                      hint: const Text("Select Room"),
                      items: availableRooms
                          .map((r) => DropdownMenuItem(
                                value: r,
                                child: Text("Room $r"),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => selectedRoom = v),
                    ),

                  if (checkInDate == null || checkOutDate == null)
                    const Text("Please choose dates.",
                        style: TextStyle(color: Colors.grey)),

                  if (checkInDate != null &&
                      checkOutDate != null &&
                      availableRooms.isEmpty)
                    const Text("No rooms available.",
                        style: TextStyle(color: Colors.redAccent)),
                ],
              ),
            ),

            const SizedBox(height: 22),

            GestureDetector(
              onTap: _confirmBooking,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    colors: [
                      Color.fromARGB(255, 0, 0, 0),
                      Color.fromARGB(255, 0, 0, 0),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFFB9A9FF).withOpacity(0.4),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    "Confirm Booking",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(value, style: const TextStyle(color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? d) =>
      d == null ? "Select date" : _uiFmt.format(d);
}
