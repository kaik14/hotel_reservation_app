import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hotel_reservation_app/pages/room_detail_page.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart'; // 状态栏样式
import 'package:hotel_reservation_app/services/database_service.dart';

// —— 统一的配色（与 Service 页一致）——
class _Brand {
  static const bg = Color.fromARGB(255, 222, 228, 236); // 浅蓝灰
  static const bar = Color(0xFF0F1722); // 顶栏深色
  static const accent = Color.fromARGB(
    255,
    49,
    59,
    83,
  ); // 按钮品牌蓝（= Service 页 View details）
  // 日期按钮的浅蓝灰渐变，既显得可点又不喧宾夺主
  static const dateGradStart = Color(0xFFEFF3F8);
  static const dateGradEnd = Color(0xFFE3EAF5);
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchKeyword = '';
  DateTime? _checkInDate;
  DateTime? _checkOutDate;

  Map<String, dynamic> userPrefs = {};
  bool loadingPrefs = true;

  final CollectionReference roomsRef = FirebaseFirestore.instance.collection(
    'rooms',
  );

  /// ✅ 默认推荐房型
  final List<String> defaultRecommendedIDs = ['R02', 'R04', 'R07'];

  @override
  void initState() {
    super.initState();
    _loadUserPreferences();
  }

  /// ✅ 读取用户偏好
  Future<void> _loadUserPreferences() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('preferences')
        .doc('userPrefs')
        .get();

    if (doc.exists) userPrefs = doc.data()!;

    setState(() => loadingPrefs = false);
  }

  /// ✅ 是否有偏好
  bool get hasPreference {
    return (userPrefs['preferredFloor'] != null &&
            userPrefs['preferredFloor'] != '') ||
        (userPrefs['preferredView'] != null &&
            userPrefs['preferredView'] != '') ||
        (userPrefs['preferredEnvironment'] != null &&
            userPrefs['preferredEnvironment'] != '') ||
        (userPrefs['familyFriendly'] == true) ||
        (userPrefs['accessibility'] == true);
  }

  /// ✅ 匹配偏好
  bool matchesPreferences(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    if (userPrefs['preferredFloor'] != null &&
        userPrefs['preferredFloor'] != '') {
      if (data['floorLevel'] != userPrefs['preferredFloor']) return false;
    }
    if (userPrefs['preferredView'] != null &&
        userPrefs['preferredView'] != '') {
      if (data['viewType'] != userPrefs['preferredView']) return false;
    }
    if (userPrefs['preferredEnvironment'] != null &&
        userPrefs['preferredEnvironment'] != '') {
      if (data['environmentType'] != userPrefs['preferredEnvironment']) {
        return false;
      }
    }
    if (userPrefs['familyFriendly'] == true && data['familyFriendly'] != true) {
      return false;
    }

    if (userPrefs['accessibility'] == true && data['accessible'] != true) {
      return false;
    }

    return true;
  }

  /// ✅ 检查房型是否在指定日期有空房
  bool roomTypeAvailableBetween(Map<String, dynamic> data) {
    if (_checkInDate == null || _checkOutDate == null) return true;

    final List rooms = data['rooms'] ?? [];
    final iso = DateFormat('yyyy-MM-dd');

    for (final r in rooms) {
      final Set booked = Set<String>.from(
        List.from(r['bookedDates'] ?? []).map((e) => e.toString()),
      );

      bool conflict = false;
      DateTime d = _checkInDate!;

      while (!d.isAfter(_checkOutDate!.subtract(const Duration(days: 1)))) {
        final key = iso.format(d);
        if (booked.contains(key)) {
          conflict = true;
          break;
        }
        d = d.add(const Duration(days: 1));
      }

      if (!conflict) return true; // ✅ 至少有一间房可住
    }

    return false;
  }

  /// ✅ 日期选择器
  Future<void> _selectDate(BuildContext context, bool isCheckIn) async {
    final now = DateTime.now();
    DateTime initial = now;
    DateTime first = now;

    if (isCheckIn && _checkInDate != null) initial = _checkInDate!;
    if (!isCheckIn && _checkInDate != null) {
      first = _checkInDate!.add(const Duration(days: 1));
      initial = _checkOutDate ?? first;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime(2026, 12, 31),
    );

    if (picked != null) {
      setState(() {
        if (isCheckIn) {
          _checkInDate = picked;
          if (_checkOutDate != null && picked.isAfter(_checkOutDate!)) {
            _checkOutDate = null;
          }
        } else {
          _checkOutDate = picked;
        }
      });
    }
  }

  /// ✅ 打开房型详情（带楼层 floorId）
