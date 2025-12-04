import 'package:flutter/material.dart';
import 'package:hotel_reservation_app/auth_gate.dart';
import 'package:video_player/video_player.dart';
import 'package:hotel_reservation_app/data/hotel_logo_painter.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late VideoPlayerController _videoController;
  bool _isReady = false;

  // ✅ Logo 动画进度（0~1，0 不显示，1 完全画完）
  double _logoProgress = 0.0;

  // ✅ 避免重复跳转 & 重复 delay
  bool _hasScheduledNext = false;

  @override
  void initState() {
    super.initState();

    _videoController = VideoPlayerController.asset(
      'assets/videos/splash.mp4',
    )
      ..setLooping(false)
      ..setVolume(0.0);

    _videoController.initialize().then((_) {
      if (!mounted) return;
      setState(() {
        _isReady = true;
      });

      _videoController.play();
      _videoController.addListener(_onVideoUpdate);
    });
  }

  void _onVideoUpdate() {
    final value = _videoController.value;
    if (!value.isInitialized) return;

    final duration = value.duration;
    final position = value.position;

    // ✅ 1.5 秒的 Logo 动画时间
    const logoDuration = Duration(milliseconds: 1500);
    final logoStart = duration - logoDuration;

    // ---------- 1）计算 Logo 动画进度 ----------
    if (position >= logoStart) {
      // 已经进入最后 1.5 秒
      double p = (position - logoStart).inMilliseconds /
          logoDuration.inMilliseconds;
      if (p < 0) p = 0;
      if (p > 1) p = 1;

      if (p != _logoProgress) {
        setState(() {
          _logoProgress = p; // 0 → 1 逐渐画完
        });
      }
    } else {
      // 还没到最后 1.5 秒，确保 Logo 是隐藏的
      if (_logoProgress != 0.0) {
        setState(() {
          _logoProgress = 0.0;
        });
      }
    }

    // ---------- 2）视频播完后：让 Logo 多停留一会再跳 ----------
    if (!_hasScheduledNext && position >= duration) {
      _hasScheduledNext = true;

      // 确保最后停留时 logo 是完整的
      if (_logoProgress != 1.0) {
        setState(() {
          _logoProgress = 1.0;
        });
      }

      // ✅ 这里控制“结束时停留多久”（现在是 1 秒）
      Future.delayed(const Duration(seconds: 1), () {
        _goNext();
      });
    }
  }

  void _goNext() {
    if (!mounted) return;
    _videoController.removeListener(_onVideoUpdate);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthGate()),
    );
  }

  @override
  void dispose() {
    _videoController.removeListener(_onVideoUpdate);
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isReady
          ? Stack(
              children: [
                // ✅ 背景视频：铺满屏幕（没有黑边）
                SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _videoController.value.size.width,
                      height: _videoController.value.size.height,
                      child: VideoPlayer(_videoController),
                    ),
                  ),
                ),

                // ✅ 最后 1.5 秒 + 结束停留时：中间画出 Logo + 文字
                if (_logoProgress > 0)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo 线条动画
                        SizedBox(
                          width: 180,
                          height: 180,
                          child: CustomPaint(
                            painter: HotelLogoPainter(_logoProgress),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 「HotelEase」从左到右渐显
                        ClipRect(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            widthFactor: _logoProgress.clamp(0.0, 1.0),
                            child: const Text(
                              "HotelEase",
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: Color.fromARGB(255, 0, 0, 0), // 视频上一般用白色比较清楚
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            )
          : const Center(
              child: CircularProgressIndicator(),
            ),
    );
  }
}
