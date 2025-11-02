import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hotel_reservation_app/data/booking_data.dart';

class BookingPage extends StatelessWidget {
  const BookingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('My Bookings'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          color: Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),

      // ✅ 主体内容
      body: bookingList.isEmpty
          ? const Center(
              child: Text(
                'No bookings yet.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: bookingList.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final booking = bookingList[index];
                final now = DateTime.now();
                final formatter = DateFormat('dd MMM yyyy');
                final checkInParsed = formatter.parse(booking.checkIn);
                final today = DateTime(now.year, now.month, now.day);

                // ✅ 动态判断订单状态
                String status;
                Color bgColor;
                Color textColor;

                if (checkInParsed.isBefore(today)) {
                  status = "Checked In";
                  bgColor = Colors.green[100]!;
                  textColor = Colors.green[800]!;
                } else if (checkInParsed.isAtSameMomentAs(today)) {
                  status = "Check-in Today";
                  bgColor = Colors.blue[100]!;
                  textColor = Colors.blue[800]!;
                } else {
                  status = "Upcoming";
                  bgColor = Colors.orange[100]!;
                  textColor = Colors.orange[800]!;
                }

                // ✅ 可点击的订单卡片
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BookingDetailPage(booking: booking),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
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
                    child: Row(
                      children: [
                        // 房间图片
                        ClipRRect(
                          borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(16)),
                          child: Image.network(
                            booking.imageUrl,
                            height: 100,
                            width: 120,
                            fit: BoxFit.cover,
                          ),
                        ),

                        // 文字内容
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  booking.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
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
                                const SizedBox(height: 10),

                                // ✅ 状态标签
                                Align(
                                  alignment: Alignment.centerRight,
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
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// -------------------- 📄 订单详情页 --------------------
class BookingDetailPage extends StatelessWidget {
  final Booking booking;
  const BookingDetailPage({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd MMM yyyy');
    final now = DateTime.now();
    final checkInParsed = formatter.parse(booking.checkIn);
    final today = DateTime(now.year, now.month, now.day);

    String status;
    Color bgColor;
    Color textColor;

    if (checkInParsed.isBefore(today)) {
      status = "Checked In";
      bgColor = Colors.green[100]!;
      textColor = Colors.green[800]!;
    } else if (checkInParsed.isAtSameMomentAs(today)) {
      status = "Check-in Today";
      bgColor = Colors.blue[100]!;
      textColor = Colors.blue[800]!;
    } else {
      status = "Upcoming";
      bgColor = Colors.orange[100]!;
      textColor = Colors.orange[800]!;
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Booking Details'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          color: Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
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
              // 房间图片
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.network(
                  booking.imageUrl,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      booking.price,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Check-in Date:",
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        Text(booking.checkIn),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Check-out Date:",
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        Text(booking.checkOut),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Guests:",
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        Text("${booking.guests}"),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Thank you for choosing our service. We wish you a pleasant stay!",
                      style: TextStyle(color: Colors.black87, height: 1.5),
                      textAlign: TextAlign.center,
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
}
