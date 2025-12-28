import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/booking_availability.dart'; // normalizeRoomNo
import 'room_map_selector.dart' show getRoomsForFloor;
import 'room_map_selector_staff.dart';

/// ========== Firebase 房型模型（rooms collection 每个 doc） ==========
class RoomTypeDoc {
  final String id; // R01 / R02 ...
  final String titleEN; // 显示用
  final List<String> roomNos; // doc.rooms[].roomNo

  const RoomTypeDoc({
    required this.id,
    required this.titleEN,
    required this.roomNos,
  });

  static RoomTypeDoc fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>? ?? {});
    final titleEN = (data['titleEN'] ?? doc.id).toString();

    final List<String> roomNos = [];
    final rawRooms = data['rooms'];

    if (rawRooms is List) {
      for (final item in rawRooms) {
        if (item is Map<String, dynamic>) {
          final rn = item['roomNo'];
          if (rn != null) roomNos.add(normalizeRoomNo(rn.toString()));
        } else if (item is Map) {
          final rn = item['roomNo'];
          if (rn != null) roomNos.add(normalizeRoomNo(rn.toString()));
        }
      }
    }

    return RoomTypeDoc(
      id: doc.id,
      titleEN: titleEN,
      roomNos: roomNos,
    );
  }
}

/// ========== UI 分组模型 ==========
class RoomTypeGroup {
  final String typeId;
  final String name;
  final List<String> roomNos;

  const RoomTypeGroup({
    required this.typeId,
    required this.name,
    required this.roomNos,
  });
}

class StaffRoomPage extends StatefulWidget {
  const StaffRoomPage({super.key});

  @override
  State<StaffRoomPage> createState() => _StaffRoomPageState();
}

