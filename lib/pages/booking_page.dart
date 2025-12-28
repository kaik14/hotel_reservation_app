import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

import 'package:hotel_reservation_app/pages/booking_detail_page.dart';
import 'package:hotel_reservation_app/pages/room_detail_page.dart';

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
  /// 浮动助手
  bool _showAssistant = true;
  Offset _assistantOffset = const Offset(16, 140);
  bool _initializedOffset = false;

  // =========================
  // 判定是否为 service booking
  // =========================
  bool _isServiceBooking(Map<String, dynamic> data) {
    final t = (data['bookingType'] ?? '').toString();
    return t == 'service' ||
        data.containsKey('serviceType') ||
        data.containsKey('serviceName');
  }

  // =========================
  // 计算 serviceStartAt（优先 serviceStart）
  // =========================
  TimeOfDay? _parseHHmm(String? s) {
    if (s == null) return null;
    final parts = s.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  DateTime? _serviceStartAt(Map<String, dynamic> data) {
    final ts = data['serviceStart'] as Timestamp?;
    if (ts != null) return ts.toDate();

    final dateTs = data['serviceDate'] as Timestamp?;
    final timeStr = data['serviceTime'] as String?;
    if (dateTs == null) return null;

    final d = dateTs.toDate();
    final tod = _parseHHmm(timeStr);
    if (tod == null) return null;

    return DateTime(d.year, d.month, d.day, tod.hour, tod.minute);
  }

  // =========================
  // serviceType -> 对应图片（✅ spa 和 dining 逻辑一样，只是 type 不同）
  // 你的 assets/services 里有：dining.jpg spa.jpg pool.jpg gym.jpg conference.jpg housekeeping.jpg laundry.jpg taxi.jpg
  // =========================
  String _serviceImageFromType(String type) {
    final t = type.trim().toLowerCase();
    const map = <String, String>{
      'dining': 'assets/services/dining.jpg',
      'spa': 'assets/services/spa.jpg',
      'pool': 'assets/services/pool.jpg',
      'gym': 'assets/services/gym.jpg',
      'conference': 'assets/services/conference.jpg',
      'housekeeping': 'assets/services/housekeeping.jpg',
      'laundry': 'assets/services/laundry.jpg',
      'taxi': 'assets/services/taxi.jpg',
    };
    return map[t] ?? 'assets/services/dining.jpg';
  }

  String _pickServiceImage(Map<String, dynamic> data) {
    final path = (data['serviceImagePath'] ?? '').toString().trim();
    if (path.isNotEmpty) return path;

    final serviceType = (data['serviceType'] ?? '').toString();
    return _serviceImageFromType(serviceType);
  }

  // =========================
  // 浮动助手（可拖动）
  // =========================
  Widget _buildFloatingAssistant(BuildContext context) {
    final size = MediaQuery.of(context).size;

    const double w = 150;
    const double h = 150;

    if (!_initializedOffset) {
      _assistantOffset = Offset(size.width - w - 6, 520);
      _initializedOffset = true;
    }

    final double left = _assistantOffset.dx.clamp(0.0, size.width - w);
    final double top = _assistantOffset.dy.clamp(
      0.0,
      size.height - h - MediaQuery.of(context).padding.top,
    );

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onPanUpdate: (d) => setState(() => _assistantOffset += d.delta),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Image.asset('assets/gifs/final5.gif', width: w, height: h),
            Positioned(
              right: 32,
              top: -6,
              child: GestureDetector(
                onTap: () => setState(() => _showAssistant = false),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.6),
                  ),
                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================
  // docs 前端按 createdAt 排序（没有 createdAt 的放后面）
  // =========================
  List<QueryDocumentSnapshot> _sortedDocs(List<QueryDocumentSnapshot> docs) {
    final list = [...docs];
    list.sort((a, b) {
      final ad = (a.data() as Map<String, dynamic>);
      final bd = (b.data() as Map<String, dynamic>);
      final at = (ad['createdAt'] as Timestamp?)?.toDate();
      final bt = (bd['createdAt'] as Timestamp?)?.toDate();

      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at); // newest first
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text("Not logged in")));
    }

    final bookingsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
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
            Text(
              'My Bookings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Review your reservations',
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
        child: Stack(
          children: [
            StreamBuilder<QuerySnapshot>(
              stream: bookingsRef.snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snap.hasData || snap.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No bookings yet.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                final docs = _sortedDocs(
                  snap.data!.docs.cast<QueryDocumentSnapshot>(),
                );

                return ListView.builder(
                  itemCount: docs.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final isService = _isServiceBooking(data);

                    // =========================
                    // ROOM card（✅只保留状态 badge + Rebook；不显示 Cancel）
                    // =========================
                    if (!isService) {
                      final title = (data['roomTypeTitle'] ?? 'Room')
                          .toString();
                      final imageName =
                          (data['imageName'] ?? "${data['roomTypeId']}.jpg")
                              .toString();
                      final image = "assets/rooms/$imageName";

                      final checkIn = (data['checkIn'] as Timestamp?)?.toDate();
                      final checkOut = (data['checkOut'] as Timestamp?)
                          ?.toDate();
                      final guests = data['guests'] ?? 1;
                      final roomNo = data['roomNo'] ?? '-';
                      final roomTypeId = (data['roomTypeId'] ?? '').toString();
                      final price = data['priceText'] ?? "RM-";

                      final now = DateTime.now();
                      final today = DateTime(now.year, now.month, now.day);
                      final dateFmt = DateFormat('dd MMM yyyy');

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
                              builder: (_) => BookingDetailPage(
                                bookingId: doc.id,
                                data: data,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
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
                          child: Stack(
                            children: [
                              Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.horizontal(
                                      left: Radius.circular(16),
                                    ),
                                    child: Image.asset(
                                      image,
                                      height: 100,
                                      width: 120,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 16,
                                              letterSpacing: .1,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            "${checkIn != null ? dateFmt.format(checkIn) : '?'} → ${checkOut != null ? dateFmt.format(checkOut) : '?'}",
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.black54,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "Room $roomNo • Guests: $guests",
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                          if (status == "Checked In")
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 6,
                                              ),
                                              child: GestureDetector(
                                                onTap: () {
                                                  final String floorId =
                                                      (data['floorId'] ?? '8F')
                                                          .toString();
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          RoomDetailPage(
                                                            docId: roomTypeId,
                                                            title: title,
                                                            imageUrl: image,
                                                            price: price,
                                                            description:
                                                                (data['description'] ??
                                                                        '')
                                                                    .toString(),
                                                            imageName:
                                                                imageName,
                                                            floorId: floorId,
                                                          ),
                                                    ),
                                                  );
                                                },
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 6,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: _Brand.accent,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: _Brand.accent
                                                            .withOpacity(0.22),
                                                        blurRadius: 10,
                                                        offset: const Offset(
                                                          0,
                                                          6,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  child: const Text(
                                                    "Rebook",
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // 状态 badge：右下角
                              Positioned(
                                right: 12,
                                bottom: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: bgColor,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    // =========================
                    // SERVICE card（✅ spa 和 dining 完全同逻辑：按 serviceType 显示图片与状态）
                    // =========================
                    final serviceType = (data['serviceType'] ?? '')
                        .toString()
                        .trim();

                    final String serviceName = (() {
                      final n = (data['serviceName'] ?? '').toString().trim();
                      if (n.isNotEmpty) return n;
                      if (serviceType.isNotEmpty) return serviceType;
                      return 'Service';
                    })();

                    final serviceImage = _pickServiceImage(data);

                    final serviceStart = _serviceStartAt(data);
                    final dateFmt = DateFormat('dd MMM yyyy');
                    final timeFmt = DateFormat('HH:mm');

                    final now = DateTime.now();
                    final bool isCompleted =
                        serviceStart != null && serviceStart.isBefore(now);

                    final String status = isCompleted
                        ? "Completed"
                        : "Upcoming";
                    final Color bgColor = isCompleted
                        ? Colors.green[100]!
                        : Colors.orange[100]!;
                    final Color textColor = isCompleted
                        ? Colors.green[800]!
                        : Colors.orange[800]!;

                    final String dateText = serviceStart == null
                        ? "?"
                        : dateFmt.format(serviceStart);
                    final String timeText = serviceStart == null
                        ? "Time?"
                        : timeFmt.format(serviceStart);

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BookingDetailPage(
                              bookingId: doc.id,
                              data: data,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
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
                        child: Stack(
                          children: [
                            Row(
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.horizontal(
                                    left: Radius.circular(16),
                                  ),
                                  child: Image.asset(
                                    serviceImage,
                                    height: 100,
                                    width: 120,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          serviceName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                            letterSpacing: .1,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          "$dateText • $timeText",
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.black54,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "Service: ${serviceType.isEmpty ? 'service' : serviceType}",
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // 状态 badge：右下角（不放 Cancel）
                            Positioned(
                              right: 12,
                              bottom: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: bgColor,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
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

            if (_showAssistant) _buildFloatingAssistant(context),

            if (!_showAssistant)
              Positioned(
                right: 16,
                bottom: 16,
                child: GestureDetector(
                  onTap: () => setState(() => _showAssistant = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _Brand.accent,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: _Brand.accent.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.pets, size: 16, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          'Assistant',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
