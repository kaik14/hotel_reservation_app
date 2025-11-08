import 'package:flutter/material.dart';
import 'package:hotel_reservation_app/data/info_data.dart';
import 'package:hotel_reservation_app/app_shell.dart';

class BookingSuccessPage extends StatefulWidget {
  final InfoMessage? message;

  const BookingSuccessPage({super.key, this.message});

  @override
  State<BookingSuccessPage> createState() => _BookingSuccessPageState();
}

class _BookingSuccessPageState extends State<BookingSuccessPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  OverlayEntry? _overlayEntry; // ✅ 防止 overlay 丢失引用

  @override
  void initState() {
    super.initState();

    // ✅ 弹出动画
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.elasticOut);

    _controller.forward();

    // ✅ 如果有系统消息 → 显示通知
    Future.delayed(const Duration(milliseconds: 300), () {
      if (widget.message != null && mounted) {
        _showTopNotification(context, widget.message!);
      }
    });

    // ✅ 停留 2 秒 → 跳 SearchPage（index = 0）
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AppShell(initialIndex: 0)),
        (route) => false,
      );
    });
  }

  /// ✅ 顶部通知（可停留 5 秒，不受跳转影响）
  void _showTopNotification(BuildContext context, InfoMessage message) {
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 50,
        left: 20,
        right: 20,
        child: SlideTransitionNotification(message: message),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);

    Future.delayed(const Duration(seconds: 5), () {
      _overlayEntry?.remove();
      _overlayEntry = null;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _overlayEntry?.remove(); // ✅ 安全移除 overlay
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.check_circle, color: Colors.green, size: 100),
              SizedBox(height: 20),
              Text(
                "Booking Successful!",
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
              SizedBox(height: 8),
              Text(
                "Your reservation has been confirmed.",
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

///////////////////////////////////////////////////////////////////////////////
/// ✅ 顶部通知（点击跳 InfoPage index = 3）
///////////////////////////////////////////////////////////////////////////////
class SlideTransitionNotification extends StatefulWidget {
  final InfoMessage message;
  const SlideTransitionNotification({super.key, required this.message});

  @override
  State<SlideTransitionNotification> createState() =>
      _SlideTransitionNotificationState();
}

class _SlideTransitionNotificationState
    extends State<SlideTransitionNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: const Offset(0, 0),
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _offsetAnimation,
      child: GestureDetector(
        onTap: () {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => const AppShell(initialIndex: 3),
            ),
            (route) => false,
          );
        },
        child: Material(
          color: Colors.blueAccent,
          elevation: 6,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(Icons.notifications_active, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "New Message: ${widget.message.title}",
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
