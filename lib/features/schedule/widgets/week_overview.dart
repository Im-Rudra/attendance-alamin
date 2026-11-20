// Seven weekday rows with the class times of each (batch schedule tab and the
// slot editor's preview card). A day without class says so, so the card never
// looks half empty.

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/domain/models/drafts.dart';

class WeekOverview extends StatelessWidget {
  const WeekOverview({
    super.key,
    required this.slots,
    required this.weekStart,
    this.title,
  });

  final List<SlotDraft> slots;
  final int weekStart;

  /// Defaults to "সপ্তাহের চিত্র".
  final String? title;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final List<int> order = <int>[
      for (var i = 0; i < 7; i++) ((weekStart - 1 + i) % 7) + 1,
    ];
    return GlassCard(
      dense: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SectionHeader(title: title ?? l10n.schedPreviewTitle),
          for (var i = 0; i < order.length; i++) ...<Widget>[
            if (i > 0) Divider(height: 1, color: tokens.hairline),
            _DayRow(
              dayName: fmt.weekdayName(order[i]),
              ranges: <String>[
                for (final SlotDraft s in (slots.where((SlotDraft s) => s.weekday == order[i]).toList()
                  ..sort((SlotDraft a, SlotDraft b) => a.startMin.compareTo(b.startMin))))
                  fmt.timeRange(s.startMin, s.endMin),
              ],
              emptyText: l10n.schedNoClass,
              tt: tt,
            ),
          ],
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.dayName,
    required this.ranges,
    required this.emptyText,
    required this.tt,
  });

  final String dayName;
  final List<String> ranges;
  final String emptyText;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    return MergeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                width: 112,
                child: Text(
                  dayName,
                  style: tt.titleSmall?.copyWith(
                    color: ranges.isEmpty ? tokens.textSecondary : tokens.textPrimary,
                  ),
                ),
              ),
              Expanded(
                child: ranges.isEmpty
                    ? Text(emptyText,
                        style: tt.bodyMedium?.copyWith(color: tokens.textSecondary))
                    : Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: <Widget>[
                          for (final String r in ranges)
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: tokens.accentContainer,
                                borderRadius:
                                    BorderRadius.circular(AuroraMetrics.radiusChip),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                child: Text(r,
                                    style: tt.labelLarge
                                        ?.copyWith(color: tokens.onAccentContainer)),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
