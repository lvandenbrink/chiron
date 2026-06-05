import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CircularTimer extends StatefulWidget {
  final int remainingSeconds;
  final int totalSeconds;
  final double size;

  const CircularTimer({
    super.key,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.size = 220,
  });

  @override
  State<CircularTimer> createState() => _CircularTimerState();
}

class _CircularTimerState extends State<CircularTimer>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(CircularTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.remainingSeconds <= 5 && widget.remainingSeconds > 0) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.totalSeconds > 0
        ? widget.remainingSeconds / widget.totalSeconds
        : 0.0;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final scale = widget.remainingSeconds <= 5 && widget.remainingSeconds > 0
            ? _pulseAnimation.value
            : 1.0;
        return Transform.scale(
          scale: scale,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _TimerPainter(
                progress: progress.toDouble(),
                isNearlyDone: widget.remainingSeconds <= 5,
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${widget.remainingSeconds}',
                      style: TextStyle(
                        fontSize: widget.size * 0.28,
                        fontWeight: FontWeight.w700,
                        color: widget.remainingSeconds <= 5
                            ? Colors.orange
                            : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'seconden',
                      style: TextStyle(
                        fontSize: widget.size * 0.09,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TimerPainter extends CustomPainter {
  final double progress;
  final bool isNearlyDone;

  const _TimerPainter({required this.progress, required this.isNearlyDone});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    const strokeWidth = 12.0;

    // Background track
    final trackPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    final progressColor = isNearlyDone ? Colors.orange : AppColors.primary;
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_TimerPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.isNearlyDone != isNearlyDone;
}
