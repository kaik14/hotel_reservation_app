import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ✅ Room edit page
import 'package:hotel_reservation_app/pages/booking_edit_page.dart';

// ✅ Dining edit page
import 'package:hotel_reservation_app/pages/dining_booking_page.dart';

// ✅ Spa edit page
import 'package:hotel_reservation_app/pages/spa_booking_page.dart';

// ✅✅✅ NEW: 6 service edit pages（⚠️请按你真实路径修改）
import 'package:hotel_reservation_app/pages/gym_booking_page.dart';
import 'package:hotel_reservation_app/pages/conference_hall_booking_page.dart';
import 'package:hotel_reservation_app/pages/taxi_booking_page.dart';
import 'package:hotel_reservation_app/pages/laundry_booking_page.dart';
import 'package:hotel_reservation_app/pages/swimming_booking_page.dart';
import 'package:hotel_reservation_app/pages/housekeeping_booking_page.dart';

// ✅✅✅ Notification Widget ✅✅✅
class SlideTransitionNotification extends StatefulWidget {
  final String message;
  final Color color;
  const SlideTransitionNotification({
    super.key,
    required this.message,
    required this.color,
  });

  @override
  State<SlideTransitionNotification> createState() =>
      _SlideTransitionNotificationState();
}

class _SlideTransitionNotificationState
    extends State<SlideTransitionNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: const Offset(0, 0),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _offsetAnimation,
      child: Material(
        color: widget.color,
        elevation: 6,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.notifications_active, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _Brand {
  static const bg = Color.fromARGB(255, 222, 228, 236);
  static const bar = Color(0xFF0F1722);
  static const accent = Color.fromARGB(255, 49, 59, 83);
}

class BookingDetailPage extends StatefulWidget {
  final String bookingId;
  final Map<String, dynamic> data;

  const BookingDetailPage({
    super.key,
    required this.bookingId,
    required this.data,
  });

  @override
  State<BookingDetailPage> createState() => _BookingDetailPageState();
}

class _BookingDetailPageState extends State<BookingDetailPage> {
  /// ✅ 浮动 GIF 助手机器人状态
  bool _showAssistant = true;
  Offset _assistantOffset = const Offset(16, 140);
  bool _initializedOffset = false;

  // ✅ 防止“预定成功消息”重复写入（本地内存锁）
  final Set<String> _createdNotified = {};

  // =========================================================
  // ✅ Common helpers
  // =========================================================
  void _showTopNotification(String message, Color color) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 50,
        left: 20,
        right: 20,
        child: SlideTransitionNotification(message: message, color: color),
      ),
    );

    overlay.insert(overlayEntry);

    Future.delayed(const Duration(seconds: 4), () {
      overlayEntry.remove();
    });
  }

  String _safeAsset(String path, {required String fallback}) {
    if (path.trim().isEmpty) return fallback;
    return path;
  }

  Future<void> _addMessage({
    required String title,
    required String body,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('messages')
        .add({
          'title': title,
          'message': body,
          'senderIcon': 'system',
          'timestamp': Timestamp.now(),
        });
  }

  Future<void> _markBookingCreatedNotified(String bookingId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('bookings')
        .doc(bookingId)
        .update({'createdNotified': true})
        .catchError((_) {});
  }

  Future<Map<String, dynamic>?> _loadLatestBookingData(String bookingId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return null;

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('bookings')
        .doc(bookingId)
        .get();

    if (!snap.exists) return null;
    return snap.data() as Map<String, dynamic>;
  }

  // =========================================================
  // ✅ ROOM 取消逻辑：完全不改（24小时规则）
  // =========================================================
  Future<void> _handleCancelBooking(
    String bookingId,
    DateTime checkInDate,
  ) async {
    final now = DateTime.now();
    if (now.isAfter(checkInDate.subtract(const Duration(hours: 24)))) {
      _showTopNotification(
        "Cancellation failed: You can only cancel up to 24 hours before check-in.",
        Colors.red,
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('bookings')
          .doc(bookingId)
          .delete();

      _showTopNotification(
        "Booking cancelled and refund processed successfully.",
        Colors.green,
      );

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _showTopNotification(
        "An error occurred while cancelling: $e",
        Colors.red,
      );
    }
  }

  // =========================================================
  // ✅ Service 判定 / 取 serviceStart / serviceEnd（增强适配更多服务）
  // =========================================================
  bool _isServiceBooking(Map<String, dynamic> data) {
    final t = (data['bookingType'] ?? '').toString();
    if (t == 'service') return true;
    return data.containsKey('serviceType') || data.containsKey('serviceName');
  }

  TimeOfDay? _parseHHmm(String? s) {
    if (s == null) return null;
    final parts = s.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  DateTime? _serviceStartAt(Map<String, dynamic> data) {
    final ts = data['serviceStart'] as Timestamp?;
    if (ts != null) return ts.toDate();

    // laundry / conference: 有时候存 startTime / pickupTime
    final dateTs = data['serviceDate'] as Timestamp?;
    if (dateTs == null) return null;
    final d = dateTs.toDate();

    final timeStr =
        (data['serviceTime'] ?? data['startTime'] ?? data['pickupTime'])
            as String?;
    final tod = _parseHHmm(timeStr);
    if (tod == null) return null;

    return DateTime(d.year, d.month, d.day, tod.hour, tod.minute);
  }

  DateTime? _serviceEndAt(Map<String, dynamic> data) {
    final ts = data['serviceEnd'] as Timestamp?;
    if (ts != null) return ts.toDate();

    final dateTs = data['serviceDate'] as Timestamp?;
    if (dateTs == null) return null;
    final d = dateTs.toDate();

    final endStr = (data['endTime'] ?? data['returnTime']) as String?;
    final endTod = _parseHHmm(endStr);
    final start = _serviceStartAt(data);
    if (endTod == null || start == null) return null;

    // ✅ 跨夜：如果 end < start，视为第二天
    final endDT = DateTime(d.year, d.month, d.day, endTod.hour, endTod.minute);
    if (endDT.isBefore(start)) return endDT.add(const Duration(days: 1));
    return endDT;
  }

  // =========================================================
  // ✅ Service Cancel (shared) - 3 hours rule + 写 message
  // =========================================================
  Future<void> _handleCancelServiceBooking({
    required String bookingId,
    required Map<String, dynamic> data,
    required String serviceTypeLabel,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final startAt = _serviceStartAt(data);
    if (startAt == null) {
      _showTopNotification(
        "Cancellation failed: Missing service time.",
        Colors.red,
      );
      return;
    }

    final now = DateTime.now();
    if (now.isAfter(startAt.subtract(const Duration(hours: 3)))) {
      _showTopNotification(
        "Cancellation failed: You can only cancel at least 3 hours before the booking time.",
        Colors.red,
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('bookings')
          .doc(bookingId)
          .delete();

      final serviceName =
          (data['serviceName'] ?? data['serviceType'] ?? serviceTypeLabel)
              .toString();

      final totalPriceRM = (data['totalPriceRM'] ?? data['totalPrice'] ?? 0);

      final totalGuests =
          (data['totalGuests'] ??
                  data['guests'] ??
                  data['passengers'] ??
                  ((data['adultCount'] ?? 0) + (data['childCount'] ?? 0)))
              .toString();

      final endAt = _serviceEndAt(data);
      final dateText = DateFormat('dd MMM yyyy').format(startAt);
      final timeText = endAt == null
          ? DateFormat('HH:mm').format(startAt)
          : '${DateFormat('HH:mm').format(startAt)}–${DateFormat('HH:mm').format(endAt)}';

      final msgTitle = '$serviceTypeLabel Booking Cancelled';
      final msgBody =
          'Your $serviceTypeLabel reservation has been cancelled.\n'
          'Service: $serviceName\n'
          'Date: $dateText\n'
          'Time: $timeText\n'
          'Guests: $totalGuests\n'
          'Total: RM $totalPriceRM';

      await _addMessage(title: msgTitle, body: msgBody);

      _showTopNotification(
        "Service booking cancelled successfully.",
        Colors.green,
      );

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _showTopNotification(
        "An error occurred while cancelling: $e",
        Colors.red,
      );
    }
  }

  // =========================================================
  // ✅ Service Updated message (shared) - 支持时间范围
  // =========================================================
  Future<void> _notifyServiceUpdated({
    required String bookingId,
    required String serviceTypeLabel,
  }) async {
    final latest = await _loadLatestBookingData(bookingId);
    if (latest == null) return;

    final startAt = _serviceStartAt(latest);
    final endAt = _serviceEndAt(latest);

    final serviceName =
        (latest['serviceName'] ?? latest['serviceType'] ?? serviceTypeLabel)
            .toString();

    final totalPriceRM = (latest['totalPriceRM'] ?? latest['totalPrice'] ?? 0);

    final totalGuests =
        (latest['totalGuests'] ??
                latest['guests'] ??
                latest['passengers'] ??
                ((latest['adultCount'] ?? 0) + (latest['childCount'] ?? 0)))
            .toString();

    final dateText = startAt == null
        ? '-'
        : DateFormat('dd MMM yyyy').format(startAt);

    final timeText = startAt == null
        ? '-'
        : (endAt == null
              ? DateFormat('HH:mm').format(startAt)
              : '${DateFormat('HH:mm').format(startAt)}–${DateFormat('HH:mm').format(endAt)}');

    final msgTitle = '$serviceTypeLabel Booking Updated';
    final msgBody =
        'Your $serviceTypeLabel reservation has been updated.\n'
        'Service: $serviceName\n'
        'Date: $dateText\n'
        'Time: $timeText\n'
        'Guests: $totalGuests\n'
        'Total: RM $totalPriceRM';

    await _addMessage(title: msgTitle, body: msgBody);
  }

  // =========================================================
  // ✅ NEW: 预定成功消息（只发一次）
  // =========================================================
  Future<void> _notifyServiceCreatedIfNeeded({
    required String bookingId,
    required Map<String, dynamic> data,
    required String serviceTypeLabel,
  }) async {
    if (_createdNotified.contains(bookingId)) return;

    final already = (data['createdNotified'] ?? false) == true;
    if (already) {
      _createdNotified.add(bookingId);
      return;
    }

    final startAt = _serviceStartAt(data);
    final endAt = _serviceEndAt(data);

    final serviceName =
        (data['serviceName'] ?? data['serviceType'] ?? serviceTypeLabel)
            .toString();

    final totalPriceRM = (data['totalPriceRM'] ?? data['totalPrice'] ?? 0);

    final totalGuests =
        (data['totalGuests'] ??
                data['guests'] ??
                data['passengers'] ??
                ((data['adultCount'] ?? 0) + (data['childCount'] ?? 0)))
            .toString();

    final dateText = startAt == null
        ? '-'
        : DateFormat('dd MMM yyyy').format(startAt);

    final timeText = startAt == null
        ? '-'
        : (endAt == null
              ? DateFormat('HH:mm').format(startAt)
              : '${DateFormat('HH:mm').format(startAt)}–${DateFormat('HH:mm').format(endAt)}');

    final msgTitle = '$serviceTypeLabel Booking Confirmed';
    final msgBody =
        'Your $serviceTypeLabel reservation is confirmed.\n'
        'Service: $serviceName\n'
        'Date: $dateText\n'
        'Time: $timeText\n'
        'Guests: $totalGuests\n'
        'Total: RM $totalPriceRM';

    await _addMessage(title: msgTitle, body: msgBody);
    await _markBookingCreatedNotified(bookingId);
    _createdNotified.add(bookingId);
  }

  // =========================================================
  // ✅ Floating Assistant
  // =========================================================
  Widget _buildFloatingAssistant(BuildContext context) {
    final size = MediaQuery.of(context).size;

    const double avatarWidth = 160;
    const double avatarHeight = 160;

    if (!_initializedOffset) {
      _assistantOffset = Offset(size.width - avatarWidth - 16, 140);
      _initializedOffset = true;
    }

    final double left = _assistantOffset.dx.clamp(
      0.0,
      size.width - avatarWidth,
    );
    final double top = _assistantOffset.dy.clamp(
      0.0,
      size.height - avatarHeight - MediaQuery.of(context).padding.top,
    );

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onPanUpdate: (details) =>
            setState(() => _assistantOffset += details.delta),
        child: SizedBox(
          width: avatarWidth,
          height: avatarHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/gifs/final3.gif',
                  fit: BoxFit.contain,
                ),
              ),
              Positioned(
                right: 40,
                top: -4,
                child: GestureDetector(
                  onTap: () => setState(() => _showAssistant = false),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.6),
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // ✅ Build
  // =========================================================
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text("Not logged in")));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('bookings')
          .doc(widget.bookingId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.data!.exists) {
          return const Scaffold(
            body: Center(child: Text("Booking has been removed.")),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;

        if (_isServiceBooking(data)) {
          final serviceType = (data['serviceType'] ?? '')
              .toString()
              .toLowerCase();

          // ✅ Dining / Spa 你原本的逻辑保留
          if (serviceType == 'dining') {
            _notifyServiceCreatedIfNeeded(
              bookingId: widget.bookingId,
              data: data,
              serviceTypeLabel: 'Dining',
            );
            return _buildDiningDetailUI(context, data);
          }
          if (serviceType == 'spa') {
            _notifyServiceCreatedIfNeeded(
              bookingId: widget.bookingId,
              data: data,
              serviceTypeLabel: 'Spa',
            );
            return _buildSpaDetailUI(context, data);
          }

          // ✅ 新增 6 个服务
          if (serviceType == 'gym') {
            _notifyServiceCreatedIfNeeded(
              bookingId: widget.bookingId,
              data: data,
              serviceTypeLabel: 'Gym',
            );
            return _buildGenericServiceDetailUI(
              context,
              data,
              serviceTypeLabel: 'Gym',
              fallbackImage: 'assets/services/gym.jpg',
              subtitle: 'Gym Service',
              onEdit: () async {
                final changed = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GymBookingPage(
                      existingBookingId: widget.bookingId,
                      existingData: data,
                    ),
                  ),
                );
                if (changed == true && mounted) {
                  await _notifyServiceUpdated(
                    bookingId: widget.bookingId,
                    serviceTypeLabel: 'Gym',
                  );
                  _showTopNotification("Gym booking updated.", Colors.green);
                }
              },
            );
          }

          if (serviceType == 'conferencehall' || serviceType == 'conference') {
            _notifyServiceCreatedIfNeeded(
              bookingId: widget.bookingId,
              data: data,
              serviceTypeLabel: 'Conference Hall',
            );
            return _buildGenericServiceDetailUI(
              context,
              data,
              serviceTypeLabel: 'Conference Hall',
              fallbackImage: 'assets/services/conference.jpg',
              subtitle: 'Conference Facility',
              extraRows: [
                _infoRow(
                  'Room Type',
                  (data['roomLabel'] ?? data['roomKey'] ?? '-').toString(),
                ),
              ],
              onEdit: () async {
                final changed = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ConferenceHallBookingPage(
                      existingBookingId: widget.bookingId,
                      existingData: data,
                    ),
                  ),
                );
                if (changed == true && mounted) {
                  await _notifyServiceUpdated(
                    bookingId: widget.bookingId,
                    serviceTypeLabel: 'Conference Hall',
                  );
                  _showTopNotification(
                    "Conference booking updated.",
                    Colors.green,
                  );
                }
              },
            );
          }

          if (serviceType == 'taxi') {
            _notifyServiceCreatedIfNeeded(
              bookingId: widget.bookingId,
              data: data,
              serviceTypeLabel: 'Taxi',
            );
            return _buildGenericServiceDetailUI(
              context,
              data,
              serviceTypeLabel: 'Taxi',
              fallbackImage: 'assets/services/taxi.jpg',
              subtitle: 'Airport Taxi',
              extraRows: [
                _infoRow(
                  'Ride Type',
                  (data['rideLabel'] ?? data['rideKey'] ?? '-').toString(),
                ),
                _infoRow(
                  'Passengers',
                  (data['passengers'] ?? data['guests'] ?? 1).toString(),
                ),
              ],
              onEdit: () async {
                final changed = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TaxiBookingPage(
                      existingBookingId: widget.bookingId,
                      existingData: data,
                    ),
                  ),
                );
                if (changed == true && mounted) {
                  await _notifyServiceUpdated(
                    bookingId: widget.bookingId,
                    serviceTypeLabel: 'Taxi',
                  );
                  _showTopNotification("Taxi booking updated.", Colors.green);
                }
              },
            );
          }

          if (serviceType == 'laundry') {
            _notifyServiceCreatedIfNeeded(
              bookingId: widget.bookingId,
              data: data,
              serviceTypeLabel: 'Laundry',
            );
            return _buildGenericServiceDetailUI(
              context,
              data,
              serviceTypeLabel: 'Laundry',
              fallbackImage: 'assets/services/laundry.jpg',
              subtitle: 'Laundry & Ironing',
              extraRows: [
                _infoRow(
                  'Room No',
                  (data['roomNumber'] ?? data['roomNo'] ?? '-').toString(),
                ),
                _infoRow(
                  'Items',
                  (data['items'] ??
                          data['clothesCount'] ??
                          data['numberOfItems'] ??
                          '-')
                      .toString(),
                ),
                _infoRow(
                  'Pickup',
                  (data['pickupTime'] ?? data['startTime'] ?? '-').toString(),
                ),
                _infoRow(
                  'Return',
                  (data['returnTime'] ?? data['endTime'] ?? '-').toString(),
                ),
              ],
              onEdit: () async {
                final changed = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LaundryIroningBookingPage(
                      existingBookingId: widget.bookingId,
                      existingData: data,
                    ),
                  ),
                );
                if (changed == true && mounted) {
                  await _notifyServiceUpdated(
                    bookingId: widget.bookingId,
                    serviceTypeLabel: 'Laundry',
                  );
                  _showTopNotification(
                    "Laundry booking updated.",
                    Colors.green,
                  );
                }
              },
            );
          }

          if (serviceType == 'swimming') {
            _notifyServiceCreatedIfNeeded(
              bookingId: widget.bookingId,
              data: data,
              serviceTypeLabel: 'Swimming',
            );
            return _buildGenericServiceDetailUI(
              context,
              data,
              serviceTypeLabel: 'Swimming',
              fallbackImage: 'assets/services/swimming.jpg',
              subtitle: 'Swimming Pool',
              onEdit: () async {
                final changed = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SwimmingBookingPage(
                      existingBookingId: widget.bookingId,
                      existingData: data,
                    ),
                  ),
                );
                if (changed == true && mounted) {
                  await _notifyServiceUpdated(
                    bookingId: widget.bookingId,
                    serviceTypeLabel: 'Swimming',
                  );
                  _showTopNotification(
                    "Swimming booking updated.",
                    Colors.green,
                  );
                }
              },
            );
          }

          if (serviceType == 'housekeeping') {
            _notifyServiceCreatedIfNeeded(
              bookingId: widget.bookingId,
              data: data,
              serviceTypeLabel: 'Housekeeping',
            );
            return _buildGenericServiceDetailUI(
              context,
              data,
              serviceTypeLabel: 'Housekeeping',
              fallbackImage: 'assets/services/housekeeping.jpg',
              subtitle: 'Housekeeping Service',
              extraRows: [
                _infoRow(
                  'Room No',
                  (data['roomNumber'] ?? data['roomNo'] ?? '-').toString(),
                ),
              ],
              onEdit: () async {
                final changed = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HousekeepingBookingPage(
                      existingBookingId: widget.bookingId,
                      existingData: data,
                    ),
                  ),
                );
                if (changed == true && mounted) {
                  await _notifyServiceUpdated(
                    bookingId: widget.bookingId,
                    serviceTypeLabel: 'Housekeeping',
                  );
                  _showTopNotification(
                    "Housekeeping booking updated.",
                    Colors.green,
                  );
                }
              },
            );
          }

          return _buildUnsupportedServiceUI(context, data);
        }

        return _buildRoomDetailUI(context, data);
      },
    );
  }

  // =========================================================
  // ✅ NEW: 通用服务详情 UI（用于 6 个新服务）
  // =========================================================
  Widget _buildGenericServiceDetailUI(
    BuildContext context,
    Map<String, dynamic> data, {
    required String serviceTypeLabel,
    required String fallbackImage,
    required String subtitle,
    required Future<void> Function() onEdit,
    List<Widget> extraRows = const [],
  }) {
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    final serviceName = (data['serviceName'] ?? serviceTypeLabel).toString();
    final serviceImage = _safeAsset(
      (data['serviceImagePath'] ?? '').toString(),
      fallback: fallbackImage,
    );

    final startAt = _serviceStartAt(data);
    final endAt = _serviceEndAt(data);

    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();

    final totalGuests =
        (data['totalGuests'] ?? data['guests'] ?? data['passengers'] ?? 1);
    final totalPriceRM = data['totalPriceRM'] ?? 0;

    final now = DateTime.now();
    final bool isCompleted = startAt != null && startAt.isBefore(now);

    final dateFmt = DateFormat('dd MMM yyyy');
    final timeFmt = DateFormat('HH:mm');
    final createdFmt = DateFormat('dd MMM yyyy – HH:mm');

    final timeText = startAt == null
        ? "-"
        : (endAt == null
              ? timeFmt.format(startAt)
              : '${timeFmt.format(startAt)}–${timeFmt.format(endAt)}');

    return Scaffold(
      backgroundColor: _Brand.bg,
      appBar: _detailAppBar(context),
      bottomNavigationBar: Container(
        height: 75 + bottomSafe,
        decoration: const BoxDecoration(color: _Brand.bar),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _detailCard(
                headerImage: serviceImage,
                title: serviceName,
                subtitle: subtitle,
                children: [
                  ...extraRows,
                  _infoRow(
                    "Date",
                    startAt != null ? dateFmt.format(startAt) : "-",
                  ),
                  _infoRow("Time", timeText),
                  _infoRow("Guests", "$totalGuests"),
                  _infoRow("Total", "RM $totalPriceRM"),
                  _infoRow("Status", isCompleted ? "Completed" : "Upcoming"),
                  _infoRow(
                    "Created",
                    createdAt != null ? createdFmt.format(createdAt) : "-",
                  ),
                  if (updatedAt != null)
                    _infoRow("Updated", createdFmt.format(updatedAt)),
                  const SizedBox(height: 20),

                  if (!isCompleted)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(
                              Icons.edit_calendar_outlined,
                              color: Colors.white,
                            ),
                            label: const Text(
                              "Edit Booking",
                              style: TextStyle(color: Colors.white),
                            ),
                            style: _primaryBtnStyle(),
                            onPressed: () async => onEdit(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(
                              Icons.cancel_outlined,
                              color: Colors.white,
                            ),
                            label: const Text(
                              "Cancel Booking",
                              style: TextStyle(color: Colors.white),
                            ),
                            style: _dangerBtnStyle(),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('Confirm Cancellation'),
                                  content: const Text(
                                    'Are you sure you want to cancel this booking?',
                                  ),
                                  actions: [
                                    TextButton(
                                      child: const Text('Back'),
                                      onPressed: () =>
                                          Navigator.of(dialogContext).pop(),
                                    ),
                                    TextButton(
                                      child: const Text(
                                        'Confirm',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                      onPressed: () {
                                        Navigator.of(dialogContext).pop();
                                        _handleCancelServiceBooking(
                                          bookingId: widget.bookingId,
                                          data: data,
                                          serviceTypeLabel: serviceTypeLabel,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),

                  if (isCompleted)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        "Completed service bookings cannot be modified or cancelled.",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),

                  if (!isCompleted && startAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        "Cancellation policy: You can only cancel at least 3 hours before the booking time.",
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            if (_showAssistant) _buildFloatingAssistant(context),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // ✅ ROOM UI（保持你原逻辑，不改）
  // =========================================================
  Widget _buildRoomDetailUI(BuildContext context, Map<String, dynamic> data) {
    final checkIn = (data['checkIn'] as Timestamp?)?.toDate();
    final isCheckedIn = checkIn != null && checkIn.isBefore(DateTime.now());

    final price = data['priceText'] ?? "RM -";
    final desc = data['description'] ?? data['roomDesc'] ?? "per night";
    final imageName = data['imageName'] ?? "${data['roomTypeId']}.jpg";
    final imagePath = "assets/rooms/$imageName";
    final checkOut = (data['checkOut'] as Timestamp?)?.toDate();
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final guests = data['guests'] ?? 1;
    final roomNo = data['roomNo'] ?? '-';
    final title = data['roomTypeTitle'] ?? 'Room';
    final nights =
        data['nights'] ??
        (checkIn != null && checkOut != null
            ? checkOut.difference(checkIn).inDays
            : 1);

    final dateFmt = DateFormat('dd MMM yyyy');
    final createdFmt = DateFormat('dd MMM yyyy – HH:mm');
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: _Brand.bg,
      appBar: _detailAppBar(context),
      bottomNavigationBar: Container(
        height: 75 + bottomSafe,
        decoration: const BoxDecoration(color: _Brand.bar),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _detailCard(
                headerImage: imagePath,
                title: title.toString(),
                subtitle: price.toString(),
                children: [
                  if (desc.toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        desc.toString(),
                        style: const TextStyle(fontSize: 15, height: 1.5),
                      ),
                    ),
                  _infoRow("Room No", roomNo.toString()),
                  _infoRow("Guests", "$guests"),
                  _infoRow(
                    "Check-in",
                    checkIn != null ? dateFmt.format(checkIn) : "-",
                  ),
                  _infoRow(
                    "Check-out",
                    checkOut != null ? dateFmt.format(checkOut) : "-",
                  ),
                  _infoRow("Nights", "$nights"),
                  _infoRow(
                    "Created",
                    createdAt != null ? createdFmt.format(createdAt) : "-",
                  ),
                  const SizedBox(height: 20),
                  if (!isCheckedIn)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(
                              Icons.edit_calendar_outlined,
                              color: Colors.white,
                            ),
                            label: const Text(
                              "Edit Booking",
                              style: TextStyle(color: Colors.white),
                            ),
                            style: _primaryBtnStyle(),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BookingEditPage(
                                    bookingId: widget.bookingId,
                                    data: data,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(
                              Icons.cancel_outlined,
                              color: Colors.white,
                            ),
                            label: const Text(
                              "Cancel Booking",
                              style: TextStyle(color: Colors.white),
                            ),
                            style: _dangerBtnStyle(),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('Confirm Cancellation'),
                                  content: const Text(
                                    'Are you sure you want to cancel this booking?',
                                  ),
                                  actions: [
                                    TextButton(
                                      child: const Text('Back'),
                                      onPressed: () =>
                                          Navigator.of(dialogContext).pop(),
                                    ),
                                    TextButton(
                                      child: const Text(
                                        'Confirm',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                      onPressed: () {
                                        Navigator.of(dialogContext).pop();
                                        _handleCancelBooking(
                                          widget.bookingId,
                                          checkIn!,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  if (isCheckedIn)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        "Checked-in bookings cannot be modified or cancelled.",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                ],
              ),
            ),
            if (_showAssistant) _buildFloatingAssistant(context),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // ✅ Dining / Spa UI：保留你原本（略），你原文件的这两段可以继续用
  // 这里为了简洁，我不再重复贴一遍——你直接保留你原来的 _buildDiningDetailUI / _buildSpaDetailUI / _buildUnsupportedServiceUI
  // =========================================================

  // ✅✅✅【已修改】Dining Detail：不再返回 unsupported，直接复用通用详情 UI
  Widget _buildDiningDetailUI(BuildContext context, Map<String, dynamic> data) {
    return _buildGenericServiceDetailUI(
      context,
      data,
      serviceTypeLabel: 'Dining',
      fallbackImage: 'assets/services/dining.jpg',
      subtitle: 'Dining Reservation',
      extraRows: [
        if (data['restaurantName'] != null)
          _infoRow('Restaurant', data['restaurantName'].toString()),
        if (data['tableNo'] != null)
          _infoRow('Table No', data['tableNo'].toString()),
        if (data['adultCount'] != null || data['childCount'] != null)
          _infoRow(
            'Guests',
            '${(data['adultCount'] ?? 0)} Adult, ${(data['childCount'] ?? 0)} Child',
          ),
        if (data['notes'] != null) _infoRow('Notes', data['notes'].toString()),
      ],
      onEdit: () async {
        final changed = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DiningBookingPage(
              existingBookingId: widget.bookingId,
              existingData: data,
            ),
          ),
        );
        if (changed == true && mounted) {
          await _notifyServiceUpdated(
            bookingId: widget.bookingId,
            serviceTypeLabel: 'Dining',
          );
          _showTopNotification("Dining booking updated.", Colors.green);
        }
      },
    );
  }

  // ✅✅✅【已修改】Spa Detail：不再返回 unsupported，直接复用通用详情 UI
  Widget _buildSpaDetailUI(BuildContext context, Map<String, dynamic> data) {
    return _buildGenericServiceDetailUI(
      context,
      data,
      serviceTypeLabel: 'Spa',
      fallbackImage: 'assets/services/spa.jpg',
      subtitle: 'Spa & Wellness',
      extraRows: [
        if (data['treatmentName'] != null)
          _infoRow('Treatment', data['treatmentName'].toString()),
        if (data['therapist'] != null)
          _infoRow('Therapist', data['therapist'].toString()),
      ],
      onEdit: () async {
        final changed = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SpaBookingPage(
              existingBookingId: widget.bookingId,
              existingData: data,
            ),
          ),
        );
        if (changed == true && mounted) {
          await _notifyServiceUpdated(
            bookingId: widget.bookingId,
            serviceTypeLabel: 'Spa',
          );
          _showTopNotification("Spa booking updated.", Colors.green);
        }
      },
    );
  }

  Widget _buildUnsupportedServiceUI(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    final serviceName =
        (data['serviceName'] ?? data['serviceType'] ?? 'Service').toString();

    return Scaffold(
      backgroundColor: _Brand.bg,
      appBar: _detailAppBar(context),
      bottomNavigationBar: Container(
        height: 75 + bottomSafe,
        decoration: const BoxDecoration(color: _Brand.bar),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Service detail page for "$serviceName" is not implemented yet.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54, fontSize: 15),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // ✅ UI helpers（你原来的保持不变）
  // =========================================================
  AppBar _detailAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: _Brand.bar,
      elevation: 0,
      centerTitle: false,
      titleSpacing: 8,
      toolbarHeight: 97,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: _Brand.bar,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      leadingWidth: 48,
      leading: IconButton(
        icon: const Icon(Icons.chevron_left, color: Colors.white, size: 30),
        onPressed: () => Navigator.maybePop(context),
        tooltip: 'Back',
      ),
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Booking Details',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Review and manage your reservation.',
            style: TextStyle(
              color: Color(0x99FFFFFF),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailCard({
    required String headerImage,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Image.asset(
              headerImage,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                const SizedBox(height: 14),
                ...children,
              ],
            ),
          ),
        ],
      ),
    );
  }

  ButtonStyle _primaryBtnStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: _Brand.accent,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 4,
      minimumSize: const Size(0, 48),
    );
  }

  ButtonStyle _dangerBtnStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: Colors.red[700],
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 4,
      minimumSize: const Size(0, 48),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.black87, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
