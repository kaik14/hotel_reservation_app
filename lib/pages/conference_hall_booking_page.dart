import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hotel_reservation_app/pages/booking_success_page.dart';
import 'package:panorama_viewer/panorama_viewer.dart'; // ⭐ panorama_viewer

class ConferenceHallBookingPage extends StatefulWidget {
  /// ✅ Edit 模式支持：保留历史选项 + 保存更改（无支付）
  final String? existingBookingId;
  final Map<String, dynamic>? existingData;

  const ConferenceHallBookingPage({
    super.key,
    this.existingBookingId,
    this.existingData,
  });

  @override
  State<ConferenceHallBookingPage> createState() =>
      _ConferenceHallBookingPageState();
}

class _ConferenceHallBookingPageState extends State<ConferenceHallBookingPage> {
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  // small / medium / large
  String? _selectedRoomKey;

  bool _showPanorama = false;

  bool _isSubmitting = false;

  bool get _isEditMode =>
      widget.existingBookingId != null && widget.existingBookingId!.isNotEmpty;

  Future<DocumentSnapshot<Map<String, dynamic>>> _loadService() {
    return FirebaseFirestore.instance
        .collection('services')
        .doc('conferenceHall')
        .get();
  }

  // ================= helpers =================
  int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  TimeOfDay _parseTimeOfDay(String hhmm) {
    final parts = hhmm.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return TimeOfDay(hour: h, minute: m);
  }

  String _fmtHHmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

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

