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

  // ✅ 你之前“淡蓝色边框”的风格（接近你截图那种）
  static const lightBlueBorder = Color(0xFFC9D6EA);
  static const lightBlueFill = Color(0xFFF2F6FC);
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

  // ---------------- 主体 UI ----------------
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

            // ✅ Recent Bookings：最多三条、整体高度就三条的量、每条淡蓝色边框
            _buildRecentBookingsShowcase(context),
            const SizedBox(height: 20),

            _buildEditPreferenceButton(context),
            // ✅ 删除 Message host 按钮
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

  // =========================
  // ✅ Recent Bookings（房间 + 服务，最多3条）
  // - 不可点击
  // - 高度刚好三条（不会出现大空白）
  // - 每条淡蓝边框包围（你截图那种）
  // =========================
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
        mainAxisSize: MainAxisSize.min, // ✅ 防止撑出底部大空白
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
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

              // ✅ 用 Column + map（而不是 ListView）确保高度就是“几条就是几条”
              final items = snap.data!.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;

                final bool isService =
                    (data['bookingType']?.toString().toLowerCase() ==
                        'service') ||
                    data.containsKey('serviceType') ||
                    data.containsKey('serviceName');

                // ----------- 统一标题 ----------
                String title;
                if (isService) {
                  // serviceName 优先
                  title =
                      (data['serviceName'] ??
                              data['serviceTitle'] ??
                              data['serviceType'] ??
                              'Service')
                          .toString();
                } else {
                  title = (data['roomTypeTitle'] ?? 'Room').toString();
                }

                // ----------- 统一图片 ----------
                // 优先从 data 里拿 serviceImagePath，否则按服务类型给默认图
                String imagePath;
                if (isService) {
                  final String raw =
                      (data['serviceImagePath'] ?? data['imagePath'] ?? '')
                          .toString();
                  if (raw.trim().isNotEmpty) {
                    imagePath = raw;
                  } else {
                    final st = (data['serviceType'] ?? '')
                        .toString()
                        .toLowerCase();
                    imagePath = _defaultServiceAsset(st);
                  }
                } else {
                  final imageName =
                      data['imageName'] ?? "${data['roomTypeId']}.jpg";
                  imagePath = "assets/rooms/$imageName";
                }

                // ----------- 统一日期/时间展示 ----------
                // 房间：checkIn → checkOut
                // 服务：serviceStart / serviceDate + serviceTime / startTime-endTime / pickup-return 等
                String subtitle = '';
                if (!isService) {
                  final tsIn = (data['checkIn'] as Timestamp?)?.toDate();
                  final tsOut = (data['checkOut'] as Timestamp?)?.toDate();
                  subtitle =
                      "${tsIn != null ? dateFmt.format(tsIn) : '?'} → ${tsOut != null ? dateFmt.format(tsOut) : '?'}";
                } else {
                  final DateTime? date = _extractServiceDate(data);
                  final String? timeText = _extractServiceTimeText(data);

                  final String dateText = date != null
                      ? dateFmt.format(date)
                      : 'Unknown date';

                  if (timeText != null && timeText.trim().isNotEmpty) {
                    subtitle = "$dateText • $timeText";
                  } else {
                    subtitle = dateText;
                  }

                  // guests/items/roomNo 等补充信息（尽量短）
                  final extra = _extractServiceExtraShort(data);
                  if (extra.isNotEmpty) {
                    subtitle = "$subtitle • $extra";
                  }
                }

                // ----------- 状态 ----------
                final status = _statusLabel(data, isService: isService);

                return _recentBookingRow(
                  title: title,
                  subtitle: subtitle,
                  status: status,
                  imagePath: imagePath,
                );
              }).toList();

              return Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(items.length, (i) {
                    return Padding(
                      padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
                      child: items[i],
                    );
                  }),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ✅ 每条“淡蓝边框包围”的卡片（你截图那种）
  Widget _recentBookingRow({
    required String title,
    required String subtitle,
    required String status,
    required String imagePath,
  }) {
    // status 颜色（参考你截图：Upcoming 橙色）
    final bool isUpcoming = status.toLowerCase().contains('upcoming');
    final bool isCompleted = status.toLowerCase().contains('completed');

    final Color chipBg = isCompleted
        ? const Color(0xFFE6F6EA)
        : isUpcoming
        ? const Color(0xFFFFF0D8)
        : const Color(0xFFF0F3F7);
    final Color chipFg = isCompleted
        ? const Color(0xFF2E7D32)
        : isUpcoming
        ? const Color(0xFFEF6C00)
        : const Color(0xFF5A6473);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _Brand.lightBlueFill, // ✅ 淡蓝底
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _Brand.lightBlueBorder, width: 1.2), // ✅ 淡蓝边框
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              imagePath,
              width: 58,
              height: 58,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                // ✅ 防止 “null.jpg” 报错（显示占位图）
                return Container(
                  width: 58,
                  height: 58,
                  color: Colors.white,
                  child: const Icon(
                    Icons.image_not_supported_outlined,
                    color: Color(0xFF5A6473),
                  ),
                );
              },
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
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    color: Color(0xFF0F1722),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF5A6473),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: chipBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: chipFg,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
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

  // =========================
  // ✅ Service helpers（用于 Recent Bookings 的展示）
  // =========================

  static String _defaultServiceAsset(String serviceTypeLower) {
    switch (serviceTypeLower) {
      case 'gym':
        return 'assets/services/gym.jpg';
      case 'conferencehall':
      case 'conference_hall':
      case 'conference':
        return 'assets/services/conference.jpg';
      case 'taxi':
        return 'assets/services/taxi.jpg';
      case 'laundry':
        return 'assets/services/laundry.jpg';
      case 'swimming':
      case 'pool':
        return 'assets/services/swimming.jpg';
      case 'housekeeping':
        return 'assets/services/housekeeping.jpg';
      case 'spa':
        return 'assets/services/spa.jpg';
      case 'dining':
        return 'assets/services/dining.jpg';
      default:
        return 'assets/services/service.jpg'; // 你可以准备一张通用占位图
    }
  }

  static DateTime? _extractServiceDate(Map<String, dynamic> data) {
    // 优先 serviceStart
    final tsStart = data['serviceStart'] as Timestamp?;
    if (tsStart != null) return tsStart.toDate();

    // 其次 serviceDate
    final tsDate = data['serviceDate'] as Timestamp?;
    if (tsDate != null) return tsDate.toDate();

    // 兼容 conference: date
    final tsAltDate = data['date'] as Timestamp?;
    if (tsAltDate != null) return tsAltDate.toDate();

    return null;
  }

  static String? _extractServiceTimeText(Map<String, dynamic> data) {
    // 1) 单时间（gym/swimming/housekeeping/taxi）
    final st = data['serviceTime']?.toString();
    if (st != null && st.trim().isNotEmpty) return st;

    final t = data['time']?.toString();
    if (t != null && t.trim().isNotEmpty) return t;

    // 2) conference: start/end
    final start = data['startTime']?.toString();
    final end = data['endTime']?.toString();
    if (start != null &&
        start.trim().isNotEmpty &&
        end != null &&
        end.trim().isNotEmpty) {
      return "$start–$end";
    }

    // 3) laundry: pickup/return
    final pickup = data['pickupTime']?.toString();
    final ret = data['returnTime']?.toString();
    if (pickup != null &&
        pickup.trim().isNotEmpty &&
        ret != null &&
        ret.trim().isNotEmpty) {
      return "$pickup–$ret";
    }

    return null;
  }

  static String _extractServiceExtraShort(Map<String, dynamic> data) {
    // guests
    final guests = data['guests'] ?? data['totalGuests'];
    if (guests != null) {
      final g = int.tryParse(guests.toString());
      if (g != null && g > 0) return "$g guests";
    }

    // laundry: items
    final items =
        data['items'] ?? data['clothesCount'] ?? data['numberOfItems'];
    if (items != null) {
      final n = int.tryParse(items.toString());
      if (n != null && n > 0) return "$n items";
    }

    // housekeeping: room number
    final roomNo = data['roomNo'] ?? data['roomNumber'];
    if (roomNo != null && roomNo.toString().trim().isNotEmpty) {
      return "Room ${roomNo.toString()}";
    }

    // taxi: passengers
    final p = data['passengers'];
    if (p != null) {
      final n = int.tryParse(p.toString());
      if (n != null && n > 0) return "$n pax";
    }

    return '';
  }

  static String _statusLabel(
    Map<String, dynamic> data, {
    required bool isService,
  }) {
    final now = DateTime.now();

    if (!isService) {
      final tsIn = (data['checkIn'] as Timestamp?)?.toDate();
      if (tsIn == null) return "Pending";
      final inDay = DateTime(tsIn.year, tsIn.month, tsIn.day);
      final today = DateTime(now.year, now.month, now.day);
      if (inDay.isBefore(today)) return "Checked In";
      return "Upcoming";
    }

    // service: 用 serviceStart/serviceDate + time 推断
    final DateTime? date = _extractServiceDate(data);
    if (date == null) return "Upcoming";

    // 如果有明确开始时间（serviceStart），直接判断完成
    final tsStart = data['serviceStart'] as Timestamp?;
    if (tsStart != null) {
      return tsStart.toDate().isBefore(now) ? "Completed" : "Upcoming";
    }

    // 没有 serviceStart：用日期 + time（如果有）做个粗略判断
    final time = data['serviceTime']?.toString();
    if (time != null && time.contains(':')) {
      final parts = time.split(':');
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts.length > 1 ? parts[1] : '');
      if (h != null && m != null) {
        final dt = DateTime(date.year, date.month, date.day, h, m);
        return dt.isBefore(now) ? "Completed" : "Upcoming";
      }
    }

    // 只按日期判断
    final day = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    return day.isBefore(today) ? "Completed" : "Upcoming";
  }
}
