// Frosted card (UX 4: glass vs dense). At most 3 `blur: true` cards per screen;
// cards inside scrollables stay blur-free (translucent `glassNoBlur`); dense
// content (lists, forms, tables) uses `dense: true` -> `surfaceDense`.

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/effects_mode.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.dense = false,
    this.blur = false,
    this.onTap,
    this.radius = 20,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Opaque-ish `surfaceDense` fill for lists, forms and tables. Never blurs.
  final bool dense;

  /// Real backdrop blur (sigma 18). Ignored in reduced-effects mode and when
  /// [dense]. Spend at most 3 per screen.
  final bool blur;

  final VoidCallback? onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final bool reduced = EffectsMode.reducedOf(context);
    final bool useBlur = blur && !reduced && !dense;
    final Color fill;
    if (dense) {
      fill = tokens.surfaceDense;
    } else if (reduced) {
      fill = tokens.surfaceSolid.withValues(alpha: 0.92);
    } else if (useBlur) {
      fill = tokens.glass;
    } else {
      fill = tokens.glassNoBlur;
    }
    final BorderRadius br = BorderRadius.circular(radius);

    Widget body = Padding(padding: padding, child: child);
    if (onTap != null) {
      body = ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(onTap: onTap, borderRadius: br, child: body),
        ),
      );
    }

    Widget card = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: br,
        border: Border.all(color: tokens.hairline),
      ),
      child: Stack(
        children: <Widget>[
          body,
          if (!dense)
            Positioned(
              left: radius * 0.6,
              right: radius * 0.6,
              top: 0,
              height: 1,
              child: IgnorePointer(child: ColoredBox(color: tokens.topHighlight)),
            ),
        ],
      ),
    );

    if (useBlur) {
      card = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: AuroraMetrics.blurGlass, sigmaY: AuroraMetrics.blurGlass),
        child: card,
      );
    }
    return ClipRRect(borderRadius: br, child: card);
  }
}
