// Segmented choice (payment method, billing type, Fees segments): a pill track
// with one selected segment. Selected = accentContainer + check icon + bold, so
// it never relies on colour alone. Every segment is at least 48dp tall.

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/theme/theme_x.dart';

class SegmentedChoice<T> extends StatelessWidget {
  const SegmentedChoice({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    required this.labelOf,
  });

  final List<T> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final String Function(T option) labelOf;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.track,
        borderRadius: BorderRadius.circular(AuroraMetrics.radiusPill),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: <Widget>[
            for (final T o in options)
              Expanded(
                child: _Segment(
                  label: labelOf(o),
                  selected: o == selected,
                  onTap: () => onChanged(o),
                  textStyle: tt.labelLarge,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.textStyle,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final Color fg = selected ? tokens.onAccentContainer : tokens.textPrimary;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? tokens.surfaceSolid : tokens.track.withValues(alpha: 0),
        shape: StadiumBorder(
          side: BorderSide(color: selected ? tokens.accent : tokens.track.withValues(alpha: 0)),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (selected) ...<Widget>[
                      Icon(Icons.check, size: 18, color: fg),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textStyle?.copyWith(
                          color: fg,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
