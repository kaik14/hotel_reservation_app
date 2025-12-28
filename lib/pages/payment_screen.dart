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
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
  // ✅ 支付成功：写 booking + 写 message（Dining / Spa）
  // =========================================================
  Future<void> _onPaymentSuccess(String paymentIntentId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // 1️⃣ 写 booking
    final finalBookingDetails = {
      ...widget.bookingDetails,
      'createdAt': Timestamp.now(),
      'status': 'paid',
      'paymentStatus': 'paid',
      'paymentIntentId': paymentIntentId,
    };

    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('bookings')
        .add(finalBookingDetails);

    // 2️⃣ 如果是 Service → 写 message（Dining / Spa）
    if (widget.bookingDetails['bookingType'] == 'service') {
      final serviceType = (widget.bookingDetails['serviceType'] ?? '')
          .toString();

      final DateTime? startAt =
          (widget.bookingDetails['serviceStart'] as Timestamp?)?.toDate();

      final serviceName = (widget.bookingDetails['serviceName'] ?? 'Service')
          .toString();
      final totalGuests = widget.bookingDetails['totalGuests'] ?? '-';
      final totalPriceRM = widget.bookingDetails['totalPriceRM'] ?? 0;

      final dateText = startAt != null
          ? DateFormat('dd MMM yyyy').format(startAt)
          : '-';
      final timeText = startAt != null
          ? DateFormat('HH:mm').format(startAt)
          : '-';

      // ===== Dining =====
      if (serviceType == 'dining') {
        final msgTitle = 'Dining Booking Confirmed';
        final msgBody =
            'Your dining reservation has been confirmed.\n'
            'Service: $serviceName\n'
            'Date: $dateText\n'
            'Time: $timeText\n'
            'Guests: $totalGuests\n'
            'Total Paid: RM $totalPriceRM';

        await FirebaseFirestore.instance
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

      // ===== Spa =====
      if (serviceType == 'spa') {
        final treatmentLabel =
            (widget.bookingDetails['treatmentLabel'] ?? 'Treatment').toString();
        final durationMin = widget.bookingDetails['durationMinutes'] ?? '-';

        final msgTitle = 'Spa Booking Confirmed';
        final msgBody =
            'Your spa booking has been confirmed.\n'
            'Service: $serviceName\n'
            'Treatment: $treatmentLabel (${durationMin} min)\n'
            'Date: $dateText\n'
            'Time: $timeText\n'
            'Guests: $totalGuests\n'
            'Total Paid: RM $totalPriceRM';

        await FirebaseFirestore.instance
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

    // 3️⃣ 跳成功页
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
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
              Text(
                'Total Amount Due',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                amountFormatted,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Pay Now',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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
