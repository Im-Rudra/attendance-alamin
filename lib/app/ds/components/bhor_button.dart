// BhorButton and BhorIconButton (docs/council/13-fluid-ui-spec.md, Button).
// Solid, soft, filled; r14, h46 (sm 38, lg 52). Press scale .96 (80 ms) and a
// spring back; hover colour shift; a trailing arrow nudges +3 px on hover.
// States (BhorButtonState): idle -> loading (the label fades out completely,
// then a spinner fades in; never both at once) ->
// success (the spinner gives way to a check that pops in + "হয়েছে").
// BhorAsyncButton drives the states from a Future.
// Usage: `BhorButton(label: 'সেভ করুন', onPressed: save)`;
// `BhorButton(label: 'মুছুন', variant: BhorButtonVariant.danger, ...)`;
// `BhorButton(label: 'হাজিরা নিন', arrow: true, variant: BhorButtonVariant.hero, ...)`;
// `BhorIconButton(icon: BhorIcons.search, semanticLabel: 'খুঁজুন', onPressed: f)`.

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/foundation/bhor_icons.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_interaction.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_theme.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_tokens.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';

/// primary: solid accent, white text, 1 px top highlight. secondary: soft
/// fill. ghost: accent text, tint on hover. tonal: accent tint fill (row
/// actions). danger: solid error. hero: near-white on the hero card.
enum BhorButtonVariant { primary, secondary, ghost, danger, tonal, hero }

enum BhorButtonSize {
  md(BhorSize.control),
  sm(BhorSize.compact),
  lg(BhorSize.large);

  const BhorButtonSize(this.height);

  final double height;
}

class _Look {
  const _Look({this.fill, required this.fg, this.highlight});

  final Color? fill;
  final Color fg;

  /// Inner top highlight colour (primary only).
  final Color? highlight;
}

_Look _lookOf(BhorColors c, BhorButtonVariant v, BhorStates s, {bool iconGhost = false}) {
  final bool hot = s.hovered || s.pressed;
  if (iconGhost) return _Look(fill: hot ? c.soft : c.soft.withValues(alpha: 0), fg: c.text2);
  switch (v) {
    case BhorButtonVariant.primary:
      return _Look(fill: hot ? c.accentFillHover : c.accentFill, fg: c.onAccentFill, highlight: c.highlight);
    case BhorButtonVariant.secondary:
      return _Look(fill: hot ? c.soft2 : c.soft, fg: c.text);
    case BhorButtonVariant.ghost:
      return _Look(fill: hot ? c.accentTint : c.accentTint.withValues(alpha: 0), fg: c.accent);
    case BhorButtonVariant.tonal:
      return _Look(fill: hot ? Color.alphaBlend(c.accentLine.withValues(alpha: 0.35), c.accentTint) : c.accentTint, fg: c.accent);
    case BhorButtonVariant.danger:
      return _Look(fill: hot ? Color.alphaBlend(c.pressShade, c.danger) : c.danger, fg: c.onDanger);
    case BhorButtonVariant.hero:
      return _Look(fill: hot ? Color.alphaBlend(c.heroStart.withValues(alpha: 0.08), c.heroButton) : c.heroButton, fg: c.heroStart);
  }
}

Widget _buttonBox({
  required BuildContext context,
  required BhorButtonVariant variant,
  required BhorStates states,
  required double height,
  required double? width,
  required EdgeInsets padding,
  required Widget Function(Color fg) content,
  required double radius,
  bool disabledLook = false,
  bool iconGhost = false,
}) {
  final BhorColors c = context.bhor.colors;
  final _Look look = _lookOf(c, variant, states, iconGhost: iconGhost);
  final BorderRadius r = BorderRadius.circular(radius);
  final Duration d = BhorMotion.of(context, BhorMotion.fast);
  Widget box = AnimatedContainer(
    duration: d,
    curve: BhorMotion.ease,
    height: height,
    width: width,
    constraints: BoxConstraints(minWidth: height),
    padding: padding,
    decoration: BoxDecoration(color: look.fill, borderRadius: r),
    child: Center(widthFactor: 1, child: content(look.fg)),
  );
  if (look.highlight != null) {
    box = ClipRRect(
      borderRadius: r,
      child: Stack(
        children: <Widget>[
          box,
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 1,
            child: IgnorePointer(child: ColoredBox(color: look.highlight!)),
          ),
        ],
      ),
    );
  }
  return AnimatedOpacity(opacity: disabledLook ? 0.45 : 1, duration: d, child: box);
}

