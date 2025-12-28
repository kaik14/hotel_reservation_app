import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hotel_reservation_app/pages/generate_report_Page.dart';
import 'package:hotel_reservation_app/pages/manage_employees_Page.dart';
import 'package:hotel_reservation_app/pages/room_statu_Page.dart';
import 'package:hotel_reservation_app/pages/task_status_page.dart';
// import 'package:hotel_reservation_app/pages/service_status_Page.dart'; // 👈 这一行也可以删掉了

import 'package:hotel_reservation_app/services/auth_service.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  final Color brandColor = const Color(0xFF313B53);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 222, 228, 236),
      appBar: AppBar(
        title: const Text('Hotel Ease/Admin'),
        centerTitle: true,
        backgroundColor: brandColor,
        automaticallyImplyLeading: false,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await AuthService().signOut();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ✅ 统计数据区域
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collectionGroup('bookings').snapshots(),
            builder: (context, snapshot) {
              int totalBookings = 0;
              double totalRevenue = 0.0;

              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                final docs = snapshot.data!.docs;
                totalBookings = docs.length;

                for (var doc in docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  var rawAmount = data['totalAmount'] ?? data['totalPrice'] ?? data['price'];
                  
                  double amountInRM = 0.0;

                  if (rawAmount != null) {
                    double val = 0.0;
                    if (rawAmount is num) {
                      val = rawAmount.toDouble();
                    } else if (rawAmount is String) {
                      val = double.tryParse(rawAmount) ?? 0.0;
                    }

                    if (data.containsKey('totalAmount')) {
                       amountInRM = val / 100.0;
                    } else {
                       amountInRM = val;
                    }
                  }
                  totalRevenue += amountInRM;
                }
              }

              return Container(
                margin: const EdgeInsets.only(left: 16, right: 16, top: 20),
                child: Row(
                  children: [
                    // --- 左边方块: Total Bookings ---
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: brandColor,
                            borderRadius: const BorderRadius.all(Radius.circular(10)),
                            boxShadow: [
                              BoxShadow(color: brandColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
                            ],
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.receipt_long, color: Colors.white70, size: 28),
                              const Spacer(),
                              const Text('Total Bookings', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 8),
                              Text('$totalBookings', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // --- 右边方块: Total Revenue ---
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: brandColor,
                            borderRadius: const BorderRadius.all(Radius.circular(10)),
                            boxShadow: [
                              BoxShadow(color: brandColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
                            ],
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.attach_money, color: Colors.white70, size: 28),
                              const Spacer(),
                              const Text('Total Revenue', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 8),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'RM${totalRevenue.toStringAsFixed(0)}', 
                                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // --- 导航按钮区域 ---
          _buildNavButton(context, 'Room Status', () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const RoomStatuPage()));
          }),
          _buildNavButton(context, 'Manage Employees', () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageEmployeesPage()));
          }),
          _buildNavButton(context, 'Task Status', () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const TaskStatusPage()));
          }),
          // ❌ 已删除 Service Status 按钮
          _buildNavButton(context, 'Generate Report', () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const GenerateReportPage()));
          }, isLast: true),
        ],
      ),
    );
  }

  Widget _buildNavButton(BuildContext context, String title, VoidCallback onTap, {bool isLast = false}) {
    return Container(
      margin: EdgeInsets.only(left: 16, right: 16, top: 20, bottom: isLast ? 20 : 0),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: brandColor,
          minimumSize: const Size(double.infinity, 70),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.bold)),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}