void _openRoom(DocumentSnapshot room, Map<String, dynamic> data) {
  // 从 Firestore 取楼层，如果没有就默认给 8F
  final String floorId = (data['floorLevel'] ?? '8F').toString();

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => RoomDetailPage(
        docId: room.id,
        title: data['titleEN'],
        imageUrl: 'assets/rooms/${data['imageName']}',
        price: "RM${data['price']} per night",
        description: data['description'] ?? '',
        imageName: data['imageName'],
        initialCheckIn: _checkInDate,
        initialCheckOut: _checkOutDate,
        floorId: floorId, // 👈 关键：把楼层传进去
      ),
    ),
  );
}


  /// ✅ 搜索结果（加入日期过滤）
  Widget _buildSearchResults() {
    return StreamBuilder<QuerySnapshot>(
      stream: roomsRef.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final filtered = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final title = data['titleEN'].toLowerCase();
          final desc = (data['description'] ?? '').toLowerCase();

          final keywordMatch =
              _searchKeyword.isEmpty ||
              title.contains(_searchKeyword) ||
              desc.contains(_searchKeyword);

          if (!keywordMatch) return false;

          return roomTypeAvailableBetween(data); // ✅ 按入住日期过滤
        }).toList();

        if (filtered.isEmpty) {
          return const Center(child: Text("No matching rooms found."));
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.9,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, i) {
            final room = filtered[i];
            final data = room.data() as Map<String, dynamic>;

            return RoomCard(
              title: data['titleEN'],
              price: "RM${data['price']} per night",
              imageUrl: 'assets/rooms/${data['imageName']}',
              onTap: () => _openRoom(room, data),
            );
          },
        );
      },
    );
  }

  /// ✅ 推荐房型（加入日期过滤）
  Widget _recommendedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Recommended Rooms",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: roomsRef.snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Text("Loading...");

            final docs = snapshot.data!.docs;
            List<QueryDocumentSnapshot> result;

            // ✅ 用户未选择日期 → 原逻辑
            if (_checkInDate == null || _checkOutDate == null) {
              if (!hasPreference) {
                result = docs
                    .where((d) => defaultRecommendedIDs.contains(d.id))
                    .toList();
              } else {
                result = docs.where((d) => matchesPreferences(d)).toList();
              }
            } else {
              // ✅ 用户已选择日期 → 必须可入住
              if (!hasPreference) {
                result = docs.where((d) {
                  if (!defaultRecommendedIDs.contains(d.id)) return false;
                  return roomTypeAvailableBetween(
                    d.data() as Map<String, dynamic>,
                  );
                }).toList();
              } else {
                result = docs.where((d) {
                  if (!matchesPreferences(d)) return false;
                  return roomTypeAvailableBetween(
                    d.data() as Map<String, dynamic>,
                  );
                }).toList();
              }
            }

            if (result.isEmpty) {
              return const Text("No recommended rooms available.");
            }

            return _recommendedList(result);
          },
        ),
      ],
    );
  }

  /// ✅ 推荐房型列表
  Widget _recommendedList(List<QueryDocumentSnapshot> rooms) {
    return SizedBox(
      height: 210,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: rooms.length,
        itemBuilder: (context, i) {
          final room = rooms[i];
          final data = room.data() as Map<String, dynamic>;

          return RoomCard(
            title: data['titleEN'],
            price: "RM${data['price']} per night",
            imageUrl: 'assets/rooms/${data['imageName']}',
            onTap: () => _openRoom(room, data),
          );
        },
      ),
    );
  }

  /// ✅ 热门房型（保留原逻辑）
  Widget _popularSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Popular Choices",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: roomsRef.where('popular', isEqualTo: true).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Text("Loading...");

            final rooms = snapshot.data!.docs;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.90,
                mainAxisSpacing: 20, // ✅ 上下距离
              ),
              itemCount: rooms.length,
              itemBuilder: (context, index) {
                final room = rooms[index];
                final data = room.data() as Map<String, dynamic>;

                return RoomCard(
                  title: data['titleEN'],
                  price: "RM${data['price']} per night",
                  imageUrl: 'assets/rooms/${data['imageName']}',
                  onTap: () => _openRoom(room, data),
                );
              },
            );
          },
        ),
      ],
    );
  }

  /// ✅ 单个日期“按钮”（配色已改为浅蓝灰系；内部不设外边距，方便在一行排布）
  Widget _dateButton(String label, DateTime? date, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_Brand.dateGradStart, Color.fromARGB(255, 147, 160, 181)],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 左侧标签
            Text(
              label, // 'Check-in' / 'Check-out'
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),

            // 右侧仅保留日历图标（黑色）
            const Icon(Icons.calendar_today, size: 18, color: Colors.black),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loadingPrefs) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      // 背景统一
      backgroundColor: _Brand.bg,