/// What a [BhorButton] shows: its label, a spinner (working; presses are
/// blocked), or a check + "হয়েছে" (done; presses are blocked).
enum BhorButtonState { idle, loading, success }

/// Text button with optional leading icon and trailing arrow. [state] (or
/// the older `loading` / `done` flags) switches between the label, a
/// spinner and the success check with a fade-through: the outgoing content
/// is gone before the incoming one appears, and the width morphs with it.
/// `disabledReason` explains a disabled button (tooltip on hover,
/// semantics hint). For a save that returns a Future use [BhorAsyncButton].
class BhorButton extends StatelessWidget {
  const BhorButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = BhorButtonVariant.primary,
    this.size = BhorButtonSize.md,
    this.icon,
    this.trailingIcon,
    this.arrow = false,
    this.loading = false,
    this.done = false,
    this.state,
    this.doneLabel,
    this.disabledReason,
    this.expand = false,
    this.pill = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final BhorButtonVariant variant;
  final BhorButtonSize size;
  final IconData? icon;

  /// Icon after the label (wins over [arrow]).
  final IconData? trailingIcon;

  /// Trailing arrow that nudges +3 px on hover.
  final bool arrow;
  final bool loading;

  /// Success state: a check and [doneLabel]; presses are blocked.
  final bool done;

  /// Wins over [loading] / [done] when set.
  final BhorButtonState? state;
  final String? doneLabel;
  final String? disabledReason;

  /// Fill the available width.
  final bool expand;

  /// Pill shape (radius 999), e.g. toast actions.
  final bool pill;

  /// Label <-> spinner <-> check fade-through.
  static const Duration switchDuration = Duration(milliseconds: 240);

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorButtonState phase =
        state ?? (done ? BhorButtonState.success : (loading ? BhorButtonState.loading : BhorButtonState.idle));
    final bool busy = phase != BhorButtonState.idle;
    final bool enabled = onPressed != null && !busy;
    final double iconSize = size == BhorButtonSize.sm ? BhorIconSize.chip - 2 : BhorIconSize.chip;
    final TextStyle style = size == BhorButtonSize.sm ? b.type.label : b.type.bodyStrong;
    final bool reduced = BhorMotion.reduced(context);
    final String shownLabel = phase == BhorButtonState.success ? (doneLabel ?? context.l10n.dsDone) : label;
    Widget button = BhorPressable(
      onTap: enabled ? onPressed : null,
      semanticLabel: shownLabel,
      semanticHint: !enabled && !busy ? disabledReason : null,
      excludeChildSemantics: true,
      radius: pill ? size.height / 2 : BhorRadius.control,
      builder: (BuildContext context, BhorStates s) => _buttonBox(
        context: context,
        variant: variant,
        states: s,
        height: size.height,
        width: expand ? double.infinity : null,
        radius: pill ? size.height / 2 : BhorRadius.control,
        disabledLook: onPressed == null && !busy,
        padding: EdgeInsets.symmetric(
          horizontal: switch (size) {
            BhorButtonSize.sm => BhorSpace.s16,
            BhorButtonSize.md => BhorSpace.s20,
            BhorButtonSize.lg => BhorSpace.s24,
          },
        ),
        content: (Color fg) {
          final Widget text = Flexible(
            child: Text(
              shownLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style.copyWith(color: fg),
            ),
          );
          final Widget row = switch (phase) {
            // Working: the spinner alone (the label has faded out; it stays
            // in the tree, invisible, so the button keeps its width).
            BhorButtonState.loading => Stack(
                key: const ValueKey<BhorButtonState>(BhorButtonState.loading),
                alignment: Alignment.center,
                children: <Widget>[
                  Opacity(opacity: 0, child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[text])),
                  BhorSpinner(size: iconSize + 2, color: fg),
                ],
              ),
            BhorButtonState.success => Row(
                key: const ValueKey<BhorButtonState>(BhorButtonState.success),
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _PopIn(child: Icon(BhorIcons.check, size: iconSize, color: fg)),
                  const SizedBox(width: BhorSpace.s8),
                  text,
                ],
              ),
            BhorButtonState.idle => Row(
            key: const ValueKey<BhorButtonState>(BhorButtonState.idle),
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: iconSize, color: fg),
                const SizedBox(width: BhorSpace.s8),
              ],
              text,
              if (trailingIcon != null || arrow) ...<Widget>[
                const SizedBox(width: BhorSpace.s8),
                AnimatedSlide(
                  offset: Offset(s.hovered && !reduced ? 3 / iconSize : 0, 0),
                  duration: BhorMotion.of(context, BhorMotion.fast),
                  curve: BhorMotion.spring,
                  child: Icon(trailingIcon ?? BhorIcons.arrowRight, size: iconSize, color: fg),
                ),
              ],
            ],
          ),
          };
          return AnimatedSize(
            duration: BhorMotion.of(context, BhorMotion.base),
            curve: BhorMotion.ease,
            child: AnimatedSwitcher(
              duration: BhorMotion.of(context, BhorButton.switchDuration),
              layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
                alignment: Alignment.center,
                children: <Widget>[...previous, if (current != null) current],
              ),
              transitionBuilder: (Widget child, Animation<double> a) =>
                  _fadeThrough(child, a, incoming: child.key == row.key, reduced: reduced),
              child: row,
            ),
          );
        },
      ),
    );
    if (onPressed == null && disabledReason != null) {
      button = BhorTooltip(message: disabledReason!, child: button);
    }
    // Keep the 44px tap target for the compact size.
    if (size == BhorButtonSize.sm) {
      button = ConstrainedBox(
        constraints: const BoxConstraints(minHeight: BhorSize.minTap),
        child: Center(widthFactor: 1, heightFactor: 1, child: button),
      );
    }
    return button;
  }
}

