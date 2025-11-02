class Booking {
  final String title;
  final String imageUrl;
  final String price;
  final String checkIn;
  final String checkOut;
  final int guests;
  final bool isCheckedIn;

  Booking({
    required this.title,
    required this.imageUrl,
    required this.price,
    required this.checkIn,
    required this.checkOut,
    required this.guests,
    required this.isCheckedIn,
  });
}

// ✅ 全局列表，存放所有订单
List<Booking> bookingList = [];
