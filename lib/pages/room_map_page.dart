import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'room_map_selector.dart';
import '../utils/booking_availability.dart';

class RoomMapPage extends StatefulWidget {
  /// 你传进来的 floorId 可能是 8F / 08F，都可以
  final String floorId;

  /// ✅ rooms collection doc id，例如 "R02"
  final String roomTypeId;

  /// ✅ 用户选的入住/退房日期
  final DateTime checkIn;
  final DateTime checkOut;

  final String? initialSelectedRoom;

  const RoomMapPage({
    super.key,
    required this.floorId,
    required this.roomTypeId,
    required this.checkIn,
    required this.checkOut,
    this.initialSelectedRoom,
  });

  @override
  State<RoomMapPage> createState() => _RoomMapPageState();
}

class _RoomMapPageState extends State<RoomMapPage> {
  late String _currentFloorId;
  String? _selectedRoom;

  bool _loading = true;

  /// ✅ 这个是“该房型所有房间”（库存，不考虑是否已被订）
  List<String> _allRoomsAll = [];

  /// ✅ 这个是“真正可选房间”（= allRooms - booked）
  List<String> _availableRoomsAll = [];

  /// ✅ 被订房：按楼层缓存
  final Map<String, Set<String>> _bookedRoomsByFloor = {};

  /// ✅ floorId 统一成两位数：8F -> 08F
  String _normalizeFloorId(String floorId) {
    final m = RegExp(r'^(\d{1,2})F$').firstMatch(floorId.trim());
    if (m == null) return floorId.trim();
    final n = int.tryParse(m.group(1)!) ?? 0;
    return '${n.toString().padLeft(2, '0')}F';
  }

  /// ✅ DateTime -> "YYYY-MM-DD"
  String _ymd(DateTime d) {
    final x = DateTime(d.year, d.month, d.day);
    return '${x.year.toString().padLeft(4, '0')}-'
        '${x.month.toString().padLeft(2, '0')}-'
        '${x.day.toString().padLeft(2, '0')}';
  }

  /// ✅ activeDates（按天）：checkIn 含，checkOut 不含
  List<String> _buildActiveDates(DateTime checkIn, DateTime checkOut) {
    final start = DateTime(checkIn.year, checkIn.month, checkIn.day);
    final end = DateTime(checkOut.year, checkOut.month, checkOut.day);

    final days = <String>[];
    for (var d = start; d.isBefore(end); d = d.add(const Duration(days: 1))) {
      days.add(_ymd(d));
    }
    return days;
  }

  /// ✅ 从房号提取楼层（0801 -> 08F，1208 -> 12F）
  String? _floorIdFromRoomNo(String roomNo) {
    final rn = normalizeRoomNo(roomNo);
    final m = RegExp(r'^(\d{2})').firstMatch(rn);
    if (m == null) return null;
    return '${m.group(1)}F';
  }

  @override
  void initState() {
    super.initState();

    _selectedRoom = widget.initialSelectedRoom == null
        ? null
        : normalizeRoomNo(widget.initialSelectedRoom!);

    _currentFloorId = _normalizeFloorId(widget.floorId);

    _loadAllRoomsAndAvailability();
  }

