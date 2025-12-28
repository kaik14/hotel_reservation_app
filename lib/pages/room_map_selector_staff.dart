import 'package:flutter/material.dart';

import '../utils/booking_availability.dart'; // normalizeRoomNo
import 'room_map_selector.dart' show MapRoom, getRoomsForFloor;

class StaffRoomMapSelector extends StatelessWidget {
  final String floorId;

  /// 该房型在该楼层有哪些房间（决定哪些房间按状态上色）
  final List<String> typeRooms;

  /// 可订（未入住/未被预订）：仍显示蓝色，但不可点
  final List<String> availableRooms;

  /// 已订（入住/已预定）：紫色，可点击查看住户信息
  final List<String> bookedRooms;

  /// 点击紫色房间时回调（用于打开住户信息）
  final ValueChanged<String> onBookedTap;

  const StaffRoomMapSelector({
    super.key,
    required this.floorId,
    required this.typeRooms,
    required this.availableRooms,
    this.bookedRooms = const [],
    required this.onBookedTap,
  });

  @override
  Widget build(BuildContext context) {
    final allRoomsOnFloor = getRoomsForFloor(floorId);

    final typeSet = typeRooms.map(normalizeRoomNo).toSet();
    final availableSet = availableRooms.map(normalizeRoomNo).toSet();
    final bookedSet = bookedRooms.map(normalizeRoomNo).toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 3.0,
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              final h = c.maxHeight;

              return Stack(
                children: [
                  // 背景框
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                  ),

                  // ✅ 画整层所有房间
                  for (final room in allRoomsOnFloor)
                    Positioned(
                      left: room.left * w,
                      top: room.top * h,
                      width: room.width * w,
                      height: room.height * h,
                      child: _RoomBoxStaff(
                        roomNo: room.roomNo,
                        typeSet: typeSet,
                        availableSet: availableSet,
                        bookedSet: bookedSet,
                        onBookedTap: onBookedTap,
                      ),
                    ),

                  // ✅ 楼梯 & 电梯（照搬你的原布局）
                  Positioned(
                    left: 0.02 * w,
                    top: 0.60 * h,
                    width: 0.06 * w,
                    height: 0.38 * h,
                    child: _buildUtilityBox("Staircase", Icons.stairs),
                  ),
                  Positioned(
                    left: 0.91 * w,
                    top: 0.60 * h,
                    width: 0.06 * w,
                    height: 0.38 * h,
                    child: _buildUtilityBox("Staircase", Icons.stairs),
                  ),
                  Positioned(
                    left: 0.52 * w,
                    top: 0.02 * h,
                    width: 0.08 * w,
                    height: 0.38 * h,
                    child: _buildUtilityBox("Elevator", Icons.elevator),
                  ),
                ],
              );
            },
          ),
        ),

        const SizedBox(height: 8),

        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: const [
            _Legend(color: Colors.blue, label: 'Available (Not Clickable)'),
            _Legend(color: Color(0xFF7B61FF), label: 'Booked (Tap to View)', filled: true),
            _Legend(color: Color(0xFFBDBDBD), label: 'Other Rooms'),
          ],
        ),
      ],
    );
  }

  static Widget _buildUtilityBox(String label, IconData icon) {
    return IgnorePointer(
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.orange, width: 1),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: Colors.orange),
              const SizedBox(width: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ✅ Staff 版房间格子：
/// - 其它房间：灰色（只显示布局）
/// - 当前房型房间：
///   - booked：紫色 + 可点击
///   - available：蓝色 + 不可点击
class _RoomBoxStaff extends StatelessWidget {
  final String roomNo;

  final Set<String> typeSet;
  final Set<String> availableSet;
  final Set<String> bookedSet;

  final ValueChanged<String> onBookedTap;

  const _RoomBoxStaff({
    required this.roomNo,
    required this.typeSet,
    required this.availableSet,
    required this.bookedSet,
    required this.onBookedTap,
  });

  @override
  Widget build(BuildContext context) {
    final no = normalizeRoomNo(roomNo);

    final isInType = typeSet.contains(no);
    final isBooked = bookedSet.contains(no);
    final isAvailable = availableSet.contains(no);

    // ✅ 只有“当前房型 + booked(紫色)”才可点
    final canTap = isInType && isBooked;

    Color borderColor;
    Color fillColor;
    Color textColor;

    if (!isInType) {
      borderColor = const Color(0xFFBDBDBD);
      fillColor = const Color(0xFFEFEFEF);
      textColor = Colors.grey.shade700;
    } else if (isBooked) {
      borderColor = const Color(0xFF7B61FF); // 紫色边框
      fillColor = const Color(0xFF7B61FF).withOpacity(0.15);
      textColor = Colors.black;
    } else if (isAvailable) {
      borderColor = Colors.blue;
      fillColor = Colors.white;
      textColor = Colors.black;
    } else {
      borderColor = Colors.grey;
      fillColor = Colors.grey.withOpacity(0.2);
      textColor = Colors.grey.shade700;
    }

    return GestureDetector(
      onTap: () {
        if (!canTap) return;
        onBookedTap(no);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            no,
            style: TextStyle(
              fontSize: 12,
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  final bool filled;

  const _Legend({
    required this.color,
    required this.label,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: filled ? color.withOpacity(0.7) : Colors.transparent,
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
