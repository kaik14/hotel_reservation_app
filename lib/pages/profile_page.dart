// lib/pages/profile_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hotel_reservation_app/services/auth_service.dart';
import 'package:hotel_reservation_app/services/database_service.dart';

class ProfilePage extends StatelessWidget {
  // 构造函数移除 'const'
  ProfilePage({super.key});

  // 获取当前用户和服务
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final DatabaseService _db = DatabaseService();

  @override
  Widget build(BuildContext context) {
    // AuthGate 理论上会保证 currentUser 不为 null，但作为安全检查
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('用户未登录')));
    }

    // 使用 StreamBuilder 实时获取 Firestore 中的用户数据
    return StreamBuilder<DocumentSnapshot>(
      stream: _db.getUserDataStream(currentUser!.uid),
      builder: (context, snapshot) {
        
        // 1. 处理加载状态
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 2. 处理错误或数据不存在
        //    (如果用户在 Auth 中创建了，但在 Firestore 中创建失败)
        if (!snapshot.hasData || !snapshot.data!.exists) {
          // 即使数据不全，也显示一个基础版本的页面
          return _buildProfileUI(
            context,
            currentUser!.email ?? 'No Email',
            'User',
            '',
            'N/A',
          );
        }

        // 3. 成功获取数据，解析数据
        Map<String, dynamic> userData =
            snapshot.data!.data() as Map<String, dynamic>;

        // 4. 构建完整的 UI
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

  // --- 主 UI 构建方法 ---
  Widget _buildProfileUI(BuildContext context, String email, String firstName,
      String lastName, String phone) {
    return Scaffold(
      backgroundColor: Colors.white,
      // 我们不再需要 AppBar
      body: SingleChildScrollView(
        child: Padding(
          // EdgeInsets.fromLTRB(Left, Top, Right, Bottom)
          padding: const EdgeInsets.fromLTRB(20.0, 60.0, 20.0, 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 顶部用户信息头
              _buildHeader(context, email, '$firstName $lastName'),
              const SizedBox(height: 30),

              // 2. User Details 卡片
              _buildUserDetailsCard(phone, "123 Elm Street, Springfield"),
              const SizedBox(height: 30),

              // 3. Booking History 列表
              _buildBookingHistory(),
              const SizedBox(height: 30),

              // 4. Message host 按钮
              _buildMessageHostButton(context),
            ],
          ),
        ),
      ),
    );
  }

  // --- 1. 顶部用户信息头 ---
  Widget _buildHeader(BuildContext context, String email, String name) {
    return Row(
      children: [
        // 头像
        const CircleAvatar(
          radius: 30,
          backgroundColor: Color(0xFFE0E0E0), // 浅灰色背景
          child: Icon(
            Icons.person,
            size: 30,
            color: Color(0xFF757575), // 深灰色图标
          ),
        ),
        const SizedBox(width: 15),
        
        // 名字和Email
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
        
        // 登出按钮
        TextButton(
          onPressed: () async {
            await AuthService().signOut();
          },
          style: TextButton.styleFrom(
            backgroundColor: const Color(0xFF212121), // 黑色
            foregroundColor: Colors.white, // 白色文字
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: const Text("Logout"),
        ),
      ],
    );
  }

  // --- 2. User Details 卡片 ---
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
            Text("Phone: $phone"), // 从 Firestore 获取
            const SizedBox(height: 8),
            Text("Address: $address"), // 模拟数据，因为我们注册时没收集
          ],
        ),
      ),
    );
  }

  // --- 3. Booking History 列表 (目前使用模拟数据) ---
  Widget _buildBookingHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Booking History",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 12),
        
        // 模拟项目 1
        _buildBookingItem(
          "City View Hotel",
          "Stayed: July 2023",
          // 这是一个占位图，你可以换成自己的
          "https://images.unsplash.com/photo-1566073771259-6a8506099945?fit=crop&w=200&h=160",
        ),
        const SizedBox(height: 12),
        
        // 模拟项目 2
        _buildBookingItem(
          "Woodland Cabin",
          "Stayed: December 2022",
          // 这是一个占位图
          "https://images.unsplash.com/photo-1533101563233-3a1ab63155aa?fit=crop&w=200&h=160",
        ),
      ],
    );
  }

  // 辅助 Widget：用于构建单个预订项
  Widget _buildBookingItem(String title, String subtitle, String imageUrl) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias, // 让图片也遵循圆角
      child: Row(
        children: [
          Image.network(
            imageUrl,
            width: 100,
            height: 80,
            fit: BoxFit.cover,
            // 处理图片加载失败
            errorBuilder: (context, error, stackTrace) =>
                Container(
                  width: 100, 
                  height: 80, 
                  color: Colors.grey[200], 
                  child: Icon(Icons.broken_image, color: Colors.grey[400])
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

  // --- 4. Message host 按钮 ---
  Widget _buildMessageHostButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        // 模拟点击事件
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Message host feature not implemented yet.')),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF212121), // 黑色背景
        foregroundColor: Colors.white, // 白色文字
        minimumSize: const Size(double.infinity, 50), // 撑满宽度
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text(
        "Message host",
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}