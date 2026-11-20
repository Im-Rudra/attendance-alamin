// Providers and pure helpers behind the batch schedule tab and the slot editor
// screen. The data itself comes from the M5 providers (`schedulesProvider`,
// `todayProvider`, `weekStartProvider`).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/core/settings/setting_keys.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/data/repositories/settings_providers.dart';
import 'package:attendance_alamin/domain/models/drafts.dart';
import 'package:attendance_alamin/domain/models/schedule.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';

/// Global class-reminder switch (Settings).
final classRemindersOnProvider = StreamProvider<bool>((ref) =>
    ref.watch(settingsRepositoryProvider).watch(SettingKeys.remindersEnabled));

/// Settings default lead in minutes (1..180).
final defaultReminderLeadProvider = StreamProvider<int>((ref) =>
    ref.watch(settingsRepositoryProvider).watch(SettingKeys.defaultReminderLead));

/// The slots a schedule edit starts from: the open-ended version of the
/// weekly schedule (what is, or will be, in force); when every slot has an end
/// date, the ones still in force today.
List<SlotDraft> currentSlotDrafts(BatchSchedule schedule, LocalDate today) {
  final List<Slot> open = <Slot>[
    for (final Slot s in schedule.slots)
      if (s.validTo == null) s,
  ];
  final List<Slot> pick = open.isNotEmpty
      ? open
      : <Slot>[
          for (final Slot s in schedule.slots)
            if (s.activeOn(today)) s,
        ];
  final List<SlotDraft> drafts = <SlotDraft>[
    for (final Slot s in pick)
      SlotDraft(
        id: s.id,
        weekday: s.weekday,
        startMin: s.startMin,
        endMin: s.endMin,
      ),
  ]..sort((SlotDraft a, SlotDraft b) {
      final int c = a.weekday.compareTo(b.weekday);
      return c != 0 ? c : a.startMin.compareTo(b.startMin);
    });
  return drafts;
}
