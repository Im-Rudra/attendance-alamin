// Three mini previews of the app (system = half light, half dark) so the
// teacher sees what each theme looks like before choosing. Decorative: the
// SegmentedChoice next to it is the control and carries the semantics.

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/theme/tokens.dart';

class ThemeSwatches extends StatelessWidget {
  const ThemeSwatches({super.key, required this.selected});

  final ThemeMode selected;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Row(
        children: <Widget>[
          for (final ThemeMode m in const <ThemeMode>[
            ThemeMode.system,
            ThemeMode.light,
            ThemeMode.dark,
          ]) ...<Widget>[
            if (m != ThemeMode.system) const SizedBox(width: 10),
            Expanded(child: _Swatch(mode: m, selected: m == selected)),
          ],
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.mode, required this.selected});

  final ThemeMode mode;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final BorderRadius br = BorderRadius.circular(AuroraMetrics.radiusField);
    final Widget face = switch (mode) {
      ThemeMode.light => const _Face(
          bg: LightTokens.bg,
          card: LightTokens.surfaceSolid,
          accent: LightTokens.accent,
          line: LightTokens.textSecondary,
        ),
      ThemeMode.dark => const _Face(
          bg: DuskTokens.bg,
          card: DuskTokens.surfaceSolid,
          accent: DuskTokens.accent,
          line: DuskTokens.textSecondary,
        ),
      ThemeMode.system => const Row(
          children: <Widget>[
            Expanded(
              child: _Face(
                bg: LightTokens.bg,
                card: LightTokens.surfaceSolid,
                accent: LightTokens.accent,
                line: LightTokens.textSecondary,
              ),
            ),
            Expanded(
              child: _Face(
                bg: DuskTokens.bg,
                card: DuskTokens.surfaceSolid,
                accent: DuskTokens.accent,
                line: DuskTokens.textSecondary,
              ),
            ),
          ],
        ),
    };
    return AspectRatio(
      aspectRatio: 1.6,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: br,
          border: Border.all(
            color: selected ? tokens.accent : tokens.hairline,
            width: selected ? 2 : 1,
          ),
        ),
        child: ClipRRect(borderRadius: BorderRadius.circular(AuroraMetrics.radiusField - 1), child: face),
      ),
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({required this.bg, required this.card, required this.accent, required this.line});

  final Color bg;
  final Color card;
  final Color accent;
  final Color line;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: bg,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: DecoratedBox(
          decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(6)),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  height: 6,
                  width: 22,
                  decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(3)),
                ),
                const SizedBox(height: 5),
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: line.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  height: 4,
                  width: 30,
                  decoration: BoxDecoration(
                    color: line.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
