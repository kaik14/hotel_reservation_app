import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:panorama_viewer/panorama_viewer.dart';
import 'package:intl/intl.dart';

// ✅ Create 模式才用到支付页
import 'package:hotel_reservation_app/pages/payment_screen.dart';

class SpaBookingPage extends StatefulWidget {
  /// ✅ 用于 edit 模式
  final String? existingBookingId;
  final Map<String, dynamic>? existingData;

  const SpaBookingPage({super.key, this.existingBookingId, this.existingData});

  @override
  State<SpaBookingPage> createState() => _SpaBookingPageState();
}

class _SpaBookingPageState extends State<SpaBookingPage> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  int _guests = 1;

  String? _selectedTreatmentKey;
  bool _showPanorama = false;

  bool _isSubmitting = false;

  bool get _isEditMode =>
      widget.existingBookingId != null && widget.existingBookingId!.isNotEmpty;

  Future<DocumentSnapshot<Map<String, dynamic>>> _loadService() {
    return FirebaseFirestore.instance.collection('services').doc('spa').get();
  }

  // ---------- helper ----------

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

  Future<void> _pickDate(BuildContext context, int maxAdvanceDays) async {
    final today = DateTime.now();
    final picked = await showDatePicker(
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

    final initial = _selectedTime ?? open;
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

  // 计算总价：单价 * 人数
  double _computeTotalPrice(Map<String, dynamic> treatments) {
    if (_selectedTreatmentKey == null) return 0.0;
    final raw = treatments[_selectedTreatmentKey];
    if (raw is! Map) return 0.0;

    final m = Map<String, dynamic>.from(raw as Map);
    final price = (m['price'] as num?)?.toDouble() ?? 0.0;
    return price * _guests;
  }

  bool get canSubmit =>
      _selectedDate != null &&
      _selectedTime != null &&
      _selectedTreatmentKey != null &&
      !_isSubmitting;

  // ---------- Edit 模式：回填历史选项 ----------
  @override
  void initState() {
    super.initState();

    if (_isEditMode && widget.existingData != null) {
      final data = widget.existingData!;

      // guests
      _guests = (data['totalGuests'] ?? data['guests'] ?? 1) as int;

      // treatment（保留历史选择）
      _selectedTreatmentKey =
          (data['treatmentKey'] as String?) ??
          (data['selectedTreatmentKey'] as String?);

      // time
      DateTime? startAt;
      final ts = data['serviceStart'] as Timestamp?;
      if (ts != null) {
        startAt = ts.toDate();
      } else {
        final dateTs = data['serviceDate'] as Timestamp?;
        final timeStr = data['serviceTime'] as String?;
        if (dateTs != null && timeStr != null && timeStr.contains(':')) {
          final d = dateTs.toDate();
          final parts = timeStr.split(':');
          final h = int.tryParse(parts[0]) ?? 0;
          final m = int.tryParse(parts[1]) ?? 0;
          startAt = DateTime(d.year, d.month, d.day, h, m);
        }
      }

      if (startAt != null) {
        _selectedDate = DateTime(startAt.year, startAt.month, startAt.day);
        _selectedTime = TimeOfDay(hour: startAt.hour, minute: startAt.minute);
      }
    }
  }

  // =========================================================
  // ✅ Edit 模式：Save Changes（不支付）→ update 原 booking
  // =========================================================
  Future<void> _saveSpaChanges({
    required Map<String, dynamic> serviceData,
    required Map<String, dynamic> treatments,
    required String currency,
    required double totalPrice,
    required String serviceName,
    required String location,
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

    final raw = treatments[_selectedTreatmentKey];
    final treat = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    final treatmentLabel =
        (treat['label'] ?? _selectedTreatmentKey ?? 'Treatment').toString();
    final durationMin = (treat['durationMinutes'] as int?) ?? 60;

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
        'serviceType': 'spa',
        'serviceName': serviceName,
        'serviceImagePath': 'assets/services/spa.jpg',
        'location': location,

        'serviceStart': Timestamp.fromDate(startAt),
        'serviceDate': Timestamp.fromDate(
          DateTime(startAt.year, startAt.month, startAt.day),
        ),
        'serviceTime':
            '${startAt.hour.toString().padLeft(2, '0')}:${startAt.minute.toString().padLeft(2, '0')}',

        'treatmentKey': _selectedTreatmentKey,
        'treatmentLabel': treatmentLabel,
        'durationMinutes': durationMin,
        'totalGuests': _guests,

        'currency': currency,
        'totalPriceRM': totalPrice,
      });

      if (!mounted) return;
      Navigator.of(context).pop(true); // ✅回到 detail 页
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // =========================================================
  // ✅ Create 模式：去 PaymentScreen（支付成功由 PaymentScreen 写 booking+message）
  // =========================================================
  Future<void> _goToPayment({
    required Map<String, dynamic> treatments,
    required String currency,
    required double totalPrice,
    required String serviceName,
    required String location,
  }) async {
    final startAt = _serviceStartAt();
    if (startAt == null) return;

    final raw = treatments[_selectedTreatmentKey];
    final treat = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    final treatmentLabel =
        (treat['label'] ?? _selectedTreatmentKey ?? 'Treatment').toString();
    final durationMin = (treat['durationMinutes'] as int?) ?? 60;

    final totalAmountCents = (totalPrice * 100).round();

    final bookingDetails = <String, dynamic>{
      'updatedAt': Timestamp.now(),

      'bookingType': 'service',
      'serviceType': 'spa',
      'serviceName': serviceName,
      'serviceImagePath': 'assets/services/spa.jpg',
      'location': location,

      'serviceStart': Timestamp.fromDate(startAt),
      'serviceDate': Timestamp.fromDate(
        DateTime(startAt.year, startAt.month, startAt.day),
      ),
      'serviceTime':
          '${startAt.hour.toString().padLeft(2, '0')}:${startAt.minute.toString().padLeft(2, '0')}',

      'treatmentKey': _selectedTreatmentKey,
      'treatmentLabel': treatmentLabel,
      'durationMinutes': durationMin,
      'totalGuests': _guests,

      'currency': currency,
      'totalPriceRM': totalPrice,
    };

    if (!mounted) return;

    setState(() => _isSubmitting = true);
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentScreen(
            totalAmount: totalAmountCents,
            bookingDetails: bookingDetails,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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
          title: Text(_isEditMode ? 'Edit Spa Reservation' : 'Spa Booking'),
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
            final description = data['description'] as String? ?? '';
            final isFree = data['isFree'] as bool? ?? false;

            final schedule = (data['schedule'] ?? {}) as Map<String, dynamic>;
            final openStr = schedule['open'] as String? ?? '09:00';
            final closeStr = schedule['close'] as String? ?? '22:00';
            final openTime = _parseTimeOfDay(openStr);
            final closeTime = _parseTimeOfDay(closeStr);

            final maxAdvanceDays = data['maxAdvanceDays'] as int? ?? 2;
            final maxGuests = data['maxGuestsPerBooking'] as int? ?? 4;
            final minGuests = data['minGuestsPerBooking'] as int? ?? 1;
            final currency = data['currency'] as String? ?? 'MYR';

            final ui = (data['ui'] ?? {}) as Map<String, dynamic>;
            final location =
                ui['location'] as String? ?? 'Level 2, Spa & Wellness Center';
            final notes =
                ui['notes'] as String? ??
                'Please arrive 10–15 minutes early for preparation.';

            final Map<String, dynamic> treatments = Map<String, dynamic>.from(
              data['treatments'] ?? {},
            );

            // ✅ Edit 进来要保留历史 treatmentKey；如果已经不存在再回落第一项
            if (_selectedTreatmentKey == null && treatments.isNotEmpty) {
              _selectedTreatmentKey = treatments.keys.first;
            } else if (_selectedTreatmentKey != null &&
                treatments.isNotEmpty &&
                !treatments.containsKey(_selectedTreatmentKey)) {
              _selectedTreatmentKey = treatments.keys.first;
            }

            final totalPrice = _computeTotalPrice(treatments);

            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 90),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 顶部图片 + 360
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

                  // 标题
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
                            'Paid Service',
                            style: TextStyle(
                              color: Colors.red[700],
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

                  // Booking details
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
                            // Treatment 下拉
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
                                        value: _selectedTreatmentKey,
                                        isExpanded: true,
                                        underline: const SizedBox.shrink(),
                                        items: treatments.entries.map((entry) {
                                          final key = entry.key;
                                          final m = Map<String, dynamic>.from(
                                            entry.value as Map,
                                          );
                                          final label =
                                              (m['label'] as String?) ?? key;
                                          final price =
                                              (m['price'] as num?)
                                                  ?.toDouble() ??
                                              0.0;
                                          final duration =
                                              m['durationMinutes'] as int? ??
                                              60;
                                          return DropdownMenuItem<String>(
                                            value: key,
                                            child: Text(
                                              '$label - $currency ${price.toStringAsFixed(0)} • $duration min',
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (val) => setState(
                                          () => _selectedTreatmentKey = val,
                                        ),
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

                            // Time
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
                                  onPressed: _guests > minGuests
                                      ? () => setState(() => _guests--)
                                      : null,
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                                Text('$_guests'),
                                IconButton(
                                  onPressed: _guests < maxGuests
                                      ? () => setState(() => _guests++)
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

                  // Price summary
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
                            const Expanded(
                              child: Text(
                                'Total price',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ),
                            Text(
                              '$currency ${totalPrice.toStringAsFixed(2)}',
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

                  // Rules & notes
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
                            _bullet('Service hours: $openStr–$closeStr.'),
                            _bullet(
                              'Please select a time within opening hours.',
                            ),
                            _bullet(
                              'Please arrive 10–15 minutes early for consultation and preparation.',
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

        // ✅ bottom button：Edit = Save Changes；Create = Pay Now
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

                        final Map<String, dynamic> treatments =
                            Map<String, dynamic>.from(
                              serviceData['treatments'] ?? {},
                            );
                        final totalPrice = _computeTotalPrice(treatments);

                        final currency =
                            (serviceData['currency'] as String?) ?? 'MYR';
                        final serviceName =
                            (serviceData['name'] as String?) ??
                            'Spa & Wellness';
                        final ui =
                            (serviceData['ui'] ?? {}) as Map<String, dynamic>;
                        final location =
                            (ui['location'] as String?) ??
                            'Level 2, Spa & Wellness Center';

                        if (_isEditMode) {
                          // ✅ Edit：直接保存，不支付
                          await _saveSpaChanges(
                            serviceData: serviceData,
                            treatments: treatments,
                            currency: currency,
                            totalPrice: totalPrice,
                            serviceName: serviceName,
                            location: location,
                          );
                        } else {
                          // ✅ Create：去支付
                          await _goToPayment(
                            treatments: treatments,
                            currency: currency,
                            totalPrice: totalPrice,
                            serviceName: serviceName,
                            location: location,
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
                        _isEditMode ? 'Save Changes' : 'Pay Now',
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

// ---------- shared widgets ----------
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
