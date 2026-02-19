import 'package:flutter/material.dart';
import 'dart:math' as math;

class MeshGradientBackground extends StatefulWidget {
  final List<Color> colors;
  final Widget? child;
  final Duration duration;

  const MeshGradientBackground({
    super.key,
    required this.colors,
    this.child,
    this.duration = const Duration(seconds: 10),
  });

  @override
  State<MeshGradientBackground> createState() => _MeshGradientBackgroundState();
}

class _MeshGradientBackgroundState extends State<MeshGradientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _MeshPainter(_controller.value, widget.colors),
          child: widget.child,
        );
      },
      child: widget.child,
    );
  }
}

class _MeshPainter extends CustomPainter {
  final double progress;
  final List<Color> colors;

  _MeshPainter(this.progress, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    if (colors.isEmpty) return;

    final paint = Paint();

    // Draw base background
    paint.color = colors[0];
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Draw rotating blobs
    for (int i = 1; i < colors.length; i++) {
      final angle =
          (progress * 2 * math.pi) + (i * 2 * math.pi / (colors.length - 1));
      final radius = math.min(size.width, size.height) * 0.8;

      final x = size.width / 2 + math.cos(angle) * radius * 0.3;
      final y = size.height / 2 + math.sin(angle * 1.5) * radius * 0.2;

      final rect = Rect.fromCircle(center: Offset(x, y), radius: radius);

      paint.shader = RadialGradient(
        colors: [colors[i].withOpacity(0.4), colors[i].withOpacity(0.0)],
      ).createShader(rect);

      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_MeshPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.colors != colors;
}
