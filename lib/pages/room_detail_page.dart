import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hotel_reservation_app/data/booking_data.dart';
import 'package:hotel_reservation_app/data/info_data.dart';
import 'package:hotel_reservation_app/pages/booking_success_page.dart';

class RoomDetailPage extends StatefulWidget {
  final String title;
  final String imageUrl;
  final String price;

  const RoomDetailPage({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.price,
  });

  @override
  State<RoomDetailPage> createState() => _RoomDetailPageState();
}

class _RoomDetailPageState extends State<RoomDetailPage> {
  DateTime? checkInDate;
  DateTime? checkOutDate;
  int guests = 1;

  /// 格式化日期
  String _formatDate(DateTime? date) {
    if (date == null) return "Select date";
    return DateFormat('dd MMM yyyy').format(date);
  }

  /// 日期选择逻辑
  Future<void> _selectDate(BuildContext context, bool isCheckIn) async {
    final DateTime today = DateTime.now();
    final DateTime firstDate = isCheckIn
        ? today
        : (checkInDate != null ? checkInDate!.add(const Duration(days: 1)) : today);

    final DateTime initialDate = isCheckIn
        ? today
        : (checkInDate != null ? checkInDate!.add(const Duration(days: 1)) : today);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime(2026, 12),
    );

    if (picked != null) {
      setState(() {
        if (isCheckIn) {
          checkInDate = picked;
          if (checkOutDate == null || checkOutDate!.isBefore(picked)) {
            checkOutDate = picked.add(const Duration(days: 1));
          }
        } else {
          checkOutDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTabletOrPC = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.black,
          fontSize: isTabletOrPC ? 22 : 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                widget.imageUrl,
                width: double.infinity,
                height: isTabletOrPC ? 320 : 240,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),
            Text(widget.title,
                style: TextStyle(
                    fontSize: isTabletOrPC ? 22 : 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(widget.price,
                style: const TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 20),

            Text("Booking Details",
                style: TextStyle(
                    fontSize: isTabletOrPC ? 20 : 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            // --- 预定信息容器 ---
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Check-in:",
                          style: TextStyle(fontWeight: FontWeight.w500)),
                      TextButton(
                        onPressed: () => _selectDate(context, true),
                        child: Text(
                          _formatDate(checkInDate),
                          style: const TextStyle(color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Check-out:",
                          style: TextStyle(fontWeight: FontWeight.w500)),
                      TextButton(
                        onPressed: () => _selectDate(context, false),
                        child: Text(
                          _formatDate(checkOutDate),
                          style: const TextStyle(color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Guests:",
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
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text("Room Description",
                style: TextStyle(
                    fontSize: isTabletOrPC ? 20 : 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              "Enjoy a relaxing stay with modern comfort, natural views, and excellent service. "
              "Every room is designed for both comfort and convenience.",
              style: TextStyle(color: Colors.black87, height: 1.5),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),

      // --- 底部确认按钮 ---
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () {
              if (checkInDate == null || checkOutDate == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Please select check-in and check-out dates."),
                  ),
                );
              } else {
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                final checkIn =
                    DateTime(checkInDate!.year, checkInDate!.month, checkInDate!.day);

                // 根据日期判断状态
                bool isCheckedIn = checkIn.isBefore(today);
                bool isToday = checkIn.isAtSameMomentAs(today);

                String status = isCheckedIn
                    ? "Completed"
                    : isToday
                        ? "Check-in Today"
                        : "Upcoming";

                // ✅ 保存订单
                bookingList.add(
                  Booking(
                    title: widget.title,
                    imageUrl: widget.imageUrl,
                    price: widget.price,
                    checkIn: _formatDate(checkInDate),
                    checkOut: _formatDate(checkOutDate),
                    guests: guests,
                    isCheckedIn: isCheckedIn,
                  ),
                );

                // ✅ 添加消息（带 senderIcon）
                final newMsg = InfoMessage(
                  title: "Booking Confirmed",
                  message:
                      "Your booking for ${widget.title} is $status. Stay from ${_formatDate(checkInDate)} to ${_formatDate(checkOutDate)}.",
                  senderIcon: 'https://cdn-icons-png.flaticon.com/512/190/190411.png',
                  timestamp: DateTime.now(),
                );
                infoMessages.insert(0, newMsg);

                // ✅ 跳转动画页，并在动画页显示弹窗
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BookingSuccessPage(message: newMsg),
                  ),
                );
              }
            },
            child: const Text(
              'Confirm Booking',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }
}
