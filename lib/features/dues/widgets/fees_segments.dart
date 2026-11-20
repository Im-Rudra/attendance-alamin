// The two segments of the Fees tab (UX 1: বকেয়া · আদায়) and the month picker
// row shared by the collection screen and the batch fees tab.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/core/time/year_month.dart';

enum FeesSegment { dues, collection }

/// Dues | Collected switch. Both screens are routes of the same tab, so a tap
/// navigates (nothing happens without a router, e.g. in widget tests).
class FeesSegments extends StatelessWidget {
  const FeesSegments({super.key, required this.selected});

  final FeesSegment selected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final double g = WindowClass.of(context).gutter;
    return Padding(
      padding: EdgeInsets.fromLTRB(g, 4, g, 8),
      child: SegmentedChoice<FeesSegment>(
        options: FeesSegment.values,
        selected: selected,
        labelOf: (FeesSegment s) =>
            s == FeesSegment.dues ? l10n.duesSegDues : l10n.duesSegCollection,
        onChanged: (FeesSegment s) {
          if (s == selected) return;
          GoRouter.maybeOf(context)
              ?.go(s == FeesSegment.dues ? Routes.fees : Routes.feesCollection);
        },
      ),
    );
  }
}

/// "‹ নভেম্বর ২০২৬ ›": steps one month at a time.
class MonthPickerRow extends StatelessWidget {
  const MonthPickerRow({
    super.key,
    required this.month,
    required this.canPrev,
    required this.canNext,
    required this.onChanged,
  });

  final YearMonth month;
  final bool canPrev;
  final bool canNext;
  final ValueChanged<YearMonth> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.aurora;
    return Row(
      children: <Widget>[
        IconButton(
          tooltip: l10n.collPrevMonth,
          icon: const Icon(Icons.chevron_left),
          onPressed: canPrev ? () => onChanged(month.addMonths(-1)) : null,
        ),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              context.fmt.monthYear(month),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: tokens.textPrimary),
            ),
          ),
        ),
        IconButton(
          tooltip: l10n.collNextMonth,
          icon: const Icon(Icons.chevron_right),
          onPressed: canNext ? () => onChanged(month.addMonths(1)) : null,
        ),
      ],
    );
  }
}
