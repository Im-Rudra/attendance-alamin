// Shared interaction pieces: press/hover/focus handling (no ripple: press
// scale .96 in 80 ms, spring back on release), the keyboard focus ring, a
// spinner and a hover tooltip (300 ms delay, fade + 4 px rise). All
// widgets-layer only; reduced motion drops the scale.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/foundation/bhor_theme.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_tokens.dart';

/// Interaction state handed to a [BhorPressable] builder.
class BhorStates {
  const BhorStates({
    this.hovered = false,
    this.focused = false,
    this.pressed = false,
    this.enabled = true,
  });

  final bool hovered;
  final bool focused;
  final bool pressed;
  final bool enabled;
}

typedef BhorStateBuilder = Widget Function(BuildContext context, BhorStates states);

/// Tap/long-press + keyboard (Enter/Space) + hover + focus ring + press scale.
/// Usage: `BhorPressable(onTap: f, semanticLabel: 'x', builder: (c, s) => ...)`.
class BhorPressable extends StatefulWidget {
  const BhorPressable({
    super.key,
    required this.builder,
    this.onTap,
    this.onLongPress,
    this.semanticLabel,
    this.semanticHint,
    this.isButton = true,
    this.selected,
    this.checked,
    this.toggled,
    this.inMutuallyExclusiveGroup = false,
    this.excludeChildSemantics = false,
    this.focusNode,
    this.autofocus = false,
    this.radius = BhorRadius.control,
    this.scaleOnPress = true,
    this.pressScale = BhorMotion.pressScale,
    this.showFocusRing = true,
  });

  final BhorStateBuilder builder;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? semanticLabel;
  final String? semanticHint;
  final bool isButton;
  final bool? selected;
  final bool? checked;
  final bool? toggled;
  final bool inMutuallyExclusiveGroup;
  final bool excludeChildSemantics;
  final FocusNode? focusNode;
  final bool autofocus;

  /// Corner radius of the focus ring.
  final double radius;
  final bool scaleOnPress;

  /// Scale while pressed (.96 buttons, .9 small stepper buttons).
  final double pressScale;
  final bool showFocusRing;

  @override
  State<BhorPressable> createState() => _BhorPressableState();
}

class _BhorPressableState extends State<BhorPressable> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  /// Last pointer that touched this control: hover visuals follow a mouse
  /// only, so a tap on a touch screen never leaves a hover tint behind.
  PointerDeviceKind? _lastKind;

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  bool get _touch => _lastKind != null && _lastKind != PointerDeviceKind.mouse;

  void _onPointer(PointerEvent e) {
    if (e is PointerDownEvent) BhorTapTracker.record(e, context.findRenderObject());
    _lastKind = e.kind;
    if (_touch && _hovered && mounted) setState(() => _hovered = false);
  }

  void _setPressed(bool v) {
    if (_pressed != v && mounted) setState(() => _pressed = v);
  }

  @override
  void didUpdateWidget(BhorPressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_enabled) {
      _pressed = false;
      _hovered = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = _enabled;
    final BhorStates states = BhorStates(
      hovered: _hovered && enabled && !_touch,
      focused: _focused && enabled,
      pressed: _pressed && enabled,
      enabled: enabled,
    );
    Widget child = widget.builder(context, states);
    if (widget.scaleOnPress && !BhorMotion.reduced(context)) {
      // Press in fast and linear-ish; release with the spring (slight overshoot).
      child = AnimatedScale(
        scale: states.pressed ? widget.pressScale : 1,
        duration: states.pressed ? BhorMotion.instant : BhorMotion.glide,
        curve: states.pressed ? BhorMotion.ease : BhorMotion.spring,
        child: child,
      );
    }
    if (widget.showFocusRing) {
      child = BhorFocusRing(visible: states.focused, radius: widget.radius, child: child);
    }
    child = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _setPressed(true) : null,
      onTapUp: enabled ? (_) => _setPressed(false) : null,
      onTapCancel: enabled ? () => _setPressed(false) : null,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: child,
    );
    child = Listener(onPointerDown: _onPointer, onPointerUp: _onPointer, child: child);
    child = FocusableActionDetector(
      enabled: enabled,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onShowFocusHighlight: (bool v) => setState(() => _focused = v),
      onShowHoverHighlight: (bool v) {
        if (v && _touch) return;
        setState(() => _hovered = v);
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (ActivateIntent _) {
          // Keyboard activation: a popover it opens anchors to this control.
          BhorTapTracker.recordControl(context.findRenderObject(), View.maybeOf(context)?.viewId);
          widget.onTap?.call();
          return null;
        }),
      },
      child: child,
    );
    return Semantics(
      container: true,
      button: widget.isButton,
      enabled: enabled,
      selected: widget.selected,
      checked: widget.checked,
      toggled: widget.toggled,
      inMutuallyExclusiveGroup: widget.inMutuallyExclusiveGroup,
      label: widget.semanticLabel,
      hint: widget.semanticHint,
      excludeSemantics: widget.excludeChildSemantics,
      child: child,
    );
  }
}

