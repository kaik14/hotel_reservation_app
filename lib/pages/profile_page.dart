import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:hotel_reservation_app/auth_gate.dart';
import 'package:hotel_reservation_app/services/auth_service.dart';
import 'package:hotel_reservation_app/services/database_service.dart';

// —— 与其它页面统一的品牌样式 —— //
class _Brand {
  static const bg = Color.fromARGB(255, 222, 228, 236); // 页面浅蓝灰
  static const bar = Color(0xFF0F1722); // 深色顶栏
  static const accent = Color.fromARGB(255, 49, 59, 83); // 主要按钮色
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0x99FFFFFF);
}

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

        final userData = snapshot.data!.data() as Map<String, dynamic>;
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

  // ---------------- 主体 UI（纯展示“历史预订”） ----------------
  Widget _buildProfileUI(
    BuildContext context,
    String email,
    String firstName,
    String lastName,
    String phone,
  ) {
    final fullName = '$firstName $lastName';

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
              'Profile',
              style: TextStyle(
                color: _Brand.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Manage your account and preferences.',
              style: TextStyle(
                color: _Brand.textSecondary,
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

      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, email, fullName),
            const SizedBox(height: 20),

            _buildUserDetailsCard(phone, "123 Elm Street, Springfield"),
            const SizedBox(height: 20),

            // —— 历史预订（纯展示 UI，不可点击，无“View all”） —— //
            _buildRecentBookingsShowcase(context),
            const SizedBox(height: 20),

            _buildEditPreferenceButton(context),
            const SizedBox(height: 12),

            _buildMessageHostButton(context),
          ],
        ),
      ),
    );
  }

  // ---------------- 顶部用户信息头 ----------------
  Widget _buildHeader(BuildContext context, String email, String name) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: Color(0xFFEFF3F8),
            child: Icon(Icons.person, size: 32, color: Color(0xFF5A6473)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    letterSpacing: .1,
                    color: Color(0xFF0F1722),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(
                    color: Color(0xFF5A6473),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: () async {
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const AuthGate()),
                  (route) => false,
                );
              }
            },
            style: TextButton.styleFrom(
              backgroundColor: _Brand.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Logout',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- 用户详情卡片 ----------------
  Widget _buildUserDetailsCard(String phone, String address) {
    return Card(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withOpacity(.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "User Details",
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.phone_rounded,
                  size: 18,
                  color: Color(0xFF5A6473),
                ),
                const SizedBox(width: 8),
                Text("Phone: $phone"),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  size: 18,
                  color: Color(0xFF5A6473),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text("Address: $address")),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- 历史预订（纯展示，不跳转、不展开） ----------------
  Widget _buildRecentBookingsShowcase(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    final dateFmt = DateFormat('dd MMM yyyy');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Recent Bookings",
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .collection('bookings')
                .orderBy('createdAt', descending: true)
                .limit(3)
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "No bookings yet.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              }

              final today = DateTime(
                DateTime.now().year,
                DateTime.now().month,
                DateTime.now().day,
              );

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snap.data!.docs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final data =
                      snap.data!.docs[i].data() as Map<String, dynamic>;

                  final title = data['roomTypeTitle'] ?? 'Unknown';
                  final imageName =
                      data['imageName'] ?? "${data['roomTypeId']}.jpg";
                  final image = "assets/rooms/$imageName";

                  final tsIn = (data['checkIn'] as Timestamp?)?.toDate();
                  final tsOut = (data['checkOut'] as Timestamp?)?.toDate();

                  String status;
                  Color chipBg;
                  Color chipFg;

                  if (tsIn == null) {
                    status = "Pending";
                    chipBg = Colors.grey[200]!;
                    chipFg = Colors.black54;
                  } else if (DateTime(
                    tsIn.year,
                    tsIn.month,
                    tsIn.day,
                  ).isBefore(today)) {
                    status = "Checked In";
                    chipBg = Colors.green[100]!;
                    chipFg = Colors.green[800]!;
                  } else {
                    status = "Not Checked In";
                    chipBg = Colors.orange[100]!;
                    chipFg = Colors.orange[800]!;
                  }

                  // 纯展示卡片（没有 onTap、没有“查看全部/展开”）
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.asset(
                            image,
                            width: 68,
                            height: 68,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${tsIn != null ? dateFmt.format(tsIn) : '?'} → ${tsOut != null ? dateFmt.format(tsOut) : '?'}",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 8),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: chipBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: chipFg,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ---------------- 编辑个人偏好按钮（白底描边） ----------------
  Widget _buildEditPreferenceButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        Navigator.pushNamed(context, '/preferences');
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: _Brand.accent,
        elevation: 0,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _Brand.accent, width: 1),
        ),
      ),
      child: const Text(
        "Edit Preferences",
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );
  }

  // ---------------- “Message host” 按钮（实心品牌色） ----------------
  Widget _buildMessageHostButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message host feature not implemented yet.'),
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: _Brand.accent,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        shadowColor: _Brand.accent.withOpacity(.25),
        elevation: 4,
      ),
      child: const Text(
        "Message host",
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );
  }
}
