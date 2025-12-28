import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:hotel_reservation_app/pages/booking_success_page.dart';
import 'package:intl/intl.dart';
import 'package:app_state/app_state.dart';

class PaymentScreen extends StatefulWidget {
  final int totalAmount; // cents
  final Map<String, dynamic> bookingDetails;

  const PaymentScreen({
    super.key,
    required this.totalAmount,
    required this.bookingDetails,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> with PageStateMixin {
  bool _isLoading = false;
  StreamSubscription? _subscription;
  String? _paymentIntentClientSecret;
  bool _isAwaitingFpxResult = false;

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    super.dispose();
  }

  @override
  void onResumed() {
    if (_isAwaitingFpxResult && _paymentIntentClientSecret != null) {
      _checkFpxPaymentStatus();
    }
  }

  // ============================
  // ✅ 工具：DateTime -> "YYYY-MM-DD"
  // ============================
  String _ymd(DateTime d) => DateFormat('yyyy-MM-dd').format(
        DateTime(d.year, d.month, d.day),
      );

  // ============================
  // ✅ 工具：activeDates（按天）
  // checkIn 含，checkOut 不含
  // ============================
  List<String> _buildActiveDates(DateTime checkIn, DateTime checkOut) {
    final start = DateTime(checkIn.year, checkIn.month, checkIn.day);
    final end = DateTime(checkOut.year, checkOut.month, checkOut.day);

    final days = <String>[];
    for (var d = start; d.isBefore(end); d = d.add(const Duration(days: 1))) {
      days.add(_ymd(d));
    }
    return days;
  }

  // ============================
  // ✅ floorId 强制标准化：8F / 08F -> 08F
  // 如果传进来不是这种格式（比如 "Low Floor"），返回 null
  // ============================
  String? _normalizeFloorIdMaybe(String raw) {
    final s = raw.trim();
    final m = RegExp(r'^(\d{1,2})F$', caseSensitive: false).firstMatch(s);
    if (m == null) return null;
    final n = int.tryParse(m.group(1)!) ?? 0;
    return '${n.toString().padLeft(2, '0')}F';
  }

  // ✅ 从房号推断楼层：0811 -> 08F
  String? _inferFloorIdFromRoomNo(String roomNo) {
    final rn = roomNo.trim();
    final m = RegExp(r'^(\d{2})').firstMatch(rn);
    if (m == null) return null;
    return '${m.group(1)}F';
  }

  Future<void> _checkFpxPaymentStatus() async {
    _isAwaitingFpxResult = false;
    final result = await Stripe.instance.retrievePaymentIntent(
      _paymentIntentClientSecret!,
    );

    if (result.status == PaymentIntentsStatus.Succeeded) {
      final paymentIntentId = _paymentIntentClientSecret!.split('_secret')[0];
      await _onPaymentSuccess(paymentIntentId);
    } else {
      _showError("Payment was not completed.");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handlePayNow() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _showError("You must be logged in to pay.");
      setState(() => _isLoading = false);
      return;
    }

    try {
      final docRef = await FirebaseFirestore.instance
          .collection('customers')
          .doc(currentUser.uid)
          .collection('checkout_sessions')
          .add({
        'client': 'mobile',
        'mode': 'payment',
        'amount': widget.totalAmount,
        'currency': 'myr',
        'payment_method_types': ['card', 'fpx'],
      });

      _subscription = docRef.snapshots().listen((snapshot) async {
        final data = snapshot.data();
        if (data != null && data.containsKey('paymentIntentClientSecret')) {
          await _subscription?.cancel();
          _paymentIntentClientSecret = data['paymentIntentClientSecret'];
          await _initiatePaymentSheet(_paymentIntentClientSecret!);
        } else if (data != null && data.containsKey('error')) {
          await _subscription?.cancel();
          _showError("Backend Error: ${data['error']['message']}");
          if (mounted) setState(() => _isLoading = false);
        }
      });
    } catch (e) {
      _showError("An error occurred: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _initiatePaymentSheet(String clientSecret) async {
    try {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Hotel Reservation App',
        ),
      );

      _isAwaitingFpxResult = true;
      await Stripe.instance.presentPaymentSheet();

      await _onPaymentSuccess(clientSecret.split('_secret')[0]);
    } on StripeException catch (e) {
      _isAwaitingFpxResult = false;
      if (e.error.code == FailureCode.Canceled) {
        return;
      }
      _showError(
        "Booking failed: ${e.error.localizedMessage ?? e.error.message}",
      );
    } catch (e) {
      _isAwaitingFpxResult = false;
      _showError("An unexpected error occurred during payment.");
    } finally {
      if (mounted && !_isAwaitingFpxResult) {
        setState(() => _isLoading = false);
      }
    }
  }

  // =========================================================
  // ✅ 支付成功：写 users/{uid}/bookings
  // ✅ 房间预订：再写全局 bookings（用于 staff 地图占用）
  // =========================================================
  Future<void> _onPaymentSuccess(String paymentIntentId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final firestore = FirebaseFirestore.instance;
    final nowTs = Timestamp.now();

    final bool isService = (widget.bookingDetails['bookingType'] ?? '')
            .toString()
            .trim()
            .toLowerCase() ==
        'service';

    final finalBookingDetails = {
      ...widget.bookingDetails,
      'createdAt': nowTs,
      'updatedAt': nowTs,
      'status': 'paid',
      'paymentStatus': 'paid',
      'paymentIntentId': paymentIntentId,
    };

    final batch = firestore.batch();

    final userBookingRef = firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('bookings')
        .doc();

    batch.set(userBookingRef, finalBookingDetails);

    // =========================
    // ✅ 房间预订：写全局 bookings
    // =========================
    if (!isService) {
      final roomNo = (widget.bookingDetails['roomNo'] ?? '').toString().trim();
      final rawFloor = (widget.bookingDetails['floorId'] ?? '').toString().trim(); // 可能是 Low Floor
      final roomTypeId =
          (widget.bookingDetails['roomTypeId'] ?? '').toString().trim();

      final checkInTs = widget.bookingDetails['checkIn'] as Timestamp?;
      final checkOutTs = widget.bookingDetails['checkOut'] as Timestamp?;

      if (roomNo.isEmpty || roomTypeId.isEmpty || checkInTs == null || checkOutTs == null) {
        _showError(
          "Missing booking data. Need roomNo, roomTypeId, checkIn, checkOut.",
        );
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // ✅ 关键：把 floorId 正规化成 08F
      final floorId =
          _normalizeFloorIdMaybe(rawFloor) ?? _inferFloorIdFromRoomNo(roomNo);

      if (floorId == null) {
        _showError("Invalid floorId. Please ensure floorId like 08F or roomNo like 0811.");
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final checkIn = checkInTs.toDate();
      final checkOut = checkOutTs.toDate();
      final activeDates = _buildActiveDates(checkIn, checkOut);

      final roomTypeTitle =
          (widget.bookingDetails['roomTypeTitle'] ?? '').toString();
      final guests =
          widget.bookingDetails['guests'] ?? widget.bookingDetails['guestCount'] ?? 1;
      final totalPriceRM = widget.bookingDetails['totalPriceRM'];
      final priceText = (widget.bookingDetails['priceText'] ?? '').toString();

      final globalBookingRef = firestore.collection('bookings').doc();

      batch.set(globalBookingRef, {
        'roomNo': roomNo,
        'floorId': floorId,          // ✅ 一定是 08F / 09F ...
        'floorName': rawFloor,       // ✅ 可选：保留 Low Floor（方便你展示）
        'roomTypeId': roomTypeId,

        'checkInDate': _ymd(checkIn),
        'checkOutDate': _ymd(checkOut),
        'activeDates': activeDates,

        'status': 'confirmed',

        'createdByRole': 'guest',
        'createdByUid': currentUser.uid,

        'userBookingId': userBookingRef.id,
        'paymentIntentId': paymentIntentId,

        'roomTypeTitle': roomTypeTitle,
        'guestCount': guests,
        'priceText': priceText,
        'totalPriceRM': totalPriceRM,

        'createdAt': nowTs,
        'updatedAt': nowTs,
      });
    }

    await batch.commit();


    // 4) ✅ 如果是 Service → 写 message（你原逻辑保留）
    if (isService) {
      final serviceType =
          (widget.bookingDetails['serviceType'] ?? '').toString();

      final DateTime? startAt =
          (widget.bookingDetails['serviceStart'] as Timestamp?)?.toDate();

      final serviceName =
          (widget.bookingDetails['serviceName'] ?? 'Service').toString();
      final totalGuests = widget.bookingDetails['totalGuests'] ?? '-';
      final totalPriceRM = widget.bookingDetails['totalPriceRM'] ?? 0;

      final dateText = startAt != null
          ? DateFormat('dd MMM yyyy').format(startAt)
          : '-';
      final timeText =
          startAt != null ? DateFormat('HH:mm').format(startAt) : '-';

      // Dining message
      if (serviceType == 'dining') {
        final msgTitle = 'Dining Booking Confirmed';
        final msgBody = 'Your dining reservation has been confirmed.\n'
            'Service: $serviceName\n'
            'Date: $dateText\n'
            'Time: $timeText\n'
            'Guests: $totalGuests\n'
            'Total Paid: RM $totalPriceRM';

        await firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('messages')
            .add({
          'title': msgTitle,
          'message': msgBody,
          'senderIcon': 'system',
          'timestamp': Timestamp.now(),
        });
      }

      // Spa message
      if (serviceType == 'spa') {
        final treatmentLabel =
            (widget.bookingDetails['treatmentLabel'] ?? 'Treatment').toString();
        final durationMin = widget.bookingDetails['durationMinutes'] ?? '-';

        final msgTitle = 'Spa Booking Confirmed';
        final msgBody = 'Your spa booking has been confirmed.\n'
            'Service: $serviceName\n'
            'Treatment: $treatmentLabel (${durationMin} min)\n'
            'Date: $dateText\n'
            'Time: $timeText\n'
            'Guests: $totalGuests\n'
            'Total Paid: RM $totalPriceRM';

        await firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('messages')
            .add({
          'title': msgTitle,
          'message': msgBody,
          'senderIcon': 'system',
          'timestamp': Timestamp.now(),
        });
      }
    }

    // 5) 跳成功页
     if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => BookingSuccessPage(paidAmount: widget.totalAmount),
        ),
        (route) => false,
      );
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amountFormatted = NumberFormat.currency(
      locale: 'en_MY',
      symbol: 'RM ',
    ).format(widget.totalAmount / 100);

    return Scaffold(
      appBar: AppBar(title: const Text('Complete Your Payment')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Total Amount Due', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                amountFormatted,
                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _handlePayNow,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'Pay Now',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              const Text(
                "You will be redirected to a secure page to complete your payment.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}