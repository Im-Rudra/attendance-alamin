// Dashed rounded-rectangle outline (excused attendance, waived month).

import 'dart:ui' show PathMetric;

import 'package:flutter/widgets.dart';

class DashedBorder extends StatelessWidget {
  const DashedBorder({
    super.key,
    required this.color,
    required this.radius,
    required this.child,
    this.width = 1,
    this.dash = 4,
    this.gap = 3,
  });

  final Color color;
  final double radius;
  final double width;
  final double dash;
  final double gap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _DashedPainter(color, radius, width, dash, gap),
      child: child,
    );
  }
}

class _DashedPainter extends CustomPainter {
  _DashedPainter(this.color, this.radius, this.width, this.dash, this.gap);

  final Color color;
  final double radius;
  final double width;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(width / 2, width / 2, size.width - width, size.height - width),
      Radius.circular(radius),
    );
    final Path path = Path()..addRRect(rrect);
    for (final PathMetric m in path.computeMetrics()) {
      double d = 0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + dash), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPainter old) =>
      old.color != color || old.radius != radius || old.width != width || old.dash != dash || old.gap != gap;
}
