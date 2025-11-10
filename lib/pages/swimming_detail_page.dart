import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SwimmingDetailPage extends StatefulWidget {
  const SwimmingDetailPage({super.key});

  @override
  State<SwimmingDetailPage> createState() => _SwimmingDetailPageState();
}

class _SwimmingDetailPageState extends State<SwimmingDetailPage> {
  // —— 本地默认数据（保证页面可渲染）——
  Map<String, dynamic> _data = {
    'name': 'Swimming Pool',
    'description':
        'Free access for hotel guests with reservations. Same-day use within guest stay only. Closed on Mondays for maintenance.',
    'ui': {
      'location': 'Level 27, Rooftop Sky Deck (Infinity Pool)',
      'notes':
          'Towels not provided. Wear proper swimwear. Children must be accompanied by adults.',
      'imageName': 'pool.jpg',
    },
    'schedule': {
      'timezone': 'Asia/Kuala_Lumpur',
      'open': '07:00',
      'close': '21:00',
      'closedWeekdays': [1], // 0=Sun ... 6=Sat
    },
    'isFree': true,
    'price': 0,
  };

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFromFirestore(); // 尝试取云端，失败也能看到本地 UI
  }

  Future<void> _loadFromFirestore() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final doc = await FirebaseFirestore.instance
          .collection('services')
          .doc('swimming')
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _data = {..._data, ...data}; // 用云端数据覆盖本地默认
        });
      } else {
        setState(() => _error = 'Service not found');
      }
    } on FirebaseException catch (e) {
      // 常见：unavailable, permission-denied, not-found
      setState(() => _error = e.code);
    } catch (e) {
      setState(() => _error = 'unknown');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = _data['ui'] as Map<String, dynamic>? ?? {};
    final schedule = _data['schedule'] as Map<String, dynamic>? ?? {};
    final img = ui['imageName'] ?? 'pool.jpg';

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 222, 228, 236),

      // 顶栏统一风格
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1722),
        elevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        toolbarHeight: 97,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Color(0xFF0F1722),
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        leadingWidth: 48,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.white, size: 30),
          onPressed: () => Navigator.maybePop(context),
          tooltip: 'Back',
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Service Details',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Learn about this facility before booking.',
              style: TextStyle(
                color: Color(0x99FFFFFF),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: Colors.white.withOpacity(0.08)),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 顶部图片卡
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/services/$img',
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),

            // 内容卡
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题 + 免费/价格
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _data['name'] ?? 'Swimming Pool',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      _data['isFree'] == true
                          ? _pill(
                              'Free',
                              Colors.green[100]!,
                              Colors.green[800]!,
                            )
                          : _pill(
                              'RM${_data['price']}',
                              Colors.black,
                              Colors.white,
                              invert: true,
                            ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _data['description'] ?? '',
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _sectionTitle('Location'),
                  Text(
                    ui['location'] ??
                        'Level 27, Rooftop Sky Deck (Infinity Pool)',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 12),

                  _sectionTitle('Opening Hours'),
                  Text(
                    "${schedule['open'] ?? '07:00'} – ${schedule['close'] ?? '21:00'}  (${schedule['timezone'] ?? 'Asia/Kuala_Lumpur'})",
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _closedText(schedule['closedWeekdays']),
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),

                  _sectionTitle('Notes'),
                  Text(
                    ui['notes'] ??
                        'Towels not provided. Wear proper swimwear. Children must be accompanied by adults.',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 错误与重试
            if (_error != null) ...[
              Text(
                'Load failed: $_error',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _loadFromFirestore,
                child: const Text('Retry'),
              ),
              const SizedBox(height: 8),
            ],

            // 预约按钮（先做样式，后面再接业务）
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading
                    ? null
                    : () {
                        // TODO: 接入“新建泳池预约”流程
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Reservation flow coming soon'),
                            duration: Duration(milliseconds: 900),
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 49, 59, 83),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  shadowColor: const Color.fromARGB(
                    255,
                    49,
                    59,
                    83,
                  ).withOpacity(.25),
                  elevation: 4,
                ),
                child: Text(
                  _loading ? 'Loading...' : 'Reserve a Time',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String text, Color bg, Color fg, {bool invert = false}) {
    final colorBg = invert ? fg : bg;
    final colorFg = invert ? bg : fg;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: colorFg,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      t,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    ),
  );

  String _closedText(dynamic list) {
    if (list is! List) return 'Closed: Monday';
    const names = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    if (list.isEmpty) return 'Open daily';
    final parts = list
        .where((e) => e is num && e >= 0 && e <= 6)
        .map((e) => names[(e as num).toInt()])
        .toList();
    return 'Closed: ${parts.join(', ')}';
  }
}
