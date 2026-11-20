// "কোন ক্লাসের হাজিরা?" (UX 2b): a day with 2+ classes of one batch shows one
// big time card per class; the first class without a roll call is highlighted.

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/domain/attendance_stats/attendance_stats.dart';
import 'package:attendance_alamin/features/attendance/controllers/roll_models.dart';

/// Returns the chosen occurrence id, or null when dismissed.
Future<String?> showSessionChooserSheet(
  BuildContext context, {
  required LocalDate date,
  required List<SessionChoice> choices,
}) {
  return showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 560),
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
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final String? highlight = defaultChoice(choices)?.occ;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(l10n.rollChooserTitle, style: tt.titleLarge?.copyWith(color: tokens.textPrimary)),
          ),
          const SizedBox(height: 4),
          Text(fmt.weekdayDate(date), style: tt.bodyMedium?.copyWith(color: tokens.textSecondary)),
          const SizedBox(height: 12),
          for (final SessionChoice c in choices) ...<Widget>[
            _ChoiceCard(choice: c, highlighted: c.occ == highlight),
            const SizedBox(height: 8),
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
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
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
    return Semantics(
      container: true,
      button: true,
      selected: highlighted,
      label: '$time, $state${count == null ? '' : ', $count'}',
      excludeSemantics: true,
      onTap: () => Navigator.of(context).pop(choice.occ),
      child: Material(
        color: highlighted ? tokens.accentContainer : tokens.surfaceDense,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AuroraMetrics.radiusDenseList),
          side: BorderSide(color: highlighted ? tokens.accent : tokens.hairline, width: highlighted ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).pop(choice.occ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      time,
                      style: tt.titleMedium?.copyWith(
                        color: highlighted ? tokens.onAccentContainer : tokens.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(icon, size: 18, color: tokens.textSecondary),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                state,
                                style: tt.labelLarge?.copyWith(color: tokens.textPrimary),
                              ),
                            ),
                          ],
                        ),
                        if (count != null)
                          Text(count, style: tt.labelMedium?.copyWith(color: tokens.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
