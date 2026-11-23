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
import 'package:attendance_alamin/data/repositories/local_meta_repository.dart';
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
import 'package:attendance_alamin/features/settings/settings_entry.dart';

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

/// The place the last new batch / tuition was made at on this device.
final batchLastPlaceProvider = StreamProvider<String?>(
    (ref) => ref.watch(localMetaRepositoryProvider).watchRaw(LocalMetaKeys.lastPlace));

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

/// What the batch form starts from.
class BatchFormSeed {
  const BatchFormSeed({
    required this.billing,
    required this.batchCount,
    this.batch,
    this.notFound = false,
    this.subjectName = '',
    this.fee,
  });

  /// The edited batch; null when creating (or [notFound]).
  final Batch? batch;
  final bool notFound;
  final BillingType billing;

  /// Live batches today (names the new one "ব্যাচ N+1").
  final int batchCount;
  final String subjectName;
  final int? fee;
}

/// The form's starting data: last billing type and batch count to create,
/// the batch with its subject and current fee to edit.
final batchFormSeedProvider =
    Provider.family<AsyncValue<BatchFormSeed>, String?>((ref, batchId) {
  if (batchId == null) {
    return combine2(
      ref.watch(batchLastBillingProvider),
      ref.watch(batchLiveBatchesProvider),
      (BillingType last, List<Batch> live) =>
          BatchFormSeed(billing: last, batchCount: live.length),
    );
  }
  final month = ref.watch(todayProvider).yearMonth;
  return combine3(
    ref.watch(batchByIdProvider(batchId)),
    ref.watch(batchSubjectsProvider),
    ref.watch(batchFeesProvider(batchId)),
    (Batch? b, List<Subject> subjects, List<FeePeriod> fees) {
      if (b == null) {
        return const BatchFormSeed(
            billing: BillingType.prepaid, batchCount: 0, notFound: true);
      }
      var subjectName = '';
      for (final s in subjects) {
        if (s.id == b.subjectId) subjectName = s.name;
      }
      return BatchFormSeed(
        billing: b.billingType,
        batchCount: 0,
        batch: b,
        subjectName: subjectName,
        fee: feeIn(fees, month),
      );
    },
  );
});

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

/// A subject header with its batches, or ([tuitions]) the "Private tuitions"
/// group after the subjects.
class SubjectGroup {
  const SubjectGroup({
    required this.subjectId,
    required this.name,
    required this.batches,
    this.tuitions = false,
  });

  /// The subject, or [kTuitionGroupId] for the private tuitions.
  final String subjectId;

  /// The subject's name; empty for the tuitions group (the UI names it).
  final String name;
  final List<BatchCardData> batches;
  final bool tuitions;
}

/// Group id of the "Private tuitions" group (never a subject id).
const String kTuitionGroupId = '_tuitions';

/// Live batches grouped by subject (subjects without a live batch are
/// dropped), then the private tuitions (any subject) as one last group;
/// batches keep their sort order. Only the batches of the place filter when
/// one is picked (2+ places).
final batchGroupsProvider = Provider<AsyncValue<List<SubjectGroup>>>((ref) {
  final today = ref.watch(todayProvider);
  final String? place = ref.watch(placeFilterProvider);
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
      final batches = <Batch>[
        for (final Batch b in d.$2)
          if (place == null || b.placeId == place) b,
      ];
      final schedules = {for (final s in d.$3) s.batch.id: s};
      final counts = <String, int>{};
      for (final e in enrollments) {
        if (e.endDate == null) counts[e.batchId] = (counts[e.batchId] ?? 0) + 1;
      }
      final groups = <SubjectGroup>[];
      for (final subject in subjects) {
        final cards = <BatchCardData>[
          for (final b in batches)
            if (!b.isTuition && b.subjectId == subject.id)
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
      final subjectName = {for (final s in subjects) s.id: s.name};
      final tuitions = <BatchCardData>[
        for (final b in batches)
          if (b.isTuition)
            BatchCardData(
              batch: b,
              // The hidden "no subject" row is not among the subjects: ''.
              subjectName: subjectName[b.subjectId] ?? '',
              slots: activeSlots(schedules[b.id]?.slots ?? const <Slot>[], today),
              studentCount: counts[b.id] ?? 0,
            ),
      ];
      if (tuitions.isNotEmpty) {
        groups.add(SubjectGroup(subjectId: kTuitionGroupId, name: '', batches: tuitions, tuitions: true));
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
