import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ← 用于设置状态栏图标/文字颜色
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hotel_reservation_app/pages/conference_hall_booking_page.dart';
import 'package:hotel_reservation_app/services/database_service.dart';
import 'package:hotel_reservation_app/pages/housekeeping_booking_page.dart';
import 'package:hotel_reservation_app/pages/laundry_booking_page.dart';
import 'package:hotel_reservation_app/pages/taxi_booking_page.dart';
import 'package:hotel_reservation_app/pages/dining_booking_page.dart';
import 'package:hotel_reservation_app/pages/spa_booking_page.dart';

// ⭐ 新增：导入 SwimmingBookingPage、GymBookingPage（注意路径）
import 'package:hotel_reservation_app/pages/swimming_booking_page.dart';
import 'package:hotel_reservation_app/pages/gym_booking_page.dart';

/// Ultra-minimal, single-column Services page.
/// - Light theme to pair with the dark bottom bar in AppShell
/// - Clean header (title + subtitle), no bell, no search
/// - Vertical list cards with subtle shadow & hairline border
/// - Staggered fade+slide entrance
class ServicePage extends StatelessWidget {
  const ServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _LightPalette.accentBlue,
          brightness: Brightness.light,
          primary: _LightPalette.accentBlue,
          surface: _LightPalette.bg,
          onSurface: _LightPalette.textPrimary,
        ),
        scaffoldBackgroundColor: _LightPalette.bg,
        textTheme: Theme.of(context).textTheme.apply(
              bodyColor: _LightPalette.textPrimary,
              displayColor: _LightPalette.textPrimary,
            ),
      ),
      child: const _ServiceScaffold(),
    );
  }
}

class _ServiceScaffold extends StatefulWidget {
  const _ServiceScaffold();

  static const _items = <_ServiceItem>[
    _ServiceItem(
      'Laundry & Ironing',
      Icons.local_laundry_service_rounded,
      'Freshly cleaned garments with press-on care, ready when you are.',
    ),
    _ServiceItem(
      'Housekeeping',
      Icons.cleaning_services_rounded,
      'Daily room refresh, linen change, and clutter-free comfort.',
    ),
    _ServiceItem(
      'Swimming',
      Icons.pool_rounded,
      'Access to the hotel pool with towel service and lockers.',
    ),
    _ServiceItem(
      'Hotel Taxi',
      Icons.local_taxi_rounded,
      'Safe, reliable rides scheduled to your itinerary.',
    ),
    _ServiceItem(
      'Dining Reservation',
      Icons.restaurant_menu_rounded,
      'Secure your table at our signature restaurants.',
    ),
    _ServiceItem(
      'Conference Hall',
      Icons.meeting_room_rounded,
      'Well-equipped venues for meetings and private events.',
    ),
    _ServiceItem(
      'Fitness',
      Icons.fitness_center_rounded,
      'Gym access, personal training, and wellness guidance.',
    ),
    _ServiceItem(
      'Spa Center',
      Icons.spa_rounded,
      'Massages, treatments, and serene recovery experiences.',
    ),
  ];

  @override
  State<_ServiceScaffold> createState() => _ServiceScaffoldState();
}

class _ServiceScaffoldState extends State<_ServiceScaffold> {
  /// ✅ 浮动 GIF 助手机器人状态
  bool _showAssistant = true;
  Offset _assistantOffset = const Offset(16, 140);
  bool _initializedOffset = false; // 是否已经按屏幕宽度设置起始位置

  /// ✅ 浮在最上层的可拖动 GIF 助手（起始在右侧）
  Widget _buildFloatingAssistant(BuildContext context) {
    final size = MediaQuery.of(context).size;

    const double avatarWidth = 140;
    const double avatarHeight = 140;

    // 第一次构建时，把起始位置设到右侧：距右 16，距上 140
    if (!_initializedOffset) {
      _assistantOffset = Offset(
        size.width - avatarWidth - 6,
        520,
      );
      _initializedOffset = true;
    }

    // 限制不让拖出屏幕
    final double left = _assistantOffset.dx.clamp(
      0.0,
      size.width - avatarWidth,
    );
    final double top = _assistantOffset.dy.clamp(
      0.0,
      size.height - avatarHeight - MediaQuery.of(context).padding.top,
    );

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _assistantOffset += details.delta;
          });
        },
        child: SizedBox(
          width: avatarWidth,
          height: avatarHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 直接放 GIF（这里暂时用 final2，你之后可以换成 service 专属）
              Positioned.fill(
                child: Image.asset(
                  'assets/gifs/final2.gif',
                  fit: BoxFit.contain,
                ),
              ),
              // 右上角小的关闭按钮
              Positioned(
                right: -4,
                top: -4,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _showAssistant = false;
                    });
                  },
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.6),
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    const parentNavHeight = 72.0;
    final bottomPadding = bottomSafe + parentNavHeight + 12;

    return Scaffold(
      backgroundColor: _LightPalette.bg,
      appBar: AppBar(
        // ==== 顶部栏样式保持不变 ====
        backgroundColor: const Color(0xFF0F1722), // 深色背景
        elevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        toolbarHeight: 97, // 保持加高的高度
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Color(0xFF0F1722),
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        // ✅ 使用 StreamBuilder 动态获取名字
        title: StreamBuilder<DocumentSnapshot>(
          stream: DatabaseService().getUserDataStream(
            FirebaseAuth.instance.currentUser?.uid ?? '',
          ),
          builder: (context, snapshot) {
            String firstName = 'Guest'; // 默认名字

            // 如果成功获取到数据，更新名字
            if (snapshot.hasData &&
                snapshot.data != null &&
                snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              firstName = data['firstName'] ?? 'Guest';
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hi, $firstName', // ✅ 动态显示名字
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Pick what you need, anytime.', // 保持原来的副标题
                  style: TextStyle(
                    color: Color(0x99FFFFFF),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            );
          },
        ),
        // 底部细分隔线
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: Colors.white.withOpacity(0.08)),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // 原来的服务列表
            ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(20, 8, 20, bottomPadding),
              itemCount: _ServiceScaffold._items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = _ServiceScaffold._items[index];
                return _AnimatedAppear(
                  delayMs: 70 * index,
                  child: _ServiceListCard(item: item),
                );
              },
            ),

            // 顶层：可拖动 GIF 助手
            if (_showAssistant) _buildFloatingAssistant(context),
          ],
        ),
      ),
    );
  }
}