appBar: AppBar(
        backgroundColor: _Brand.bar, // 为了防止 _Brand 报错，我先用了深色背景，你也可以换回 _Brand.bar
        elevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        toolbarHeight: 97,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent, //通常设为透明，让背景色透出来
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        // ✅ 使用 StreamBuilder 包裹 title
        title: StreamBuilder<DocumentSnapshot>(
          stream: DatabaseService().getUserDataStream(
            FirebaseAuth.instance.currentUser?.uid ?? '',
          ),
          builder: (context, snapshot) {
            String firstName = 'Guest';

            // 如果获取到了数据，就更新名字
            if (snapshot.hasData &&
                snapshot.data != null &&
                snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              firstName = data['firstName'] ?? 'Guest';
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hi, $firstName', // 动态显示名字
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Find the perfect room for your stay.',
                  style: TextStyle(
                    color: Color(0x99FFFFFF),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            );
          },
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(
            height: 0.5,
            color: Colors.white.withOpacity(0.08),
          ),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // —— Check-in / Check-out 并排一行 —— //
              Row(
                children: [
                  Expanded(
                    child: _dateButton(
                      'Check-in',
                      _checkInDate,
                      () => _selectDate(context, true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _dateButton(
                      'Check-out',
                      _checkOutDate,
                      () => _selectDate(context, false),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              /// ✅ 搜索栏（按钮改为品牌蓝）
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Search By Room Name Or Description',
                        ),
                        onChanged: (v) =>
                            setState(() => _searchKeyword = v.toLowerCase()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    height: 46,
                    width: 46,
                    decoration: BoxDecoration(
                      color: _Brand.accent, // ← 品牌蓝
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: _Brand.accent.withOpacity(.25),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.search, color: Colors.white),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              if (_searchKeyword.isNotEmpty) ...[
                const Text(
                  "Search Results",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildSearchResults(),
              ] else ...[
                _recommendedSection(),
                const SizedBox(height: 28),
                _popularSection(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// ✅ 房型卡片组件
class RoomCard extends StatelessWidget {
  final String title;
  final String price;
  final String imageUrl;
  final VoidCallback onTap;

  const RoomCard({
    super.key,
    required this.title,
    required this.price,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: Image.asset(
              imageUrl,
              height: 95,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              price,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _Brand.accent, // ← 品牌蓝
                  minimumSize: const Size(90, 32),
                  shadowColor: _Brand.accent.withOpacity(.25),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'Book Now',
                  style: TextStyle(fontSize: 12, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
