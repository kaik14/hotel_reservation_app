import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// ✅ 复用 BookingPage 的品牌配色
class _Brand {
  static const bg = Color.fromARGB(255, 222, 228, 236);
  static const bar = Color(0xFF313B53); // Admin 专用深色
  static const accent = Color.fromARGB(255, 49, 59, 83);
}

class RoomStatuPage extends StatefulWidget {
  const RoomStatuPage({super.key});

  @override
  State<RoomStatuPage> createState() => _RoomStatuPageState();
}

class _RoomStatuPageState extends State<RoomStatuPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 判断是否为服务订单 (只显示客房)
  bool _isServiceBooking(Map<String, dynamic> data) {
    final t = (data['bookingType'] ?? '').toString();
    return t == 'service' || data.containsKey('serviceType') || data.containsKey('serviceName');
  }

  // ✅ 本地排序方法 (解决索引报错问题)
  List<QueryDocumentSnapshot> _sortDocs(List<QueryDocumentSnapshot> docs) {
    docs.sort((a, b) {
      final ad = a.data() as Map<String, dynamic>;
      final bd = b.data() as Map<String, dynamic>;
      // 优先用 createdAt，没有就用 checkIn
      final at = (ad['createdAt'] ?? ad['checkIn']) as Timestamp?;
      final bt = (bd['createdAt'] ?? bd['checkIn']) as Timestamp?;
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at); // 降序：最新的在最上面
    });
    return docs;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Brand.bg,
      appBar: AppBar(
        title: const Text('Room Status (All)'),
        backgroundColor: _Brand.bar,
        foregroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Active / Upcoming'),
            Tab(text: 'Completed / Past'),
          ],
        ),
      ),
      // 🔥 使用 collectionGroup 查询所有用户的 bookings
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collectionGroup('bookings').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No bookings found.', style: TextStyle(color: Colors.grey)));
          }

          final now = DateTime.now();
          final allDocs = snapshot.data!.docs;
          
          // 1. 过滤掉 Service 订单
          final roomDocs = allDocs.where((doc) {
            return !_isServiceBooking(doc.data() as Map<String, dynamic>);
          }).toList();

          // 2. 本地排序 (最新的在上面)
          final sortedDocs = _sortDocs(roomDocs);

          final List<DocumentSnapshot> activeList = [];
          final List<DocumentSnapshot> completedList = [];

          // 3. 分类 Active vs Completed
          for (var doc in sortedDocs) {
            final data = doc.data() as Map<String, dynamic>;
            final checkOutTs = data['checkOut'] ?? data['endDate'];
            
            bool isCompleted = false;
            // 修复 Crash: 只有当 checkOutTs 不为空且是 Timestamp 时才比较
            if (checkOutTs != null && checkOutTs is Timestamp) {
              if (checkOutTs.toDate().isBefore(now)) {
                isCompleted = true; // 退房时间已过 -> 完成
              }
            }
            
            if (isCompleted) {
              completedList.add(doc);
            } else {
              activeList.add(doc);
            }
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildBookingList(activeList, "No active bookings."),
              _buildBookingList(completedList, "No completed bookings."),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBookingList(List<DocumentSnapshot> docs, String emptyMsg) {
    if (docs.isEmpty) {
      return Center(child: Text(emptyMsg, style: TextStyle(fontSize: 16, color: Colors.grey[600])));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        final data = doc.data() as Map<String, dynamic>;

        // === 数据提取 (和 BookingPage 保持一致) ===
        final title = (data['roomTypeTitle'] ?? data['roomName'] ?? 'Room').toString();
        
        // 🛠️ 图片保底逻辑 (List View)
        String imageName = (data['imageName'] ?? data['imageUrl'] ?? "").toString();
        if (imageName.isEmpty) {
           final roomTypeId = data['roomTypeId'];
           if (roomTypeId != null) {
             imageName = "$roomTypeId.jpg"; // ✅ 强制保底：用房型ID拼图片名
           }
        }
        final imagePath = imageName.contains('assets') ? imageName : "assets/rooms/$imageName";
        
        final checkIn = (data['checkIn'] ?? data['startDate'] as Timestamp?)?.toDate();
        final checkOut = (data['checkOut'] ?? data['endDate'] as Timestamp?)?.toDate();
        final guests = data['guests'] ?? 1;
        final roomNo = data['roomNo'] ?? '-';
        // 自动计算金额显示
        final rawPrice = data['totalPrice'] ?? data['totalAmount'] ?? 0;
        final priceVal = (rawPrice is int) ? rawPrice / 100.0 : (rawPrice is double ? rawPrice : 0.0);
        final priceText = "RM ${priceVal.toStringAsFixed(0)}";

        final dateFmt = DateFormat('dd MMM yyyy');
        
        // === 状态显示逻辑 ===
        String statusText = "Reserved";
        Color bgColor = Colors.orange[100]!;
        Color textColor = Colors.orange[800]!;

        if (checkIn != null && checkOut != null) {
           final now = DateTime.now();
           if (now.isAfter(checkOut)) { 
             statusText = "Completed";
             bgColor = Colors.grey[200]!;
             textColor = Colors.black54;
           } else if (now.isAfter(checkIn)) {
             statusText = "Occupied";
             bgColor = Colors.green[100]!;
             textColor = Colors.green[800]!;
           }
        } else if (checkIn == null) {
          statusText = "Pending";
          bgColor = Colors.grey[200]!;
          textColor = Colors.black54;
        }

        return GestureDetector(
          onTap: () {
            // ✅ 跳转到 Admin 版详情页
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _AdminBookingDetailPage(doc: doc, data: data),
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
                    // 图片
                    ClipRRect(
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                      child: (imageName.isNotEmpty) 
                        ? Image.asset(
                            imagePath,
                            height: 100, width: 120, fit: BoxFit.cover,
                            errorBuilder: (c,e,s) => Container(width: 120, height: 100, color: Colors.grey[300], child: const Icon(Icons.broken_image)),
                          )
                        : Container(width: 120, height: 100, color: Colors.grey[300], child: const Icon(Icons.bed)),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: .1),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "${checkIn != null ? dateFmt.format(checkIn) : '?'} → ${checkOut != null ? dateFmt.format(checkOut) : '?'}",
                              style: const TextStyle(fontSize: 13, color: Colors.black54),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Room $roomNo • Guests: $guests",
                              style: const TextStyle(fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              priceText,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _Brand.bar),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                // 状态 Badge
                Positioned(
                  right: 12,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// 👇 管理员专用详情页 (✅ 修复了 UserID 读取逻辑)
// ============================================================================

class _AdminBookingDetailPage extends StatelessWidget {
  final DocumentSnapshot doc;
  final Map<String, dynamic> data;

  const _AdminBookingDetailPage({required this.doc, required this.data});

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '-';
    return DateFormat('dd MMM yyyy').format(timestamp.toDate());
  }

  // 🗑️ 删除订单逻辑
  Future<void> _handleCancel(BuildContext context) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Admin Cancel'),
        content: const Text('Are you sure you want to PERMANENTLY delete this booking?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await doc.reference.delete();
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking deleted.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = (data['roomTypeTitle'] ?? data['roomName'] ?? 'Room').toString();
    
    // 🛠️ 图片保底逻辑 (Detail Page)
    String imageName = (data['imageName'] ?? data['imageUrl'] ?? "").toString();
    if (imageName.isEmpty) {
       final roomTypeId = data['roomTypeId'];
       if (roomTypeId != null) imageName = "$roomTypeId.jpg"; // ✅ 保底
    }
    final imagePath = imageName.contains('assets') ? imageName : "assets/rooms/$imageName";
    
    final rawPrice = data['totalPrice'] ?? data['totalAmount'] ?? 0;
    final priceVal = (rawPrice is int) ? rawPrice / 100.0 : (rawPrice is double ? rawPrice : 0.0);
    final priceText = "RM ${priceVal.toStringAsFixed(0)}";

    final status = (data['status'] ?? 'Confirmed').toString().toUpperCase();
    final guests = data['guests'] ?? 1;

    // 🔥🔥 关键修复：智能获取 UserID 🔥🔥
    // 1. 尝试从字段取
    String? userId = data['userId'];
    // 2. 如果字段没有，尝试从文档路径取 (users/{uid}/bookings/{docId})
    if (userId == null || userId.isEmpty) {
      if (doc.reference.parent.parent != null) {
        userId = doc.reference.parent.parent!.id;
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Booking Details'),
        backgroundColor: _Brand.bar,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 大图
            (imageName.isNotEmpty)
              ? Image.asset(imagePath, fit: BoxFit.cover, width: double.infinity, height: 200, errorBuilder: (c,e,s) => Container(height: 200, color: Colors.grey[300], child: const Icon(Icons.broken_image)))
              : Container(height: 200, width: double.infinity, color: Colors.grey[300], child: const Icon(Icons.hotel, size: 64)),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[800]),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 信息行
                  _infoRow(Icons.calendar_today, 'Check-in', _formatDate(data['startDate'] ?? data['checkIn'])),
                  const SizedBox(height: 12),
                  _infoRow(Icons.calendar_today_outlined, 'Check-out', _formatDate(data['endDate'] ?? data['checkOut'])),
                  const SizedBox(height: 12),
                  _infoRow(Icons.attach_money, 'Total Price', priceText),
                  const SizedBox(height: 12),
                  _infoRow(Icons.person, 'Guests', '$guests Adult(s)'),
                  const SizedBox(height: 12),
                  _infoRow(Icons.confirmation_number, 'Booking ID', doc.id),
                  const SizedBox(height: 12),
                  
                  // 🔥🔥 显示下单人信息 🔥🔥
                  if (userId != null && userId.isNotEmpty)
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
                      builder: (context, snapshot) {
                        String emailText = 'Loading...';
                        String nameText = 'Loading...';
                        String phoneText = '';

                        if (snapshot.connectionState == ConnectionState.done) {
                          if (snapshot.hasData && snapshot.data!.exists) {
                            final userData = snapshot.data!.data() as Map<String, dynamic>;
                            
                            emailText = userData['email'] ?? 'No Email';
                            
                            final f = userData['firstName'] ?? '';
                            final l = userData['lastName'] ?? '';
                            nameText = '$f $l'.trim();
                            if (nameText.isEmpty) nameText = 'Unknown Name';

                            phoneText = userData['phoneNumber'] ?? '';
                          } else {
                            emailText = 'User Not Found';
                            nameText = 'Unknown';
                          }
                        }
                        
                        return Column(
                          children: [
                            _infoRow(Icons.account_circle, 'Booker Name', nameText),
                            const SizedBox(height: 12),
                            _infoRow(Icons.email, 'Booker Email', emailText),
                            if (phoneText.isNotEmpty) ...[
                               const SizedBox(height: 12),
                               _infoRow(Icons.phone, 'Phone', phoneText),
                            ]
                          ],
                        );
                      },
                    )
                  else
                    const Text('Error: Could not determine User ID from database path.', style: TextStyle(color: Colors.red)),

                  const SizedBox(height: 40),

                  // Admin 操作按钮
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => _AdminEditPage(doc: doc, data: data)),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _Brand.bar,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Edit Booking (Admin)'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _handleCancel(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Cancel Booking'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 12),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

// ============================================================================
// 👇 管理员专用：日期编辑页
// ============================================================================

class _AdminEditPage extends StatefulWidget {
  final DocumentSnapshot doc;
  final Map<String, dynamic> data;

  const _AdminEditPage({required this.doc, required this.data});

  @override
  State<_AdminEditPage> createState() => _AdminEditPageState();
}

class _AdminEditPageState extends State<_AdminEditPage> {
  late DateTime _startDate;
  late DateTime _endDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    var start = widget.data['startDate'] ?? widget.data['checkIn'];
    var end = widget.data['endDate'] ?? widget.data['checkOut'];
    _startDate = (start is Timestamp) ? start.toDate() : DateTime.now();
    _endDate = (end is Timestamp) ? end.toDate() : DateTime.now().add(const Duration(days: 1));
  }

  Future<void> _selectDate(bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate.add(const Duration(days: 1));
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      await widget.doc.reference.update({
        'startDate': Timestamp.fromDate(_startDate),
        'endDate': Timestamp.fromDate(_endDate),
        'checkIn': Timestamp.fromDate(_startDate),
        'checkOut': Timestamp.fromDate(_endDate),
      });
      if (mounted) {
        Navigator.pop(context); // 回详情
        Navigator.pop(context); // 回列表刷新
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Updated successfully!')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Dates'), backgroundColor: _Brand.bar, foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ListTile(
              title: const Text('Check-in'),
              subtitle: Text(DateFormat('dd MMM yyyy').format(_startDate)),
              trailing: const Icon(Icons.edit),
              onTap: () => _selectDate(true),
            ),
            const Divider(),
            ListTile(
              title: const Text('Check-out'),
              subtitle: Text(DateFormat('dd MMM yyyy').format(_endDate)),
              trailing: const Icon(Icons.edit),
              onTap: () => _selectDate(false),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _Brand.bar,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}