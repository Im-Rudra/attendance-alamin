// Labelled horizontal bars (QA-09): "students per batch" style distribution
// that fills an overview pane with something useful. Pure presentation.

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/glass_card.dart';

class BarEntry {
  const BarEntry({required this.label, required this.value, required this.valueText, this.onTap});

  final String label;

  /// Drives the bar length (relative to the largest entry).
  final int value;

  /// Already formatted number shown at the end of the row.
  final String valueText;
  final VoidCallback? onTap;
}

class BarListCard extends StatelessWidget {
  const BarListCard({super.key, required this.entries, this.emptyText});

  final List<BarEntry> entries;
  final String? emptyText;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final int maxValue = entries.fold<int>(1, (int m, BarEntry e) => e.value > m ? e.value : m);
    if (entries.isEmpty) {
      return GlassCard(
        dense: true,
        child: Text(emptyText ?? '', style: tt.bodyMedium?.copyWith(color: tokens.textSecondary)),
      );
    }
    return GlassCard(
      dense: true,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: <Widget>[
          for (final BarEntry e in entries)
            InkWell(
              onTap: e.onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              e.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.bodyLarge?.copyWith(color: tokens.textPrimary),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            e.valueText,
                            style: tt.titleSmall?.copyWith(color: tokens.textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          height: 6,
                          child: Stack(
                            children: <Widget>[
                              Positioned.fill(child: ColoredBox(color: tokens.track)),
                              FractionallySizedBox(
                                alignment: AlignmentDirectional.centerStart,
                                widthFactor: e.value <= 0 ? 0 : e.value / maxValue,
                                child: ColoredBox(color: tokens.accent),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
