// The two segments of the Fees tab (UX 1: বকেয়া · আদায়) and the month picker
// row shared by the collection screen and the batch fees tab.

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/core/time/year_month.dart';

enum FeesSegment { dues, collection }

/// Dues | Collected switch. The Fees page swaps its body in place.
class FeesSegments extends StatelessWidget {
  const FeesSegments({super.key, required this.selected, required this.onChanged});

  final FeesSegment selected;
  final ValueChanged<FeesSegment> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final double g = WindowClass.of(context).gutter;
    return Padding(
      padding: EdgeInsets.fromLTRB(g, BhorSpace.s4, g, BhorSpace.s8),
      child: BhorSegmented<FeesSegment>(
        segments: <BhorSegment<FeesSegment>>[
          BhorSegment<FeesSegment>(FeesSegment.dues, l10n.duesSegDues),
          BhorSegment<FeesSegment>(FeesSegment.collection, l10n.duesSegCollection),
        ],
        value: selected,
        onChanged: (FeesSegment s) {
          if (s != selected) onChanged(s);
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
    return Row(
      children: <Widget>[
        BhorIconButton(
          icon: BhorIcons.chevronLeft,
          semanticLabel: l10n.collPrevMonth,
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
              style: context.bhor.type.heading,
            ),
          ),
        ),
        BhorIconButton(
          icon: BhorIcons.chevronRight,
          semanticLabel: l10n.collNextMonth,
          onPressed: canNext ? () => onChanged(month.addMonths(1)) : null,
        ),
      ],
    );
  }
}
