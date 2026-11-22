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
  const FeesSegments({super.key, required this.selected, required this.onChanged, this.trailing});

  final FeesSegment selected;
  final ValueChanged<FeesSegment> onChanged;

  /// Grouped right next to the segments on wide windows (the month stepper).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final WindowClass wc = WindowClass.of(context);
    final double g = wc.gutter;
    final Widget segmented = BhorSegmented<FeesSegment>(
      segments: <BhorSegment<FeesSegment>>[
        BhorSegment<FeesSegment>(FeesSegment.dues, l10n.duesSegDues),
        BhorSegment<FeesSegment>(FeesSegment.collection, l10n.duesSegCollection),
      ],
      value: selected,
      onChanged: (FeesSegment s) {
        if (s != selected) onChanged(s);
      },
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(g, BhorSpace.s4, g, BhorSpace.s8),
      child: wc.isWide
          ? Row(
              children: <Widget>[
                SizedBox(width: 360, child: segmented),
                if (trailing != null) ...<Widget>[const SizedBox(width: BhorSpace.s16), trailing!],
              ],
            )
          : segmented,
    );
  }
}

/// "‹ নভেম্বর ২০২৬ ›": steps one month at a time. Compact: the chevrons sit
/// right beside the month name (a grouped control, not spread to the edges).
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
    final BhorThemeData b = context.bhor;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: 1,
      heightFactor: 1,
      child: DecoratedBox(
      decoration: BoxDecoration(
        color: b.colors.soft,
        borderRadius: BorderRadius.circular(BhorRadius.control),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          BhorIconButton(
            icon: BhorIcons.chevronLeft,
            semanticLabel: l10n.collPrevMonth,
            onPressed: canPrev ? () => onChanged(month.addMonths(-1)) : null,
          ),
          Semantics(
            header: true,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 132),
              child: Text(
                context.fmt.monthYear(month),
                textAlign: TextAlign.center,
                maxLines: 1,
                style: b.type.heading,
              ),
            ),
          ),
          BhorIconButton(
            icon: BhorIcons.chevronRight,
            semanticLabel: l10n.collNextMonth,
            onPressed: canNext ? () => onChanged(month.addMonths(1)) : null,
          ),
        ],
      ),
      ),
    );
  }
}
