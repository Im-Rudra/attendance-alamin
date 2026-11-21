// Seven weekday rows with the class times of each (batch schedule tab and the
// slot editor's preview card). A day without class says so, so the card never
// looks half empty.

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
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
    final BhorThemeData b = context.bhor;
    final List<int> order = <int>[
      for (var i = 0; i < 7; i++) ((weekStart - 1 + i) % 7) + 1,
    ];
    return BhorCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          BhorSectionHeader(title: title ?? l10n.schedPreviewTitle),
          for (var i = 0; i < order.length; i++) ...<Widget>[
            if (i > 0) ColoredBox(color: b.colors.line, child: const SizedBox(height: 1)),
            _DayRow(
              dayName: fmt.weekdayName(order[i]),
              ranges: <String>[
                for (final SlotDraft s in (slots.where((SlotDraft s) => s.weekday == order[i]).toList()
                  ..sort((SlotDraft a, SlotDraft b) => a.startMin.compareTo(b.startMin))))
                  fmt.timeRange(s.startMin, s.endMin),
              ],
              emptyText: l10n.schedNoClass,
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
  });

  final String dayName;
  final List<String> ranges;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    return MergeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: BhorSpace.s8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                width: 112,
                child: Text(
                  dayName,
                  style: b.type.bodyStrong.copyWith(color: ranges.isEmpty ? b.colors.text2 : b.colors.text),
                ),
              ),
              Expanded(
                child: ranges.isEmpty
                    ? Text(emptyText, style: b.type.body.copyWith(color: b.colors.text2))
                    : Wrap(
                        spacing: BhorSpace.s8,
                        runSpacing: 6,
                        children: <Widget>[
                          for (final String r in ranges)
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: b.colors.accentTint,
                                borderRadius: BorderRadius.circular(BhorRadius.chip),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                child: Text(
                                  r,
                                  style: BhorType.tabular(b.type.label.copyWith(color: b.colors.accent)),
                                ),
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