/// ----- ANIMATION -----
class _AnimatedAppear extends StatefulWidget {
  final Widget child;
  final int delayMs;
  const _AnimatedAppear({required this.child, this.delayMs = 0});

  @override
  State<_AnimatedAppear> createState() => _AnimatedAppearState();
}

class _AnimatedAppearState extends State<_AnimatedAppear> {
  bool _v = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) setState(() => _v = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOut,
      opacity: _v ? 1 : 0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
        offset: _v ? Offset.zero : const Offset(0, .12),
        child: widget.child,
      ),
    );
  }
}

/// ----- LIST CARD -----
class _ServiceListCard extends StatefulWidget {
  final _ServiceItem item;
  const _ServiceListCard({required this.item});

  @override
  State<_ServiceListCard> createState() => _ServiceListCardState();
}

class _ServiceListCardState extends State<_ServiceListCard> {
  double _press = 1.0;

  @override
  Widget build(BuildContext context) {
    final iconColor = _LightPalette.icon;
    final halo = _LightPalette.accentBlue.withOpacity(0.12);
    final item = widget.item;

    return GestureDetector(
      onTapDown: (_) => setState(() => _press = 0.985),
      onTapCancel: () => setState(() => _press = 1.0),
      onTapUp: (_) => setState(() => _press = 1.0),
      // 整个卡片点击依然保留 snack（作为统一反馈）
      onTap: () => _snack(context, 'Coming soon: ${item.label}'),
      child: Transform.scale(
        scale: _press,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _LightPalette.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon block
              Container(
                height: 56,
                width: 56,
                decoration: BoxDecoration(
                  color: _LightPalette.iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: halo,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    Center(
                        child:
                            Icon(item.icon, color: iconColor, size: 26)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // Title + description + CTA chip
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _LightPalette.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _LightPalette.textSecondary,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        // ⭐ 这里控制 View details 的跳转
                        onTap: () {
                          if (item.label == 'Swimming') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SwimmingBookingPage(),
                              ),
                            );
                          } else if (item.label == 'Fitness') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const GymBookingPage(),
                              ),
                            );
                          } else if (item.label == 'Conference Hall') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const ConferenceHallBookingPage(),
                              ),
                            );
                          } else if (item.label == 'Housekeeping') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const HousekeepingBookingPage(),
                              ),
                            );
                          } else if (item.label == 'Laundry & Ironing') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const LaundryIroningBookingPage(),
                              ),
                            );
                          } else if (item.label == 'Hotel Taxi') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const TaxiBookingPage(),
                              ),
                            );
                          } else if (item.label == 'Dining Reservation') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const DiningBookingPage(),
                              ),
                            );
                          } else if (item.label == 'Spa Center') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SpaBookingPage(),
                              ),
                            );
                          } else {
                            _snack(context, 'Coming soon: ${item.label}');
                          }
                        },
                        child: Container(
                          height: 28,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10),
                          decoration: BoxDecoration(
                            color: _LightPalette.accentBlue,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: _LightPalette.accentBlue
                                    .withOpacity(.24),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              'View details',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                letterSpacing: .2,
                                fontSize: 12.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ----- MODELS & PALETTE -----
class _ServiceItem {
  final String label;
  final IconData icon;
  final String caption;
  const _ServiceItem(this.label, this.icon, this.caption);
}

class _LightPalette {
  static const bg =
      Color.fromARGB(255, 222, 228, 236); // near-white blue-gray
  static const textPrimary =
      Color(0xFF0F1722); // deep slate (pairs with bar)
  static const textSecondary = Color(0xFF5A6473);
  static const icon = Color(0xFF1F2A44);
  static const iconBg = Color(0xFFF0F4F9);
  static const border = Color.fromARGB(255, 255, 255, 255);
  static const accentBlue = Color.fromARGB(255, 49, 59, 83);
}

/// Helper
void _snack(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(text),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 900),
    ),
  );
}
