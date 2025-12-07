import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hotel_reservation_app/pages/payment_screen.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart'; // 📦 引入 3D 库

// 跳转到地图选房页面
import 'room_map_page.dart';

class RoomDetailPage extends StatefulWidget {
  final String docId;
  final String title;
  final String imageUrl;
  final String price;
  final String description;
  final String imageName;

  final DateTime? initialCheckIn;
  final DateTime? initialCheckOut;

  // 👇 新增：楼层 ID，比如 '8F' 或 '9F'
  final String floorId;

  const RoomDetailPage({
    super.key,
    required this.docId,
    required this.title,
    required this.imageUrl,
    required this.price,
    required this.description,
    required this.imageName,
    this.initialCheckIn,
    this.initialCheckOut,
    required this.floorId, // 👈 记得 required
  });

  @override
  State<RoomDetailPage> createState() => _RoomDetailPageState();
}

class _RoomDetailPageState extends State<RoomDetailPage> {
  DateTime? checkInDate;
  DateTime? checkOutDate;
  int guests = 1;

  // Firestore 过滤出来的可用房间号
  List<String> availableRooms = [];
  String? selectedRoom;

  bool _isModelLoading = false; // 是否正在准备加载 3D 视图
  bool _isModelReady = false;   // 3D 模型是否已经加载完毕
  // 🧊 新增：控制 3D 视图显示的状态
  bool _show3D = false;


  final DateFormat _isoDay = DateFormat('yyyy-MM-dd');
  final DateFormat _uiFmt = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    checkInDate = widget.initialCheckIn;
    checkOutDate = widget.initialCheckOut;

