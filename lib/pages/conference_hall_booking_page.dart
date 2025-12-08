import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hotel_reservation_app/pages/booking_success_page.dart';
import 'package:panorama_viewer/panorama_viewer.dart'; // ⭐ 改成 panorama_viewer

class ConferenceHallBookingPage extends StatefulWidget {
  const ConferenceHallBookingPage({super.key});

  @override
  State<ConferenceHallBookingPage> createState() =>
      _ConferenceHallBookingPageState();
}

class _ConferenceHallBookingPageState extends State<ConferenceHallBookingPage> {
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  // 选择的小/中/大会议室 key：small / medium / large
  String? _selectedRoomKey;

  // 是否显示 360° 模式
  bool _showPanorama = false;

  Future<DocumentSnapshot<Map<String, dynamic>>> _loadService() {
    return FirebaseFirestore.instance
        .collection('services')
        .doc('conferenceHall')
        .get();
  }

  // ------------ 日期选择：最多提前 maxAdvanceDays 天 ------------
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
      // 换了日期后，时间清空，避免出现“选了过去时间”
      _startTime = null;
      _endTime = null;
    });
  }

  int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  // 支持跨夜的营业时间判断，例如 06:00–02:00
  bool _isTimeInRange(TimeOfDay t, TimeOfDay open, TimeOfDay close) {
    final tM = _toMinutes(t);
    final oM = _toMinutes(open);
    final cM = _toMinutes(close);

    if (cM >= oM) {
      // 正常情况：开始 < 结束，例如 08:00–20:00
      return tM >= oM && tM <= cM;
    } else {
      // 跨夜：例如 06:00–02:00
      // 允许 [open, 24:00) ∪ [00:00, close]
      return tM >= oM || tM <= cM;
    }
  }

  bool _isEndAfterStart(TimeOfDay start, TimeOfDay end) {
    return _toMinutes(end) > _toMinutes(start);
  }

  // ------------ 开始时间选择 ------------
  Future<void> _pickStartTime(
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

    final TimeOfDay initial = _startTime ?? open;

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );

    if (picked == null) return;

    // 检查是否在营业时间内
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

    // 当天不能选当前时间之前
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
      _startTime = picked;
      // 如果已有结束时间且不合法，则清空
      if (_endTime != null && !_isEndAfterStart(_startTime!, _endTime!)) {
        _endTime = null;
      }
    });
  }

  // ------------ 结束时间选择 ------------
  Future<void> _pickEndTime(
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

    if (_startTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a start time first.')),
      );
      return;
    }

    final TimeOfDay initial = _endTime ?? _startTime!;

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

    if (!_isEndAfterStart(_startTime!, picked)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End time must be later than start time.'),
        ),
      );
      return;
    }

    setState(() {
      _endTime = picked;
    });
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
      // 和 ServicePage 同色系
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
          title: const Text('Conference Hall Booking'),
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
            final name = data['name'] as String? ?? 'Conference Hall';
            final description =
                data['description'] as String? ?? 'Conference facility.';
            final isFree = data['isFree'] as bool? ?? false;

            final schedule = (data['schedule'] ?? {}) as Map<String, dynamic>;
            final openStr = schedule['open'] as String? ?? '06:00';
            final closeStr = schedule['close'] as String? ?? '02:00';
            // closeNextDay 在这里目前不直接用，靠 _isTimeInRange 处理跨夜
            final openTime = _parseTimeOfDay(openStr);
            final closeTime = _parseTimeOfDay(closeStr);

            final ui = (data['ui'] ?? {}) as Map<String, dynamic>;
            final location =
                ui['location'] as String? ??
                'Level 3, Conference & Events Floor';
            final notes =
                ui['notes'] as String? ??
                'Please arrive 15 minutes early for setup.';

            final maxAdvanceDays = data['maxAdvanceDays'] as int? ?? 5;

            final roomTypes = (data['roomTypes'] ?? {}) as Map<String, dynamic>;

            // 初始化当前选中的房型 key：small / medium / large
            if (_selectedRoomKey == null && roomTypes.isNotEmpty) {
              _selectedRoomKey = roomTypes.keys.first;
            }
            final selectedRoomMap =
                _selectedRoomKey != null &&
                    roomTypes[_selectedRoomKey] is Map<String, dynamic>
                ? roomTypes[_selectedRoomKey] as Map<String, dynamic>
                : null;

            final selectedRoomLabel =
                selectedRoomMap?['label'] as String? ?? 'Select room type';
            final capMin = selectedRoomMap?['capacityMin'] as int?;
            final capMax = selectedRoomMap?['capacityMax'] as int?;

            final roomSubtitle = (capMin != null && capMax != null)
                ? '($capMin–$capMax people)'
                : '';

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
                                    child: Image.asset(
                                      // 记得把 conference_360.jpg 放到 assets/services/
                                      'assets/services/conference_360.jpg',
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Image.asset(
                                    'assets/services/conference.jpg',
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
                            // Room Type 选择
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Icon(Icons.meeting_room_outlined),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Room Type',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      DropdownButton<String>(
                                        value: _selectedRoomKey,
                                        isExpanded: true,
                                        underline: const SizedBox.shrink(),
                                        hint: const Text('Select room type'),
                                        items: roomTypes.entries.map((entry) {
                                          final key = entry.key;
                                          final map =
                                              entry.value
                                                  as Map<String, dynamic>;
                                          final label =
                                              map['label'] as String? ?? key;
                                          final cMin =
                                              map['capacityMin'] as int?;
                                          final cMax =
                                              map['capacityMax'] as int?;
                                          final sub =
                                              (cMin != null && cMax != null)
                                              ? ' ($cMin–$cMax people)'
                                              : '';
                                          return DropdownMenuItem<String>(
                                            value: key,
                                            child: Text(label + sub),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          setState(() {
                                            _selectedRoomKey = val;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),

                            // Date
                            _bookingRow(
                              context: context,
                              icon: Icons.calendar_today_outlined,
                              label: 'Date',
                              value: _formatDate(_selectedDate),
                              onTap: () => _pickDate(context, maxAdvanceDays),
                            ),
                            const Divider(height: 24),

                            // Start Time
                            _bookingRow(
                              context: context,
                              icon: Icons.schedule,
                              label: 'Start time',
                              value: _startTime == null
                                  ? 'Select start time'
                                  : _startTime!.format(context),
                              onTap: () =>
                                  _pickStartTime(context, openTime, closeTime),
                            ),
                            const Divider(height: 24),

                            // End Time
                            _bookingRow(
                              context: context,
                              icon: Icons.schedule_outlined,
                              label: 'End time',
                              value: _endTime == null
                                  ? 'Select end time'
                                  : _endTime!.format(context),
                              onTap: () =>
                                  _pickEndTime(context, openTime, closeTime),
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
                              'Bookings must be within your stay dates and opening hours (06:00–02:00).',
                            ),
                            _bullet(
                              'Please arrive 15 minutes early for setup.',
                            ),
                            _bullet(
                              'Food and beverages must follow hotel catering policies.',
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
                onPressed:
                    (_selectedDate == null ||
                        _startTime == null ||
                        _endTime == null ||
                        _selectedRoomKey == null)
                    ? null
                    : () {
                        // 这里简单跳到通用成功页面，实际项目可以写入 Firestore
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

  TimeOfDay _parseTimeOfDay(String hhmm) {
    final parts = hhmm.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return TimeOfDay(hour: h, minute: m);
  }
}

// ---------- 小组件 & 工具函数 ----------

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
