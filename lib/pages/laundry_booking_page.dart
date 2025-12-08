import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hotel_reservation_app/pages/booking_success_page.dart';
import 'package:panorama_viewer/panorama_viewer.dart';

class LaundryIroningBookingPage extends StatefulWidget {
  const LaundryIroningBookingPage({super.key});

  @override
  State<LaundryIroningBookingPage> createState() =>
      _LaundryIroningBookingPageState();
}

class _LaundryIroningBookingPageState extends State<LaundryIroningBookingPage> {
  DateTime? _selectedDate;
  TimeOfDay? _pickupTime;
  TimeOfDay? _returnTime;

  // 房间号 & 衣服件数
  final TextEditingController _roomController = TextEditingController();
  final TextEditingController _clothesController = TextEditingController();

  // 360° 控制
  bool _showPanorama = false;

  @override
  void dispose() {
    _roomController.dispose();
    _clothesController.dispose();
    super.dispose();
  }

  /// ⚠️ 这里一定要和 Firestore 文档 ID 一样：laundry
  Future<DocumentSnapshot<Map<String, dynamic>>> _loadService() {
    return FirebaseFirestore.instance
        .collection('services')
        .doc('laundry') // ← 已改成 laundry
        .get();
  }

  // ---------- 帮助函数 ----------

  TimeOfDay _parseTimeOfDay(String hhmm) {
    final parts = hhmm.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return TimeOfDay(hour: h, minute: m);
  }

  int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  bool _isTimeInRange(TimeOfDay t, TimeOfDay start, TimeOfDay end) {
    final tM = _toMinutes(t);
    final sM = _toMinutes(start);
    final eM = _toMinutes(end);
    return tM >= sM && tM <= eM;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Select date';
    return '${date.day.toString().padLeft(2, '0')} '
        '${_monthName(date.month)} ${date.year}';
  }

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  // ---------- 交互逻辑 ----------

  // 只能预约「今天 & 明天」（maxAdvanceDays 通常为 2）
  Future<void> _pickDate(BuildContext context, int maxAdvanceDays) async {
    final today = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? today,
      firstDate: today,
      lastDate: today.add(Duration(days: maxAdvanceDays)),
    );

    if (picked == null) return;

