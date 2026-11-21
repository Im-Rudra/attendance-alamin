// BhorScaffold: page background + faint top-left wash + safe areas, with
// optional header, sidebar (desktop), bottom nav (phone) and a floating
// primary action. Replaces Material Scaffold. BhorActionBar is the sticky
// save bar pinned under full-screen forms.
// Usage: `BhorScaffold(header: BhorHeader(title: 'আজ'), body: ..., bottomNav: nav)`.

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/components/bhor_button.dart';
import 'package:attendance_alamin/app/ds/components/bhor_navigation.dart' show BhorBottomNav;
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
                  bottom: BhorSpace.s16 +
                      (bottomNav == null
                          ? MediaQuery.paddingOf(context).bottom
                          : BhorBottomNav.height + MediaQuery.paddingOf(context).bottom),
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

/// The bar pinned under a full-screen form or the roll call: optional live
/// summary above the full-width primary button, and the reason under it
/// while it is disabled. Pass it as `BhorScaffold(bottomNav: ...)` or put it
/// at the bottom of a Column.
/// Usage: `BhorActionBar(label: 'সংরক্ষণ', onPressed: save, disabledReason: why, summary: counts)`.
class BhorActionBar extends StatelessWidget {
  const BhorActionBar({
    super.key,
    required this.label,
    required this.onPressed,
    this.buttonKey,
    this.disabledReason,
    this.summary,
    this.loading = false,
    this.done = false,
  });

  /// Spinner in the button (saving).
  final bool loading;

  /// The button morphs to a check + "হয়েছে".
  final bool done;

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;

  /// Key of the [BhorButton] itself (tests and automation tap it).
  final Key? buttonKey;

  /// Shown under a disabled button so the teacher knows what is missing.
  final String? disabledReason;

  /// Live counts, e.g. "২৮ উপস্থিত, ২ অনুপস্থিত".
  final String? summary;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: b.colors.surface,
        border: Border(top: BorderSide(color: b.colors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(BhorSpace.s16, BhorSpace.s12, BhorSpace.s16, BhorSpace.s12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (summary != null) ...<Widget>[
                Semantics(
                  liveRegion: true,
                  child: Text(summary!, textAlign: TextAlign.center, style: b.type.meta),
                ),
                const SizedBox(height: BhorSpace.s8),
              ],
              BhorButton(
                key: buttonKey,
                label: label,
                expand: true,
                size: BhorButtonSize.lg,
                loading: loading,
                done: done,
                onPressed: onPressed,
                disabledReason: disabledReason,
              ),
              if (onPressed == null && disabledReason != null) ...<Widget>[
                const SizedBox(height: BhorSpace.s8),
                Text(disabledReason!, textAlign: TextAlign.center, style: b.type.meta),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The Bhor page transition. Phone push: the new page slides in from
/// x +32 px and fades in (ease) while the page underneath slides to
/// x -16 px and dims to .94 (parallax); pop reverses with the exit curve.
/// Desktop (>= 840): a cross-fade with scale .985 -> 1. Reduced motion: a
/// fade only. Used by [BhorPageRoute] and the app router's pages.
Widget bhorPageTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final Animation<double> curved =
      CurvedAnimation(parent: animation, curve: BhorMotion.ease, reverseCurve: BhorMotion.exitCurve);
  if (BhorMotion.reduced(context)) return FadeTransition(opacity: curved, child: child);
  if (context.bhorIsWide) {
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(scale: Tween<double>(begin: 0.985, end: 1).animate(curved), child: child),
    );
  }
  final Animation<double> under =
      CurvedAnimation(parent: secondaryAnimation, curve: BhorMotion.ease, reverseCurve: BhorMotion.exitCurve);
  return AnimatedBuilder(
    animation: Listenable.merge(<Listenable>[curved, under]),
    builder: (BuildContext context, Widget? page) => Transform.translate(
      offset: Offset(32 * (1 - curved.value) - 16 * under.value, 0),
      child: Opacity(
        opacity: (curved.value * (1 - 0.06 * under.value)).clamp(0.0, 1.0),
        child: page,
      ),
    ),
    child: child,
  );
}

/// A full-screen page pushed outside the router (replaces MaterialPageRoute).
/// Usage: `Navigator.of(context).push(BhorPageRoute<void>(builder: (_) => const X()))`.
class BhorPageRoute<T> extends PageRouteBuilder<T> {
  BhorPageRoute({required WidgetBuilder builder, super.settings, super.fullscreenDialog})
      : super(
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 220),
          pageBuilder: (BuildContext context, Animation<double> a, Animation<double> s) => builder(context),
          transitionsBuilder: bhorPageTransition,
        );
}