  DateTime? _serviceStartAt() {
    if (_selectedDate == null || _startTime == null) return null;
    return DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _startTime!.hour,
      _startTime!.minute,
    );
  }

  DateTime? _serviceEndAt() {
    if (_selectedDate == null || _endTime == null || _startTime == null) {
      return null;
    }
    // ✅ 如果 end < start，视为跨夜（第二天）
    final base = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
    );
    final startMin = _toMinutes(_startTime!);
    final endMin = _toMinutes(_endTime!);

    final endDate = endMin >= startMin
        ? base
        : base.add(const Duration(days: 1));
    return DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      _endTime!.hour,
      _endTime!.minute,
    );
  }

  // 支持跨夜营业时间判断，例如 06:00–02:00
  bool _isTimeInRange(TimeOfDay t, TimeOfDay open, TimeOfDay close) {
    final tM = _toMinutes(t);
    final oM = _toMinutes(open);
    final cM = _toMinutes(close);

    if (cM >= oM) {
      return tM >= oM && tM <= cM;
    } else {
      // 跨夜：允许 [open, 24:00) ∪ [00:00, close]
      return tM >= oM || tM <= cM;
    }
  }

  // ✅ 允许跨夜：end 必须 != start（至少 1 分钟）
  bool _isValidEndAfterStart(TimeOfDay start, TimeOfDay end) {
    final s = _toMinutes(start);
    final e = _toMinutes(end);
    return e != s; // 同一时间不允许；end < start 视为跨夜 OK
  }

  // ================= Edit 回填 =================
  @override
  void initState() {
    super.initState();

    if (_isEditMode && widget.existingData != null) {
      final d = widget.existingData!;

      // room key
      final rk = d['roomKey'] ?? d['conferenceRoomKey'] ?? d['roomTypeKey'];
      if (rk is String && rk.isNotEmpty) _selectedRoomKey = rk;

      // start/end
      DateTime? startAt;
      DateTime? endAt;

      final sTs = d['serviceStart'] as Timestamp?;
      final eTs = d['serviceEnd'] as Timestamp?;
      if (sTs != null) startAt = sTs.toDate();
      if (eTs != null) endAt = eTs.toDate();

      if (startAt != null) {
        _selectedDate = DateTime(startAt.year, startAt.month, startAt.day);
        _startTime = TimeOfDay(hour: startAt.hour, minute: startAt.minute);
      }

      if (endAt != null) {
        _endTime = TimeOfDay(hour: endAt.hour, minute: endAt.minute);
      }
    }
  }

  // ================= pickers =================
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
      _startTime = null;
      _endTime = null;
    });
  }

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

    // 如果选的是今天：开始时间不能早于当前时间
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
      _startTime = picked;
      if (_endTime != null && !_isValidEndAfterStart(_startTime!, _endTime!)) {
        _endTime = null;
      }
    });
  }

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

    if (!_isValidEndAfterStart(_startTime!, picked)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End time must be different from start time.'),
        ),
      );
      return;
    }

    setState(() {
      _endTime = picked;
    });
  }

  // ================= submit =================
  bool get canSubmit {
    if (_selectedDate == null || _startTime == null || _endTime == null)
      return false;
    if (_selectedRoomKey == null || _selectedRoomKey!.isEmpty) return false;
    return !_isSubmitting;
  }

  Future<void> _createConferenceBooking({
    required String serviceName,
    required String location,
    required String serviceImagePath,
    required Map<String, dynamic> roomTypes,
    required String roomKey,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Not logged in.')));
      return;
    }

    final startAt = _serviceStartAt();
    final endAt = _serviceEndAt();
    if (startAt == null || endAt == null) return;

    setState(() => _isSubmitting = true);

    try {
      final selectedRoom = roomTypes[roomKey] is Map<String, dynamic>
          ? roomTypes[roomKey] as Map<String, dynamic>
          : <String, dynamic>{};

      final roomLabel = selectedRoom['label'] as String? ?? roomKey;
      final capMin = selectedRoom['capacityMin'];
      final capMax = selectedRoom['capacityMax'];

      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('bookings')
          .doc();

      await docRef.set({
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),

        'bookingType': 'service',
        'serviceType': 'conferenceHall',
        'serviceName': serviceName,
        'serviceImagePath': serviceImagePath,
        'location': location,

        'serviceDate': Timestamp.fromDate(
          DateTime(startAt.year, startAt.month, startAt.day),
        ),
        'serviceStart': Timestamp.fromDate(startAt),
        'serviceEnd': Timestamp.fromDate(endAt),

        'startTime': _fmtHHmm(_startTime!),
        'endTime': _fmtHHmm(_endTime!),

        // conference specific
        'roomKey': roomKey,
        'roomLabel': roomLabel,
        if (capMin != null) 'capacityMin': capMin,
        if (capMax != null) 'capacityMax': capMax,

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

  Future<void> _updateConferenceBooking({
    required String serviceName,
    required String location,
    required String serviceImagePath,
    required Map<String, dynamic> roomTypes,
    required String roomKey,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Not logged in.')));
      return;
    }

    final startAt = _serviceStartAt();
    final endAt = _serviceEndAt();
    if (startAt == null || endAt == null) return;

    setState(() => _isSubmitting = true);

    try {
      final selectedRoom = roomTypes[roomKey] is Map<String, dynamic>
          ? roomTypes[roomKey] as Map<String, dynamic>
          : <String, dynamic>{};

      final roomLabel = selectedRoom['label'] as String? ?? roomKey;
      final capMin = selectedRoom['capacityMin'];
      final capMax = selectedRoom['capacityMax'];

      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('bookings')
          .doc(widget.existingBookingId);

      await docRef.update({
        'updatedAt': Timestamp.now(),

        'bookingType': 'service',
        'serviceType': 'conferenceHall',
        'serviceName': serviceName,
        'serviceImagePath': serviceImagePath,
        'location': location,

        'serviceDate': Timestamp.fromDate(
          DateTime(startAt.year, startAt.month, startAt.day),
        ),
        'serviceStart': Timestamp.fromDate(startAt),
        'serviceEnd': Timestamp.fromDate(endAt),

        'startTime': _fmtHHmm(_startTime!),
        'endTime': _fmtHHmm(_endTime!),

        'roomKey': roomKey,
        'roomLabel': roomLabel,
        'capacityMin': capMin,
        'capacityMax': capMax,

        'currency': 'MYR',
        'totalPriceRM': 0,
      });

      if (!mounted) return;
      // ✅ 返回 true 给 BookingDetail
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

  // ================= UI =================
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
            _isEditMode ? 'Edit Conference Booking' : 'Conference Hall Booking',
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

            // 初始化默认 roomKey（仅在创建时）
            if (!_isEditMode &&
                _selectedRoomKey == null &&
                roomTypes.isNotEmpty) {
              _selectedRoomKey = roomTypes.keys.first;
            } else {
              // Edit 模式：如果旧 key 不存在，则兜底选择第一个
              if (_selectedRoomKey != null &&
                  _selectedRoomKey!.isNotEmpty &&
                  roomTypes.isNotEmpty &&
                  !roomTypes.containsKey(_selectedRoomKey)) {
                _selectedRoomKey = roomTypes.keys.first;
              }
            }

            final selectedRoomMap =
                (_selectedRoomKey != null &&
                    roomTypes[_selectedRoomKey] is Map<String, dynamic>)
                ? roomTypes[_selectedRoomKey] as Map<String, dynamic>
                : null;

            final capMin = selectedRoomMap?['capacityMin'] as int?;
            final capMax = selectedRoomMap?['capacityMax'] as int?;
            final roomSubtitle = (capMin != null && capMax != null)
                ? '($capMin–$capMax people)'
                : '';

            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 90),
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
                                        onChanged: (val) => setState(
                                          () => _selectedRoomKey = val,
                                        ),
                                      ),
                                      if (roomSubtitle.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 2,
                                          ),
                                          child: Text(
                                            roomSubtitle,
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
                              icon: Icons.schedule,
                              label: 'Start time',
                              value: _startTime == null
                                  ? 'Select start time'
                                  : _startTime!.format(context),
                              onTap: () =>
                                  _pickStartTime(context, openTime, closeTime),
                            ),
                            const Divider(height: 24),

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
                              'Operating hours: $openStr–$closeStr (cross-day supported).',
                            ),
                            _bullet(
                              'Bookings can be made up to $maxAdvanceDays days in advance.',
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
                onPressed: canSubmit
                    ? () async {
                        final snap = await _loadService();
                        if (!snap.exists) return;
                        final serviceData = snap.data() ?? {};

                        final serviceName =
                            (serviceData['name'] as String?) ??
                            'Conference Hall';

                        final ui =
                            (serviceData['ui'] ?? {}) as Map<String, dynamic>;
                        final location =
                            (ui['location'] as String?) ??
                            'Level 3, Conference & Events Floor';

                        final roomTypes =
                            (serviceData['roomTypes'] ?? {})
                                as Map<String, dynamic>;

                        const serviceImagePath =
                            'assets/services/conference.jpg';

                        final roomKey = _selectedRoomKey ?? '';
                        if (roomKey.isEmpty) return;

                        if (_isEditMode) {
                          await _updateConferenceBooking(
                            serviceName: serviceName,
                            location: location,
                            serviceImagePath: serviceImagePath,
                            roomTypes: roomTypes,
                            roomKey: roomKey,
                          );
                        } else {
                          await _createConferenceBooking(
                            serviceName: serviceName,
                            location: location,
                            serviceImagePath: serviceImagePath,
                            roomTypes: roomTypes,
                            roomKey: roomKey,
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

/// 和 ServicePage 一致的浅色调色板
class _LightPalette {
  static const bg = Color.fromARGB(255, 222, 228, 236);
  static const textPrimary = Color(0xFF0F1722);
  static const textSecondary = Color(0xFF5A6473);
  static const accentBlue = Color.fromARGB(255, 49, 59, 83);
}