    setState(() {
      _selectedDate = picked;
      _pickupTime = null;
      _returnTime = null;
    });
  }

  // 取衣时间（不能早于当前时间 & 营业时间外）
  Future<void> _pickPickupTime(
    BuildContext context,
    TimeOfDay open,
    TimeOfDay close,
  ) async {
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date first.')),
      );
      return;
    }

    final TimeOfDay initial = _pickupTime ?? open;

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );

    if (picked == null) return;

    // 营业时间检查
    if (!_isTimeInRange(picked, open, close)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select a time between ${open.format(context)} and ${close.format(context)}.',
          ),
        ),
      );
      return;
    }

    // 当天不能预约过去时间
    final now = DateTime.now();
    final selectedDay = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
    );
    final today = DateTime(now.year, now.month, now.day);

    if (selectedDay == today) {
      final nowTod = TimeOfDay.fromDateTime(now);
      if (_toMinutes(picked) <= _toMinutes(nowTod)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a future time.')),
        );
        return;
      }
    }

    setState(() {
      _pickupTime = picked;
      // 如果已有归还时间但不合法，则清空
      if (_returnTime != null &&
          !_isValidReturnTime(_pickupTime!, _returnTime!)) {
        _returnTime = null;
      }
    });
  }

  // 归还时间：> 取衣时间 & 至少间隔 3 小时 & 在营业时间内
  Future<void> _pickReturnTime(
    BuildContext context,
    TimeOfDay open,
    TimeOfDay close,
  ) async {
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date first.')),
      );
      return;
    }

    if (_pickupTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select pickup time first.')),
      );
      return;
    }

    final TimeOfDay initial = _returnTime ?? _pickupTime!;

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );

    if (picked == null) return;

    if (!_isTimeInRange(picked, open, close)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select a time between ${open.format(context)} and ${close.format(context)}.',
          ),
        ),
      );
      return;
    }

    if (!_isValidReturnTime(_pickupTime!, picked)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Return time must be at least 3 hours after pickup time.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _returnTime = picked;
    });
  }

  bool _isValidReturnTime(TimeOfDay pickup, TimeOfDay ret) {
    final p = _toMinutes(pickup);
    final r = _toMinutes(ret);
    const threeHours = 3 * 60;
    return r > p && (r - p) >= threeHours;
  }

  // ✅ 提交按钮是否可以点
  bool get canSubmit {
    if (_selectedDate == null || _pickupTime == null || _returnTime == null) {
      return false;
    }

    if (_roomController.text.trim().isEmpty) {
      return false;
    }

    final clothes = int.tryParse(_clothesController.text.trim());
    if (clothes == null || clothes <= 0) {
      return false;
    }

    return true;
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _LightPalette.accentBlue,
          brightness: Brightness.light,
          primary: _LightPalette.accentBlue,
          surface: Colors.white,
          onSurface: _LightPalette.textPrimary,
        ),
        scaffoldBackgroundColor: _LightPalette.bg,
        textTheme: Theme.of(context).textTheme.apply(
          bodyColor: _LightPalette.textPrimary,
          displayColor: _LightPalette.textPrimary,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F1722),
          elevation: 0,
          centerTitle: false,
          titleSpacing: 20,
          toolbarHeight: 97,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: _LightPalette.bg,
        appBar: AppBar(
          title: const Text('Laundry & Ironing Booking'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(0.5),
            child: Container(
              height: 0.5,
              color: Colors.white.withOpacity(0.08),
            ),
          ),
        ),
        body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: _loadService(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: Text('Service not found.'));
            }

            final data = snapshot.data!.data()!;
            final name = data['name'] as String? ?? 'Laundry & Ironing Service';
            final description =
                data['description'] as String? ??
                'Laundry and ironing pickup & return.';
            final isFree = data['isFree'] as bool? ?? false;

            final schedule = (data['schedule'] ?? {}) as Map<String, dynamic>;
            final openStr = schedule['open'] as String? ?? '07:00';
            final closeStr = schedule['close'] as String? ?? '21:00';
            final openTime = _parseTimeOfDay(openStr);
            final closeTime = _parseTimeOfDay(closeStr);

            // 最多提前 2 天（今天 + 明天）
            final maxAdvanceDays = data['maxAdvanceDays'] as int? ?? 2;

            final ui = (data['ui'] ?? {}) as Map<String, dynamic>;
            final location =
                ui['location'] as String? ?? 'Laundry & Services Counter';
            final notes =
                ui['notes'] as String? ??
                'Please pack your clothes in a laundry bag before pickup.';

            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 顶部图片 + 360°
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          AspectRatio(
                            aspectRatio: 16 / 9,
                            child: _showPanorama
                                ? PanoramaViewer(
                                    child: Image.asset(
                                      'assets/services/laundry_360.jpg',
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Image.asset(
                                    'assets/services/laundry.jpg',
                                    fit: BoxFit.cover,
                                  ),
                          ),
                          Positioned(
                            right: 12,
                            top: 12,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black.withOpacity(0.6),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  _showPanorama = !_showPanorama;
                                });
                              },
                              icon: const Icon(Icons.threesixty),
                              label: Text(
                                _showPanorama ? 'Exit 360°' : '360° View',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 标题 + 标签
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: _LightPalette.textPrimary,
                                ),
                          ),
                        ),
                        if (isFree)
                          Text(
                            'Free',
                            style: TextStyle(
                              color: Colors.green[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            location,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: _LightPalette.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _LightPalette.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Booking Details
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Booking Details',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _LightPalette.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // 房间号
                            Row(
                              children: [
                                const Icon(Icons.door_front_door_outlined),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _roomController,
                                    decoration: const InputDecoration(
                                      labelText: 'Room number',
                                      hintText: 'e.g. 0812',
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),

                            // 衣服件数
                            Row(
                              children: [
                                const Icon(Icons.checkroom_outlined),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _clothesController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Number of items',
                                      hintText: 'e.g. 6',
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),

                            // 日期
                            _bookingRow(
                              context: context,
                              icon: Icons.calendar_today_outlined,
                              label: 'Date',
                              value: _formatDate(_selectedDate),
                              onTap: () => _pickDate(context, maxAdvanceDays),
                            ),
                            const Divider(height: 24),

                            // 上门取衣时间
                            _bookingRow(
                              context: context,
                              icon: Icons.access_time,
                              label: 'Pickup time',
                              value: _pickupTime == null
                                  ? 'Select pickup time'
                                  : _pickupTime!.format(context),
                              onTap: () =>
                                  _pickPickupTime(context, openTime, closeTime),
                            ),
                            const Divider(height: 24),

                            // 归还时间
                            _bookingRow(
                              context: context,
                              icon: Icons.access_time_outlined,
                              label: 'Return time',
                              value: _returnTime == null
                                  ? 'Select return time'
                                  : _returnTime!.format(context),
                              onTap: () =>
                                  _pickReturnTime(context, openTime, closeTime),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 规则
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Rules & Notes',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _LightPalette.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _bullet(
                              'Service hours: $openStr–$closeStr (today or tomorrow only).',
                            ),
                            _bullet(
                              'Pickup time cannot be earlier than the current time on the same day.',
                            ),
                            _bullet(
                              'Return time must be at least 3 hours later than pickup time.',
                            ),
                            _bullet(
                              'Please make sure the room number and clothing count are accurate.',
                            ),
                            _bullet(notes),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _LightPalette.accentBlue,
                  disabledBackgroundColor: _LightPalette.accentBlue.withOpacity(
                    0.3,
                  ),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onPressed: canSubmit
                    ? () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const BookingSuccessPage(),
                          ),
                        );
                      }
                    : null,
                child: const Text(
                  'Confirm Booking',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- 公用小组件 ----------

Widget _bookingRow({
  required BuildContext context,
  required IconData icon,
  required String label,
  required String value,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    child: Row(
      children: [
        Icon(icon),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: TextStyle(color: Theme.of(context).colorScheme.primary),
        ),
      ],
    ),
  );
}

Widget _bullet(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('•  '),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

/// 和 ServicePage 一致的浅色调色板
class _LightPalette {
  static const bg = Color.fromARGB(255, 222, 228, 236);
  static const textPrimary = Color(0xFF0F1722);
  static const textSecondary = Color(0xFF5A6473);
  static const accentBlue = Color.fromARGB(255, 49, 59, 83);
}
