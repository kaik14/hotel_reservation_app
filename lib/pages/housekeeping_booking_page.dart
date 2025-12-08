import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hotel_reservation_app/pages/booking_success_page.dart';
import 'package:panorama_viewer/panorama_viewer.dart'; // ⭐ 使用 panorama_viewer

class HousekeepingBookingPage extends StatefulWidget {
  const HousekeepingBookingPage({super.key});

  @override
  State<HousekeepingBookingPage> createState() =>
      _HousekeepingBookingPageState();
}

class _HousekeepingBookingPageState extends State<HousekeepingBookingPage> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  final TextEditingController _roomController = TextEditingController();

  bool _showPanorama = false;

  Future<DocumentSnapshot<Map<String, dynamic>>> _loadService() {
    return FirebaseFirestore.instance
        .collection('services')
        .doc('housekeeping')
        .get();
  }

  // ---------------------- 日期选择（仅限今明两天） ----------------------
  Future<void> _pickDate() async {
    final today = DateTime.now();
    final maxDate = today.add(const Duration(days: 1)); // 今 + 明

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? today,
      firstDate: today,
      lastDate: maxDate,
    );

    if (picked == null) return;

    setState(() {
      _selectedDate = picked;
      _selectedTime = null;
    });
  }

  // ---------------------- 时间选择（07:00–22:00） ----------------------
  Future<void> _pickTime(TimeOfDay open, TimeOfDay close) async {
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date first.')),
      );
      return;
    }

    final TimeOfDay initial = _selectedTime ?? open;

    final picked = await showTimePicker(context: context, initialTime: initial);

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

    // 当天不能选过去时间
    final now = DateTime.now();
    final selectedDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      picked.hour,
      picked.minute,
    );

    if (selectedDateTime.isBefore(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a future time.')),
      );
      return;
    }

    setState(() => _selectedTime = picked);
  }

  bool _isTimeInRange(TimeOfDay t, TimeOfDay open, TimeOfDay close) {
    final minutes = t.hour * 60 + t.minute;
    final openM = open.hour * 60 + open.minute;
    final closeM = close.hour * 60 + close.minute;
    return minutes >= openM && minutes <= closeM;
  }

  TimeOfDay _parseTimeOfDay(String hhmm) {
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

  String _monthName(int m) {
    const names = [
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
    return names[m - 1];
  }

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
          title: const Text('Housekeeping Booking'),
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
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.data!.exists) {
              return const Center(child: Text('Service not found'));
            }

            final data = snapshot.data!.data()!;
            final name = data['name'] ?? 'Housekeeping';
            final description = data['description'] ?? 'Room cleaning service.';
            final location = data['ui']?['location'] ?? 'Your room';
            final notes = data['ui']?['notes'] ?? 'Staff will arrive on time.';

            final schedule = (data['schedule'] ?? {});
            final openStr = schedule['open'] ?? '07:00';
            final closeStr = schedule['close'] ?? '22:00';

            final openTime = _parseTimeOfDay(openStr);
            final closeTime = _parseTimeOfDay(closeStr);

            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ---------------------- 顶部大图 + 360 按钮 ----------------------
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
                                      'assets/services/housekeeping_360.jpg',
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Image.asset(
                                    'assets/services/housekeeping.jpg',
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
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                              ),
                              onPressed: () => setState(
                                () => _showPanorama = !_showPanorama,
                              ),
                              icon: const Icon(Icons.threesixty),
                              label: Text(_showPanorama ? 'Exit 360°' : '360°'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ---------------------- 标题 & 描述 ----------------------
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: _LightPalette.textPrimary,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      description,
                      style: TextStyle(color: _LightPalette.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ---------------------- Booking Details ----------------------
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Booking Details',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // 房间号输入
                            TextField(
                              controller: _roomController,
                              decoration: const InputDecoration(
                                labelText: 'Room Number',
                                prefixIcon: Icon(Icons.door_front_door),
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 日期
                            _bookingRow(
                              context: context,
                              icon: Icons.calendar_today_outlined,
                              label: 'Date',
                              value: _formatDate(_selectedDate),
                              onTap: _pickDate,
                            ),

                            const Divider(height: 24),

                            // 时间
                            _bookingRow(
                              context: context,
                              icon: Icons.access_time,
                              label: 'Time',
                              value: _selectedTime == null
                                  ? 'Select Time'
                                  : _selectedTime!.format(context),
                              onTap: () => _pickTime(openTime, closeTime),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ---------------------- Notes ----------------------
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Rules & Notes',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _bullet('Service available from 07:00 to 22:00.'),
                            _bullet('Please ensure the room is accessible.'),
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

        // ---------------------- Confirm Button ----------------------
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _LightPalette.accentBlue,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              onPressed:
                  (_selectedDate == null ||
                      _selectedTime == null ||
                      _roomController.text.isEmpty)
                  ? null
                  : () {
                      Navigator.push(
                        context,
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
    );
  }
}

// ---------------------- 小组件 ----------------------

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
        Expanded(child: Text(label)),
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

// ---------------------- 配色 ----------------------
class _LightPalette {
  static const bg = Color.fromARGB(255, 222, 228, 236);
  static const textPrimary = Color(0xFF0F1722);
  static const textSecondary = Color(0xFF5A6473);
  static const accentBlue = Color.fromARGB(255, 49, 59, 83);
}
