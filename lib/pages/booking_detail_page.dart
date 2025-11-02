import 'package:flutter/material.dart';
import 'package:hotel_reservation_app/data/booking_data.dart';

class BookingDetailPage extends StatelessWidget {
  final Booking booking;

  const BookingDetailPage({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(booking.title),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                booking.imageUrl,
                width: double.infinity,
                height: 250,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              booking.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(booking.price, style: const TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 20),
            Text("Check-in: ${booking.checkIn}", style: const TextStyle(fontSize: 16)),
            Text("Check-out: ${booking.checkOut}", style: const TextStyle(fontSize: 16)),
            Text("Guests: ${booking.guests}", style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            const Text(
              "Thank you for booking with us!",
              style: TextStyle(color: Colors.black87, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
