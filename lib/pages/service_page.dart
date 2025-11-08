import 'package:flutter/material.dart';

enum ServiceType { spa, swim, clean, gym, laundry, taxi }

class ServicePage extends StatefulWidget {
  const ServicePage({super.key});

  @override
  State<ServicePage> createState() => _ServicePageState();
}

class _ServicePageState extends State<ServicePage> {
  // ====== 状态 ======
  ServiceType _service = ServiceType.spa;
  DateTime _selectedDate = DateTime.now();
  String? _selectedTime;

  int _adults = 0;
  int _kids = 0;
  int _pets = 0;

  final List<String> _timeSlots = const [
    '12:00pm', '01:00pm', '02:00pm', '03:00pm', '04:00pm', '05:00pm',
  ];

  // 可按需修改价格
  final Map<ServiceType, int> _basePrice = const {
    ServiceType.spa: 168,
    ServiceType.swim: 60,
    ServiceType.clean: 120,
    ServiceType.gym: 50,
    ServiceType.laundry: 20,
    ServiceType.taxi: 30,
  };

  String get _serviceName {
    switch (_service) {
      case ServiceType.spa:
        return 'SPA';
      case ServiceType.swim:
        return 'Swim';
      case ServiceType.clean:
        return 'Clean';
      case ServiceType.gym:
        return 'Gym';
      case ServiceType.laundry:
        return 'Laundry';
      case ServiceType.taxi:
        return 'Taxi';
    }
  }
  
int get _totalPrice => _basePrice[_service] ?? 0;

String _fmtDate(DateTime d) =>
    '${_monthName(d.month)} ${d.day}, ${d.year}'; // 简单格式化：March 15, 2024

String _monthName(int m) {
  const names = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];
  return names[m - 1];
}

@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.white, // 跟你现在的风格一致
    appBar: AppBar(
      title: const Text('Service'),
      backgroundColor: Colors.white,
      elevation: 0,
      titleTextStyle: const TextStyle(
        color: Colors.black,
        fontSize: 20,
        fontWeight: FontWeight.w500,
      ),
      iconTheme: const IconThemeData(color: Colors.black),
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _sectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Service'),
                const SizedBox(height: 8),
                _serviceChips(),
              ],
            ),
          ),
          const SizedBox(height: 12),
          
_sectionCard(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionTitle('Service Date'),
      const SizedBox(height: 8),
      _calendar(),
    ],
  ),
),
const SizedBox(height: 12),

_sectionCard(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionTitle('Service Time'),
      const SizedBox(height: 8),
      _timeSlotWrap(),
    ],
  ),
),
const SizedBox(height: 12),

_sectionCard(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionTitle('Guest'),
      const SizedBox(height: 8),
      _counterRow('Adult', _adults, onMinus: () {
        setState(() => _adults = (_adults > 0) ? _adults - 1 : 0);
      }, onPlus: () {
        setState(() => _adults += 1);
      }),
      const Divider(height: 24),
      _counterRow('Kids', _kids, onMinus: () {
        setState(() => _kids = (_kids > 0) ? _kids - 1 : 0);
      }, onPlus: () {
        setState(() => _kids += 1);
      }),
      const Divider(height: 24),
      _counterRow('Pet', _pets, onMinus: () {
        setState(() => _pets = (_pets > 0) ? _pets - 1 : 0);
      }, onPlus: () {
        setState(() => _pets += 1);
      }),
    ],
  ),
),
const SizedBox(height: 12),

          _sectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Booking Details'),
                const SizedBox(height: 8),
                _kv('Service Name', _serviceName),
                _kv('Service Date', _fmtDate(_selectedDate)),
                _kv('Service Time', _selectedTime ?? '--:--'),
                const SizedBox(height: 8),
                Text(
                  'Total Price: RM$_totalPrice',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_selectedTime == null)
                        ? null
                        : () {
                      // TODO: 这里接入你的提交逻辑（如写入 Firebase / 调后端）
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Booked $_serviceName on ${_fmtDate(_selectedDate)} at ${_selectedTime!}',
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Confirm Booking'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

// ====== 下面是一些可复用的小部件 ======
Widget _sectionCard({required Widget child}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF5F5F7),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE2E2E8)),
    ),
    child: child,
  );
}

Widget _sectionTitle(String title) {
  return Row(
    children: [
      const Icon(Icons.circle, size: 10, color: Colors.black54),
      const SizedBox(width: 6),
      Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ],
  );
}

Widget _serviceChips() {
  Widget chip(ServiceType type, IconData icon, String label) {
    final selected = _service == type;
    return ChoiceChip(
      selected: selected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selectedColor: Colors.black87,
      labelStyle: TextStyle(color: selected ? Colors.white : Colors.black87),
      onSelected: (_) => setState(() => _service = type),
    );
  }
  return Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      chip(ServiceType.spa, Icons.spa, 'SPA'),
      chip(ServiceType.swim, Icons.pool, 'Swim'),
      chip(ServiceType.clean, Icons.cleaning_services, 'Clean'),
      chip(ServiceType.gym, Icons.fitness_center, 'Gym'),
      chip(ServiceType.laundry, Icons.local_laundry_service, 'Laundry'),
      chip(ServiceType.taxi, Icons.local_taxi, 'Taxi'),
    ],
  );
}

Widget _calendar() {
  final first = DateTime(DateTime.now().year, DateTime.now().month, 1);
  final last = DateTime(DateTime.now().year, DateTime.now().month + 3, 0); // 未来 3 个月

  return CalendarDatePicker(
    initialDate: _selectedDate,
    firstDate: first,
    lastDate: last,
    onDateChanged: (date) => setState(() => _selectedDate = date),
  );
}

Widget _timeSlotWrap() {
  return Wrap(
    spacing: 12,
    runSpacing: 12,
    children: _timeSlots.map((t) {
      final selected = _selectedTime == t;
      return ChoiceChip(
        label: Text(t),
        selected: selected,
        selectedColor: Colors.black87,
        labelStyle: TextStyle(color: selected ? Colors.white : Colors.black87),
        onSelected: (_) => setState(() => _selectedTime = t),
      );
    }).toList(),
  );
}
Widget _counterRow(String title, int value,
      {required VoidCallback onMinus, required VoidCallback onPlus}) {
    return Row(
      children: [
        Expanded(child: Text(title)),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE2E2E8)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: onMinus,
                icon: const Icon(Icons.remove),
                visualDensity: VisualDensity.compact,
              ),
              Text('$value', style: const TextStyle(fontWeight: FontWeight.w600)),
              IconButton(
                onPressed: onPlus,
                icon: const Icon(Icons.add),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        )
      ],
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(k)),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
