// Three mini previews of the app (system = half light, half dark) so the
// teacher sees what each theme looks like before choosing. Decorative: the
// segmented control next to it is the control and carries the semantics.

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';

class ThemeSwatches extends StatelessWidget {
  const ThemeSwatches({super.key, required this.selected, required this.onChanged});

  final ThemeMode selected;
  final ValueChanged<ThemeMode> onChanged;

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
            Expanded(child: _Swatch(mode: m, selected: m == selected, onTap: () => onChanged(m))),
          ],
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.mode, required this.selected, required this.onTap});

  final ThemeMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final BhorColors c = context.bhor.colors;
    final BorderRadius br = BorderRadius.circular(BhorRadius.control);
    final Widget face = switch (mode) {
      ThemeMode.light => _Face(
          bg: BhorColors.light.bg,
          card: BhorColors.light.surface,
          accent: BhorColors.light.accent,
          line: BhorColors.light.text2,
        ),
      ThemeMode.dark => _Face(
          bg: BhorColors.dark.bg,
          card: BhorColors.dark.surface,
          accent: BhorColors.dark.accent,
          line: BhorColors.dark.text2,
        ),
      ThemeMode.system => Row(
          children: <Widget>[
            Expanded(
              child: _Face(
                bg: BhorColors.light.bg,
                card: BhorColors.light.surface,
                accent: BhorColors.light.accent,
                line: BhorColors.light.text2,
              ),
            ),
            Expanded(
              child: _Face(
                bg: BhorColors.dark.bg,
                card: BhorColors.dark.surface,
                accent: BhorColors.dark.accent,
                line: BhorColors.dark.text2,
              ),
            ),
          ],
        ),
    };
    return AspectRatio(
      aspectRatio: 1.6,
      child: BhorPressable(
        key: ValueKey<String>('theme-swatch-${mode.name}'),
        onTap: onTap,
        isButton: false,
        radius: BhorRadius.control,
        builder: (BuildContext context, BhorStates s) => DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: br,
            border: Border.all(
              color: selected ? c.accent : c.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: ClipRRect(borderRadius: BorderRadius.circular(BhorRadius.control - 1), child: face),
        ),
      ),
    );
  }
}

class _Face extends StatelessWidget {
  _Face({required this.bg, required this.card, required this.accent, required this.line});

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