/// Remembers the control the user last pressed (pointer-down on a
/// [BhorPressable], or Enter / Space on a focused one), so a popover opened
/// from a whole-screen or whole-card context can still anchor to the exact
/// control that was used (showBhorPopover, showBhorMenu).
abstract final class BhorTapTracker {
  /// Global position and view of the last press (null before one).
  static Offset? position;
  static int? viewId;

  /// The innermost [BhorPressable] that was pressed (null when unknown).
  static RenderBox? control;

  static PointerDownEvent? _event;

  /// Records a pointer-down. Every [BhorPressable] on the hit path sees the
  /// same event, innermost first: only the innermost one is kept.
  static void record(PointerDownEvent e, [RenderObject? box]) {
    final PointerDownEvent original = (e.original as PointerDownEvent?) ?? e;
    if (identical(original, _event)) return;
    _event = original;
    position = e.position;
    viewId = e.viewId;
    control = box is RenderBox ? box : null;
  }

  /// Records a keyboard activation of [box] in view [view] (its centre
  /// stands in for the pointer position).
  static void recordControl(RenderObject? box, int? view) {
    if (box is! RenderBox || !box.attached || !box.hasSize) return;
    _event = null;
    control = box;
    position = box.localToGlobal(box.size.center(Offset.zero));
    viewId = view ?? viewId ?? 0;
  }

  /// The last pressed control's rect in [ancestor]'s coordinates, or null
  /// when there is none (or it is gone, or not inside [ancestor]).
  static Rect? controlRectIn(RenderBox ancestor) {
    final RenderBox? box = control;
    if (position == null || box == null || !box.attached || !box.hasSize) return null;
    RenderObject? p = box;
    while (p != null && p != ancestor) {
      p = p.parent;
    }
    if (p == null) return null;
    return box.localToGlobal(Offset.zero, ancestor: ancestor) & box.size;
  }

  /// Forgets the last press (tests).
  static void reset() {
    position = null;
    viewId = null;
    control = null;
    _event = null;
  }
}

/// Paints the keyboard focus ring (4px accent tint + a thin accent edge)
/// around [child] without changing its layout.
class BhorFocusRing extends StatelessWidget {
  const BhorFocusRing({super.key, required this.visible, required this.child, this.radius = BhorRadius.control});