  /// =========================================================
  /// ✅ 重点：加载“该房型所有房间” + 查询 bookings 得到 bookedRooms
  /// =========================================================
  Future<void> _loadAllRoomsAndAvailability() async {
    setState(() => _loading = true);

    try {
      // 1) 先拿该房型所有房间（库存）
      final all = await getAvailableRoomNosFromFirestore(
        roomTypeId: widget.roomTypeId,
        checkIn: widget.checkIn,
        checkOut: widget.checkOut,
      );

      // 你的工具函数名字叫 getAvailableRoomNosFromFirestore，
      // 但很多同学其实用它当“该房型所有房间列表”。
      // 我这里统一当“库存列表”，后面会减去 bookedRooms 得到真正可用。
      _allRoomsAll = all.map(normalizeRoomNo).toList();

      // 2) 计算 activeDates（按天）
      final activeDates = _buildActiveDates(widget.checkIn, widget.checkOut);

      // 3) 查全局 bookings：把这些天里已占用的房间抓出来
      await _loadBookedRoomsFromGlobalBookings(
        activeDates: activeDates,
      );

      // 4) 计算真正可用房：all - booked（按楼层）
      _recomputeAvailability();

      // 5) 设置当前楼层
      final floors = _computeFloorIds();
      final wanted = _normalizeFloorId(widget.floorId);

      if (floors.contains(wanted)) {
        _currentFloorId = wanted;
      } else if (floors.isNotEmpty) {
        _currentFloorId = floors.first;
      }

      // 6) 如果已选房已变不可用，清掉
      if (_selectedRoom != null && !_availableRoomsAll.contains(_selectedRoom)) {
        _selectedRoom = null;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load rooms: $e')),
        );
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  /// =========================================================
  /// ✅ 从全局 bookings 集合里查 booked 房间
  /// - 用 activeDates array-contains-any（一次最多 10 个）
  /// - 所以要分批查询，再合并
  /// =========================================================
  Future<void> _loadBookedRoomsFromGlobalBookings({
    required List<String> activeDates,
  }) async {
    _bookedRoomsByFloor.clear();

    // 没有天数就不查
    if (activeDates.isEmpty) return;

    final firestore = FirebaseFirestore.instance;
    final bookingsRef = firestore.collection('bookings');

    // Firestore 限制：array-contains-any 最多 10 个
    final chunks = <List<String>>[];
    for (int i = 0; i < activeDates.length; i += 10) {
      chunks.add(activeDates.sublist(
        i,
        (i + 10 > activeDates.length) ? activeDates.length : i + 10,
      ));
    }

    // 逐批查
    for (final chunk in chunks) {
      final snap = await bookingsRef
          .where('roomTypeId', isEqualTo: widget.roomTypeId) // 只查该房型
          .where('activeDates', arrayContainsAny: chunk)
          .where('status', whereIn: ['confirmed', 'paid']) // 只算已确认/已支付
          .get();

      for (final doc in snap.docs) {
        final data = doc.data();

        final floorId = _normalizeFloorId((data['floorId'] ?? '').toString());
        final roomNo = normalizeRoomNo((data['roomNo'] ?? '').toString());

        if (floorId.isEmpty || roomNo.isEmpty) continue;

        _bookedRoomsByFloor.putIfAbsent(floorId, () => <String>{});
        _bookedRoomsByFloor[floorId]!.add(roomNo);
      }
    }
  }

  /// ✅ 重新计算可用房：allRooms - bookedRooms（跨楼层）
  void _recomputeAvailability() {
    final bookedAll = <String>{};

    for (final entry in _bookedRoomsByFloor.entries) {
      bookedAll.addAll(entry.value);
    }

    _availableRoomsAll = _allRoomsAll
        .where((r) => !bookedAll.contains(normalizeRoomNo(r)))
        .map(normalizeRoomNo)
        .toList();
  }

  /// ✅ 计算有哪些楼层（用 allRoomsAll，这样“整层满房”也还会显示出来）
  List<String> _computeFloorIds() {
    final set = <String>{};

    for (final room in _allRoomsAll) {
      final floorId = _floorIdFromRoomNo(room);
      if (floorId != null) set.add(floorId);
    }

    final list = set.toList()
      ..sort((a, b) {
        int pa = int.tryParse(a.replaceAll('F', '')) ?? 0;
        int pb = int.tryParse(b.replaceAll('F', '')) ?? 0;
        return pa.compareTo(pb);
      });

    return list;
  }

  /// ✅ 某一层“库存房”
  List<String> _allRoomsForFloor(String floorId) {
    final fid = _normalizeFloorId(floorId);
    final prefix = fid.replaceAll('F', ''); // 08 / 12
    final rooms = _allRoomsAll
        .where((r) => normalizeRoomNo(r).startsWith(prefix))
        .map(normalizeRoomNo)
        .toList()
      ..sort();
    return rooms;
  }

  /// ✅ 某一层“真正可选房”
  List<String> _availableRoomsForFloor(String floorId) {
    final fid = _normalizeFloorId(floorId);
    final prefix = fid.replaceAll('F', ''); // 08 / 12
    final rooms = _availableRoomsAll
        .where((r) => normalizeRoomNo(r).startsWith(prefix))
        .map(normalizeRoomNo)
        .toList()
      ..sort();
    return rooms;
  }

  void _changeFloor(String floorId) {
    final fid = _normalizeFloorId(floorId);

    setState(() {
      _currentFloorId = fid;

      final floorAvail = _availableRoomsForFloor(fid);
      if (_selectedRoom != null && !floorAvail.contains(_selectedRoom)) {
        _selectedRoom = null;
      }
    });
  }

  void _onConfirm() {
    if (_selectedRoom == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a room.')),
      );
      return;
    }

    // ✅ 二次保险：确认时再判断一次（避免你停留在页面很久，期间被别人订走）
    final floorAvail = _availableRoomsForFloor(_currentFloorId);
    if (!floorAvail.contains(_selectedRoom)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This room has just been booked. Please choose another.'),
        ),
      );
      _loadAllRoomsAndAvailability();
      return;
    }

    Navigator.pop(context, _selectedRoom);
  }

  @override
  Widget build(BuildContext context) {
    final floorIds = _computeFloorIds();

    // ✅ 关键：RoomMapSelector 的 availableRooms 必须传“真正可选房”
    final floorAvail = _availableRoomsForFloor(_currentFloorId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Room on Map'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            onPressed: _loadAllRoomsAndAvailability,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh availability',
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/seacity.jpg', fit: BoxFit.cover),
          ),
          Positioned.fill(child: Container(color: Colors.black26)),
          SafeArea(
            child: _loading
                ? const Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(width: 12),
                            Text('Loading available rooms...'),
                          ],
                        ),
                      ),
                    ),
                  )
                : Column(
                    children: [
                      const SizedBox(height: 12),
                      Expanded(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 246),
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.18),
                                    blurRadius: 18,
                                    offset: const Offset(0, 9),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: (floorIds.isEmpty
                                              ? [_currentFloorId]
                                              : floorIds)
                                          .map((fid) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                          ),
                                          child: ChoiceChip(
                                            label: Text(fid),
                                            selected: _currentFloorId == fid,
                                            onSelected: (_) => _changeFloor(fid),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  RoomMapSelector(
                                    floorId: _currentFloorId,
                                    availableRooms: floorAvail, // ✅ 只传真正可选
                                    selectedRoom: _selectedRoom,
                                    onSelected: (roomNo) {
                                      setState(() => _selectedRoom = roomNo);
                                    },
                                  ),

                                  // （可选）给你显示一下 booked 数量，方便你调试
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      'Booked on ${_currentFloorId}: ${(_bookedRoomsByFloor[_currentFloorId] ?? {}).length}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black45,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _onConfirm,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              backgroundColor: const Color(0xFF5E4BB5),
                            ),
                            child: const Text(
                              'Confirm Room',
                              style: TextStyle(fontSize: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
