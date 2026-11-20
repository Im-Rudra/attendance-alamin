// The single saturated surface (Today, onboarding): heroBase with a violet
// radial top-left and a teal radial bottom-right, near-white pill CTA.

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/theme/theme_x.dart';

class HeroCard extends StatelessWidget {
  const HeroCard({super.key, required this.child, this.cta});

  final Widget child;

  /// Usually a [HeroPillButton].
  final Widget? cta;

  @override
  Widget build(BuildContext context) {
    final g = context.gradients;
    final BorderRadius br = BorderRadius.circular(AuroraMetrics.radiusHero);
    final TextTheme tt = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: br,
        boxShadow: <BoxShadow>[
          BoxShadow(color: g.heroShadow, blurRadius: 32, offset: const Offset(0, 12)),
        ],
      ),
      child: ClipRRect(
        borderRadius: br,
        child: Stack(
          children: <Widget>[
            Positioned.fill(child: ColoredBox(color: g.heroBase)),
            for (final RadialGradient r in g.heroRadials)
              Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: r))),
            Positioned(
              left: 24,
              right: 24,
              top: 0,
              height: 1,
              child: ColoredBox(color: g.heroTopHighlight),
            ),
            DefaultTextStyle.merge(
              style: tt.bodyLarge?.copyWith(color: g.heroText),
              child: IconTheme.merge(
                data: IconThemeData(color: g.heroText),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      child,
                      if (cta != null) ...<Widget>[
                        const SizedBox(height: 16),
                        cta!,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Near-white pill on the hero card. 52dp tall.
class HeroPillButton extends StatelessWidget {
  const HeroPillButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final g = context.gradients;
    final TextTheme tt = Theme.of(context).textTheme;
    final bool enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: enabled ? g.heroCtaFill : g.heroCtaFill.withValues(alpha: 0.5),
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AuroraMetrics.buttonHeight, minWidth: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Center(
                widthFactor: 1,
                child: Text(label, style: tt.labelLarge?.copyWith(color: g.heroCtaText)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
