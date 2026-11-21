// Three mini previews of the app (system = half light, half dark): the tiles
// themselves are the theme selector (selected = accent ring + a check badge
// that springs in), so the teacher sees each theme before choosing it.

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';

class ThemeSwatches extends StatelessWidget {
  const ThemeSwatches({
    super.key,
    required this.selected,
    required this.onChanged,
    this.labelOf,
  });

  final ThemeMode selected;
  final ValueChanged<ThemeMode> onChanged;

  /// Name shown under each tile (also its accessibility label).
  final String Function(ThemeMode mode)? labelOf;

  @override
  Widget build(BuildContext context) {
    // A 3-up grid with a 12 px gap; each tile is at most 120 x 72.
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 3 * 120 + 2 * 12),
        child: _row(),
      ),
    );
  }

  Widget _row() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final ThemeMode m in const <ThemeMode>[
          ThemeMode.system,
          ThemeMode.light,
          ThemeMode.dark,
        ]) ...<Widget>[
          if (m != ThemeMode.system) const SizedBox(width: 12),
          Expanded(
            child: _Swatch(
              mode: m,
              selected: m == selected,
              label: labelOf?.call(m),
              onTap: () => onChanged(m),
            ),
          ),
        ],
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.mode, required this.selected, required this.label, required this.onTap});

  final ThemeMode mode;
  final bool selected;
  final String? label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
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
    return BhorPressable(
      key: ValueKey<String>('theme-swatch-${mode.name}'),
      onTap: onTap,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      semanticLabel: label,
      excludeChildSemantics: label != null,
      radius: BhorRadius.control,
      builder: (BuildContext context, BhorStates s) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AspectRatio(
            aspectRatio: 120 / 72,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                AnimatedContainer(
                  duration: BhorMotion.fast,
                  curve: BhorMotion.ease,
                  decoration: BoxDecoration(
                    borderRadius: br,
                    border: Border.all(
                      color: selected ? c.accent : (s.hovered ? c.accentLine : c.line),
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(BhorRadius.control - 1),
                    child: face,
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: AnimatedScale(
                    scale: selected ? 1 : 0,
                    duration: BhorMotion.base,
                    curve: BhorMotion.spring,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: c.accentFill, shape: BoxShape.circle),
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: Icon(BhorIcons.check, size: 14, color: c.onAccentFill),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (label != null) ...<Widget>[
            const SizedBox(height: 6),
            AnimatedDefaultTextStyle(
              duration: BhorMotion.fast,
              textAlign: TextAlign.center,
              style: (selected ? b.type.bodyStrong : b.type.body).copyWith(color: selected ? c.accent : c.text2),
              child: Text(label!, textAlign: TextAlign.center),
            ),
          ],
        ],
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
