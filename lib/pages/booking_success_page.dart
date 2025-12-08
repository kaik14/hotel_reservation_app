import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hotel_reservation_app/app_shell.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

class BookingSuccessPage extends StatefulWidget {
  // 支付金额（分）
  final int? paidAmount;

  const BookingSuccessPage({super.key, this.paidAmount});

  @override
  State<BookingSuccessPage> createState() => _BookingSuccessPageState();
}

class _BookingSuccessPageState extends State<BookingSuccessPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  OverlayEntry? _overlayEntry;

  Timer? _redirectTimer;

  // 🔥 视频控制器
  late VideoPlayerController _videoController;
  bool _videoInitialized = false;

  @override
  void initState() {
    super.initState();

    // 1. 初始化前景缩放动画
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _controller.forward();

    // 2. 初始化背景视频
    _videoController = VideoPlayerController.asset(
      'assets/videos/booking_success.mp4', // 👈 换成你自己的视频路径
    )
      ..setLooping(true)
      ..setVolume(0.0)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _videoInitialized = true);
        _videoController.play();
      });

    // 3. 顶部支付成功通知
    Future.delayed(const Duration(milliseconds: 300), () {
      if (widget.paidAmount != null && mounted) {
        final amountFormatted = NumberFormat.currency(
          locale: 'en_MY',
          symbol: 'RM ',
        ).format(widget.paidAmount! / 100);

        _showTopNotification(
          context,
          "Payment successful! You have paid $amountFormatted.",
          Colors.green,
        );
      }
    });

    // 4. 5 秒后跳回 Search（AppShell index 0）
    _redirectTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const AppShell(initialIndex: 0),
        ),
        (route) => false,
      );
    });
  }

  void _showTopNotification(BuildContext context, String message, Color color) {
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 50,
        left: 20,
        right: 20,
        child: SlideTransitionNotification(message: message, color: color),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);

    Future.delayed(const Duration(seconds: 3), () {
      _overlayEntry?.remove();
      _overlayEntry = null;
    });
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    _controller.dispose();
    _overlayEntry?.remove();
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1️⃣ 背景视频（铺满全屏）
          if (_videoInitialized)
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoController.value.size.width,
                  height: _videoController.value.size.height,
                  child: VideoPlayer(_videoController),
                ),
              ),
            )
          else
            // 视频没加载好时的占位背景
            const Positioned.fill(
              child: Center(child: CircularProgressIndicator()),
            ),

          // 2️⃣ 半透明黑色遮罩，让文字更清晰
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.35),
            ),
          ),

          // 3️⃣ 前景内容：图标 + 文本，居中放在最上层
          SafeArea(
            child: Center(
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.check_circle,
                        color: Colors.white, size: 100),
                    SizedBox(height: 20),
                    Text(
                      "Booking Successful!",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Your reservation has been confirmed.",
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 顶部滑入通知
class SlideTransitionNotification extends StatefulWidget {
  final String message;
  final Color color;
  const SlideTransitionNotification({
    super.key,
    required this.message,
    required this.color,
  });

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
      child: Material(
        color: widget.color,
        elevation: 6,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.notifications_active, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
