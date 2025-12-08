import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hotel_reservation_app/pages/booking_success_page.dart';
import 'package:panorama_viewer/panorama_viewer.dart'; // ⭐ 改成 panorama_viewer

class SwimmingBookingPage extends StatefulWidget {
  const SwimmingBookingPage({super.key});

  @override
  State<SwimmingBookingPage> createState() => _SwimmingBookingPageState();
}

class _SwimmingBookingPageState extends State<SwimmingBookingPage> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  int _guests = 1;

  // ⭐ 控制是否显示全景模式
  bool _showPanorama = false;

  Future<DocumentSnapshot<Map<String, dynamic>>> _loadService() {
    return FirebaseFirestore.instance
        .collection('services')
        .doc('swimming')
        .get();
  }

  // 选择日期，遵守 closedWeekdays + maxAdvanceDays
  Future<void> _pickDate(
    BuildContext context,
    List<int> closedWeekdays,
    int maxAdvanceDays,
  ) async {
    final today = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? today,
      firstDate: today,
      lastDate: today.add(Duration(days: maxAdvanceDays)), // ⭐ 最多提前 N 天
    );

    if (picked == null) return;

    // Firestore 里：0=Sunday, 1=Monday...
    final weekdayIndex = picked.weekday % 7; // Monday=1 ->1, Sunday=7->0
    if (closedWeekdays.contains(weekdayIndex)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The pool is closed on the selected day.'),
        ),
      );
      return;
    }

    setState(() {
      _selectedDate = picked;
    });
  }

  // 选择时间，遵守 open/close
  Future<void> _pickTime(
    BuildContext context,
    TimeOfDay open,
    TimeOfDay close,
  ) async {
    final TimeOfDay initial = _selectedTime ?? open; // 默认用开放时间作为初始值

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

    setState(() {
      _selectedTime = picked;
    });
  }

  bool _isTimeInRange(TimeOfDay t, TimeOfDay start, TimeOfDay end) {
    final tMinutes = t.hour * 60 + t.minute;
    final sMinutes = start.hour * 60 + start.minute;
    final eMinutes = end.hour * 60 + end.minute;
    return tMinutes >= sMinutes && tMinutes <= eMinutes;
  }

  TimeOfDay _parseTimeOfDay(String hhmm) {
    // 例如 "07:00"
    final parts = hhmm.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return TimeOfDay(hour: h, minute: m);
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Select Date';
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

  @override
  Widget build(BuildContext context) {
    return Theme(
      // ⭐ 颜色风格对齐 ServicePage
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
          title: const Text('Swimming Booking'),
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
            final name = data['name'] as String? ?? 'Swimming Pool';
            final description = data['description'] as String? ?? '';
            final isFree = data['isFree'] as bool? ?? false;
            final schedule = (data['schedule'] ?? {}) as Map<String, dynamic>;
            final openStr = schedule['open'] as String? ?? '07:00';
            final closeStr = schedule['close'] as String? ?? '21:00';
            final closedWeekdays =
                (schedule['closedWeekdays'] as List<dynamic>? ?? [])
                    .map((e) => e as int)
                    .toList();

            final ui = (data['ui'] ?? {}) as Map<String, dynamic>;
            final location =
                ui['location'] as String? ?? 'Hotel swimming pool area';
            final notes =
                ui['notes'] as String? ?? 'Please follow the pool rules.';

            final allowBookingWithinStay =
                data['allowBookingWithinStay'] as bool? ?? true;
            final bookOnlyDuringOpenHours =
                data['bookOnlyDuringOpenHours'] as bool? ?? true;
            final guestMustHaveActiveStay =
                data['guestMustHaveActiveStay'] as bool? ?? true;
            final preventDuplicateActiveBookings =
                data['preventDuplicateActiveBookings'] as bool? ?? true;

            final openTime = _parseTimeOfDay(openStr);
            final closeTime = _parseTimeOfDay(closeStr);

            // ⭐ 从 Firebase 读取 maxAdvanceDays（没有就默认 3）
            final maxAdvanceDays = data['maxAdvanceDays'] as int? ?? 3;

            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 顶部大图 + 360 按钮
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
                                    // ⭐ 使用 panorama_viewer
                                    child: Image.asset(
                                      'assets/services/pool_360.jpg',
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Image.asset(
                                    'assets/services/pool.jpg',
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

                  // 标题 + 免费标签 + 描述
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

                  // Booking Details 卡片
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
                            // Date
                            _bookingRow(
                              context: context,
                              icon: Icons.calendar_today_outlined,
                              label: 'Date',
                              value: _selectedDate == null
                                  ? 'Select Date'
                                  : _formatDate(_selectedDate),
                              onTap: () => _pickDate(
                                context,
                                closedWeekdays,
                                maxAdvanceDays, // ⭐ 传入最大提前天数
                              ),
                            ),
                            const Divider(height: 24),
                            // Time
                            _bookingRow(
                              context: context,
                              icon: Icons.access_time,
                              label: 'Time',
                              value: _selectedTime == null
                                  ? 'Select Time'
                                  : _selectedTime!.format(context),
                              onTap: () =>
                                  _pickTime(context, openTime, closeTime),
                            ),
                            const Divider(height: 24),
                            // Guests
                            Row(
                              children: [
                                const Icon(Icons.person_outline),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Guests',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: _guests > 1
                                      ? () {
                                          setState(() {
                                            _guests--;
                                          });
                                        }
                                      : null,
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                                Text('$_guests'),
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _guests++;
                                    });
                                  },
                                  icon: const Icon(Icons.add_circle_outline),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Rules & Notes
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
                            if (guestMustHaveActiveStay)
                              _bullet(
                                'Available only for guests with an active hotel stay.',
                              ),
                            if (allowBookingWithinStay)
                              _bullet(
                                'Reservations must be within your stay dates.',
                              ),
                            if (bookOnlyDuringOpenHours)
                              _bullet(
                                'Bookings and usage must be within operating hours ($openStr–$closeStr).',
                              ),
                            if (preventDuplicateActiveBookings)
                              _bullet(
                                'Only one active swimming booking is allowed at a time.',
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
                onPressed: _selectedDate == null || _selectedTime == null
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const BookingSuccessPage(),
                          ),
                        );
                      },
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

// 小组件 & 工具函数

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
