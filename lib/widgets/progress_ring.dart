import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Circular progress ring showing today's adherence
class ProgressRing extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final int total;
  final int taken;

  const ProgressRing({
    super.key,
    required this.progress,
    required this.total,
    required this.taken,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeOutBack,
      tween: Tween<double>(begin: 0, end: progress),
      builder: (context, animatedProgress, child) {
        final percentage = (animatedProgress * 100).toInt();
        final theme = Theme.of(context);
        
        return SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            children: [
              CustomPaint(
                size: const Size(220, 220),
                painter: _ProgressRingPainter(
                  progress: animatedProgress,
                  color: theme.colorScheme.secondary,
                  backgroundColor: theme.colorScheme.surface.withAlpha(26), // 10% opacity,
                ),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$percentage%',
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontSize: 56,
                        height: 1.0,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$taken / $total',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(153),
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      'COMPLETED',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(102),
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }


}

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  _ProgressRingPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 12;
    const strokeWidth = 24.0;

    // Background circle
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
      
    // Add shadow to progress
    final shadowPaint = Paint()
      ..color = color.withAlpha(102)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    const startAngle = -math.pi / 2; // Start from top
    final sweepAngle = 2 * math.pi * progress;

    if (progress > 0) {
      // Draw shadow first
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        shadowPaint,
      );
      
      // Draw actual progress
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress || 
           oldDelegate.color != color ||
           oldDelegate.backgroundColor != backgroundColor;
  }
}
