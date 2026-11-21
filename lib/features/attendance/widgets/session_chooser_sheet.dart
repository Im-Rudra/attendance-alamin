// "কোন ক্লাসের হাজিরা?" (UX 2b): a day with 2+ classes of one batch shows one
// big time card per class; the first class without a roll call is highlighted.

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/domain/attendance_stats/attendance_stats.dart';
import 'package:attendance_alamin/features/attendance/controllers/roll_models.dart';

/// Returns the chosen occurrence id, or null when dismissed.
Future<String?> showSessionChooserSheet(
  BuildContext context, {
  required LocalDate date,
  required List<SessionChoice> choices,
}) {
  return showBhorSheet<String>(
    context,
    builder: (BuildContext ctx) => SessionChooserSheet(date: date, choices: choices),
  );
}

/// The sheet body (public so the screen matrix can render it directly).
class SessionChooserSheet extends StatelessWidget {
  const SessionChooserSheet({super.key, required this.date, required this.choices});

  final LocalDate date;
  final List<SessionChoice> choices;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final BhorThemeData b = context.bhor;
    final String? highlight = defaultChoice(choices)?.occ;
    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(l10n.rollChooserTitle, style: b.type.title),
          ),
          const SizedBox(height: BhorSpace.s4),
          Text(fmt.weekdayDate(date), style: b.type.meta),
          const SizedBox(height: BhorSpace.s12),
          for (final SessionChoice c in choices) ...<Widget>[
            _ChoiceCard(choice: c, highlighted: c.occ == highlight),
            const SizedBox(height: BhorSpace.s8),
          ],
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({required this.choice, required this.highlighted});

  final SessionChoice choice;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final AttendanceTally? tally = choice.tally;
    final String state;
    final IconData icon;
    if (choice.cancelled) {
      state = l10n.rollChooserCancelled;
      icon = Icons.block;
    } else if (choice.taken) {
      state = l10n.rollChooserTaken;
      icon = Icons.check_circle_outline;
    } else {
      state = l10n.rollChooserPending;
      icon = Icons.radio_button_unchecked;
    }
    final String? count = (choice.taken && tally != null)
        ? l10n.rollChooserCount(fmt.number(tally.present + tally.late), fmt.number(tally.held))
        : null;
    final String time = fmt.timeRange(choice.startMin, choice.endMin);
    final String countPart = count == null ? '' : ', $count';
    return BhorPressable(
      onTap: () => Navigator.of(context).pop(choice.occ),
      selected: highlighted,
      semanticLabel: '$time, $state$countPart',
      excludeChildSemantics: true,
      radius: BhorRadius.card,
      builder: (BuildContext context, BhorStates s) => Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s16, vertical: BhorSpace.s12),
        decoration: BoxDecoration(
          color: highlighted ? c.accentTint : (s.hovered ? c.surface2 : c.surface),
          borderRadius: BorderRadius.circular(BhorRadius.card),
          border: Border.all(color: highlighted ? c.accent : c.line, width: highlighted ? 2 : 1),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                time,
                style: b.type.heading.copyWith(color: highlighted ? c.accent : c.text),
              ),
            ),
            const SizedBox(width: BhorSpace.s8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(icon, size: 18, color: c.text2),
                      const SizedBox(width: BhorSpace.s4),
                      Flexible(child: Text(state, style: b.type.label)),
                    ],
                  ),
                  if (count != null) Text(count, style: b.type.meta),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
