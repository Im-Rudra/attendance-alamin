// BhorButton and BhorIconButton (docs/council/13-fluid-ui-spec.md, Button).
// Solid, soft, filled; r14, h46 (sm 38, lg 52). Press scale .96 (80 ms) and a
// spring back; hover colour shift; a trailing arrow nudges +3 px on hover;
// loading shows a spinner, `done` morphs to a check + "হয়েছে".
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

enum _Phase { idle, loading, done }

/// Text button with optional leading icon and trailing arrow. `loading`
/// shows a spinner and blocks presses; `done` morphs the content to a check
/// and [doneLabel] (default "হয়েছে"); `disabledReason` explains a disabled
/// button (tooltip on hover, semantics hint).
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
  final String? doneLabel;
  final String? disabledReason;

  /// Fill the available width.
  final bool expand;

  /// Pill shape (radius 999), e.g. toast actions.
  final bool pill;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final bool enabled = onPressed != null && !loading && !done;
    final double iconSize = size == BhorButtonSize.sm ? BhorIconSize.chip - 2 : BhorIconSize.chip;
    final TextStyle style = size == BhorButtonSize.sm ? b.type.label : b.type.bodyStrong;
    final _Phase phase = done ? _Phase.done : (loading ? _Phase.loading : _Phase.idle);
    final bool reduced = BhorMotion.reduced(context);
    final String shownLabel = done ? (doneLabel ?? context.l10n.dsDone) : label;
    Widget button = BhorPressable(
      onTap: enabled ? onPressed : null,
      semanticLabel: shownLabel,
      semanticHint: !enabled && !loading && !done ? disabledReason : null,
      excludeChildSemantics: true,
      radius: pill ? size.height / 2 : BhorRadius.control,
      builder: (BuildContext context, BhorStates s) => _buttonBox(
        context: context,
        variant: variant,
        states: s,
        height: size.height,
        width: expand ? double.infinity : null,
        radius: pill ? size.height / 2 : BhorRadius.control,
        disabledLook: onPressed == null && !done,
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
          final Widget row = Row(
            key: ValueKey<_Phase>(phase),
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (phase == _Phase.loading) ...<Widget>[
                BhorSpinner(size: iconSize, color: fg),
                const SizedBox(width: BhorSpace.s8),
              ] else if (phase == _Phase.done) ...<Widget>[
                _PopIn(child: Icon(BhorIcons.check, size: iconSize, color: fg)),
                const SizedBox(width: BhorSpace.s8),
              ] else if (icon != null) ...<Widget>[
                Icon(icon, size: iconSize, color: fg),
                const SizedBox(width: BhorSpace.s8),
              ],
              text,
              if (phase == _Phase.idle && (trailingIcon != null || arrow)) ...<Widget>[
                const SizedBox(width: BhorSpace.s8),
                AnimatedSlide(
                  offset: Offset(s.hovered && !reduced ? 3 / iconSize : 0, 0),
                  duration: BhorMotion.of(context, BhorMotion.fast),
                  curve: BhorMotion.spring,
                  child: Icon(trailingIcon ?? BhorIcons.arrowRight, size: iconSize, color: fg),
                ),
              ],
            ],
          );
          return AnimatedSize(
            duration: BhorMotion.of(context, BhorMotion.base),
            curve: BhorMotion.ease,
            child: AnimatedSwitcher(
              duration: BhorMotion.of(context, BhorMotion.fast),
              switchInCurve: BhorMotion.ease,
              switchOutCurve: BhorMotion.exitCurve,
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
