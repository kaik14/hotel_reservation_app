import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hotel_reservation_app/pages/booking_success_page.dart';
import 'package:panorama_viewer/panorama_viewer.dart';

class TaxiBookingPage extends StatefulWidget {
  const TaxiBookingPage({super.key});

  @override
  State<TaxiBookingPage> createState() => _TaxiBookingPageState();
}

class _TaxiBookingPageState extends State<TaxiBookingPage> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  // 行程类型：airportPickup / airportDropoff
  String? _selectedRideKey;

  // 乘客人数
  int _passengers = 1;

  // 360° 控制
  bool _showPanorama = false;

  // 加载 Firebase 中的 taxi 文档
  Future<DocumentSnapshot<Map<String, dynamic>>> _loadService() {
    return FirebaseFirestore.instance.collection('services').doc('taxi').get();
  }

  // ---------- 工具函数 ----------

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

  // 日期：今天 ~ 今天 + maxAdvanceDays（例如 3）
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
      _selectedTime = null;
    });
  }

  // 时间：在营业时间内 & 如果是今天，不能选过去时间
  Future<void> _pickTime(
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

    final TimeOfDay initial = _selectedTime ?? open;

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );

    if (picked == null) return;

    // 营业时间检查（这里是 00:00–23:59，但保留逻辑）
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

    // 如果预约日期是今天，不能早于当前时间
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
      _selectedTime = picked;
    });
  }

  // 提交按钮是否可用
  bool get canSubmit {
    if (_selectedDate == null || _selectedTime == null) return false;
    if (_selectedRideKey == null) return false;
    if (_passengers <= 0) return false;
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
          title: const Text('Taxi Booking'),
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

            // 基本信息
            final name = data['name'] as String? ?? 'Airport Taxi';
            final description =
                data['description'] as String? ??
                'Free airport pickup and drop-off taxi service.';
            final isFree = data['isFree'] as bool? ?? false;

            // 营业时间（这里基本是 24 小时）
            final schedule = (data['schedule'] ?? {}) as Map<String, dynamic>;
            final openStr = schedule['open'] as String? ?? '00:00';
            final closeStr = schedule['close'] as String? ?? '23:59';
            final openTime = _parseTimeOfDay(openStr);
            final closeTime = _parseTimeOfDay(closeStr);

            // 最多提前几天（一般是 3）
            final maxAdvanceDays = data['maxAdvanceDays'] as int? ?? 3;

            // rideTypes: airportPickup / airportDropoff
            final rideTypes = (data['rideTypes'] ?? {}) as Map<String, dynamic>;

            if (_selectedRideKey == null && rideTypes.isNotEmpty) {
              _selectedRideKey = rideTypes.keys.first;
            }

            Map<String, dynamic>? selectedRide;
            if (_selectedRideKey != null &&
                rideTypes[_selectedRideKey] is Map<String, dynamic>) {
              selectedRide =
                  rideTypes[_selectedRideKey] as Map<String, dynamic>;
            }

            final rideLabel =
                selectedRide?['label'] as String? ?? 'Select ride type';
            final rideDescription =
                selectedRide?['description'] as String? ?? '';
            final rideNote = selectedRide?['note'] as String? ?? '';
            final minPassengers = selectedRide?['passengersMin'] as int? ?? 1;
            final maxPassengers = selectedRide?['passengersMax'] as int? ?? 4;

            // 保证人数在合法范围内（只影响 UI，不在 build 里 setState）
            final shownPassengers = _passengers.clamp(
              minPassengers,
              maxPassengers,
            );

            // UI 信息
            final ui = (data['ui'] ?? {}) as Map<String, dynamic>;
            final location =
                ui['location'] as String? ?? 'Hotel Main Lobby Pick-up Point';
            final notes =
                ui['notes'] as String? ??
                'Please wait at the main lobby pick-up point.';

            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 顶部大图 + 360°
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
                                      'assets/services/taxi_360.jpg',
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Image.asset(
                                    'assets/services/taxi.jpg',
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

                  // 标题 + Free 标签
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
                            // Ride type 下拉
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.local_taxi_outlined),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Ride type',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      DropdownButton<String>(
                                        value: _selectedRideKey,
                                        isExpanded: true,
                                        underline: const SizedBox.shrink(),
                                        hint: const Text(
                                          'Select pickup/drop-off',
                                        ),
                                        items: rideTypes.entries.map((entry) {
                                          final key = entry.key;
                                          final map =
                                              entry.value
                                                  as Map<String, dynamic>;
                                          final label =
                                              map['label'] as String? ?? key;
                                          return DropdownMenuItem<String>(
                                            value: key,
                                            child: Text(label),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          setState(() {
                                            _selectedRideKey = val;
                                          });
                                        },
                                      ),
                                      if (rideDescription.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 2,
                                          ),
                                          child: Text(
                                            rideDescription,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color:
                                                  _LightPalette.textSecondary,
                                            ),
                                          ),
                                        ),
                                    ],
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

                            // 时间
                            _bookingRow(
                              context: context,
                              icon: Icons.access_time,
                              label: 'Time',
                              value: _selectedTime == null
                                  ? 'Select time'
                                  : _selectedTime!.format(context),
                              onTap: () =>
                                  _pickTime(context, openTime, closeTime),
                            ),
                            const Divider(height: 24),

                            // 乘客人数
                            Row(
                              children: [
                                const Icon(Icons.people_outline),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Passengers',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: shownPassengers > minPassengers
                                      ? () {
                                          setState(() {
                                            _passengers--;
                                          });
                                        }
                                      : null,
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                                Text('$shownPassengers'),
                                IconButton(
                                  onPressed: shownPassengers < maxPassengers
                                      ? () {
                                          setState(() {
                                            _passengers++;
                                          });
                                        }
                                      : null,
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

                  // 规则 & Notes
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
                              'Bookings are available within ${maxAdvanceDays.toString()} days from today (today and the next days).',
                            ),
                            _bullet(
                              'For rides scheduled today, the pickup time must be later than the current time.',
                            ),
                            _bullet(
                              'Passenger count must be between $minPassengers and $maxPassengers per car.',
                            ),
                            if (rideNote.isNotEmpty) _bullet(rideNote),
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
                        // 现在只是跳到成功页面，将来可以在这里写入 Firestore
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

// ---------- 共用小组件 ----------

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
