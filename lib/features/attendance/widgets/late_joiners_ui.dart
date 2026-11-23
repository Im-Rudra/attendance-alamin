// The quiet footer line of a past roll call ("3 students joined after this
// date. Show") and the list it opens. Read-only for now: marking a late joiner
// needs the join date moved first (see late_joiners.dart).

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/features/attendance/controllers/late_joiners.dart';

class LateJoinersFooter extends StatelessWidget {
  const LateJoinersFooter({super.key, required this.count, required this.onShow});

  final int count;

  /// Gets the context of the "Show" button (anchor of the list).
  final ValueChanged<BuildContext> onShow;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: BhorSpace.s12),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: BhorSpace.s8,
        runSpacing: BhorSpace.s4,
        children: <Widget>[
          Text(
            l10n.rollLateLine(context.fmt.number(count)),
            style: b.type.meta.copyWith(color: b.colors.text2),
          ),
          Builder(
            builder: (BuildContext bc) => BhorButton(
              label: l10n.rollLateShow,
              size: BhorButtonSize.sm,
              variant: BhorButtonVariant.ghost,
              onPressed: () => onShow(bc),
            ),
          ),
        ],
      ),
    );
  }
}

/// Who joined after [date], with their join dates, and what to do about it.
class LateJoinersList extends StatelessWidget {
  const LateJoinersList({super.key, required this.joiners, required this.date});

  final List<LateJoiner> joiners;
  final LocalDate date;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final l10n = context.l10n;
    final fmt = context.fmt;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          l10n.rollLateNote(fmt.date(date)),
          style: b.type.meta.copyWith(color: b.colors.text2),
        ),
        const SizedBox(height: BhorSpace.s8),
        for (final LateJoiner j in joiners)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: BhorSpace.s8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: Text(j.student.name, style: b.type.body)),
                const SizedBox(width: BhorSpace.s12),
                Text(l10n.rollLateJoined(fmt.date(j.joinDate)), style: b.type.meta),
              ],
            ),
          ),
      ],
    );
  }
}
