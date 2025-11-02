import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hotel_reservation_app/services/auth_service.dart';
import 'package:hotel_reservation_app/services/database_service.dart';

class ProfilePage extends StatelessWidget {
  ProfilePage({super.key});

  final User? currentUser = FirebaseAuth.instance.currentUser;
  final DatabaseService _db = DatabaseService();

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('用户未登录')));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: _db.getUserDataStream(currentUser!.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _buildProfileUI(
            context,
            currentUser!.email ?? 'No Email',
            'User',
            '',
            'N/A',
          );
        }

        Map<String, dynamic> userData =
            snapshot.data!.data() as Map<String, dynamic>;

        return _buildProfileUI(
          context,
          userData['email'] ?? 'No Email',
          userData['firstName'] ?? 'First',
          userData['lastName'] ?? 'Last',
          userData['phoneNumber'] ?? 'No Phone',
        );
      },
    );
  }

  // --- 主体 UI ---
  Widget _buildProfileUI(BuildContext context, String email, String firstName,
      String lastName, String phone) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, email, '$firstName $lastName'),
            const SizedBox(height: 30),

            _buildUserDetailsCard(phone, "123 Elm Street, Springfield"),
            const SizedBox(height: 30),

            _buildBookingHistory(),
            const SizedBox(height: 30),

            // ✅ 新增按钮：编辑偏好
            _buildEditPreferenceButton(context),
            const SizedBox(height: 20),

            _buildMessageHostButton(context),
          ],
        ),
      ),
    );
  }

  // --- 顶部用户信息头 ---
  Widget _buildHeader(BuildContext context, String email, String name) {
    return Row(
      children: [
        const CircleAvatar(
          radius: 30,
          backgroundColor: Color(0xFFE0E0E0),
          child: Icon(Icons.person, size: 30, color: Color(0xFF757575)),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              Text(
                email,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        TextButton(
          onPressed: () async {
            await AuthService().signOut();
          },
          style: TextButton.styleFrom(
            backgroundColor: const Color(0xFF212121),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: const Text("Logout"),
        ),
      ],
    );
  }

  // --- 用户详情卡片 ---
  Widget _buildUserDetailsCard(String phone, String address) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "User Details",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),
            Text("Phone: $phone"),
            const SizedBox(height: 8),
            Text("Address: $address"),
          ],
        ),
      ),
    );
  }

  // --- 预订历史 ---
  Widget _buildBookingHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Booking History",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 12),

        _buildBookingItem(
          "City View Hotel",
          "Stayed: July 2023",
          "https://images.unsplash.com/photo-1566073771259-6a8506099945?fit=crop&w=200&h=160",
        ),
        const SizedBox(height: 12),

        _buildBookingItem(
          "Woodland Cabin",
          "Stayed: December 2022",
          "https://images.unsplash.com/photo-1533101563233-3a1ab63155aa?fit=crop&w=200&h=160",
        ),
      ],
    );
  }

  // 单个历史项
  Widget _buildBookingItem(String title, String subtitle, String imageUrl) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Image.network(
            imageUrl,
            width: 100,
            height: 80,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              width: 100,
              height: 80,
              color: Colors.grey[200],
              child:
                  Icon(Icons.broken_image, color: Colors.grey[400]),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ 新增：编辑个人偏好按钮
  Widget _buildEditPreferenceButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        Navigator.pushNamed(context, '/preferences'); // 跳转到偏好页
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.black, width: 1),
        ),
      ),
      child: const Text(
        "Edit Preferences",
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  // --- 消息按钮 ---
  Widget _buildMessageHostButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Message host feature not implemented yet.'),
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF212121),
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text(
        "Message host",
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}