class _StaffRoomPageState extends State<StaffRoomPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _rightScroll = ScrollController();

  String _selectedFloorId = '08F';

  late final Map<String, GlobalKey> _floorKeys;

  List<RoomTypeDoc> _roomTypes = const [];
  StreamSubscription<QuerySnapshot>? _roomTypesSub;

  DateTime _selectedDate = DateTime.now();

  final Map<String, Set<String>> _bookedByFloor = {};
  Timer? _debounce;

  final List<String> _floors = const [
    '08F','09F','10F','11F','12F','13F','14F','15F','16F','17F',
    '18F','19F','20F','21F','22F','23F','24F','25F','26F',
  ];

  @override
  void initState() {
    super.initState();
    _floorKeys = {for (final f in _floors) f: GlobalKey()};

    _roomTypesSub = FirebaseFirestore.instance
        .collection('rooms')
        .snapshots()
        .listen((snap) {
      final types = snap.docs.map(RoomTypeDoc.fromFirestore).toList();
      types.sort((a, b) => a.titleEN.compareTo(b.titleEN));
      if (mounted) setState(() => _roomTypes = types);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reloadAllFloorsBooked();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _rightScroll.dispose();
    _roomTypesSub?.cancel();
    super.dispose();
  }

  // ✅ floorId 统一：8F -> 08F
  String _normalizeFloorId(String floorId) {
    final m = RegExp(r'^(\d{1,2})F$').firstMatch(floorId.trim());
    if (m == null) return floorId.trim();
    final n = int.tryParse(m.group(1)!) ?? 0;
    return '${n.toString().padLeft(2, '0')}F';
  }

  // ✅ 兼容：08F <-> 8F（用于查询 whereIn）
  List<String> _floorVariants(String floorId) {
    final norm = _normalizeFloorId(floorId); // 08F
    final num = int.tryParse(norm.replaceAll('F', '')) ?? 0;
    final short = '${num}F'; // 8F
    if (short == norm) return [norm];
    return [norm, short];
  }

  // ✅ DateTime -> "YYYY-MM-DD"
  String _ymd(DateTime d) {
    final dt = DateTime(d.year, d.month, d.day);
    return "${dt.year.toString().padLeft(4, '0')}-"
        "${dt.month.toString().padLeft(2, '0')}-"
        "${dt.day.toString().padLeft(2, '0')}";
  }

  // ============================
  // ✅ 查 booked rooms（只拿 roomNo 集合）
  // ============================
  Future<Set<String>> _fetchBookedRoomsForFloor(String floorId) async {
    final dateKey = _ymd(_selectedDate);
    final variants = _floorVariants(floorId);

    final snap = await FirebaseFirestore.instance
        .collection('bookings')
        .where('floorId', whereIn: variants)
        .where('status', whereIn: const ['pending', 'confirmed'])
        .where('activeDates', arrayContains: dateKey)
        .get();

    final set = <String>{};
    for (final d in snap.docs) {
      final data = d.data();
      final rn = (data['roomNo'] ?? '').toString();
      if (rn.trim().isNotEmpty) {
        set.add(normalizeRoomNo(rn));
      }
    }
    return set;
  }

  Future<void> _reloadAllFloorsBooked() async {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () async {
      final results = <String, Set<String>>{};
      for (final f in _floors) {
        try {
          results[f] = await _fetchBookedRoomsForFloor(f);
        } catch (_) {
          results[f] = <String>{};
        }
      }
      if (!mounted) return;
      setState(() {
        _bookedByFloor
          ..clear()
          ..addAll(results);
      });
    });
  }

  Future<void> _reloadOneFloorBooked(String floorId) async {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () async {
      try {
        final set = await _fetchBookedRoomsForFloor(floorId);
        if (!mounted) return;
        setState(() => _bookedByFloor[floorId] = set);
      } catch (_) {
        if (!mounted) return;
        setState(() => _bookedByFloor[floorId] = <String>{});
      }
    });
  }

  List<String> _getAvailableRoomsForFloor(String floorId) {
    final all = getRoomsForFloor(floorId).map((r) => normalizeRoomNo(r.roomNo)).toSet();
    final booked = _bookedByFloor[floorId] ?? <String>{};
    final available = all.difference(booked).toList();
    available.sort();
    return available;
  }

  List<String> _getBookedRoomsForFloor(String floorId) {
    final booked = _bookedByFloor[floorId] ?? <String>{};
    final list = booked.toList()..sort();
    return list;
  }

  String _floorPrefix(String floorId) {
    final fid = _normalizeFloorId(floorId);
    return fid.substring(0, 2);
  }

  List<RoomTypeGroup> _buildRoomTypesForFloor(String floorId) {
    final prefix = _floorPrefix(floorId);
    if (_roomTypes.isEmpty) return const [];

    final groups = <RoomTypeGroup>[];
    for (final type in _roomTypes) {
      final onThisFloor = <String>[];
      for (final rn in type.roomNos) {
        final no = normalizeRoomNo(rn);
        final onlyDigits = RegExp(r'^\d+$').hasMatch(no);
        if (onlyDigits && no.length >= 2 && no.substring(0, 2) == prefix) {
          onThisFloor.add(no);
        }
      }
      if (onThisFloor.isNotEmpty) {
        groups.add(RoomTypeGroup(typeId: type.id, name: type.titleEN, roomNos: onThisFloor));
      }
    }
    return groups;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final init = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(now.year - 1, 1, 1),
      lastDate: DateTime(now.year + 2, 12, 31),
    );

    if (picked == null) return;

    setState(() => _selectedDate = picked);
    await _reloadAllFloorsBooked();
  }

  void _onSearchChanged(String raw) {
    final q = raw.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() {});
      return;
    }

    String? hitFloor;

    for (final floorId in _floors) {
      final groups = _buildRoomTypesForFloor(floorId);

      final hitType = groups.any((g) => g.name.toLowerCase().contains(q));
      final hitRoom = groups.any((g) => g.roomNos.any((r) => r.toLowerCase().contains(q)));

      if (hitType || hitRoom) {
        hitFloor = floorId;
        break;
      }
    }

    if (hitFloor != null) {
      setState(() => _selectedFloorId = hitFloor!);
      _scrollToFloorTop(hitFloor!);

      if (!_bookedByFloor.containsKey(hitFloor)) {
        _reloadOneFloorBooked(hitFloor!);
      }
    } else {
      setState(() {});
    }
  }

  void _onFloorTap(String floorId) {
    setState(() => _selectedFloorId = floorId);
    _scrollToFloorTop(floorId);

    if (!_bookedByFloor.containsKey(floorId)) {
      _reloadOneFloorBooked(floorId);
    }
  }

  void _scrollToFloorTop(String floorId) {
    final key = _floorKeys[floorId];
    if (key == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = key.currentContext;
      if (ctx == null) return;

      Scrollable.ensureVisible(
        ctx,
        alignment: 0.02,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  bool _floorMatchesSearch(String floorId, String q) {
    if (q.isEmpty) return false;
    final groups = _buildRoomTypesForFloor(floorId);
    return groups.any((g) =>
        g.name.toLowerCase().contains(q) || g.roomNos.any((r) => r.toLowerCase().contains(q)));
  }

  // =========================================================
  // ✅ 点击紫色 booked 房间：查 booking + 弹窗显示住户信息
  // =========================================================
  Future<void> _openBookedRoomInfo({
    required String floorId,
    required String roomNo,
  }) async {
    final dateKey = _ymd(_selectedDate);
    final variants = _floorVariants(floorId);
    final rn = normalizeRoomNo(roomNo);

    try {
      // 找到当日占用该房的 booking（取第一条）
      final snap = await FirebaseFirestore.instance
          .collection('bookings')
          .where('floorId', whereIn: variants)
          .where('roomNo', isEqualTo: rn)
          .where('status', whereIn: const ['pending', 'confirmed'])
          .where('activeDates', arrayContains: dateKey)
          .limit(1)
          .get();

      if (!mounted) return;

      if (snap.docs.isEmpty) {
        // bookedSet 里有，但查不到 -> 数据不同步也给提示
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Booking not found'),
            content: Text('No active booking found for Room $rn on $dateKey.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
            ],
          ),
        );
        return;
      }

      final doc = snap.docs.first;
      final data = doc.data();

      // 常用字段（你截图里有的）
      final status = (data['status'] ?? '').toString();
      final checkIn = (data['checkInDate'] ?? '').toString();
      final checkOut = (data['checkOutDate'] ?? '').toString();
      final guestCount = (data['guestCount'] ?? '').toString();
      final priceText = (data['priceText'] ?? '').toString();
      final roomTypeTitle = (data['roomTypeTitle'] ?? '').toString();
      final createdByRole = (data['createdByRole'] ?? '').toString();
      final createdByUid = (data['createdByUid'] ?? '').toString();

      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Room $rn • Booking Info'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv('Date', dateKey),
                const SizedBox(height: 6),
                _kv('Status', status),
                _kv('Room Type', roomTypeTitle),
                _kv('Guest Count', guestCount),
                _kv('Check-in', checkIn),
                _kv('Check-out', checkOut),
                _kv('Price', priceText),
                const Divider(height: 18),
                _kv('Created By Role', createdByRole),
                _kv('Created By UID', createdByUid),
                _kv('Booking Doc ID', doc.id),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Error'),
          content: Text('Failed to load booking info.\n$e'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
    }
  }

  static Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w700))),
          Expanded(child: Text(v.isEmpty ? '-' : v)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _searchCtrl.text.trim().toLowerCase();
    final dateLabel = _ymd(_selectedDate);

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search room type / room no (e.g., Standard Twin, 0810)...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchCtrl.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.clear),
                            ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(dateLabel),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Row(
              children: [
                // 左侧楼层
                SizedBox(
                  width: 110,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(right: BorderSide(color: Theme.of(context).dividerColor)),
                    ),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _floors.length,
                      itemBuilder: (context, index) {
                        final floorId = _floors[index];
                        final isSelected = floorId == _selectedFloorId;
                        final isHit = _floorMatchesSearch(floorId, q);
                        final highlight = isSelected || isHit;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ElevatedButton(
                            onPressed: () => _onFloorTap(floorId),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: highlight ? 2 : 0,
                              backgroundColor: highlight
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.surfaceContainerHighest,
                              foregroundColor: highlight
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context).colorScheme.onSurface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(floorId, textAlign: TextAlign.center),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // 右侧楼层内容
                Expanded(
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _rightScroll,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                      child: Column(
                        children: _floors.map((floorId) {
                          final shouldShow = q.isEmpty || _floorMatchesSearch(floorId, q);
                          if (!shouldShow) return const SizedBox.shrink();

                          final groups = _buildRoomTypesForFloor(floorId);
                          final floorBooked = _getBookedRoomsForFloor(floorId);
                          final floorAvailable = _getAvailableRoomsForFloor(floorId);

                          if (_roomTypes.isEmpty) {
                            return Container(
                              key: _floorKeys[floorId],
                              margin: const EdgeInsets.only(bottom: 18),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Theme.of(context).dividerColor),
                              ),
                              child: Row(
                                children: const [
                                  SizedBox(width: 6),
                                  Text('Loading room types...'),
                                  Spacer(),
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ],
                              ),
                            );
                          }

                          return _FloorBlock(
                            key: _floorKeys[floorId],
                            floorId: floorId,
                            groups: groups,
                            floorAvailableRooms: floorAvailable,
                            floorBookedRooms: floorBooked,
                            onBookedTap: (roomNo) => _openBookedRoomInfo(
                              floorId: floorId,
                              roomNo: roomNo,
                            ),
                          );
                        }).toList(),
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

/// ========== 一个楼层的 UI 块 ==========
class _FloorBlock extends StatelessWidget {
  final String floorId;
  final List<RoomTypeGroup> groups;

  final List<String> floorAvailableRooms;
  final List<String> floorBookedRooms;

  /// 点击紫色 booked 房间
  final ValueChanged<String> onBookedTap;

  const _FloorBlock({
    super.key,
    required this.floorId,
    required this.groups,
    required this.floorAvailableRooms,
    required this.floorBookedRooms,
    required this.onBookedTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.layers, size: 18, color: Theme.of(context).hintColor),
              const SizedBox(width: 8),
              Text(
                'Floor $floorId',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 12),

          ...groups.map((g) {
            final typeRooms = g.roomNos.map(normalizeRoomNo).toList();

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 房型名称底框
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Text(
                      g.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  StaffRoomMapSelector(
                    floorId: floorId,
                    typeRooms: typeRooms,
                    availableRooms: floorAvailableRooms, // 蓝色（不可点）
                    bookedRooms: floorBookedRooms, // 紫色（可点）
                    onBookedTap: onBookedTap,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
