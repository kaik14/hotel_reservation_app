import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hotel_reservation_app/data/booking_data.dart';
import 'package:hotel_reservation_app/pages/booking_detail_page.dart';
import 'package:hotel_reservation_app/pages/room_detail_page.dart';
import 'package:flutter/services.dart';

// —— 统一配色 —— //
class _Brand {
  static const bg = Color.fromARGB(255, 222, 228, 236); // 浅蓝灰背景
  static const bar = Color(0xFF0F1722); // 顶栏深色
  static const accent = Color.fromARGB(255, 49, 59, 83); // 品牌按钮色
}

class BookingPage extends StatelessWidget {
  const BookingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text("Not logged in")));
    }

    /// ✅ 只看当前用户的 bookings
    final CollectionReference bookingsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('bookings');

    return Scaffold(
      backgroundColor: _Brand.bg,

      // —— 深色 AppBar（97px），与全站一致 —— //
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
              'Review your stays at a glance.',
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

      // ✅ 不再有 bottomNavigationBar
      body: StreamBuilder<QuerySnapshot>(
        stream: bookingsRef.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No bookings yet.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final docs = snapshot.data!.docs;
          final dateFmt = DateFormat('dd MMM yyyy');

          return ListView.builder(
            itemCount: docs.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;

              final title = data['roomTypeTitle'] ?? 'Unknown';
              final imageName =
                  data['imageName'] ?? "${data['roomTypeId']}.jpg";
              final image = "assets/rooms/$imageName";

              final checkIn = (data['checkIn'] as Timestamp?)?.toDate();
              final checkOut = (data['checkOut'] as Timestamp?)?.toDate();
              final guests = data['guests'] ?? 1;
              final price = data['priceText'] ?? "RM-";
              final roomNo = data['roomNo'] ?? '-';
              final roomTypeId = data['roomTypeId'] ?? '';

              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);

              // ✅ 状态计算（原逻辑）
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
                        bookingId: docs[index].id,
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
                          // 房图
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
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      // 右下角：状态 + Rebook
                      Positioned(
                        right: 12,
                        bottom: 10,
                        child: Row(
                          children: [
                            Container(
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
                            const SizedBox(width: 8),
                            if (status == "Checked In")
                              GestureDetector(
                                onTap: () {
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
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
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

  /// 本地备份列表（未变）
  Widget _buildLocalBookingList(BuildContext context) {
    final formatter = DateFormat('dd MMM yyyy');

    return ListView.builder(
      itemCount: bookingList.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final booking = bookingList[index];
        final now = DateTime.now();
        final checkInParsed = formatter.parse(booking.checkIn);
        final today = DateTime(now.year, now.month, now.day);

        String status;
        Color bgColor;
        Color textColor;

        if (!checkInParsed.isAfter(today)) {
          status = "Checked In";
          bgColor = Colors.green[100]!;
          textColor = Colors.green[800]!;
        } else {
          status = "Not Checked In";
          bgColor = Colors.orange[100]!;
          textColor = Colors.orange[800]!;
        }

        return Container(
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
                      booking.imageUrl,
                      height: 100,
                      width: 120,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              letterSpacing: .1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "${booking.checkIn} → ${booking.checkOut}",
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Guests: ${booking.guests}",
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

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
        );
      },
    );
  }
}