/// Fade-through for the button content: the outgoing content is fully gone
/// in the first 40% (label never overlaps the spinner), then the incoming
/// one fades and scales in (.8 -> 1 with the spring).
Widget _fadeThrough(Widget child, Animation<double> a, {required bool incoming, required bool reduced}) {
  if (reduced) return FadeTransition(opacity: a, child: child);
  if (!incoming) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: a, curve: const Interval(0.6, 1, curve: BhorMotion.ease)),
      child: child,
    );
  }
  final Animation<double> inA = CurvedAnimation(parent: a, curve: const Interval(0.4, 1, curve: BhorMotion.ease));
  return FadeTransition(
    opacity: inA,
    child: ScaleTransition(
      scale: Tween<double>(begin: 0.8, end: 1)
          .animate(CurvedAnimation(parent: a, curve: const Interval(0.4, 1, curve: BhorMotion.spring))),
      child: child,
    ),
  );
}

/// A [BhorButton] that runs [onPressed] (a Future) through the states:
/// idle -> loading while it runs -> success (check + [doneLabel]) for
/// [successHold], then [onDone] and back to idle. A result of `false` or
/// an error returns straight to idle (the error is rethrown to the zone).
/// Usage: `BhorAsyncButton(label: 'হাজিরা সেভ করুন', onPressed: save, onDone: close)`.
class BhorAsyncButton extends StatefulWidget {
  const BhorAsyncButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.onDone,
    this.variant = BhorButtonVariant.primary,
    this.size = BhorButtonSize.md,
    this.icon,
    this.doneLabel,
    this.disabledReason,
    this.expand = false,
    this.successHold = const Duration(milliseconds: 700),
  });

  final String label;

  /// The work; return false to skip the success state. Null disables.
  final Future<bool?> Function()? onPressed;

  /// After the success hold (e.g. close the screen).
  final VoidCallback? onDone;
  final BhorButtonVariant variant;
  final BhorButtonSize size;
  final IconData? icon;
  final String? doneLabel;
  final String? disabledReason;
  final bool expand;
  final Duration successHold;

  @override
  State<BhorAsyncButton> createState() => _BhorAsyncButtonState();
}

