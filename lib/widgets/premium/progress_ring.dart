import 'dart:math' as math;
import 'package:flutter/material.dart';

class ProgressRing extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final double size;
  final double strokeWidth;
  final Gradient gradient;
  final Color backgroundColor;
  final Widget? child;
  final bool showGlow;

  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 200,
    this.strokeWidth = 15,
    this.gradient = const LinearGradient(
      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFEC4899)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    this.backgroundColor = const Color(0xFFE2E8F0),
    this.child,
    this.showGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Ring
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
              progress: 1.0,
              strokeWidth: strokeWidth,
              color: backgroundColor.withOpacity(0.2),
              style: PaintingStyle.stroke,
            ),
          ),

          // Glowing Effect (Optional)
          if (showGlow && progress > 0)
            CustomPaint(
              size: Size(size, size),
              painter: _RingPainter(
                progress: progress,
                strokeWidth: strokeWidth + 4,
                gradient: gradient,
                style: PaintingStyle.stroke,
                blur: 12.0,
                opacity: 0.4,
              ),
            ),

          // Foreground Gradient Ring
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: progress),
            duration: const Duration(milliseconds: 1500),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return CustomPaint(
                size: Size(size, size),
                painter: _RingPainter(
                  progress: value,
                  strokeWidth: strokeWidth,
                  gradient: gradient,
                  style: PaintingStyle.stroke,
                  strokeCap: StrokeCap.round,
                ),
              );
            },
          ),

          // Inner Content
          if (child != null) Center(child: child),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color? color;
  final Gradient? gradient;
  final PaintingStyle style;
  final StrokeCap strokeCap;
  final double blur;
  final double opacity;

  _RingPainter({
    required this.progress,
    required this.strokeWidth,
    this.color,
    this.gradient,
    required this.style,
    this.strokeCap = StrokeCap.butt,
    this.blur = 0.0,
    this.opacity = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Rotate -90 degrees to start from top
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-math.pi / 2);
    canvas.translate(-center.dx, -center.dy);

    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = style
      ..strokeWidth = strokeWidth
      ..strokeCap = strokeCap;

    if (blur > 0) {
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
    }

    if (gradient != null) {
      paint.shader = gradient!.createShader(rect);
    } else {
      paint.color = color ?? Colors.grey;
    }

    if (opacity < 1.0) {
      paint.color = paint.color.withOpacity(opacity);
      // Note: Shader opacity handling is tricky in Paint.
      // For simple glow, we rely on the layer opacity.
    }

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(rect, 0, sweepAngle, false, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.color != color ||
        oldDelegate.gradient != gradient ||
        oldDelegate.blur != blur;
  }
}
