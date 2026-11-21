// Hint strip: class reminders are only planned for fewer than three more days
// (the app plans a rolling window and renews it whenever it is opened).

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/features/home/controllers/today_providers.dart';

class ReminderHint extends ConsumerWidget {
  const ReminderHint({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int? days = ref.watch(todayReminderHintProvider).value;
    if (days == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final BhorThemeData b = context.bhor;
    final String text = days == 0
        ? l10n.todayRemindersHintZero
        : l10n.todayRemindersHint(context.fmt.number(days));
    return Padding(
      padding: const EdgeInsets.only(bottom: BhorSpace.s12),
      child: Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: b.colors.accentTint,
          borderRadius: BorderRadius.circular(BhorRadius.card),
          border: Border.all(color: b.colors.accentLine),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s12, vertical: BhorSpace.s12),
          child: Row(
            children: <Widget>[
              Icon(Icons.notifications_active_outlined, size: 22, color: b.colors.accent),
              const SizedBox(width: BhorSpace.s12),
              Expanded(
                child: Text(
                  text,
                  style: b.type.body.copyWith(color: b.colors.accent),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
