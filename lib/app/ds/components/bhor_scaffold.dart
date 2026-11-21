// BhorScaffold: page background + faint top-left wash + safe areas, with
// optional header, sidebar (desktop), bottom nav (phone) and a floating
// primary action. Replaces Material Scaffold. BhorActionBar is the sticky
// save bar pinned under full-screen forms. The header fades in a hairline
// once the body scrolls; the floating action moves up out of a toast's way.
// Page transitions (bhorPageTransition / bhorFullscreenTransition) fade
// through on an opaque page background: the page below is covered before
// the new page's content appears, so two pages are never legible at once.
// Usage: `BhorScaffold(header: BhorHeader(title: 'আজ'), body: ..., bottomNav: nav)`.

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/components/bhor_button.dart';
import 'package:attendance_alamin/app/ds/components/bhor_navigation.dart' show BhorBottomNav, BhorHeaderScrolled;
import 'package:attendance_alamin/app/ds/components/bhor_overlays.dart' show BhorBottomObstruction, BhorToast;
import 'package:attendance_alamin/app/ds/foundation/bhor_theme.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_tokens.dart';

class BhorScaffold extends StatefulWidget {
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
  State<BhorScaffold> createState() => _BhorScaffoldState();
}

class _BhorScaffoldState extends State<BhorScaffold> {
  bool _scrolled = false;

  bool _onScroll(ScrollNotification n) {
    if (n.depth == 0 && n.metrics.axis == Axis.vertical) {
      final bool now = n.metrics.pixels > 4;
      if (now != _scrolled) setState(() => _scrolled = now);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final Widget? header = widget.header;
    final Widget? sidebar = widget.sidebar;
    final Widget? bottomNav = widget.bottomNav;
    final Widget? floating = widget.floating;
    final Widget body = header == null
        ? widget.body
        : NotificationListener<ScrollNotification>(onNotification: _onScroll, child: widget.body);
    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (header != null)
          SafeArea(
            bottom: false,
            left: sidebar == null,
            child: BhorHeaderScrolled(scrolled: _scrolled, child: header),
          ),
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
              if (widget.wash)
                Positioned.fill(
                  child: IgnorePointer(child: CustomPaint(painter: _WashPainter(c.washStart))),
                ),
              Positioned.fill(
                child: sidebar == null
                    ? content
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[sidebar, Expanded(child: content)],
                      ),
              ),
              if (floating != null)
                Positioned(
                  right: BhorSpace.s16,
                  bottom: BhorSpace.s16 +
                      (bottomNav == null
                          ? MediaQuery.paddingOf(context).bottom
                          : BhorBottomNav.height + MediaQuery.paddingOf(context).bottom),
                  child: SafeArea(top: false, bottom: false, child: _FloatingLift(child: floating)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Moves the floating action up by the height of a bottom toast while one
/// shows (phones), so the two never overlap.
class _FloatingLift extends StatelessWidget {
  const _FloatingLift({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (context.bhorIsWide) return child;
    return ValueListenableBuilder<double>(
      valueListenable: BhorToast.occupied,
      builder: (BuildContext context, double lift, Widget? child) => AnimatedPadding(
        padding: EdgeInsets.only(bottom: lift),
        duration: BhorMotion.of(context, BhorMotion.base),
        curve: BhorMotion.curveOf(context, BhorMotion.springSoft),
        child: child,
      ),
      child: child,
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
    this.state,
  });

  /// Spinner in the button (saving).
  final bool loading;

  /// The button morphs to a check + "হয়েছে".
  final bool done;

  /// Wins over [loading] / [done] when set.
  final BhorButtonState? state;

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
    // Toasts sit above the bar, never on its button.
    return BhorBottomObstruction(
      child: DecoratedBox(
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
                state: state,
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
      ),
    );
  }
}

/// Share of a page transition during which the new page's opaque
/// background covers the page below; its content only fades in after it.
const double kBhorPageCover = 0.4;

/// The Bhor page transition, a true fade-through. First the new page's
/// opaque background fades over the page below (first 40%), then its
/// content fades in (rest): two pages' content is never legible at once.
/// Phone push: the content slides in from x +32 px while the page
/// underneath slides to x -16 px and dims to .94 (parallax); pop reverses
/// (the content fades out first, then the background uncovers the page
/// below). Desktop (>= 840): the content scales .985 -> 1. Reduced motion:
/// fades only. Used by [BhorPageRoute] and the app router's pages.
Widget bhorPageTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) =>
    _fadeThroughPage(context, animation, secondaryAnimation, child, fullscreen: false);

/// The full-screen flow transition (roll call, search, onboarding): the
/// same fade-through, rising 24 px in; on close the content drops 24 px and
/// fades out before its background uncovers the page below.
Widget bhorFullscreenTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) =>
    _fadeThroughPage(context, animation, secondaryAnimation, child, fullscreen: true);

Widget _fadeThroughPage(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child, {
  required bool fullscreen,
}) {
  final BhorColors c = context.bhor.colors;
  final bool reduced = BhorMotion.reduced(context);
  final bool wide = context.bhorIsWide;
  final Animation<double> cover =
      CurvedAnimation(parent: animation, curve: const Interval(0, kBhorPageCover, curve: BhorMotion.ease));
  final Animation<double> reveal =
      CurvedAnimation(parent: animation, curve: const Interval(kBhorPageCover, 1, curve: BhorMotion.ease));
  Widget content = FadeTransition(opacity: reveal, child: child);
  if (!reduced) {
    content = AnimatedBuilder(
      animation: reveal,
      builder: (BuildContext context, Widget? page) {
        final double t = 1 - reveal.value;
        if (fullscreen) return Transform.translate(offset: Offset(0, 24 * t), child: page);
        if (wide) return Transform.scale(scale: 0.985 + 0.015 * reveal.value, child: page);
        return Transform.translate(offset: Offset(BhorMotion.distanceLg * t, 0), child: page);
      },
      child: content,
    );
  }
  Widget page = Stack(
    fit: StackFit.expand,
    children: <Widget>[
      IgnorePointer(
        child: FadeTransition(
          key: const ValueKey<String>('bhor-page-cover'),
          opacity: cover,
          child: ColoredBox(color: c.bg),
        ),
      ),
      content,
    ],
  );
  if (!reduced && !wide && !fullscreen) {
    // The page underneath a phone push: parallax to x -16 and dim to .94
    // (it is covered by then; this only shapes the uncover on pop).
    final Animation<double> under =
        CurvedAnimation(parent: secondaryAnimation, curve: BhorMotion.ease, reverseCurve: BhorMotion.exitCurve);
    page = AnimatedBuilder(
      animation: under,
      builder: (BuildContext context, Widget? p) => Transform.translate(
        offset: Offset(-16 * under.value, 0),
        child: Opacity(opacity: (1 - 0.06 * under.value).clamp(0.0, 1.0), child: p),
      ),
      child: page,
    );
  }
  return page;
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

