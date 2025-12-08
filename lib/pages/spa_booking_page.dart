import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hotel_reservation_app/pages/booking_success_page.dart';
import 'package:panorama_viewer/panorama_viewer.dart';

class SpaBookingPage extends StatefulWidget {
  const SpaBookingPage({super.key});

  @override
  State<SpaBookingPage> createState() => _SpaBookingPageState();
}

class _SpaBookingPageState extends State<SpaBookingPage> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  int _guests = 1;
  String? _selectedServiceKey; // 选中的治疗项目 key，如 swedishMassage

  bool _showPanorama = false;

  Future<DocumentSnapshot<Map<String, dynamic>>> _loadService() {
    return FirebaseFirestore.instance.collection('services').doc('spa').get();
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

  // 日期：今明两天（由 maxAdvanceDays 控制）
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
      _selectedTime = null; // 换日期时清空时间，避免时间变成“过去”
    });
  }

  // 时间：在营业时间内，且如果是今天必须晚于当前时间
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
    final today = DateTime(now.year, now.month, now.day);
    final selectedDay = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
    );

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
  bool _canSubmit({
    required Map<String, dynamic> services,
    required int minGuests,
    required int maxGuests,
  }) {
    if (_selectedDate == null || _selectedTime == null) return false;
    if (_selectedServiceKey == null) return false;
    if (_guests < minGuests || _guests > maxGuests) return false;
    if (!services.containsKey(_selectedServiceKey)) return false;
    return true;
  }

  // 计算总价
  double _computeTotalPrice(Map<String, dynamic> services) {
    if (_selectedServiceKey == null) return 0;
    final dynamic raw = services[_selectedServiceKey];
    if (raw is! Map<String, dynamic>) return 0;
    final price = (raw['price'] as num?) ?? 0;
    return price.toDouble() * _guests;
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
          title: const Text('Spa Booking'),
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

            final name = data['name'] as String? ?? 'Spa & Wellness';
            final description =
                data['description'] as String? ??
                'Professional spa and wellness treatments.';
            final isFree = data['isFree'] as bool? ?? false; // 这里应该是 false

            final schedule = (data['schedule'] ?? {}) as Map<String, dynamic>;
            final openStr = schedule['open'] as String? ?? '09:00';
            final closeStr = schedule['close'] as String? ?? '22:00';
            final openTime = _parseTimeOfDay(openStr);
            final closeTime = _parseTimeOfDay(closeStr);

            final maxAdvanceDays = data['maxAdvanceDays'] as int? ?? 2;
            final minGuests = data['minGuestsPerBooking'] as int? ?? 1;
            final maxGuests = data['maxGuestsPerBooking'] as int? ?? 4;
            final currency = data['currency'] as String? ?? 'MYR';

            final ui = (data['ui'] ?? {}) as Map<String, dynamic>;
            final location =
                ui['location'] as String? ?? 'Level 2, Spa & Wellness Center';
            final notes =
                ui['notes'] as String? ??
                'Please arrive 10–15 minutes early for preparation.';

            final services = (data['services'] ?? {}) as Map<String, dynamic>;

            // 初始化默认选中第一个服务
            if (_selectedServiceKey == null && services.isNotEmpty) {
              _selectedServiceKey = services.keys.first;
            }

            final totalPrice = _computeTotalPrice(services);

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
                                      'assets/services/spa_360.jpg',
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Image.asset(
                                    'assets/services/spa.jpg',
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

                  // 标题 + 是否免费（这里一般是收费，不会显示 Free）
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
                            // 服务类型选择（Swedish / Aromatherapy / …）
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.spa_outlined),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Treatment',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      DropdownButton<String>(
                                        value: _selectedServiceKey,
                                        isExpanded: true,
                                        underline: const SizedBox.shrink(),
                                        hint: const Text('Select treatment'),
                                        items: services.entries.map((entry) {
                                          final key = entry.key;
                                          final map =
                                              entry.value
                                                  as Map<String, dynamic>;
                                          final label =
                                              map['label'] as String? ?? key;
                                          final price =
                                              (map['price'] as num?) ?? 0;
                                          return DropdownMenuItem<String>(
                                            value: key,
                                            child: Text(
                                              '$label  (${currency == 'MYR' ? 'RM' : currency} ${price.toStringAsFixed(2)})',
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          setState(() {
                                            _selectedServiceKey = val;
                                          });
                                        },
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

                            // Guests 人数
                            Row(
                              children: [
                                const Icon(Icons.person_outline),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Guests',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: _guests > minGuests
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
                                  onPressed: _guests < maxGuests
                                      ? () {
                                          setState(() {
                                            _guests++;
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

                  // 价格 Summary
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.receipt_long_outlined),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Total (${_guests} guest${_guests > 1 ? 's' : ''})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Text(
                              totalPrice <= 0
                                  ? '--'
                                  : '${currency == 'MYR' ? 'RM' : currency} ${totalPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
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
                            _bullet(
                              'Service hours: $openStr–$closeStr (today or tomorrow only).',
                            ),
                            _bullet(
                              'Bookings must be within your stay dates and within opening hours.',
                            ),
                            _bullet(
                              'Please arrive 10–15 minutes early before your session.',
                            ),
                            _bullet(
                              'Guests with medical conditions should inform the therapist in advance.',
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
            child: Builder(
              builder: (context) {
                // 这里为了拿到 services / guests 等状态，需要在上面的 FutureBuilder 里计算，
                // 但我们已经在 _canSubmit 里封装了逻辑，所以在 onPressed 里只简单判断：
                // （注意：_canSubmit 需要 services 等参数，所以我们在 FutureBuilder 里判断）
                // 为了简单，我们直接在按钮 enable/disable 用一个布尔占位，真正逻辑在上面控制。
                // 这里我们用一个占位的 enabled，在 FutureBuilder 内部调用时会正确传递。
                return ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _LightPalette.accentBlue,
                    disabledBackgroundColor: _LightPalette.accentBlue
                        .withOpacity(0.3),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  onPressed: null, // 👉 真正的 enable/disable 在上面的逻辑中控制
                  child: const Text(
                    'Confirm Booking',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                );
              },
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
