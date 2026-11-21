// Motion primitives for screens (docs/council/13-fluid-ui-spec.md, Motion
// tokens; 12-ux-review.md section 4). All honour reduced motion
// (BhorMotion.reduced: 120 ms fades, final values, no stagger) and use
// animation controllers only (no timers), so widget tests can settle.
//
// - BhorStaggerScope + BhorStagger: first-load stagger (fade + 8 px rise,
//   30 ms per item, first 8 only, only during the scope's first paint).
// - BhorCountUp (+ .money): numbers and money count up on first appearance
//   and roll to new values; Bangla digits per frame, tabular.
// - BhorFadeThrough: tab / view switches (old fades out 90 ms, new fades in
//   and scales .98 -> 1 over 210 ms). `.replay` re-plays the entrance on a
//   widget that must stay mounted (the shell's branch stack).
// - BhorPaneSwitcher: desktop detail pane cross-fade + 6 px rise.
// - BhorSuccess: the success circle that pops and draws its check.

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/components/bhor_choice.dart' show BhorCheckPainter;
import 'package:attendance_alamin/app/ds/components/bhor_domain.dart' show BhorMoney;
import 'package:attendance_alamin/app/ds/foundation/bhor_theme.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_tokens.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/core/format/app_format.dart';

// ------------------------------------------------------------- Stagger ----

/// Limits [BhorStagger] to the first paint of a list: items that mount
/// while the scope's window is open stagger in; items mounted later (scroll,
/// new data, returning to a tab) just appear. Put one at the top of a
/// screen's list. Usage:
/// `BhorStaggerScope(child: ListView(children: [for (i...) BhorStagger(index: i, child: row)]))`.
class BhorStaggerScope extends StatefulWidget {
  const BhorStaggerScope({super.key, required this.child});

  final Widget child;

  @override
  State<BhorStaggerScope> createState() => _BhorStaggerScopeState();
}

class _BhorStaggerScopeState extends State<BhorStaggerScope> with SingleTickerProviderStateMixin {
  /// Open from the first registered item until the cap has played.
  late final AnimationController _window = AnimationController(
    vsync: this,
    duration: BhorMotion.base + BhorMotion.staggerStep * BhorMotion.staggerCap,
  );
  bool _started = false;

  bool get open => !_started || _window.isAnimating;

  void _register() {
    if (_started) return;
    _started = true;
    _window.forward();
  }

  @override
  void dispose() {
    _window.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _StaggerScopeData(state: this, child: widget.child);
}

class _StaggerScopeData extends InheritedWidget {
  const _StaggerScopeData({required this.state, required super.child});

  final _BhorStaggerScopeState state;

  @override
  bool updateShouldNotify(_StaggerScopeData oldWidget) => false;
}

/// One list item that fades in and rises 8 px on first load, delayed
/// [index] x 30 ms (items from 8 on appear without animation).
class BhorStagger extends StatefulWidget {
  const BhorStagger({super.key, required this.index, required this.child, this.enabled = true});

  final int index;
  final Widget child;

  /// False renders [child] as is.
  final bool enabled;

  @override
  State<BhorStagger> createState() => _BhorStaggerState();
}

class _BhorStaggerState extends State<BhorStagger> with SingleTickerProviderStateMixin {
  AnimationController? _c;
  Animation<double>? _a;
  bool _decided = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_decided) return;
    _decided = true;
    final _BhorStaggerScopeState? scope =
        context.getInheritedWidgetOfExactType<_StaggerScopeData>()?.state;
    final bool animate = widget.enabled &&
        widget.index < BhorMotion.staggerCap &&
        !BhorMotion.reduced(context) &&
        (scope == null || scope.open);
    if (!animate) return;
    scope?._register();
    final Duration delay = BhorMotion.staggerStep * widget.index;
    final Duration total = delay + BhorMotion.base;
    final AnimationController c = AnimationController(vsync: this, duration: total);
    _c = c;
    _a = CurvedAnimation(
      parent: c,
      curve: Interval(delay.inMicroseconds / total.inMicroseconds, 1, curve: BhorMotion.ease),
    );
    c.forward();
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double>? a = _a;
    if (a == null) return widget.child;
    return FadeTransition(
      opacity: a,
      child: AnimatedBuilder(
        animation: a,
        builder: (BuildContext context, Widget? child) =>
            Transform.translate(offset: Offset(0, 8 * (1 - a.value)), child: child),
        child: widget.child,
      ),
    );
  }
}

// ------------------------------------------------------------ Count up ----

