// BhorButton and BhorIconButton.
// Usage: `BhorButton(label: 'সংরক্ষণ', onPressed: save)`;
// `BhorButton(label: 'মুছুন', variant: BhorButtonVariant.danger, ...)`;
// `BhorIconButton(icon: Icons.search, semanticLabel: 'খুঁজুন', onPressed: f)`.

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/foundation/bhor_interaction.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_theme.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_tokens.dart';

enum BhorButtonVariant { primary, secondary, ghost, danger }

enum BhorButtonSize {
  md(BhorSize.control),
  sm(BhorSize.compact);

  const BhorButtonSize(this.height);

  final double height;
}

class _Look {
  const _Look({this.fill, this.gradient, required this.fg, this.border});

  final Color? fill;
  final Gradient? gradient;
  final Color fg;
  final Color? border;
}

_Look _lookOf(BhorColors c, BhorButtonVariant v, BhorStates s) {
  switch (v) {
    case BhorButtonVariant.primary:
      return _Look(gradient: c.buttonGradient, fg: c.onAccent);
    case BhorButtonVariant.secondary:
      return _Look(
        fill: s.hovered ? c.surface2 : c.surface,
        fg: c.text,
        border: s.hovered ? c.accentLine : c.line,
      );
    case BhorButtonVariant.ghost:
      return _Look(fill: s.hovered ? c.surface2 : null, fg: c.accent);
    case BhorButtonVariant.danger:
      return _Look(fill: c.danger, fg: c.onDanger);
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
  bool disabledLook = false,
}) {
  final BhorColors c = context.bhor.colors;
  final _Look look = _lookOf(c, variant, states);
  final BorderRadius radius = BorderRadius.circular(BhorRadius.control);
  return AnimatedOpacity(
    opacity: disabledLook ? 0.45 : 1,
    duration: BhorMotion.fast,
    child: AnimatedContainer(
      duration: BhorMotion.fast,
      curve: BhorMotion.curve,
      height: height,
      width: width,
      constraints: BoxConstraints(minWidth: height),
      padding: padding,
      decoration: BoxDecoration(
        color: look.gradient == null ? look.fill : null,
        gradient: look.gradient,
        borderRadius: radius,
        border: look.border == null ? null : Border.all(color: look.border!),
      ),
      foregroundDecoration: states.pressed
          ? BoxDecoration(color: c.pressShade, borderRadius: radius)
          : null,
      child: Center(widthFactor: 1, child: content(look.fg)),
    ),
  );
}

/// Text button with optional leading icon; `loading` shows a spinner and
/// blocks presses; `disabledReason` explains a disabled button (tooltip on
/// hover, semantics hint).
class BhorButton extends StatelessWidget {
  const BhorButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = BhorButtonVariant.primary,
    this.size = BhorButtonSize.md,
    this.icon,
    this.loading = false,
    this.disabledReason,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final BhorButtonVariant variant;
  final BhorButtonSize size;
  final IconData? icon;
  final bool loading;
  final String? disabledReason;

  /// Fill the available width.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final bool enabled = onPressed != null && !loading;
    final double iconSize = size == BhorButtonSize.md ? 18 : 16;
    final TextStyle style = size == BhorButtonSize.md ? b.type.bodyStrong : b.type.label;
    Widget button = BhorPressable(
      onTap: enabled ? onPressed : null,
      semanticLabel: label,
      semanticHint: !enabled && !loading ? disabledReason : null,
      excludeChildSemantics: true,
      builder: (BuildContext context, BhorStates s) => _buttonBox(
        context: context,
        variant: variant,
        states: s,
        height: size.height,
        width: expand ? double.infinity : null,
        disabledLook: onPressed == null,
        padding: EdgeInsets.symmetric(horizontal: size == BhorButtonSize.md ? BhorSpace.s20 : BhorSpace.s12),
        content: (Color fg) => Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (loading) ...<Widget>[
              BhorSpinner(size: iconSize, color: fg),
              const SizedBox(width: BhorSpace.s8),
            ] else if (icon != null) ...<Widget>[
              Icon(icon, size: iconSize, color: fg),
              const SizedBox(width: BhorSpace.s8),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style.copyWith(color: fg),
              ),
            ),
          ],
        ),
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

/// Square icon-only button (44, or 36 visual inside a 44 target).
/// [semanticLabel] is required: it is the accessible name and the tooltip.
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

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final Widget button = BhorPressable(
      onTap: onPressed,
      semanticLabel: semanticLabel,
      excludeChildSemantics: true,
      builder: (BuildContext context, BhorStates s) => _buttonBox(
        context: context,
        variant: variant,
        states: s,
        height: size.height,
        width: size.height,
        disabledLook: onPressed == null,
        padding: EdgeInsets.zero,
        content: (Color fg) {
          final Color iconColor =
              color ?? (variant == BhorButtonVariant.ghost ? (s.hovered ? b.colors.text : b.colors.text2) : fg);
          final Widget glyph = Icon(icon, size: size == BhorButtonSize.md ? 22 : 18, color: iconColor);
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
                    style: b.type.caption.copyWith(color: b.colors.onDanger, height: 1.35),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
    final Widget sized = SizedBox.square(
      dimension: BhorSize.minTap,
      child: Center(child: button),
    );
    return BhorTooltip(message: semanticLabel, enabled: context.bhorIsWide, child: sized);
  }
}