    if (checkInDate != null && checkOutDate != null) {
      _filterAvailableRooms();
    }
  }

  Future<void> _filterAvailableRooms() async {
    if (checkInDate == null || checkOutDate == null) {
      setState(() {
        availableRooms = [];
        selectedRoom = null;
      });
      return;
    }

    final snap = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.docId)
        .get();
    if (!snap.exists) return;

    final data = snap.data();
    final List<dynamic> rooms = data?['rooms'] ?? [];
    final List<String> free = [];

    for (final r in rooms) {
      final String roomNo = (r['roomNo'] ?? '').toString();
      final List<dynamic> bookedRaw = List.from(r['bookedDates'] ?? []);
      final Set<String> booked = bookedRaw.map((e) => e.toString()).toSet();

      bool overlap = false;
      DateTime d = checkInDate!;
      while (!d.isAfter(checkOutDate!.subtract(const Duration(days: 1)))) {
        if (booked.contains(_isoDay.format(d))) {
          overlap = true;
          break;
        }
        d = d.add(const Duration(days: 1));
      }

      if (!overlap) free.add(roomNo);
    }

    setState(() {
      availableRooms = free;
      selectedRoom = null;
    });
  }

  Future<void> _selectDate(BuildContext context, bool isCheckIn) async {
    final today = DateTime.now();
    DateTime initial = today;
    DateTime first = today;

    if (!isCheckIn && checkInDate != null) {
      first = checkInDate!.add(const Duration(days: 1));
      initial = first;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime(2026, 12, 31),
    );
    if (picked == null) return;

    setState(() {
      if (isCheckIn) {
        checkInDate = picked;
        if (checkOutDate == null || !checkOutDate!.isAfter(checkInDate!)) {
          checkOutDate = checkInDate!.add(const Duration(days: 1));
        }
      } else {
        checkOutDate = picked;
      }
    });

    await _filterAvailableRooms();
  }

  Future<void> _openRoomMap() async {
    if (checkInDate == null || checkOutDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select dates first.")),
      );
      return;
    }
    if (availableRooms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No rooms available for the selected dates.")),
      );
      return;
    }

    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => RoomMapPage(
          floorId: widget.floorId,
          availableRooms: availableRooms,
          initialSelectedRoom: selectedRoom,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        selectedRoom = result;
      });
    }
  }

  Future<void> _confirmBooking() async {
    if (checkInDate == null || checkOutDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select dates.")),
      );
      return;
    }
    if (selectedRoom == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a room on the map.")),
      );
      return;
    }

    try {
      final nights = checkOutDate!.difference(checkInDate!).inDays;
      final priceRegex = RegExp(r'(\d+)');
      final match = priceRegex.firstMatch(widget.price);
      final pricePerNight = int.tryParse(match?.group(1) ?? '0') ?? 0;
      final totalAmount = pricePerNight * nights * 100;

      final bookingDetails = {
        'roomTypeId': widget.docId,
        'roomTypeTitle': widget.title,
        'roomNo': selectedRoom,
        'priceText': widget.price,
        'description': widget.description,
        'guests': guests,
        'checkIn': Timestamp.fromDate(checkInDate!),
        'checkOut': Timestamp.fromDate(checkOutDate!),
        'nights': nights,
        'imageName': widget.imageName,
        'totalAmount': totalAmount,
        'floorId': widget.floorId,
      };

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentScreen(
            totalAmount: totalAmount,
            bookingDetails: bookingDetails,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  // 🪄 构建顶部展示区域 (图片/3D)
  Widget _buildDisplayArea() {
    String rawName = widget.imageName.split('.').first;
    String modelPath = 'assets/models/$rawName.glb';

    // 动态计算高度
    double displayHeight = _show3D ? 350 : 260;

    // 决定是否显示加载圈：(正在准备加载) 或者 (已经切换到3D但模型还没渲染好)
    bool showLoader = _isModelLoading || (_show3D && !_isModelReady);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: displayHeight,
      width: double.infinity,
      decoration: BoxDecoration(
        color: _show3D ? Colors.grey[200] : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        boxShadow: _show3D
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ]
            : [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // ---------------------------------------------
            // 1. 底层：始终放置一张静态图片
            //    (这样在 3D 加载出来之前，或者切回 Photos 模式时，用户都能看到东西)
            // ---------------------------------------------
            Positioned.fill(
              child: Image.asset(
                'assets/rooms/${widget.imageName}',
                fit: BoxFit.cover,
              ),
            ),

            // ---------------------------------------------
            // 2. 中层：3D 模型视图
            // ---------------------------------------------
            Positioned.fill(
              child: Visibility(
                visible: _show3D,    // 只有 _show3D 为 true 时才可见
                maintainState: true, // 🔥 核心：隐藏时不要销毁，保持在内存中！
                child: ModelViewer(
                  key: ValueKey(modelPath), 
                  src: modelPath,
                  alt: "Room 3D Model",
                  autoRotate: true,
                  cameraControls: true,
                  backgroundColor: Colors.grey[200]!,
                  // 监听：当 WebView 创建成功，说明 3D 引擎开始启动
                  onWebViewCreated: (controller) {
                    // ⚠️ 修复点：这里无法直接监听进度，我们用一个延时来模拟“加载完成”
                    // 因为本地模型加载很快，1秒通常足够解析并渲染第一帧
                    Future.delayed(const Duration(milliseconds: 1000), () {
                      if (mounted) {
                        setState(() {
                          _isModelReady = true; 
                          _isModelLoading = false;
                        });
                      }
                    });
                  },
                ),
              ),
            ),

            // ---------------------------------------------
            // 3. 顶层：加载指示器
            // ---------------------------------------------
            if (showLoader)
              Container(
                color: Colors.black12, // 半透明遮罩
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                ),
              ),

            // ---------------------------------------------
            // 4. 浮动层：切换按钮 (保持不变)
            // ---------------------------------------------
            Positioned(
              top: 12,
              right: 12,
              child: GestureDetector(
                onTap: () {
                  if (_isModelLoading) return;

                  if (_show3D) {
                    setState(() {
                      _show3D = false;
                    });
                  } else {
                    if (_isModelReady) {
                      setState(() {
                        _show3D = true;
                      });
                    } else {
                      // 第一次加载
                      setState(() {
                        _isModelLoading = true;
                      });
                      // 给 UI 一点时间渲染 loading，再启动 3D
                      Future.delayed(const Duration(milliseconds: 100), () {
                        if (mounted) {
                          setState(() {
                            _show3D = true;
                          });
                        }
                      });
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _show3D ? Icons.image_outlined : Icons.view_in_ar_rounded,
                        size: 18,
                        color: Colors.black87,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _show3D ? "Photos" : "3D View",
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // ... 底部提示文字代码保持不变
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(
          color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🖼️ 替换原有的 Image.asset 为新的构建方法
            _buildDisplayArea(),

            const SizedBox(height: 20),
            
            // 标题和价格
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  widget.price,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600, color: Colors.blueAccent),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // 描述
            Text(
              widget.description,
              style: const TextStyle(fontSize: 15, height: 1.6, color: Colors.black87),
            ),
            
            const SizedBox(height: 24),
            
            // Booking Details Header
            const Text(
              "Booking Details",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
            // 表单区域
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 2,
                    blurRadius: 10,
                  )
                ],
              ),
              child: Column(
                children: [
                  _buildRow(
                    "Check-in",
                    _formatDate(checkInDate),
                    () => _selectDate(context, true),
                  ),
                  const Divider(height: 24),
                  _buildRow(
                    "Check-out",
                    _formatDate(checkOutDate),
                    () => _selectDate(context, false),
                  ),
                  const Divider(height: 24),
                  
                  // Guests Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Guests",
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: guests > 1
                                ? () => setState(() => guests--)
                                : null,
                            color: Colors.grey,
                          ),
                          SizedBox(
                            width: 30,
                            child: Center(
                              child: Text(
                                '$guests',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () => setState(() => guests++),
                            color: Colors.black,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // ------- 选择房间（跳转地图页面） -------
                  InkWell(
                    onTap: _openRoomMap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Select Room",
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                          ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: selectedRoom == null 
                                      ? Colors.grey[100] 
                                      : Colors.blue[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  selectedRoom == null
                                      ? "Choose on Map"
                                      : "Room $selectedRoom",
                                  style: TextStyle(
                                    color: selectedRoom == null
                                        ? Colors.grey
                                        : Colors.blue[800],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.map_outlined, size: 20, color: Colors.grey),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // 提示信息
                  if (checkInDate == null || checkOutDate == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 14, color: Colors.orange[300]),
                            const SizedBox(width: 4),
                            const Text(
                              "Select dates first to view available rooms",
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // 确认按钮
            GestureDetector(
              onTap: _confirmBooking,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF1A1A1A),
                      Color(0xFF333333),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    "Confirm Booking",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  label == "Check-in" ? Icons.login : Icons.logout,
                  size: 20, 
                  color: Colors.grey[600]
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                value,
                style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? d) =>
      d == null ? "Select Date" : _uiFmt.format(d);
}