  final bool visible;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!visible) return child;
    final BhorColors c = context.bhor.colors;
    return CustomPaint(
      foregroundPainter: _RingPainter(ring: c.focusRing, edge: c.accent, radius: radius),
      child: child,
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.ring, required this.edge, required this.radius});

  final Color ring;
  final Color edge;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final RRect r = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    canvas.drawRRect(
      r.inflate(BhorSize.focusRingWidth / 2 + 1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = BhorSize.focusRingWidth
        ..color = ring,
    );
    canvas.drawRRect(
      r.inflate(0.75),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = edge,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.ring != ring || old.edge != edge || old.radius != radius;
}

/// Indeterminate spinner (static arc when animations are disabled).
/// Usage: `BhorSpinner(size: 18, color: c.onAccent)`.
class BhorSpinner extends StatefulWidget {
  const BhorSpinner({super.key, this.size = 18, this.color, this.semanticLabel});

  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  State<BhorSpinner> createState() => _BhorSpinnerState();
}

class _BhorSpinnerState extends State<BhorSpinner> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color color = widget.color ?? context.bhor.colors.accent;
    return Semantics(
      label: widget.semanticLabel,
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (BuildContext context, Widget? _) =>
              CustomPaint(painter: _ArcPainter(color: color, turn: _c.value)),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({required this.color, required this.turn});

  final Color color;
  final double turn;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = math.max(2, size.width / 9);
    final Rect r = (Offset.zero & size).deflate(w / 2);
    canvas.drawArc(
      r,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..color = color.withValues(alpha: 0.22),
    );
    canvas.drawArc(
      r,
      turn * math.pi * 2,
      math.pi * 0.6,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.turn != turn || old.color != color;
}

/// Hover tooltip (desktop), also shown on long press. Announced as a
/// semantics tooltip. Usage: `BhorTooltip(message: 'Why disabled', child: b)`.
class BhorTooltip extends StatefulWidget {
  const BhorTooltip({super.key, required this.message, required this.child, this.enabled = true});

  final String message;
  final Widget child;
  final bool enabled;

  @override
  State<BhorTooltip> createState() => _BhorTooltipState();
}

class _BhorTooltipState extends State<BhorTooltip> {
  final OverlayPortalController _portal = OverlayPortalController();
  final LayerLink _link = LayerLink();
  Timer? _timer;

  void _showSoon() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _portal.show();
    });
  }

  void _hide() {
    _timer?.cancel();
    _timer = null;
    if (_portal.isShowing) _portal.hide();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || widget.message.isEmpty) return widget.child;
    final BhorThemeData b = context.bhor;
    return Semantics(
      tooltip: widget.message,
      child: CompositedTransformTarget(
        link: _link,
        child: OverlayPortal(
          controller: _portal,
          overlayChildBuilder: (BuildContext context) => Positioned(
            left: 0,
            top: 0,
            child: CompositedTransformFollower(
              link: _link,
              targetAnchor: Alignment.bottomCenter,
              followerAnchor: Alignment.topCenter,
              offset: const Offset(0, 6),
              child: IgnorePointer(
                child: _TooltipEntrance(
                  child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: b.colors.text,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Text(widget.message, style: b.type.meta.copyWith(color: b.colors.bg)),
                    ),
                  ),
                ),
                ),
              ),
            ),
          ),
          child: MouseRegion(
            onEnter: (_) => _showSoon(),
            onExit: (_) => _hide(),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onLongPress: () => _portal.show(),
              onLongPressEnd: (_) => _hide(),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Tooltip entrance: 120 ms fade + 4 px rise (fade only when reduced).
class _TooltipEntrance extends StatefulWidget {
  const _TooltipEntrance({required this.child});

  final Widget child;

  @override
  State<_TooltipEntrance> createState() => _TooltipEntranceState();
}

class _TooltipEntranceState extends State<_TooltipEntrance> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: BhorMotion.reducedFade)..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool still = BhorMotion.reduced(context);
    final Animation<double> a = CurvedAnimation(parent: _c, curve: BhorMotion.ease);
    return FadeTransition(
      opacity: a,
      child: AnimatedBuilder(
        animation: a,
        builder: (BuildContext context, Widget? child) =>
            Transform.translate(offset: Offset(0, still ? 0 : 4 * (1 - a.value)), child: child),
        child: widget.child,
      ),
    );
  }
}
