// Providers and pure helpers of the batches feature (M6-C). Screens watch
// these; nothing here touches widgets.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/providers/async_combine.dart';
import 'package:attendance_alamin/app/providers/schedule_providers.dart';
import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/core/settings/setting_keys.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/data/repositories/people_providers.dart';
import 'package:attendance_alamin/data/repositories/settings_providers.dart';
import 'package:attendance_alamin/data/repositories/structure_providers.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/drafts.dart';
import 'package:attendance_alamin/domain/models/enrollment.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/fee_period.dart';
import 'package:attendance_alamin/domain/models/schedule.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/domain/models/subject.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/features/schedule/schedule_entry.dart';

/// All live subjects (never a destination: they only group batches).
final batchSubjectsProvider = StreamProvider<List<Subject>>(
    (ref) => ref.watch(subjectsRepositoryProvider).watchAll());

/// Live (not archived) batches.
final batchLiveBatchesProvider = StreamProvider<List<Batch>>(
    (ref) => ref.watch(batchesRepositoryProvider).watchAll());

/// Live and archived batches.
final batchEveryBatchProvider = StreamProvider<List<Batch>>((ref) =>
    ref.watch(batchesRepositoryProvider).watchAll(includeArchived: true));

final batchByIdProvider = StreamProvider.family<Batch?, String>(
    (ref, id) => ref.watch(batchesRepositoryProvider).watchById(id));

final batchFeesProvider = StreamProvider.family<List<FeePeriod>, String>(
    (ref, id) => ref.watch(batchesRepositoryProvider).watchFees(id));

final batchEnrollmentsProvider = StreamProvider.family<List<Enrollment>, String>(
    (ref, id) => ref.watch(enrollmentsRepositoryProvider).watchForBatch(id));

final batchAllStudentsProvider = StreamProvider<List<Student>>(
    (ref) => ref.watch(studentsRepositoryProvider).watchAll());

/// The billing type the teacher chose last (default for a new batch).
final batchLastBillingProvider = FutureProvider<BillingType>((ref) async {
  final String code =
      await ref.read(settingsRepositoryProvider).get(SettingKeys.lastBillingType);
  try {
    return BillingType.parse(code);
  } on FormatException {
    return BillingType.prepaid;
  }
});

/// Builds the weekly slot editor of the batch form. Defaults to M6-A's
/// `SlotEditorField`; tests override it with a lightweight stand-in.
typedef SlotEditorBuilder = Widget Function(
  BuildContext context, {
  required List<SlotDraft> initial,
  required ValueChanged<List<SlotDraft>> onChanged,
  String? batchId,
  ValueChanged<SlotCheckResult>? onCheck,
});

final batchSlotEditorBuilderProvider = Provider<SlotEditorBuilder>(
  (ref) => (
    BuildContext context, {
    required List<SlotDraft> initial,
    required ValueChanged<List<SlotDraft>> onChanged,
    String? batchId,
    ValueChanged<SlotCheckResult>? onCheck,
  }) =>
      SlotEditorField(
        initial: initial,
        onChanged: onChanged,
        batchId: batchId,
        onCheck: onCheck,
      ),
);

/// One batch with what a card needs.
class BatchCardData {
  const BatchCardData({
    required this.batch,
    required this.subjectName,
    required this.slots,
    required this.studentCount,
  });

  final Batch batch;
  final String subjectName;
  final List<Slot> slots;
  final int studentCount;
}

/// A subject header with its batches.
class SubjectGroup {
  const SubjectGroup({required this.subjectId, required this.name, required this.batches});

  final String subjectId;
  final String name;
  final List<BatchCardData> batches;
}

/// Live batches grouped by subject (subjects without a live batch are
/// dropped); batches keep their sort order.
final batchGroupsProvider = Provider<AsyncValue<List<SubjectGroup>>>((ref) {
  final today = ref.watch(todayProvider);
  final AsyncValue<(List<Subject>, List<Batch>, List<BatchSchedule>)> base = combine3(
    ref.watch(batchSubjectsProvider),
    ref.watch(batchLiveBatchesProvider),
    ref.watch(schedulesProvider),
    (List<Subject> s, List<Batch> b, List<BatchSchedule> sc) => (s, b, sc),
  );
  return combine2(
    base,
    ref.watch(allEnrollmentsProvider),
    ((List<Subject>, List<Batch>, List<BatchSchedule>) d, List<Enrollment> enrollments) {
      final subjects = d.$1;
      final batches = d.$2;
      final schedules = {for (final s in d.$3) s.batch.id: s};
      final counts = <String, int>{};
      for (final e in enrollments) {
        if (e.endDate == null) counts[e.batchId] = (counts[e.batchId] ?? 0) + 1;
      }
      final groups = <SubjectGroup>[];
      for (final subject in subjects) {
        final cards = <BatchCardData>[
          for (final b in batches)
            if (b.subjectId == subject.id)
              BatchCardData(
                batch: b,
                subjectName: subject.name,
                slots: activeSlots(schedules[b.id]?.slots ?? const <Slot>[], today),
                studentCount: counts[b.id] ?? 0,
              ),
        ];
        if (cards.isNotEmpty) {
          groups.add(SubjectGroup(subjectId: subject.id, name: subject.name, batches: cards));
        }
      }
      return groups;
    },
  );
});

/// Slots that are still in force on [today] (not ended before it).
List<Slot> activeSlots(List<Slot> slots, LocalDate today) => [
      for (final s in slots)
        if (s.validTo == null || !s.validTo!.isBefore(today)) s,
    ];

/// Weekday order of the Bangladeshi week: Saturday first.
const List<int> kWeekOrder = <int>[6, 7, 1, 2, 3, 4, 5];

/// The fee in force in [month] (latest period starting on or before it), or
/// the earliest one when the history starts later. Null when there is none.
int? feeIn(List<FeePeriod> fees, YearMonth month) {
  FeePeriod? best;
  FeePeriod? earliest;
  for (final f in fees) {
    if (earliest == null || f.effective.isBefore(earliest.effective)) earliest = f;
    if (!f.effective.isAfter(month) && (best == null || f.effective.isAfter(best.effective))) {
      best = f;
    }
  }
  return (best ?? earliest)?.amount;
}

/// Roll numbers that are numbers sort numerically first, then by name.
int compareByRoll(Student a, Student b) {
  final int? ra = int.tryParse(AppFormat.toAsciiDigits(a.roll ?? ''));
  final int? rb = int.tryParse(AppFormat.toAsciiDigits(b.roll ?? ''));
  if (ra != null && rb != null && ra != rb) return ra.compareTo(rb);
  if (ra != null && rb == null) return -1;
  if (ra == null && rb != null) return 1;
  return a.name.compareTo(b.name);
}

/// Months between an archived batch's last billable month and [current] (the
/// largest count over its enrollments that the archive ended).
int gapMonthsOnUnarchive(List<Enrollment> enrollments, YearMonth current) {
  var gap = 0;
  for (final e in enrollments) {
    final YearMonth? end = e.endMonth;
    if (e.endDate != null || end == null) continue;
    final int g = end.monthsUntil(current) - 1;
    if (g > gap) gap = g;
  }
  return gap;
}
