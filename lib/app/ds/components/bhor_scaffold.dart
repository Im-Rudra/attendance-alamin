// BhorScaffold: page background + faint top-left wash + safe areas, with
// optional header, sidebar (desktop), bottom nav (phone) and a floating
// primary action. Replaces Material Scaffold.
// Usage: `BhorScaffold(header: BhorHeader(title: 'আজ'), body: ..., bottomNav: nav)`.

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/foundation/bhor_theme.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_tokens.dart';

class BhorScaffold extends StatelessWidget {
  const BhorScaffold({
    super.key,
    required this.body,
    this.header,
    this.sidebar,
    this.bottomNav,
    this.floating,
    this.wash = true,
  });

  final Widget body;
  final Widget? header;
  final Widget? sidebar;
  final Widget? bottomNav;

  /// Primary action pinned bottom-right (above the bottom nav).
  final Widget? floating;

  /// Paint the faint top-left accent wash.
  final bool wash;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (header != null) SafeArea(bottom: false, left: sidebar == null, child: header!),
        Expanded(
          child: SafeArea(
            top: header == null,
            bottom: bottomNav == null,
            left: sidebar == null,
            child: body,
          ),
        ),
        ?bottomNav,
      ],
    );
    return ColoredBox(
      color: c.bg,
      child: DefaultTextStyle(
        style: b.type.body,
        child: IconTheme(
          data: IconThemeData(color: c.text2, size: 22),
          child: Stack(
            children: <Widget>[
              if (wash)
                Positioned.fill(
                  child: IgnorePointer(child: CustomPaint(painter: _WashPainter(c.washStart))),
                ),
              Positioned.fill(
                child: sidebar == null
                    ? content
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[sidebar!, Expanded(child: content)],
                      ),
              ),
              if (floating != null)
                Positioned(
                  right: BhorSpace.s16,
                  bottom: BhorSpace.s16 + (bottomNav == null ? MediaQuery.paddingOf(context).bottom : 64 + MediaQuery.paddingOf(context).bottom),
                  child: SafeArea(top: false, bottom: false, child: floating!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Radial accent wash, 90% wide x 40% tall, anchored at the top-left corner.
class _WashPainter extends CustomPainter {
  _WashPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final double rx = size.width * 0.9;
    final double ry = size.height * 0.4;
    canvas.save();
    canvas.scale(1, ry / rx);
    final Rect rect = Rect.fromCircle(center: Offset.zero, radius: rx);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * rx / ry),
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[color, color.withValues(alpha: 0)],
        ).createShader(rect),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WashPainter old) => old.color != color;
}
