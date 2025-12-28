import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hotel_reservation_app/pages/booking_success_page.dart';
import 'package:panorama_viewer/panorama_viewer.dart';

class TaxiBookingPage extends StatefulWidget {
  /// ✅ Edit 模式支持（保留历史选项 + 保存更改，无支付）
  final String? existingBookingId;
  final Map<String, dynamic>? existingData;

  const TaxiBookingPage({super.key, this.existingBookingId, this.existingData});

  @override
  State<TaxiBookingPage> createState() => _TaxiBookingPageState();
}

class _TaxiBookingPageState extends State<TaxiBookingPage> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  // airportPickup / airportDropoff
  String? _selectedRideKey;

  int _passengers = 1;

  bool _showPanorama = false;

  bool _isSubmitting = false;

  bool get _isEditMode =>
      widget.existingBookingId != null && widget.existingBookingId!.isNotEmpty;

  // -------------------- Firestore --------------------
  Future<DocumentSnapshot<Map<String, dynamic>>> _loadService() {
    return FirebaseFirestore.instance.collection('services').doc('taxi').get();
  }

  // -------------------- helpers --------------------
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

  // -------------------- init (Edit 回填) --------------------
  @override
  void initState() {
    super.initState();

    if (_isEditMode && widget.existingData != null) {
      final d = widget.existingData!;

      // ride type
      _selectedRideKey =
          (d['rideKey'] ?? d['rideType'] ?? d['rideTypeKey'] ?? d['ride'] ?? '')
              .toString()
              .trim();
      if (_selectedRideKey != null && _selectedRideKey!.isEmpty) {
        _selectedRideKey = null;
      }

      // passengers
      final p = d['passengers'] ?? d['totalGuests'] ?? d['guests'];
      if (p is int) _passengers = p;
      if (p is String) _passengers = int.tryParse(p) ?? _passengers;

      // time
      DateTime? startAt;
      final ts = d['serviceStart'] as Timestamp?;
      if (ts != null) {
        startAt = ts.toDate();
      } else {
        final dateTs = d['serviceDate'] as Timestamp?;
        final timeStr = (d['serviceTime'] as String?);
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

  // -------------------- pickers --------------------
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

  // -------------------- submit enabled --------------------
  bool get canSubmit {
    if (_selectedDate == null || _selectedTime == null) return false;
    if (_selectedRideKey == null) return false;
    if (_passengers <= 0) return false;
    return !_isSubmitting;
  }

  // -------------------- create/update booking (free service) --------------------
  Future<void> _createTaxiBooking({
    required String serviceName,
    required String location,
    required String rideLabel,
    required int minPassengers,
    required int maxPassengers,
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

    final passengers = _passengers.clamp(minPassengers, maxPassengers);

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
        'serviceType': 'taxi',
        'serviceName': serviceName,
        'serviceImagePath': 'assets/services/taxi.jpg',
        'location': location,

        'serviceDate': Timestamp.fromDate(
          DateTime(startAt.year, startAt.month, startAt.day),
        ),
        'serviceStart': Timestamp.fromDate(startAt),
        'serviceTime': _fmtHHmm(_selectedTime!),

        // taxi specific
        'rideKey': _selectedRideKey,
        'rideLabel': rideLabel,
        'passengers': passengers,

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

  Future<void> _updateTaxiBooking({
    required String serviceName,
    required String location,
    required String rideLabel,
    required int minPassengers,
    required int maxPassengers,
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

    final passengers = _passengers.clamp(minPassengers, maxPassengers);

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
        'serviceType': 'taxi',
        'serviceName': serviceName,
        'serviceImagePath': 'assets/services/taxi.jpg',
        'location': location,

        'serviceDate': Timestamp.fromDate(
          DateTime(startAt.year, startAt.month, startAt.day),
        ),
        'serviceStart': Timestamp.fromDate(startAt),
        'serviceTime': _fmtHHmm(_selectedTime!),

        'rideKey': _selectedRideKey,
        'rideLabel': rideLabel,
        'passengers': passengers,

        'currency': 'MYR',
        'totalPriceRM': 0,
      });

      if (!mounted) return;
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

  // -------------------- UI --------------------
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
          title: Text(_isEditMode ? 'Edit Taxi Booking' : 'Taxi Booking'),
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

            final name = data['name'] as String? ?? 'Airport Taxi';
            final description =
                data['description'] as String? ??
                'Free airport pickup and drop-off taxi service.';
            final isFree = data['isFree'] as bool? ?? true;

            final schedule = (data['schedule'] ?? {}) as Map<String, dynamic>;
            final openStr = schedule['open'] as String? ?? '00:00';
            final closeStr = schedule['close'] as String? ?? '23:59';
            final openTime = _parseTimeOfDay(openStr);
            final closeTime = _parseTimeOfDay(closeStr);

            final maxAdvanceDays = data['maxAdvanceDays'] as int? ?? 3;

            final rideTypes = (data['rideTypes'] ?? {}) as Map<String, dynamic>;

            // ✅ 如果不是编辑模式 + 没选过 ride，默认选第一个
            if (!_isEditMode &&
                _selectedRideKey == null &&
                rideTypes.isNotEmpty) {
              _selectedRideKey = rideTypes.keys.first;
            }
            // ✅ 如果是编辑模式，但 rideKey 不存在于 rideTypes，则兜底选第一个
            if (_selectedRideKey != null &&
                rideTypes.isNotEmpty &&
                !rideTypes.containsKey(_selectedRideKey)) {
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

            final shownPassengers = _passengers.clamp(
              minPassengers,
              maxPassengers,
            );

            final ui = (data['ui'] ?? {}) as Map<String, dynamic>;
            final location =
                ui['location'] as String? ?? 'Hotel Main Lobby Pick-up Point';
            final notes =
                ui['notes'] as String? ??
                'Please wait at the main lobby pick-up point.';

            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 90),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // header image + 360
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
                              onPressed: () => setState(() {
                                _showPanorama = !_showPanorama;
                              }),
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

                  // title + free
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
                            // ride type dropdown
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
                                            // ride 切换时，如果人数超范围，拉回范围
                                            final clamped = _passengers.clamp(
                                              minPassengers,
                                              maxPassengers,
                                            );
                                            _passengers = clamped;
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

                            // date
                            _bookingRow(
                              context: context,
                              icon: Icons.calendar_today_outlined,
                              label: 'Date',
                              value: _formatDate(_selectedDate),
                              onTap: () => _pickDate(context, maxAdvanceDays),
                            ),
                            const Divider(height: 24),

                            // time
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

                            // passengers
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
                                      ? () => setState(() => _passengers--)
                                      : null,
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                                Text('$shownPassengers'),
                                IconButton(
                                  onPressed: shownPassengers < maxPassengers
                                      ? () => setState(() => _passengers++)
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

                  // rules
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
                              'Bookings are available within $maxAdvanceDays days from today.',
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
                    ? () async {
                        final snap = await _loadService();
                        if (!snap.exists) return;
                        final serviceData = snap.data() ?? {};

                        final serviceName =
                            (serviceData['name'] as String?) ?? 'Airport Taxi';
                        final ui =
                            (serviceData['ui'] ?? {}) as Map<String, dynamic>;
                        final location =
                            (ui['location'] as String?) ??
                            'Hotel Main Lobby Pick-up Point';

                        final rideTypes =
                            (serviceData['rideTypes'] ?? {})
                                as Map<String, dynamic>;

                        Map<String, dynamic>? selectedRide;
                        if (_selectedRideKey != null &&
                            rideTypes[_selectedRideKey]
                                is Map<String, dynamic>) {
                          selectedRide =
                              rideTypes[_selectedRideKey]
                                  as Map<String, dynamic>;
                        }
                        final rideLabel =
                            selectedRide?['label'] as String? ??
                            _selectedRideKey ??
                            'Ride';
                        final minPassengers =
                            selectedRide?['passengersMin'] as int? ?? 1;
                        final maxPassengers =
                            selectedRide?['passengersMax'] as int? ?? 4;

                        if (_isEditMode) {
                          await _updateTaxiBooking(
                            serviceName: serviceName,
                            location: location,
                            rideLabel: rideLabel,
                            minPassengers: minPassengers,
                            maxPassengers: maxPassengers,
                          );
                        } else {
                          await _createTaxiBooking(
                            serviceName: serviceName,
                            location: location,
                            rideLabel: rideLabel,
                            minPassengers: minPassengers,
                            maxPassengers: maxPassengers,
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

class _LightPalette {
  static const bg = Color.fromARGB(255, 222, 228, 236);
  static const textPrimary = Color(0xFF0F1722);
  static const textSecondary = Color(0xFF5A6473);
  static const accentBlue = Color.fromARGB(255, 49, 59, 83);
}
