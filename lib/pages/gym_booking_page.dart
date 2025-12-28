import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hotel_reservation_app/pages/booking_success_page.dart';
import 'package:panorama_viewer/panorama_viewer.dart'; // ⭐ panorama_viewer

class GymBookingPage extends StatefulWidget {
  /// ✅ Edit 模式支持：保留历史选项 + 保存更改（无支付）
  final String? existingBookingId;
  final Map<String, dynamic>? existingData;

  const GymBookingPage({super.key, this.existingBookingId, this.existingData});

  @override
  State<GymBookingPage> createState() => _GymBookingPageState();
}

class _GymBookingPageState extends State<GymBookingPage> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  int _guests = 1;

  bool _showPanorama = false;

  bool _isSubmitting = false;

  bool get _isEditMode =>
      widget.existingBookingId != null && widget.existingBookingId!.isNotEmpty;

  Future<DocumentSnapshot<Map<String, dynamic>>> _loadService() {
    return FirebaseFirestore.instance.collection('services').doc('gym').get();
  }

  // =================== helper ===================
  TimeOfDay _parseTimeOfDay(String hhmm) {
    final parts = hhmm.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return TimeOfDay(hour: h, minute: m);
  }

  String _fmtHHmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  DateTime? _serviceStartAt() {
    if (_selectedDate == null || _selectedTime == null) return null;
    return DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
  }

  int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  bool _isTimeInRange(TimeOfDay t, TimeOfDay start, TimeOfDay end) {
    final tMinutes = t.hour * 60 + t.minute;
    final sMinutes = start.hour * 60 + start.minute;
    final eMinutes = end.hour * 60 + end.minute;
    return tMinutes >= sMinutes && tMinutes <= eMinutes;
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

  // =================== Edit 回填 ===================
  @override
  void initState() {
    super.initState();

    if (_isEditMode && widget.existingData != null) {
      final d = widget.existingData!;

      // guests
      final g = d['guests'] ?? d['totalGuests'];
      if (g is int) _guests = g;
      if (g is String) _guests = int.tryParse(g) ?? _guests;

      // time
      DateTime? startAt;
      final ts = d['serviceStart'] as Timestamp?;
      if (ts != null) {
        startAt = ts.toDate();
      } else {
        final dateTs = d['serviceDate'] as Timestamp?;
        final timeStr = d['serviceTime'] as String?;
        if (dateTs != null && timeStr != null && timeStr.contains(':')) {
          final date = dateTs.toDate();
          final parts = timeStr.split(':');
          final h = int.tryParse(parts[0]) ?? 0;
          final m = int.tryParse(parts[1]) ?? 0;
          startAt = DateTime(date.year, date.month, date.day, h, m);
        }
      }

      if (startAt != null) {
        _selectedDate = DateTime(startAt.year, startAt.month, startAt.day);
        _selectedTime = TimeOfDay(hour: startAt.hour, minute: startAt.minute);
      }
    }
  }

  // =================== pickers ===================
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
      lastDate: today.add(Duration(days: maxAdvanceDays)),
    );

    if (picked == null) return;

    final weekdayIndex = picked.weekday % 7;
    if (closedWeekdays.contains(weekdayIndex)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The gym is closed on the selected day.')),
      );
      return;
    }

    setState(() {
      _selectedDate = picked;
      _selectedTime = null;
    });
  }

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

    // 今天不能选过去
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

    setState(() {
      _selectedTime = picked;
    });
  }

  // =================== submit availability ===================
  bool get canSubmit {
    if (_selectedDate == null || _selectedTime == null) return false;
    if (_guests <= 0) return false;
    return !_isSubmitting;
  }

  // =================== create/update booking ===================
  Future<void> _createGymBooking({
    required String serviceName,
    required String location,
    required String serviceImagePath,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Not logged in.')));
      return;
    }

    final startAt = _serviceStartAt();
    if (startAt == null) return;

    setState(() => _isSubmitting = true);

    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('bookings')
          .doc();

      await docRef.set({
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),

        'bookingType': 'service',
        'serviceType': 'gym',
        'serviceName': serviceName,
        'serviceImagePath': serviceImagePath,
        'location': location,

        'serviceDate': Timestamp.fromDate(
          DateTime(startAt.year, startAt.month, startAt.day),
        ),
        'serviceStart': Timestamp.fromDate(startAt),
        'serviceTime': _fmtHHmm(_selectedTime!),

        // gym specific
        'guests': _guests,
        'totalGuests': _guests,

        // free service
        'currency': 'MYR',
        'totalPriceRM': 0,
      });

      if (!mounted) return;
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const BookingSuccessPage()));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Booking failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _updateGymBooking({
    required String serviceName,
    required String location,
    required String serviceImagePath,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Not logged in.')));
      return;
    }

    final startAt = _serviceStartAt();
    if (startAt == null) return;

    setState(() => _isSubmitting = true);

    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('bookings')
          .doc(widget.existingBookingId);

      await docRef.update({
        'updatedAt': Timestamp.now(),

        'bookingType': 'service',
        'serviceType': 'gym',
        'serviceName': serviceName,
        'serviceImagePath': serviceImagePath,
        'location': location,

        'serviceDate': Timestamp.fromDate(
          DateTime(startAt.year, startAt.month, startAt.day),
        ),
        'serviceStart': Timestamp.fromDate(startAt),
        'serviceTime': _fmtHHmm(_selectedTime!),

        'guests': _guests,
        'totalGuests': _guests,

        'currency': 'MYR',
        'totalPriceRM': 0,
      });

      if (!mounted) return;
      // ✅ 保存更改：返回 true 给 BookingDetail
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // =================== UI ===================
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
          title: Text(_isEditMode ? 'Edit Gym Booking' : 'Gym Booking'),
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
            final name = data['name'] as String? ?? 'Gym & Fitness Center';
            final description =
                data['description'] as String? ?? 'Hotel fitness center.';
            final isFree = data['isFree'] as bool? ?? false;

            final schedule = (data['schedule'] ?? {}) as Map<String, dynamic>;
            final openStr = schedule['open'] as String? ?? '06:00';
            final closeStr = schedule['close'] as String? ?? '22:00';
            final closedWeekdays =
                (schedule['closedWeekdays'] as List<dynamic>? ?? [])
                    .map((e) => e as int)
                    .toList();

            final ui = (data['ui'] ?? {}) as Map<String, dynamic>;
            final location =
                ui['location'] as String? ?? 'Level 5, Fitness Center';
            final notes =
                ui['notes'] as String? ??
                'Please wear sports attire and follow gym safety rules.';

            final allowBookingWithinStay =
                data['allowBookingWithinStay'] as bool? ?? true;
            final bookOnlyDuringOpenHours =
                data['bookOnlyDuringOpenHours'] as bool? ?? true;
            final guestMustHaveActiveStay =
                data['guestMustHaveActiveStay'] as bool? ?? true;
            final preventDuplicateActiveBookings =
                data['preventDuplicateActiveBookings'] as bool? ?? true;

            final maxAdvanceDays = data['maxAdvanceDays'] as int? ?? 3;

            final openTime = _parseTimeOfDay(openStr);
            final closeTime = _parseTimeOfDay(closeStr);

            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 90),
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
                                      'assets/services/gym_360.jpg',
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Image.asset(
                                    'assets/services/gym.jpg',
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
                                maxAdvanceDays,
                              ),
                            ),
                            const Divider(height: 24),
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
                                      ? () => setState(() => _guests--)
                                      : null,
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                                Text('$_guests'),
                                IconButton(
                                  onPressed: () => setState(() => _guests++),
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
                                'Only one active gym booking is allowed at a time.',
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

        // ✅ 按你的规则：创建=Confirm Booking；编辑=Save Changes（无支付）
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
                    ? () async {
                        final snap = await _loadService();
                        if (!snap.exists) return;
                        final serviceData = snap.data() ?? {};

                        final serviceName =
                            (serviceData['name'] as String?) ??
                            'Gym & Fitness Center';
                        final ui =
                            (serviceData['ui'] ?? {}) as Map<String, dynamic>;
                        final location =
                            (ui['location'] as String?) ??
                            'Level 5, Fitness Center';

                        // ✅ gym 不需要支付，统一写 0
                        const serviceImagePath = 'assets/services/gym.jpg';

                        if (_isEditMode) {
                          await _updateGymBooking(
                            serviceName: serviceName,
                            location: location,
                            serviceImagePath: serviceImagePath,
                          );
                        } else {
                          await _createGymBooking(
                            serviceName: serviceName,
                            location: location,
                            serviceImagePath: serviceImagePath,
                          );
                        }
                      }
                    : null,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isEditMode ? 'Save Changes' : 'Confirm Booking',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// 小组件
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

class _LightPalette {
  static const bg = Color.fromARGB(255, 222, 228, 236);
  static const textPrimary = Color(0xFF0F1722);
  static const textSecondary = Color(0xFF5A6473);
  static const accentBlue = Color.fromARGB(255, 49, 59, 83);
}
