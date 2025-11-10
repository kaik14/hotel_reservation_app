// service_detail_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class ServiceDetailPage extends StatefulWidget {
  final String serviceId; // e.g. 'swimming', 'spa'
  const ServiceDetailPage({super.key, required this.serviceId});

  @override
  State<ServiceDetailPage> createState() => _ServiceDetailPageState();
}

class _ServiceDetailPageState extends State<ServiceDetailPage> {
  DocumentSnapshot<Map<String, dynamic>>? _snap;
  bool _loading = true;
  String? _loadError;

  DateTime? _pickedDate;
  TimeOfDay? _pickedTime;

  // ====== Load with retry ======
  @override
  void initState() {
    super.initState();
    _loadService();
  }

  Future<void> _loadService() async {
    const maxRetries = 3;
    int attempt = 0;

    setState(() {
      _loading = true;
      _loadError = null;
    });

    while (true) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('services')
            .doc(widget.serviceId)
            .get();

        if (!mounted) return;
        setState(() {
          _snap = doc;
          _loading = false;
        });
        return;
      } on FirebaseException catch (e) {
        attempt++;
        final transient =
            e.code == 'unavailable' || e.code == 'deadline-exceeded';

        if (transient && attempt < maxRetries) {
          await Future.delayed(
            Duration(milliseconds: 400 * (1 << (attempt - 1))),
          );
          continue;
        }

        if (!mounted) return;
        setState(() {
          _loading = false;
          _loadError = e.code;
        });
        return;
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _loadError = 'unexpected';
        });
        return;
      }
    }
  }

  // ====== Pickers ======
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _pickedDate ?? now,
      firstDate: now.subtract(const Duration(days: 0)),
      lastDate: DateTime(now.year + 2, 12, 31),
    );
    if (d == null) return;
    setState(() => _pickedDate = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _pickedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        // 24h/AMPM 由系统决定，这里保持默认
        return child ?? const SizedBox.shrink();
      },
    );
    if (t == null) return;
    setState(() => _pickedTime = t);
  }

  // ====== Validation ======
  Future<String?> _validate() async {
    if (_snap == null) return 'Service not loaded.';
    final data = _snap!.data() ?? {};

    final requiresReservation = data['requiresReservation'] == true;
    if (!requiresReservation) return 'This service does not require booking.';

    if (_pickedDate == null || _pickedTime == null) {
      return 'Please select date and time.';
    }

    // 规则：guestMustHaveActiveStay / allowBookingWithinStay
    final mustStay =
        data['guestMustHaveActiveStay'] == true ||
        data['allowBookingWithinStay'] == true;

    if (mustStay) {
      final ok = await _isWithinAnyStay(_pickedDate!);
      if (!ok) {
        return 'Only hotel guests with an active stay can book within their stay dates.';
      }
    }

    // 规则：周一闭馆等
    final schedule = (data['schedule'] as Map?) ?? {};
    final closedWeekdays = List<int>.from(schedule['closedWeekdays'] ?? []);
    final weekday = _pickedDate!.weekday % 7; // Mon=1..Sun=7 -> 1..0
    // 我们约定 0=Sun,1=Mon..6=Sat，Firestore中你存的是 [1] 表示周一
    final weekdayZeroBased = (_pickedDate!.weekday % 7); // Mon=1..Sun=0
    if (closedWeekdays.contains(weekdayZeroBased)) {
      return 'Closed on selected day.';
    }

    // 规则：当天预约必须在开放时段内（Swimming 的要求）
    final bookOnlyDuringOpen = data['bookOnlyDuringOpenHours'] == true;
    if (bookOnlyDuringOpen) {
      final openStr = (schedule['open'] ?? '07:00') as String;
      final closeStr = (schedule['close'] ?? '21:00') as String;
      final open = _parseHHmm(openStr);
      final close = _parseHHmm(closeStr);

      // 只对“预约当天”做时段限制（你的需求）
      final now = DateTime.now();
      final isToday = DateUtils.isSameDay(_pickedDate, now);
      if (isToday) {
        if (!_isWithin(open, close, _pickedTime!)) {
          return 'Today’s bookings are only allowed between $openStr and $closeStr.';
        }
      }
    }

    // 防重复：preventDuplicateActiveBookings（同服务未完成的预约不能再约）
    if (data['preventDuplicateActiveBookings'] == true) {
      final hasActive = await _hasActiveReservation(widget.serviceId);
      if (hasActive) {
        return 'You already have an active reservation for this service.';
      }
    }

    return null; // OK
  }

  // 任一有效入住区间（[checkIn, checkOut)）包含所选日期
  Future<bool> _isWithinAnyStay(DateTime date) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final qs = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('bookings')
        .get();

    for (final d in qs.docs) {
      final m = d.data() as Map<String, dynamic>;
      final tsIn = (m['checkIn'] as Timestamp?)?.toDate();
      final tsOut = (m['checkOut'] as Timestamp?)?.toDate();
      if (tsIn == null || tsOut == null) continue;

      final day = DateTime(date.year, date.month, date.day);
      final inDay = DateTime(tsIn.year, tsIn.month, tsIn.day);
      final outDay = DateTime(tsOut.year, tsOut.month, tsOut.day);

      if (!day.isBefore(inDay) && day.isBefore(outDay)) {
        return true;
      }
    }
    return false;
  }

  // 是否已有该服务的“进行中/未过期”预约（这里只给示例：简单查未结束的记录）
  Future<bool> _hasActiveReservation(String serviceId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final now = DateTime.now();
    final qs = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('serviceReservations')
        .where('serviceId', isEqualTo: serviceId)
        .where('endAt', isGreaterThan: Timestamp.fromDate(now))
        .limit(1)
        .get();

    return qs.docs.isNotEmpty;
  }

  // ====== Helpers ======
  TimeOfDay _parseHHmm(String hhmm) {
    final p = hhmm.split(':');
    return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
  }

  bool _isWithin(TimeOfDay start, TimeOfDay end, TimeOfDay t) {
    final s = start.hour * 60 + start.minute;
    final e = end.hour * 60 + end.minute;
    final x = t.hour * 60 + t.minute;
    return x >= s && x <= e;
  }

  String _formatOpenHours(Map schedule) {
    final open = schedule['open'] ?? '—';
    final close = schedule['close'] ?? '—';
    final tz = schedule['timezone'] ?? '';
    return '$open — $close${tz.isNotEmpty ? '  ($tz)' : ''}';
  }

  // ====== UI ======
  @override
  Widget build(BuildContext context) {
    final bar = const Color(0xFF0F1722);

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 222, 228, 236),
      appBar: AppBar(
        backgroundColor: bar,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        toolbarHeight: 97,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Color(0xFF0F1722),
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
              'Service Details',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Learn about this facility before booking.',
              style: TextStyle(
                color: Color(0x99FFFFFF),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Load failed: $_loadError'),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _loadService, child: const Text('Retry')),
          ],
        ),
      );
    }
    final data = _snap!.data() ?? {};

    final name = (data['name'] ?? 'Service') as String;
    final ui = (data['ui'] as Map?) ?? {};
    final imageName = (ui['imageName'] ?? '') as String;
    final location = (ui['location'] ?? '') as String;
    final notes = (ui['notes'] ?? '') as String;
    final desc = (data['description'] ?? '') as String;
    final schedule = (data['schedule'] as Map?) ?? {};
    final hours = _formatOpenHours(schedule);

    final closedWeekdays = List<int>.from(schedule['closedWeekdays'] ?? []);
    final weekNames = const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final closedText = closedWeekdays.isEmpty
        ? 'Open daily'
        : 'Closed: ${closedWeekdays.map((i) => weekNames[i]).join(', ')}';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 封面图（可选）
          if (imageName.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/rooms/$imageName',
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(height: 16),

          Text(
            name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          if (desc.isNotEmpty)
            Text(desc, style: const TextStyle(fontSize: 14, height: 1.4)),

          const SizedBox(height: 14),
          _infoTile(Icons.place_rounded, location.isEmpty ? '—' : location),
          _infoTile(Icons.access_time_rounded, hours),
          _infoTile(Icons.event_busy_rounded, closedText),
          if (notes.isNotEmpty) _infoTile(Icons.info_outline_rounded, notes),

          const SizedBox(height: 18),
          const Text(
            'Select date & time',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _pickerBox(
                  icon: Icons.calendar_today_rounded,
                  label: _pickedDate == null
                      ? 'Choose date'
                      : DateFormat('dd MMM yyyy').format(_pickedDate!),
                  onTap: _pickDate,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _pickerBox(
                  icon: Icons.schedule_rounded,
                  label: _pickedTime == null
                      ? 'Choose time'
                      : _pickedTime!.format(context),
                  onTap: _pickTime,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final err = await _validate();
                if (!mounted) return;
                if (err != null) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(err)));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Validation passed. Ready to reserve.'),
                    ),
                  );
                  // 下一步 Step：真正写入 reservation（我们下一回合补）
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 49, 59, 83),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Check & Continue',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Note: Swimming pool bookings are free for guests. Same-day booking must be within open hours.',
            style: TextStyle(color: Colors.black54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.black87),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _pickerBox({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(label)),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
