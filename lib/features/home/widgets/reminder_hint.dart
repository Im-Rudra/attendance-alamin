// Hint strip: class reminders are only planned for fewer than three more days
// (the app plans a rolling window and renews it whenever it is opened).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/features/home/controllers/today_providers.dart';

class ReminderHint extends ConsumerWidget {
  const ReminderHint({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int? days = ref.watch(todayReminderHintProvider).value;
    if (days == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final tokens = context.aurora;
    final String text = days == 0
        ? l10n.todayRemindersHintZero
        : l10n.todayRemindersHint(context.fmt.number(days));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.infoContainer,
          borderRadius: BorderRadius.circular(AuroraMetrics.radiusDenseList),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: <Widget>[
              Icon(Icons.notifications_active_outlined, size: 22, color: tokens.info),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: tokens.info),
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
