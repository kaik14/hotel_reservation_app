import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// ✅ 复用品牌配色
class _Brand {
  static const bg = Color.fromARGB(255, 222, 228, 236);
  static const bar = Color(0xFF313B53); // Admin 专用深色
  static const accent = Color.fromARGB(255, 49, 59, 83);
}

class TaskStatusPage extends StatefulWidget {
  const TaskStatusPage({super.key});

  @override
  State<TaskStatusPage> createState() => _TaskStatusPageState();
}

class _TaskStatusPageState extends State<TaskStatusPage> with SingleTickerProviderStateMixin {
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

  // ✅ 核心判断：是否为服务订单
  bool _isServiceBooking(Map<String, dynamic> data) {
    final t = (data['bookingType'] ?? '').toString();
    return t == 'service' || data.containsKey('serviceType') || data.containsKey('serviceName');
  }

  // ✅ 本地排序：最新的在最上面
  List<QueryDocumentSnapshot> _sortDocs(List<QueryDocumentSnapshot> docs) {
    docs.sort((a, b) {
      final ad = a.data() as Map<String, dynamic>;
      final bd = b.data() as Map<String, dynamic>;
      // 优先用 createdAt，没有就用 serviceStart
      final at = (ad['createdAt'] ?? ad['serviceStart']) as Timestamp?;
      final bt = (bd['createdAt'] ?? bd['serviceStart']) as Timestamp?;
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at); // 降序
    });
    return docs;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Brand.bg,
      appBar: AppBar(
        title: const Text('Task Status (Services)'),
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
      // 🔥 抓取所有 bookings
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collectionGroup('bookings').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No service bookings found.', style: TextStyle(color: Colors.grey)));
          }

          final now = DateTime.now();
          final allDocs = snapshot.data!.docs;
          
          // 1. 只保留服务订单
          final serviceDocs = allDocs.where((doc) {
            return _isServiceBooking(doc.data() as Map<String, dynamic>);
          }).toList();

          // 2. 排序
          final sortedDocs = _sortDocs(serviceDocs);

          final List<DocumentSnapshot> activeList = [];
          final List<DocumentSnapshot> completedList = [];

