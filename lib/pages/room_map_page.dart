import 'package:flutter/material.dart';
import 'room_map_selector.dart';

class RoomMapPage extends StatefulWidget {
  /// 进入页面时默认楼层，比如 '8F'
  final String floorId;

  /// 所有可用房间号（可能包含 801–816、901–916、1201–1216 等）
  final List<String> availableRooms;

  /// 如果一开始已经选过房间，可以传进来；否则为 null
  final String? initialSelectedRoom;

  const RoomMapPage({
    super.key,
    required this.floorId,
    required this.availableRooms,
    this.initialSelectedRoom,
  });

  @override
  State<RoomMapPage> createState() => _RoomMapPageState();
}

class _RoomMapPageState extends State<RoomMapPage> {
  /// 当前显示的楼层，形如 '8F'、'12F'
  late String _currentFloorId;

  /// 当前选中的房间号
  String? _selectedRoom;

  @override
  void initState() {
    super.initState();

    _selectedRoom = widget.initialSelectedRoom;

    // 先算出有哪些楼层
    final floors = _computeFloorIds();

    // 如果传进来的 floorId 在可用楼层里，就用它；否则默认用第一个楼层
    if (floors.contains(widget.floorId)) {
      _currentFloorId = widget.floorId;
    } else if (floors.isNotEmpty) {
      _currentFloorId = floors.first;
    } else {
      // 防御：没有房间时随便给一个，避免空字符串
      _currentFloorId = widget.floorId;
    }
  }

  /// 根据 availableRooms 计算有哪些楼层
  /// 例如 ['801', '802', '902', '1208'] -> ['8F', '9F', '12F']
  List<String> _computeFloorIds() {
    final set = <String>{};

    for (final room in widget.availableRooms) {
      if (room.length >= 3) {
        // 3 位房号：801 -> 楼层 '8'
        // 4 位房号：1208 -> 楼层 '12'
        final floorNumber =
            room.length == 3 ? room.substring(0, 1) : room.substring(0, 2);
        set.add('${floorNumber}F');
      }
    }

    final list = set.toList()
      ..sort((a, b) {
        // 按数字排序：'8F'、'9F'、'10F'...
        int pa = int.tryParse(a.replaceAll('F', '')) ?? 0;
        int pb = int.tryParse(b.replaceAll('F', '')) ?? 0;
        return pa.compareTo(pb);
      });
    return list;
  }

  /// 按楼层过滤可用房间号
  List<String> _roomsForFloor(String floorId) {
    // '8F' -> '8'，'12F' -> '12'
    final prefix = floorId.replaceAll('F', '');
    final rooms = widget.availableRooms
        .where((r) => r.startsWith(prefix))
        .toList()
      ..sort(); // 顺便按房号排序
    return rooms;
  }

  /// 切换楼层时调用
  void _changeFloor(String floorId) {
    setState(() {
      _currentFloorId = floorId;

      // 如果之前选的房间不属于当前楼层，就清空选中
      final floorRooms = _roomsForFloor(floorId);
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
    final floorRooms = _roomsForFloor(_currentFloorId);
    final floorIds = _computeFloorIds(); // 只包含真正有房间的楼层

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Room on Map'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        foregroundColor: Colors.black,
      ),
      body: Stack(
        children: [
          // 背景图
          Positioned.fill(
            child: Image.asset(
              'assets/seacity.jpg', // 你的背景图路径
              fit: BoxFit.cover,
            ),
          ),
          // 半透明蒙层
          Positioned.fill(
            child: Container(color: Colors.black26),
          ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 12),

                Expanded(
  child: Align(
    alignment: Alignment.topCenter, // 顶部居中
    child: Padding(
      padding: const EdgeInsets.only(top: 246), // 往下 24px，数值越大越靠下
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 0),
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
                          // ---------- 楼层切换按钮（根据 availableRooms 动态生成） ----------
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: floorIds.map((floorId) {
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  child: ChoiceChip(
                                    label: Text(floorId),
                                    selected: _currentFloorId == floorId,
                                    onSelected: (_) => _changeFloor(floorId),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // ---------- 地图选房 ----------
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
                // 底部确认按钮
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
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
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