class _BhorAsyncButtonState extends State<BhorAsyncButton> with SingleTickerProviderStateMixin {
  BhorButtonState _state = BhorButtonState.idle;
  late final AnimationController _hold = AnimationController(vsync: this, duration: widget.successHold);

  Future<void> _run() async {
    final Future<bool?> Function()? task = widget.onPressed;
    if (task == null || _state != BhorButtonState.idle) return;
    setState(() => _state = BhorButtonState.loading);
    bool? ok;
    try {
      ok = await task();
    } catch (_) {
      if (mounted) setState(() => _state = BhorButtonState.idle);
      rethrow;
    }
    if (!mounted) return;
    if (ok == false) {
      setState(() => _state = BhorButtonState.idle);
      return;
    }
    setState(() => _state = BhorButtonState.success);
    await _hold.forward(from: 0).orCancel.catchError((Object _) {});
    if (!mounted) return;
    widget.onDone?.call();
    if (mounted) setState(() => _state = BhorButtonState.idle);
  }

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BhorButton(
        label: widget.label,
        onPressed: widget.onPressed == null ? null : _run,
        state: _state,
        variant: widget.variant,
        size: widget.size,
        icon: widget.icon,
        doneLabel: widget.doneLabel,
        disabledReason: widget.disabledReason,
        expand: widget.expand,
      );
}

/// Scale-pops its child in once (the done check).
class _PopIn extends StatefulWidget {
  const _PopIn({required this.child});

  final Widget child;

  @override
  State<_PopIn> createState() => _PopInState();
}

class _PopInState extends State<_PopIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: BhorMotion.glide);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.status == AnimationStatus.dismissed) {
      if (BhorMotion.reduced(context)) {
        _c.value = 1;
      } else {
        _c.forward();
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
        scale: CurvedAnimation(parent: _c, curve: BhorMotion.spring),
        child: widget.child,
      );
}

/// Square (or [circle]) icon-only button: 46 (md) / 38 (sm) visual inside a
/// 44 target. [semanticLabel] is required: it is the accessible name and the
/// tooltip. Ghost (default) is transparent with a soft hover; secondary is
/// the 46x46 soft button.
class BhorIconButton extends StatelessWidget {
  const BhorIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.variant = BhorButtonVariant.ghost,
    this.size = BhorButtonSize.md,
    this.badge,
    this.color,
    this.circle = false,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final BhorButtonVariant variant;
  final BhorButtonSize size;

  /// Small count dot (e.g. unread); null hides it.
  final String? badge;

  /// Icon colour override (ghost variant defaults to text2).
  final Color? color;

  /// Round instead of r14.
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final double side = size.height;
    final double radius = circle ? side / 2 : (size == BhorButtonSize.sm ? BhorRadius.back : BhorRadius.control);
    final Widget button = BhorPressable(
      onTap: onPressed,
      semanticLabel: semanticLabel,
      excludeChildSemantics: true,
      radius: radius,
      builder: (BuildContext context, BhorStates s) {
        // Ghost icon buttons get a soft hover, not the accent tint.
        final bool ghost = variant == BhorButtonVariant.ghost;
        return _buttonBox(
          context: context,
          variant: variant,
          iconGhost: ghost,
          states: s,
          height: side,
          width: side,
          radius: radius,
          disabledLook: onPressed == null,
          padding: EdgeInsets.zero,
          content: (Color fg) {
            final Color iconColor = color ?? (ghost ? (s.hovered ? b.colors.text : b.colors.text2) : fg);
            final Widget glyph =
                Icon(icon, size: size == BhorButtonSize.sm ? BhorIconSize.chip : BhorIconSize.row + 2, color: iconColor);
            if (badge == null) return glyph;
            return Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                glyph,
                Positioned(
                  right: -6,
                  top: -4,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(color: b.colors.danger, borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      badge!,
                      textAlign: TextAlign.center,
                      style: BhorType.tabular(b.type.caption).copyWith(color: b.colors.onDanger, height: 1.3),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    final Widget sized = ConstrainedBox(
      constraints: const BoxConstraints(minWidth: BhorSize.minTap, minHeight: BhorSize.minTap),
      child: Center(widthFactor: 1, heightFactor: 1, child: button),
    );
    return BhorTooltip(message: semanticLabel, enabled: context.bhorIsWide, child: sized);
  }
}