/// A number that counts up from [from] (default 0) on first appearance
/// and rolls from the old to the new value on change (260-480 ms, count
/// curve). Digits follow the locale (Bangla) and are tabular, so the width
/// stays stable. Screen readers hear only the final value.
/// Usage: `BhorCountUp(value: 24, style: b.type.stat)`,
/// `BhorCountUp.money(amount: 18500, style: b.type.stat, muteSign: true)`,
/// `BhorCountUp(value: 0.82, format: (v) => fmt.percent(v))`.
class BhorCountUp extends StatelessWidget {
  const BhorCountUp({
    super.key,
    required this.value,
    this.from,
    this.format,
    this.style,
    this.textAlign,
    this.color,
  })  : money = false,
        muteSign = false;

  const BhorCountUp.money({
    super.key,
    required int amount,
    this.from,
    this.style,
    this.muteSign = false,
    this.color,
  })  : value = amount,
        money = true,
        format = null,
        textAlign = null;

  final num value;

  /// Start of the first count (default 0). Pass [value] to count only on change.
  final num? from;

  /// Formats a frame value (default: rounded, locale digits).
  final String Function(num value)? format;
  final TextStyle? style;
  final TextAlign? textAlign;
  final Color? color;
  final bool money;
  final bool muteSign;

  static Duration _durationFor(num a, num b) {
    final double delta = (b - a).abs().toDouble();
    if (delta == 0) return BhorMotion.countUpMin;
    // Small changes are quick; big jumps take up to 480 ms.
    final double t = (delta / 1000).clamp(0.0, 1.0);
    final int ms = BhorMotion.countUpMin.inMilliseconds +
        ((BhorMotion.countUpMax.inMilliseconds - BhorMotion.countUpMin.inMilliseconds) * t).round();
    return Duration(milliseconds: ms);
  }

  @override
  Widget build(BuildContext context) {
    final AppFormat fmt = context.fmt;
    final BhorThemeData b = context.bhor;
    final bool reduced = BhorMotion.reduced(context);
    final String Function(num v) f = format ?? ((num v) => fmt.number(v.round()));
    final num start = reduced ? value : (from ?? 0);
    TextStyle base = BhorType.tabular(style ?? b.type.bodyStrong);
    if (color != null) base = base.copyWith(color: color);
    final String finalText = money ? fmt.money(value.round()) : f(value);
    return Semantics(
      label: finalText,
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: start.toDouble(), end: value.toDouble()),
        duration: reduced ? Duration.zero : _durationFor(start, value),
        curve: BhorMotion.countCurve,
        builder: (BuildContext context, double v, Widget? _) {
          if (money) return BhorMoney(v.round(), style: base, muteSign: muteSign);
          return Text(value is int ? f(v.round()) : f(v), maxLines: 1, textAlign: textAlign, style: base);
        },
      ),
    );
  }
}

// -------------------------------------------------------- Fade through ----

/// Tab / view switch: the old child fades out (90 ms), then the new one
/// fades in and scales .98 -> 1 (210 ms). Give each content a distinct key:
/// `BhorFadeThrough(child: KeyedSubtree(key: ValueKey(tab), child: page))`.
///
/// [BhorFadeThrough.replay] keeps one child mounted and replays the
/// entrance whenever [trigger] changes (the shell's branch stack, whose
/// navigators must never be built twice).
class BhorFadeThrough extends StatefulWidget {
  const BhorFadeThrough({super.key, required this.child}) : trigger = null, _replay = false;

  const BhorFadeThrough.replay({super.key, required Object this.trigger, required this.child}) : _replay = true;

  final Widget child;
  final Object? trigger;
  final bool _replay;

  static const Duration duration = Duration(milliseconds: 300);

  @override
  State<BhorFadeThrough> createState() => _BhorFadeThroughState();
}

class _BhorFadeThroughState extends State<BhorFadeThrough> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 210), value: 1);

  @override
  void didUpdateWidget(BhorFadeThrough oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget._replay && oldWidget.trigger != widget.trigger) {
      _c.duration = BhorMotion.of(context, const Duration(milliseconds: 210));
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool reduced = BhorMotion.reduced(context);
    if (widget._replay) {
      final Animation<double> a = CurvedAnimation(parent: _c, curve: BhorMotion.ease);
      return FadeTransition(
        opacity: a,
        child: reduced ? widget.child : ScaleTransition(scale: Tween<double>(begin: 0.98, end: 1).animate(a), child: widget.child),
      );
    }
    final Key? current = widget.child.key;
    return AnimatedSwitcher(
      duration: reduced ? BhorMotion.reducedFade : BhorFadeThrough.duration,
      layoutBuilder: _stackTopLayout,
      transitionBuilder: (Widget child, Animation<double> a) {
        final bool incoming = child.key == current;
        if (reduced) return FadeTransition(opacity: a, child: child);
        if (!incoming) {
          // Reverse 1 -> 0: gone after the first 30% (90 ms).
          return FadeTransition(
            opacity: CurvedAnimation(parent: a, curve: const Interval(0.7, 1.0, curve: BhorMotion.ease)),
            child: child,
          );
        }
        final Animation<double> inA = CurvedAnimation(parent: a, curve: const Interval(0.3, 1.0, curve: BhorMotion.ease));
        return FadeTransition(
          opacity: inA,
          child: ScaleTransition(scale: Tween<double>(begin: 0.98, end: 1).animate(inA), child: child),
        );
      },
      child: widget.child,
    );
  }
}

