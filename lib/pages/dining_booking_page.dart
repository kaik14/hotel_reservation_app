import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:panorama_viewer/panorama_viewer.dart';

import 'package:hotel_reservation_app/pages/booking_success_page.dart';
import 'package:hotel_reservation_app/pages/payment_screen.dart';

class DiningBookingPage extends StatefulWidget {
  /// ✅ Edit Mode：如果不为 null，代表编辑已有预订
  final String? existingBookingId;
  final Map<String, dynamic>? existingData;

  const DiningBookingPage({
    super.key,
    this.existingBookingId,
    this.existingData,
  });

  @override
  State<DiningBookingPage> createState() => _DiningBookingPageState();
}

class _DiningBookingPageState extends State<DiningBookingPage> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  int _adultCount = 1; // 至少 1 位成人
  int _childCount = 0;

  bool _showPanorama = false;

  bool get _isEditMode => widget.existingBookingId != null;

  // 从 Firestore 读取 dining service
  Future<DocumentSnapshot<Map<String, dynamic>>> _loadService() {
    return FirebaseFirestore.instance
        .collection('services')
        .doc('dining')
        .get();
  }

  // ======== 时间工具函数 ========

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

  DateTime _combineDateTime(DateTime d, TimeOfDay t) {
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Select date';
    return '${date.day.toString().padLeft(2, '0')} ${_monthName(date.month)} ${date.year}';
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

  // ======== 选择日期：只能今 / 明两天（由 maxAdvanceDays 控制） ========

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

  // ======== 选择时间：在营业时间内，且当天不能早于当前时间 ========

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

    setState(() => _selectedTime = picked);
  }

  // ======== 提交条件 & 总价计算 ========

  int _calcTotalPriceRM({required int adultPrice, required int childPrice}) {
    return _adultCount * adultPrice + _childCount * childPrice;
  }

  bool _canSubmit({required int minAdults, required int? maxGuests}) {
    if (_selectedDate == null || _selectedTime == null) return false;
    if (_adultCount < minAdults) return false;

    final totalGuests = _adultCount + _childCount;
    if (maxGuests != null && totalGuests > maxGuests) return false;

    return true;
  }

  // ======== Edit Mode：预填旧值 ========

  @override
  void initState() {
    super.initState();

    final d = widget.existingData;
    if (d == null) return;

    final Timestamp? serviceDateTs = d['serviceDate'] as Timestamp?;
    final Timestamp? serviceStartTs = d['serviceStart'] as Timestamp?;
    final int? adults = d['adultCount'] as int?;
    final int? children = d['childCount'] as int?;

    if (serviceDateTs != null) {
      _selectedDate = serviceDateTs.toDate();
    } else if (serviceStartTs != null) {
      _selectedDate = serviceStartTs.toDate();
    }

    final DateTime? start = serviceStartTs?.toDate();
    if (start != null) {
      _selectedTime = TimeOfDay(hour: start.hour, minute: start.minute);
    } else {
      final String? timeStr = d['serviceTime'] as String?;
      if (timeStr != null && timeStr.contains(':')) {
        final parts = timeStr.split(':');
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        _selectedTime = TimeOfDay(hour: h, minute: m);
      }
    }

    if (adults != null) _adultCount = adults;
    if (children != null) _childCount = children;
  }

  // ======== Edit Mode：保存修改（不走 Payment） ========

  Future<void> _saveDiningChanges({
    required String serviceName,
    required int adultPrice,
    required int childPrice,
    required int? maxGuests,
    required int minAdults,
    required String openStr,
    required String closeStr,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please log in first.')));
      return;
    }
    if (_selectedDate == null || _selectedTime == null) return;

    if (!_canSubmit(minAdults: minAdults, maxGuests: maxGuests)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete your booking details.')),
      );
      return;
    }

    final start = _combineDateTime(_selectedDate!, _selectedTime!);
    final totalPriceRM = _calcTotalPriceRM(
      adultPrice: adultPrice,
      childPrice: childPrice,
    );

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('bookings')
          .doc(widget.existingBookingId)
          .update({
            'serviceDate': Timestamp.fromDate(_selectedDate!),
            'serviceTime':
                '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
            'serviceStart': Timestamp.fromDate(start),
            'adultCount': _adultCount,
            'childCount': _childCount,
            'totalGuests': _adultCount + _childCount,
            'totalPriceRM': totalPriceRM,
            'updatedAt': Timestamp.now(),
          });

      final msgTitle = 'Dining Booking Updated';
      final msgBody =
          'Your dining reservation has been updated.\n'
          'Date: ${DateFormat('dd MMM yyyy').format(_selectedDate!)}\n'
          'Time: ${_selectedTime!.format(context)}\n'
          'Guests: $_adultCount adult(s), $_childCount child(ren)\n'
          'Total: RM $totalPriceRM\n'
          'Service hours: $openStr–$closeStr';

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('messages')
          .add({
            'title': msgTitle,
            'message': msgBody,
            'senderIcon': 'system',
            'timestamp': Timestamp.now(),
          });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Changes saved successfully.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save changes: $e')));
    }
  }

  // ✅ free booking 成功后写 message
  Future<void> _writeCreateSuccessMessage({
    required User user,
    required String serviceName,
    required DateTime serviceStart,
    required int totalPriceRM,
  }) async {
    final msgTitle = 'Dining Booking Confirmed';
    final msgBody =
        'Your dining reservation is confirmed.\n'
        'Date: ${DateFormat('dd MMM yyyy').format(serviceStart)}\n'
        'Time: ${DateFormat('HH:mm').format(serviceStart)}\n'
        'Guests: $_adultCount adult(s), $_childCount child(ren)\n'
        'Total: RM $totalPriceRM';

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('messages')
        .add({
          'title': msgTitle,
          'message': msgBody,
          'senderIcon': 'system',
          'timestamp': Timestamp.now(),
        });
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
          title: Text(
            _isEditMode ? 'Edit Dining Reservation' : 'Dining Reservation',
          ),
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
            if (snapshot.hasError)
              return Center(child: Text('Error: ${snapshot.error}'));
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: Text('Service not found.'));
            }

            final data = snapshot.data!.data()!;
            final name = data['name'] as String? ?? 'All-Day Dining Restaurant';
            final description =
                data['description'] as String? ??
                'Buffet-style all-day dining restaurant.';
            final isFree = data['isFree'] as bool? ?? false;

            final schedule = (data['schedule'] ?? {}) as Map<String, dynamic>;
            final openStr = schedule['open'] as String? ?? '06:00';
            final closeStr = schedule['close'] as String? ?? '22:00';
            final openTime = _parseTimeOfDay(openStr);
            final closeTime = _parseTimeOfDay(closeStr);

            final ui = (data['ui'] ?? {}) as Map<String, dynamic>;
            final location =
                ui['location'] as String? ??
                'Level 2, All-Day Dining Restaurant';
            final notes =
                ui['notes'] as String? ??
                'Please arrive on time. Seating duration is 90 minutes during peak hours.';

            final adultPrice = data['adultPrice'] as int? ?? 98;
            final childPrice = data['childPrice'] as int? ?? 58;
            final maxAdvanceDays = data['maxAdvanceDays'] as int? ?? 2;
            final int? maxGuests = data['maxGuestsPerBooking'] as int?;
            final minAdults = data['minAdultsPerBooking'] as int? ?? 1;

            final totalPriceRM = _calcTotalPriceRM(
              adultPrice: adultPrice,
              childPrice: childPrice,
            );

            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 110),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                                      'assets/services/dining_360.jpg',
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Image.asset(
                                    'assets/services/dining.jpg',
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
                              onPressed: () => setState(
                                () => _showPanorama = !_showPanorama,
                              ),
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
                        if (!isFree)
                          Text(
                            'From RM $adultPrice',
                            style: const TextStyle(
                              color: Colors.redAccent,
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
                            Row(
                              children: [
                                const Icon(Icons.person),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Adults',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: _adultCount > minAdults
                                      ? () => setState(() => _adultCount--)
                                      : null,
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                                Text('$_adultCount'),
                                IconButton(
                                  onPressed: () =>
                                      setState(() => _adultCount++),
                                  icon: const Icon(Icons.add_circle_outline),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              children: [
                                const Icon(Icons.child_care_outlined),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Children',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: _childCount > 0
                                      ? () => setState(() => _childCount--)
                                      : null,
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                                Text('$_childCount'),
                                IconButton(
                                  onPressed: () =>
                                      setState(() => _childCount++),
                                  icon: const Icon(Icons.add_circle_outline),
                                ),
                              ],
                            ),
                            if (maxGuests != null) ...[
                              const SizedBox(height: 4),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  'Max $maxGuests guests per booking',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: _LightPalette.textSecondary,
                                      ),
                                ),
                              ),
                            ],
                            const Divider(height: 24),
                            _bookingRow(
                              context: context,
                              icon: Icons.calendar_today_outlined,
                              label: 'Date',
                              value: _formatDate(_selectedDate),
                              onTap: () => _pickDate(context, maxAdvanceDays),
                            ),
                            const Divider(height: 24),
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
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

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
                            Text(
                              'Price Summary',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: _LightPalette.textPrimary,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Adult: RM $adultPrice  •  Child: RM $childPrice',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: _LightPalette.textSecondary,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$_adultCount adult(s), $_childCount child(ren)',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Total: RM $totalPriceRM',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.redAccent,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

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
                              'Service hours: $openStr–$closeStr (today or next few days only).',
                            ),
                            _bullet(
                              'Reservations cannot be made for past dates or times.',
                            ),
                            _bullet(
                              'At least $minAdults adult(s) per booking is required.',
                            ),
                            if (maxGuests != null)
                              _bullet(
                                'Maximum $maxGuests guests per reservation.',
                              ),
                            _bullet(
                              'Children must be accompanied by an adult.',
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
            child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: _loadService(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _LightPalette.accentBlue.withOpacity(
                          0.3,
                        ),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: Text(
                        _isEditMode ? 'Save Changes' : 'Confirm Booking',
                      ),
                    ),
                  );
                }

                final data = snapshot.data!.data()!;
                final isFree = data['isFree'] as bool? ?? false;

                final adultPrice = data['adultPrice'] as int? ?? 98;
                final childPrice = data['childPrice'] as int? ?? 58;
                final minAdults = data['minAdultsPerBooking'] as int? ?? 1;
                final int? maxGuests = data['maxGuestsPerBooking'] as int?;

                final schedule =
                    (data['schedule'] ?? {}) as Map<String, dynamic>;
                final openStr = schedule['open'] as String? ?? '06:00';
                final closeStr = schedule['close'] as String? ?? '22:00';

                final name =
                    data['name'] as String? ?? 'All-Day Dining Restaurant';

                final totalPriceRM = _calcTotalPriceRM(
                  adultPrice: adultPrice,
                  childPrice: childPrice,
                );
                final canSubmit = _canSubmit(
                  minAdults: minAdults,
                  maxGuests: maxGuests,
                );

                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
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
                    onPressed: canSubmit
                        ? () async {
                            if (_selectedDate == null || _selectedTime == null)
                              return;

                            // Edit Mode：直接 update + message（不走 payment）
                            if (_isEditMode) {
                              await _saveDiningChanges(
                                serviceName: name,
                                adultPrice: adultPrice,
                                childPrice: childPrice,
                                maxGuests: maxGuests,
                                minAdults: minAdults,
                                openStr: openStr,
                                closeStr: closeStr,
                              );
                              return;
                            }

                            // Create Mode：Paid -> 进 PaymentScreen；Free -> 直接写 booking + success + message
                            final user = FirebaseAuth.instance.currentUser;
                            if (user == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please log in first.'),
                                ),
                              );
                              return;
                            }

                            final serviceStart = _combineDateTime(
                              _selectedDate!,
                              _selectedTime!,
                            );

                            final bookingDetails = <String, dynamic>{
                              'bookingType': 'service',
                              'serviceType': 'dining',
                              'serviceName': name,
                              'serviceImagePath': 'assets/services/dining.jpg',
                              'serviceDate': Timestamp.fromDate(_selectedDate!),
                              'serviceTime':
                                  '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
                              'serviceStart': Timestamp.fromDate(serviceStart),
                              'adultCount': _adultCount,
                              'childCount': _childCount,
                              'totalGuests': _adultCount + _childCount,
                              'totalPriceRM': totalPriceRM,
                              'currency': 'myr',
                            };

                            if (isFree) {
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(user.uid)
                                  .collection('bookings')
                                  .add({
                                    ...bookingDetails,
                                    'createdAt': Timestamp.now(),
                                    'status': 'confirmed',
                                    'paymentStatus': 'free',
                                  });

                              await _writeCreateSuccessMessage(
                                user: user,
                                serviceName: name,
                                serviceStart: serviceStart,
                                totalPriceRM: totalPriceRM,
                              );

                              if (!mounted) return;
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const BookingSuccessPage(),
                                ),
                              );
                              return;
                            }

                            final totalAmountCents = totalPriceRM * 100;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PaymentScreen(
                                  totalAmount: totalAmountCents,
                                  bookingDetails: bookingDetails,
                                ),
                              ),
                            );
                          }
                        : null,
                    child: Text(
                      _isEditMode ? 'Save Changes' : 'Confirm Booking',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
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

class _LightPalette {
  static const bg = Color.fromARGB(255, 222, 228, 236);
  static const textPrimary = Color(0xFF0F1722);
  static const textSecondary = Color(0xFF5A6473);
  static const accentBlue = Color.fromARGB(255, 49, 59, 83);
}
