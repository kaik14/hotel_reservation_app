class Service {
  final String id;
  final String title;
  final String iconPath;
  final String description;
  final double priceFrom;

  const Service({
    required this.id,
    required this.title,
    required this.iconPath,
    required this.description,
    required this.priceFrom,
  });
}

const demoServices = <Service>[
  Service(
    id: 'spa',
    title: 'Spa & Massage',
    iconPath: 'assets/icons/spa.png',
    description: 'Relax and enjoy our premium spa packages.',
    priceFrom: 199.0,
  ),
  Service(
    id: 'dining',
    title: 'Dining Reservation',
    iconPath: 'assets/icons/dining.png',
    description: 'Reserve a table at our SkyView restaurant.',
    priceFrom: 59.0,
  ),
  Service(
    id: 'cleaning',
    title: 'Room Cleaning',
    iconPath: 'assets/icons/cleaning.png',
    description: 'Book a cleaning session for your room.',
    priceFrom: 0.0,
  ),
  Service(
    id: 'transport',
    title: 'Airport Transfer',
    iconPath: 'assets/icons/transport.png',
    description: 'Enjoy comfortable transfers to the airport.',
    priceFrom: 120.0,
  ),
];
