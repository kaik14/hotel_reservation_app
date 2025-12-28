import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// ----------- helpers -----------

String _ymd(DateTime d) => DateFormat('yyyy-MM-dd').format(DateTime(d.year, d.month, d.day));

/// 生成入住到退房之间的每一天（不含退房日）
/// checkIn=11-09, checkOut=11-11 => ["2025-11-09","2025-11-10"]
List<String> dateRangeYmd(DateTime checkIn, DateTime checkOut) {
  final start = DateTime(checkIn.year, checkIn.month, checkIn.day);
  final end = DateTime(checkOut.year, checkOut.month, checkOut.day);

  final days = <String>[];
  for (var d = start; d.isBefore(end); d = d.add(const Duration(days: 1))) {
    days.add(_ymd(d));
  }
  return days;
}

/// ✅ 把 Firestore 里的 roomNo 统一成你地图用的格式：
/// - 纯数字且长度=3 -> 补 0 变 4 位：801 -> 0801
/// - 纯数字且长度<4 -> 左补 0 到 4 位
/// - 非纯数字（MeetingR1）保持原样
String normalizeRoomNo(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return '';

  final isDigits = RegExp(r'^\d+$').hasMatch(t);
  if (!isDigits) return t;

  if (t.length >= 4) return t;
  return t.padLeft(4, '0');
}

/// ✅ 把 bookedDates 里的元素统一成 yyyy-MM-dd
String bookedDateToYmd(dynamic e) {
  if (e == null) return '';

  if (e is Timestamp) return _ymd(e.toDate());
  if (e is DateTime) return _ymd(e);

  final s = e.toString().trim();
  if (s.isEmpty) return '';

  // 如果已经是 yyyy-MM-dd
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) return s;

  // 常见：Timestamp(...) / 2025-11-09 00:00:00.000 / ISO8601
  // 尝试 parse
  final dt = DateTime.tryParse(s);
  if (dt != null) return _ymd(dt);

  // 再尝试只取前 10 位（很多 string 形态前面就是 yyyy-MM-dd）
  if (s.length >= 10 && RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(s.substring(0, 10))) {
    return s.substring(0, 10);
  }

  return s; // 最后兜底：原样返回（但可能无法命中冲突）
}

/// 从 rooms/{roomTypeId} 读取 rooms[]，并根据 bookedDates 过滤可用房号
/// ✅ 不改 Firebase（只读）
Future<List<String>> getAvailableRoomNosFromFirestore({
  required String roomTypeId, // e.g. "R02"
  required DateTime checkIn,
  required DateTime checkOut,
}) async {
  final needDates = dateRangeYmd(checkIn, checkOut).toSet();

  final doc = await FirebaseFirestore.instance.collection('rooms').doc(roomTypeId).get();
  final data = doc.data();
  if (data == null) return [];

  final List rooms = (data['rooms'] as List?) ?? [];
  final available = <String>[];

  for (final r in rooms) {
    if (r is! Map) continue;

    final rawRoomNo = (r['roomNo'] ?? r['roomNumber'] ?? r['number'] ?? r['no'] ?? '').toString();
    final roomNo = normalizeRoomNo(rawRoomNo);

    if (roomNo.isEmpty) continue;

    final bookedList = (r['bookedDates'] as List?) ?? [];
    final booked = bookedList.map(bookedDateToYmd).where((x) => x.isNotEmpty).toSet();

    final conflict = booked.intersection(needDates).isNotEmpty;
    if (!conflict) {
      available.add(roomNo);
    }
  }

  available.sort();
  return available;
}