Widget _stackTopLayout(Widget? current, List<Widget> previous) => Stack(
      alignment: AlignmentDirectional.topStart,
      fit: StackFit.passthrough,
      children: <Widget>[...previous, if (current != null) current],
    );

// -------------------------------------------------------- Pane switcher ----

/// Desktop list -> detail: when [paneKey] changes, the old detail fades
/// out over 90 ms while the new one fades in and rises 6 px over 180 ms.
/// Usage: `BhorPaneSwitcher(paneKey: selectedId, child: StudentDetail(id: selectedId))`.
class BhorPaneSwitcher extends StatelessWidget {
  const BhorPaneSwitcher({super.key, required this.paneKey, required this.child});

  final Object? paneKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool reduced = BhorMotion.reduced(context);
    final Key key = ValueKey<Object?>(paneKey);
    return AnimatedSwitcher(
      duration: reduced ? BhorMotion.reducedFade : const Duration(milliseconds: 180),
      layoutBuilder: _stackTopLayout,
      transitionBuilder: (Widget c, Animation<double> a) {
        if (reduced) return FadeTransition(opacity: a, child: c);
        if (c.key != key) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: a, curve: const Interval(0.5, 1.0, curve: BhorMotion.ease)),
            child: c,
          );
        }
        final Animation<double> inA = CurvedAnimation(parent: a, curve: BhorMotion.ease);
        return FadeTransition(
          opacity: inA,
          child: AnimatedBuilder(
            animation: inA,
            builder: (BuildContext context, Widget? child) =>
                Transform.translate(offset: Offset(0, BhorMotion.distanceSm * (1 - inA.value)), child: child),
            child: c,
          ),
        );
      },
      child: KeyedSubtree(key: key, child: child),
    );
  }
}

// -------------------------------------------------------------- Success ----

/// The success moment: a tinted circle that pops in (spring) and draws its
/// check, an optional [label], then [onDone] after a short hold. Shown by
/// `BhorSuccess.complete` inside sheets and side panels, or on its own.
/// Usage: `BhorSuccess(label: 'জমা হয়েছে', onDone: close)`.
class BhorSuccess extends StatefulWidget {
  const BhorSuccess({super.key, this.size = 72, this.label, this.onDone, this.color});

  final double size;
  final String? label;
  final VoidCallback? onDone;

  /// Check / ring colour (default ok).
  final Color? color;

  /// Pop + draw, then the hold before [onDone].
  static const Duration duration = Duration(milliseconds: 900);

  @override
  State<BhorSuccess> createState() => _BhorSuccessState();
}

class _BhorSuccessState extends State<BhorSuccess> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: BhorSuccess.duration);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (BhorMotion.reduced(context)) _c.duration = BhorMotion.reducedFade * 3;
    _c.forward().whenCompleteOrCancel(() {
      if (mounted && _c.isCompleted) widget.onDone?.call();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final Color col = widget.color ?? b.colors.ok;
    final bool reduced = BhorMotion.reduced(context);
    final Animation<double> pop = CurvedAnimation(
      parent: _c,
      curve: reduced ? const Interval(0, 0.6, curve: BhorMotion.ease) : const Interval(0, 0.5, curve: BhorMotion.spring),
    );
    final Animation<double> draw =
        CurvedAnimation(parent: _c, curve: Interval(reduced ? 0 : 0.3, reduced ? 0.6 : 0.75, curve: BhorMotion.ease));
    return Semantics(
      liveRegion: true,
      label: widget.label ?? context.l10n.dsDone,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AnimatedBuilder(
            animation: _c,
            builder: (BuildContext context, Widget? _) => Transform.scale(
              scale: reduced ? 1 : pop.value,
              child: Opacity(
                opacity: reduced ? pop.value.clamp(0.0, 1.0) : 1,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color.alphaBlend(col.withValues(alpha: 0.14), b.colors.surface),
                    border: Border.all(color: col, width: 2),
                  ),
                  child: CustomPaint(
                    painter: BhorCheckPainter(progress: draw.value, color: col, strokeWidth: widget.size / 18),
                  ),
                ),
              ),
            ),
          ),
          if (widget.label != null) ...<Widget>[
            const SizedBox(height: BhorSpace.s12),
            FadeTransition(
              opacity: draw,
              child: Text(widget.label!, textAlign: TextAlign.center, style: b.type.heading),
            ),
          ],
        ],
      ),
    );
  }
}
