// Stat tile: label + big number (+ caption, + footer). Glass without blur so it
// is safe inside scrolling bento grids.

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/glass_card.dart';
import 'package:attendance_alamin/app/widgets/money_text.dart';

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.footer,
  });

  final String label;

  /// Already formatted (money, percent, count) with `context.fmt`.
  final String value;
  final String? caption;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final String? cap = caption;
    return GlassCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            container: true,
            label: context.l10n.a11yLabelValue(label, cap == null ? value : '$value, $cap'),
            excludeSemantics: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: tt.labelMedium?.copyWith(color: tokens.textSecondary)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: MoneyText(value, maxLines: 1, style: context.statNumber),
                ),
                if (cap != null)
                  Text(cap, style: tt.labelMedium?.copyWith(color: tokens.textSecondary)),
              ],
            ),
          ),
          if (footer != null) ...<Widget>[const SizedBox(height: 12), footer!],
        ],
      ),
    );
  }
}
