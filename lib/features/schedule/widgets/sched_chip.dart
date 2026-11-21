// Small selectable chip used by the time picker (hours, minutes, periods), the
// weekday chips and the reminder presets. At least 48dp tall; the selected
// state is a filled accent container, an accent border and bold text, so it
// never relies on colour alone.

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/theme/theme_x.dart';

class SchedChip extends StatelessWidget {
  const SchedChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.minWidth = 48,
    this.semanticLabel,
    this.leading,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double minWidth;
  final String? semanticLabel;
  final IconData? leading;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final Color fg = selected ? tokens.onAccentContainer : tokens.textPrimary;
    final BorderRadius br = BorderRadius.circular(AuroraMetrics.radiusField);
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? tokens.accentContainer : tokens.surfaceDense,
        shape: RoundedRectangleBorder(
          borderRadius: br,
          side: BorderSide(
            color: selected ? tokens.accent : tokens.textSecondary.withValues(alpha: 0.6),
            width: selected ? 2 : 1.2,
          ),
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(borderRadius: br),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: minWidth, minHeight: 48),
            child: Center(
              widthFactor: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (leading != null) ...<Widget>[
                      Icon(leading, size: 18, color: fg),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.labelLarge?.copyWith(
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
