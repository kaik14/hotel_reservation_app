import 'package:flutter/material.dart';
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
  List<String> _availableRoomsAll = [];

  /// ✅ 把 floorId 统一成两位数格式：8F -> 08F
  String _normalizeFloorId(String floorId) {
    final m = RegExp(r'^(\d{1,2})F$').firstMatch(floorId.trim());
    if (m == null) return floorId.trim();
    final n = int.tryParse(m.group(1)!) ?? 0;
    return '${n.toString().padLeft(2, '0')}F';
  }

  @override
  void initState() {
    super.initState();

    _selectedRoom = widget.initialSelectedRoom == null
        ? null
        : normalizeRoomNo(widget.initialSelectedRoom!);

    _currentFloorId = _normalizeFloorId(widget.floorId);

    _loadAvailableRooms();
  }

  Future<void> _loadAvailableRooms() async {
    setState(() => _loading = true);

    try {
      final list = await getAvailableRoomNosFromFirestore(
        roomTypeId: widget.roomTypeId,
        checkIn: widget.checkIn,
        checkOut: widget.checkOut,
      );

      _availableRoomsAll = list.map(normalizeRoomNo).toList();

      final floors = _computeFloorIds();

      final wanted = _normalizeFloorId(widget.floorId);
      if (floors.contains(wanted)) {
        _currentFloorId = wanted;
      } else if (floors.isNotEmpty) {
        _currentFloorId = floors.first;
      }

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

  /// 从房号提取楼层（只取开头数字，比如 0801 -> 08F，1208 -> 12F）
  String? _floorIdFromRoomNo(String roomNo) {
    final rn = normalizeRoomNo(roomNo);
    final m = RegExp(r'^(\d{2})').firstMatch(rn);
    if (m == null) return null;
    return '${m.group(1)}F';
  }

  List<String> _computeFloorIds() {
    final set = <String>{};

    for (final room in _availableRoomsAll) {
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

  List<String> _roomsForFloor(String floorId) {
    final fid = _normalizeFloorId(floorId);
    final prefix = fid.replaceAll('F', ''); // 08 / 12
    final rooms = _availableRoomsAll.where((r) => r.startsWith(prefix)).toList()..sort();
    return rooms;
  }

  void _changeFloor(String floorId) {
    final fid = _normalizeFloorId(floorId);

    setState(() {
      _currentFloorId = fid;

      final floorRooms = _roomsForFloor(fid);
      if (_selectedRoom != null && !floorRooms.contains(_selectedRoom)) {
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
    Navigator.pop(context, _selectedRoom);
  }

  @override
  Widget build(BuildContext context) {
    final floorIds = _computeFloorIds();
    final floorRooms = _roomsForFloor(_currentFloorId);

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
            onPressed: _loadAvailableRooms,
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
                                      children: (floorIds.isEmpty ? [_currentFloorId] : floorIds)
                                          .map((fid) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 4),
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
                                    availableRooms: floorRooms,
                                    selectedRoom: _selectedRoom,
                                    onSelected: (roomNo) {
                                      setState(() => _selectedRoom = roomNo);
                                    },
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
