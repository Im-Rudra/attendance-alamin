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
//   widget that must stay mounted.
// - BhorBranchFadeThrough: the shell's branch stack. Keeps every branch
//   mounted, fades the old tab out completely, then the new one in.
// - BhorStepTransition: shared-axis X for step changes (onboarding, steps in
//   a sheet): out -24 px + fade over 90 ms, then in from +24 px over 210 ms.
// - BhorPaneSwitcher: desktop detail pane fade-through + 6 px rise.
// No switcher here ever shows two contents legibly at once: the outgoing one
// is fully transparent before the incoming one starts (reduced motion too).
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
        if (reduced) return _reducedThrough(child, a, incoming: incoming);
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

/// Reduced motion: a plain fade, still without overlap (out in the first
/// half, in during the second).
Widget _reducedThrough(Widget child, Animation<double> a, {required bool incoming}) => FadeTransition(
      opacity: CurvedAnimation(parent: a, curve: const Interval(0.5, 1)),
      child: child,
    );

// ------------------------------------------------- Branch fade through ----

/// The shell's tab stack: every branch stays mounted (its navigator and
/// scroll state survive), only the current one is on stage. On a switch the
/// old branch fades out completely in 90 ms, then the new one fades in and
/// scales .98 -> 1 over 210 ms; at no frame are two tabs legible together.
/// Usage (go_router): `StatefulShellRoute(navigatorContainerBuilder:
/// (c, shell, children) => BhorBranchFadeThrough(index: shell.currentIndex, children: children), ...)`.
class BhorBranchFadeThrough extends StatefulWidget {
  const BhorBranchFadeThrough({super.key, required this.index, required this.children});

  final int index;
  final List<Widget> children;

  /// Whole switch: 90 ms out + 210 ms in.
  static const Duration duration = Duration(milliseconds: 300);

  @override
  State<BhorBranchFadeThrough> createState() => _BhorBranchFadeThroughState();
}

class _BhorBranchFadeThroughState extends State<BhorBranchFadeThrough> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: BhorBranchFadeThrough.duration, value: 1)
    ..addStatusListener((AnimationStatus s) {
      if (s == AnimationStatus.completed && _previous != null && mounted) setState(() => _previous = null);
    });
  int? _previous;

  @override
  void didUpdateWidget(BhorBranchFadeThrough oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _previous = oldWidget.index;
      _c.duration = BhorMotion.of(context, BhorBranchFadeThrough.duration);
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
    final Animation<double> out = ReverseAnimation(
      CurvedAnimation(parent: _c, curve: Interval(0, reduced ? 0.5 : 0.3, curve: BhorMotion.ease)),
    );
    final Animation<double> inA = CurvedAnimation(parent: _c, curve: Interval(reduced ? 0.5 : 0.3, 1, curve: BhorMotion.ease));
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        for (int i = 0; i < widget.children.length; i++)
          _branch(i, out, inA, reduced),
      ],
    );
  }

  Widget _branch(int i, Animation<double> out, Animation<double> inA, bool reduced) {
    final bool active = i == widget.index;
    final bool leaving = i == _previous && !active;
    final bool onStage = active || leaving;
    final Animation<double> opacity = active ? inA : (leaving ? out : kAlwaysCompleteAnimation);
    // The same wrappers for every branch, so a branch's subtree is never
    // re-parented when it becomes current.
    final Widget child = ScaleTransition(
      scale: active && !reduced ? Tween<double>(begin: 0.98, end: 1).animate(inA) : kAlwaysCompleteAnimation,
      child: widget.children[i],
    );
    return KeyedSubtree(
      key: ValueKey<int>(i),
      child: Offstage(
        offstage: !onStage,
        child: TickerMode(
          enabled: onStage,
          child: IgnorePointer(
            ignoring: !active,
            child: FadeTransition(opacity: opacity, child: child),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------ Step transition ----

/// A step change inside one screen or sheet (onboarding steps, a two-step
/// add flow), shared axis X: the old step moves 24 px towards the start and
/// fades to 0 in the first 90 ms; only then the new step comes in from
/// +24 px and fades in (210 ms). Going [forward] = false mirrors it. Give
/// each step a distinct [step]; wrap the footer in a second
/// BhorStepTransition with the same [step] so body and footer change
/// together. [color] paints an opaque background behind each step.
/// Usage: `BhorStepTransition(step: index, forward: index > old, child: stepWidget(index))`.
class BhorStepTransition extends StatelessWidget {
  const BhorStepTransition({
    super.key,
    required this.step,
    required this.child,
    this.forward = true,
    this.color,
    this.alignment = AlignmentDirectional.topStart,
  });

  final Object step;
  final Widget child;
  final bool forward;
  final Color? color;
  final AlignmentGeometry alignment;

  /// 90 ms out + 210 ms in.
  static const Duration duration = Duration(milliseconds: 300);

  /// How far a step slides.
  static const double distance = 24;

  @override
  Widget build(BuildContext context) {
    final bool reduced = BhorMotion.reduced(context);
    final Key current = ValueKey<Object>(step);
    final double dir = (forward ? 1 : -1) * (Directionality.maybeOf(context) == TextDirection.rtl ? -1 : 1);
    Widget content = child;
    if (color != null) content = ColoredBox(color: color!, child: content);
    return AnimatedSwitcher(
      duration: reduced ? BhorMotion.reducedFade : duration,
      layoutBuilder: (Widget? cur, List<Widget> previous) => Stack(
        alignment: alignment,
        fit: StackFit.passthrough,
        children: <Widget>[...previous, if (cur != null) cur],
      ),
      transitionBuilder: (Widget c, Animation<double> a) {
        final bool incoming = c.key == current;
        if (reduced) return _reducedThrough(c, a, incoming: incoming);
        final Animation<double> phase = CurvedAnimation(
          parent: a,
          curve: incoming ? const Interval(0.3, 1, curve: BhorMotion.ease) : const Interval(0.7, 1, curve: BhorMotion.ease),
        );
        return FadeTransition(
          opacity: phase,
          child: AnimatedBuilder(
            animation: phase,
            builder: (BuildContext context, Widget? w) => Transform.translate(
              // In: +24 -> 0. Out (phase 1 -> 0): 0 -> -24.
              offset: Offset((incoming ? 1 : -1) * dir * distance * (1 - phase.value), 0),
              child: w,
            ),
            child: c,
          ),
        );
      },
      child: KeyedSubtree(key: current, child: content),
    );
  }
}

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
      duration: reduced ? BhorMotion.reducedFade : const Duration(milliseconds: 270),
      layoutBuilder: _stackTopLayout,
      transitionBuilder: (Widget c, Animation<double> a) {
        if (reduced) return _reducedThrough(c, a, incoming: c.key == key);
        if (c.key != key) {
          // Gone in the first 90 ms.
          return FadeTransition(
            opacity: CurvedAnimation(parent: a, curve: const Interval(0.667, 1.0, curve: BhorMotion.ease)),
            child: c,
          );
        }
        final Animation<double> inA = CurvedAnimation(parent: a, curve: const Interval(0.333, 1.0, curve: BhorMotion.ease));
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