          // 3. 分类 Active vs Completed
          for (var doc in sortedDocs) {
            final data = doc.data() as Map<String, dynamic>;
            final startTs = data['serviceStart'] ?? data['serviceDate'];
            
            bool isCompleted = false;
            // 如果服务时间已过，视为 Completed
            if (startTs != null && startTs is Timestamp) {
              if (startTs.toDate().isBefore(now)) {
                isCompleted = true; 
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
              _buildBookingList(activeList, "No active tasks."),
              _buildBookingList(completedList, "No history tasks."),
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

        // === 数据提取 ===
        final serviceType = (data['serviceType'] ?? 'Service').toString();
        final title = (data['serviceName'] ?? serviceType).toString();
        
        // 🛠️ 图片保底逻辑
        String imagePath = (data['serviceImagePath'] ?? data['imageUrl'] ?? "").toString();
        if (imagePath.isEmpty || !imagePath.contains('assets')) {
           // 如果没图，根据类型给个默认图
           imagePath = _getFallbackImage(serviceType);
        }
        
        // 时间处理
        final startTs = (data['serviceStart'] ?? data['serviceDate']) as Timestamp?;
        final dateStr = startTs != null 
            ? DateFormat('dd MMM yyyy').format(startTs.toDate()) 
            : 'Date Pending';
        final timeStr = (data['serviceTime'] ?? data['startTime'] ?? data['pickupTime'] ?? '').toString();
        final displayTime = timeStr.isNotEmpty 
            ? timeStr 
            : (startTs != null ? DateFormat('HH:mm').format(startTs.toDate()) : '-');

        // 状态
        final statusText = (startTs != null && startTs.toDate().isBefore(DateTime.now())) 
            ? "Completed" 
            : "Upcoming";
        final bgColor = statusText == "Completed" ? Colors.grey[200]! : Colors.blue[50]!;
        final textColor = statusText == "Completed" ? Colors.black54 : Colors.blue[800]!;

        // 价格
        final rawPrice = data['totalPriceRM'] ?? data['totalPrice'] ?? 0;
        final priceText = "RM ${rawPrice.toString()}";

        return GestureDetector(
          onTap: () {
            // ✅ 跳转 Admin 详情页
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _AdminServiceDetailPage(doc: doc, data: data),
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
                      child: Image.asset(
                        imagePath,
                        height: 100, width: 120, fit: BoxFit.cover,
                        errorBuilder: (c,e,s) => Container(width: 120, height: 100, color: Colors.grey[300], child: const Icon(Icons.room_service)),
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
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: .1),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "$dateStr • $displayTime",
                              style: const TextStyle(fontSize: 13, color: Colors.black54),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              serviceType.toUpperCase(),
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
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

  String _getFallbackImage(String type) {
    type = type.toLowerCase();
    if (type.contains('din')) return 'assets/services/dining.jpg';
    if (type.contains('spa')) return 'assets/services/spa.jpg';
    if (type.contains('gym')) return 'assets/services/gym.jpg';
    if (type.contains('pool') || type.contains('swim')) return 'assets/services/pool.jpg';
    if (type.contains('clean') || type.contains('house')) return 'assets/services/housekeeping.jpg';
    if (type.contains('taxi')) return 'assets/services/taxi.jpg';
    if (type.contains('laundry')) return 'assets/services/laundry.jpg';
    if (type.contains('conf')) return 'assets/services/conference.jpg';
    return 'assets/services/service.jpg';
  }
}

// ============================================================================
// 👇 管理员专用：服务详情页
// ============================================================================

class _AdminServiceDetailPage extends StatelessWidget {
  final DocumentSnapshot doc;
  final Map<String, dynamic> data;

  const _AdminServiceDetailPage({required this.doc, required this.data});

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '-';
    return DateFormat('dd MMM yyyy').format(timestamp.toDate());
  }

  Future<void> _handleCancel(BuildContext context) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Admin Cancel'),
        content: const Text('Are you sure you want to PERMANENTLY delete this task?'),
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task deleted.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final serviceType = (data['serviceType'] ?? 'Service').toString();
    final title = (data['serviceName'] ?? serviceType).toString();
    
    String imagePath = (data['serviceImagePath'] ?? "").toString();
    if (imagePath.isEmpty || !imagePath.contains('assets')) {
       // 简单的本地 fallback，避免白屏
       if (serviceType.toLowerCase().contains('din')) imagePath = 'assets/services/dining.jpg';
       else imagePath = 'assets/services/service.jpg';
    }

    final rawPrice = data['totalPriceRM'] ?? data['totalPrice'] ?? 0;
    final priceText = "RM $rawPrice";

    // 字段提取
    final startTs = (data['serviceStart'] ?? data['serviceDate']) as Timestamp?;
    final timeStr = (data['serviceTime'] ?? data['startTime'] ?? data['pickupTime'] ?? '').toString();
    final guests = data['totalGuests'] ?? data['guests'] ?? data['passengers'] ?? data['adultCount'] ?? 1;
    final userId = data['userId'];

    // 智能获取 UserID (如果字段没有，从路径取)
    String effectiveUserId = userId ?? '';
    if (effectiveUserId.isEmpty && doc.reference.parent.parent != null) {
      effectiveUserId = doc.reference.parent.parent!.id;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Task Details'),
        backgroundColor: _Brand.bar,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 大图
            Image.asset(
              imagePath, 
              fit: BoxFit.cover, 
              width: double.infinity, 
              height: 200, 
              errorBuilder: (c,e,s) => Container(height: 200, color: Colors.grey[300], child: const Icon(Icons.broken_image))
            ),

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
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      serviceType.toUpperCase(),
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[800]),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 详情行
                  _infoRow(Icons.calendar_today, 'Date', _formatDate(startTs)),
                  const SizedBox(height: 12),
                  _infoRow(Icons.access_time, 'Time', timeStr.isNotEmpty ? timeStr : '-'),
                  const SizedBox(height: 12),
                  _infoRow(Icons.attach_money, 'Total Price', priceText),
                  const SizedBox(height: 12),
                  _infoRow(Icons.group, 'Guests / Pax', '$guests'),
                  const SizedBox(height: 12),
                  _infoRow(Icons.confirmation_number, 'Task ID', doc.id),
                  const SizedBox(height: 12),
                  
                  // 🔥 用户信息查询
                  if (effectiveUserId.isNotEmpty)
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(effectiveUserId).get(),
                      builder: (context, snapshot) {
                        String emailText = 'Loading...';
                        String nameText = 'Loading...';
                        if (snapshot.connectionState == ConnectionState.done) {
                          if (snapshot.hasData && snapshot.data!.exists) {
                            final userData = snapshot.data!.data() as Map<String, dynamic>;
                            emailText = userData['email'] ?? 'No Email';
                            final f = userData['firstName'] ?? '';
                            final l = userData['lastName'] ?? '';
                            nameText = '$f $l'.trim();
                            if (nameText.isEmpty) nameText = 'Unknown Name';
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
                          ],
                        );
                      },
                    )
                  else
                    const Text('Error: User ID missing.', style: TextStyle(color: Colors.red)),

                  const SizedBox(height: 40),

                  // 按钮
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // 跳转到通用服务编辑页
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => _AdminServiceEditPage(doc: doc, data: data)),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _Brand.bar,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Edit Task (Admin)'),
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
                      child: const Text('Delete Task'),
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
// 👇 管理员专用：通用服务编辑页 (改日期/时间/人数)
// ============================================================================

class _AdminServiceEditPage extends StatefulWidget {
  final DocumentSnapshot doc;
  final Map<String, dynamic> data;

  const _AdminServiceEditPage({required this.doc, required this.data});

  @override
  State<_AdminServiceEditPage> createState() => _AdminServiceEditPageState();
}

class _AdminServiceEditPageState extends State<_AdminServiceEditPage> {
  late DateTime _date;
  late TimeOfDay _time;
  final TextEditingController _guestsCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // 初始化日期
    final ts = (widget.data['serviceStart'] ?? widget.data['serviceDate']) as Timestamp?;
    _date = ts != null ? ts.toDate() : DateTime.now();

    // 初始化时间
    final tStr = (widget.data['serviceTime'] ?? widget.data['startTime'] ?? '09:00').toString();
    _time = _parseTime(tStr);

    // 初始化人数
    final g = widget.data['totalGuests'] ?? widget.data['guests'] ?? widget.data['passengers'] ?? 1;
    _guestsCtrl.text = g.toString();
  }

  TimeOfDay _parseTime(String s) {
    if (!s.contains(':')) return const TimeOfDay(hour: 9, minute: 0);
    final parts = s.split(':');
    return TimeOfDay(hour: int.tryParse(parts[0])??9, minute: int.tryParse(parts[1])??0);
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      final newStart = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
      final timeStr = "${_time.hour.toString().padLeft(2,'0')}:${_time.minute.toString().padLeft(2,'0')}";
      final guests = int.tryParse(_guestsCtrl.text) ?? 1;

      // 更新所有可能涉及的字段，确保覆盖不同服务类型
      await widget.doc.reference.update({
        'serviceStart': Timestamp.fromDate(newStart),
        'serviceDate': Timestamp.fromDate(_date),
        'serviceTime': timeStr,
        'startTime': timeStr,
        'pickupTime': timeStr, // 兼容 taxi/laundry
        'totalGuests': guests,
        'guests': guests,
        'passengers': guests,
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
      appBar: AppBar(title: const Text('Edit Service Task'), backgroundColor: _Brand.bar, foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ListTile(
              title: const Text('Date'),
              subtitle: Text(DateFormat('dd MMM yyyy').format(_date)),
              trailing: const Icon(Icons.edit),
              onTap: _selectDate,
            ),
            const Divider(),
            ListTile(
              title: const Text('Time'),
              subtitle: Text(_time.format(context)),
              trailing: const Icon(Icons.access_time),
              onTap: _selectTime,
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextFormField(
                controller: _guestsCtrl,
                decoration: const InputDecoration(labelText: 'Guests / Pax / Items'),
                keyboardType: TextInputType.number,
              ),
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