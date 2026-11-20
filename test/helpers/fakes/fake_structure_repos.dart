// In-memory fakes of the structure repositories for widget / controller
// tests (no drift, no timers). Streams emit the current value on listen and
// again after every write. Clash checks are off unless [FakeStructureStore.clash]
// is set: then every check returns it and every clash-checked write throws it.

import 'dart:async';

import 'package:attendance_alamin/core/ids/ids.dart';
import 'package:attendance_alamin/core/time/date_range.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/data/repositories/batches_repository.dart';
import 'package:attendance_alamin/data/repositories/schedule_repository.dart';
import 'package:attendance_alamin/data/repositories/subjects_repository.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/drafts.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/fee_period.dart';
import 'package:attendance_alamin/domain/models/schedule.dart';
import 'package:attendance_alamin/domain/models/subject.dart';
import 'package:attendance_alamin/domain/schedule/occ_id.dart';
import 'package:attendance_alamin/domain/schedule/schedule_engine.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';

/// Shared state of the three fakes (pass the same store to all of them).
class FakeStructureStore {
  FakeStructureStore({LocalDate? today})
      : today = today ?? const LocalDate(2026, 11, 20);

  /// The fake "today" (batch `createdOn`, slot edits).
  LocalDate today;

  final List<Subject> subjects = [];
  final List<Batch> batches = [];
  final List<Slot> slots = [];
  final List<ScheduleException> exceptions = [];
  final Map<String, List<FeePeriod>> fees = {};

  /// When set, checks return it and clash-checked writes throw it.
  SlotCheckResult? clash;

  /// Value returned by `previewPartialMonths` / `unarchive`.
  int partialMonths = 0;
  int unarchiveGapMonths = 0;

  final StreamController<void> _changes = StreamController<void>.broadcast(sync: true);
  int _n = 0;

  String nextId(String prefix) => '$prefix-${++_n}';

  void notify() => _changes.add(null);

  Stream<T> watch<T>(T Function() read) => Stream<T>.multi((c) {
        c.add(read());
        final sub = _changes.stream.listen((_) => c.add(read()));
        c.onCancel = sub.cancel;
      });

  void throwIfClash() {
    final c = clash;
    if (c != null && !c.ok) throw ScheduleClashException(c);
  }

  String subjectName(String subjectId) {
    for (final s in subjects) {
      if (s.id == subjectId) return s.name;
    }
    return '';
  }

  List<BatchSchedule> schedules() => [
        for (final b in batches)
          BatchSchedule(
            batch: b,
            subjectName: subjectName(b.subjectId),
            slots: [for (final s in slots) if (s.batchId == b.id) s],
            exceptions: [for (final e in exceptions) if (e.batchId == b.id) e],
          ),
      ];

  void replaceBatch(Batch b) {
    final i = batches.indexWhere((x) => x.id == b.id);
    if (i >= 0) batches[i] = b;
  }
}

class FakeSubjectsRepository implements SubjectsRepository {
  FakeSubjectsRepository([FakeStructureStore? store])
      : store = store ?? FakeStructureStore();

  final FakeStructureStore store;

  @override
  Stream<List<Subject>> watchAll() => store.watch(() => List.of(store.subjects));

  @override
  Future<Subject?> findByName(String name) async {
    final wanted = name.trim().toLowerCase();
    for (final s in store.subjects) {
      if (s.name.trim().toLowerCase() == wanted) return s;
    }
    return null;
  }

  @override
  Future<String> create({required String name, String? notes}) async {
    final id = store.nextId('sub');
    store.subjects.add(Subject(
        id: id, name: name.trim(), sortOrder: store.subjects.length, notes: notes));
    store.notify();
    return id;
  }

  @override
  Future<void> rename(String id, String name) async {
    final i = store.subjects.indexWhere((s) => s.id == id);
    if (i < 0) return;
    final s = store.subjects[i];
    store.subjects[i] = Subject(
        id: s.id, name: name.trim(), sortOrder: s.sortOrder, notes: s.notes);
    store.notify();
  }

  @override
  Future<void> softDelete(String id) async {
    store.subjects.removeWhere((s) => s.id == id);
    final gone = [for (final b in store.batches) if (b.subjectId == id) b.id];
    store.batches.removeWhere((b) => b.subjectId == id);
    store.slots.removeWhere((s) => gone.contains(s.batchId));
    store.exceptions.removeWhere((e) => gone.contains(e.batchId));
    store.notify();
  }
}

class FakeBatchesRepository implements BatchesRepository {
  FakeBatchesRepository([FakeStructureStore? store])
      : store = store ?? FakeStructureStore();

  final FakeStructureStore store;

  @override
  Stream<List<Batch>> watchAll({bool includeArchived = false}) =>
      store.watch(() => [
            for (final b in store.batches)
              if (includeArchived || !b.archived) b,
          ]);

  @override
  Stream<Batch?> watchById(String id) => store.watch(() {
        for (final b in store.batches) {
          if (b.id == id) return b;
        }
        return null;
      });

  @override
  Future<Batch?> getById(String id) async {
    for (final b in store.batches) {
      if (b.id == id) return b;
    }
    return null;
  }

  @override
  Future<String> create(BatchDraft draft) async {
    store.throwIfClash();
    final id = store.nextId('bat');
    store.batches.add(Batch(
      id: id,
      subjectId: draft.subjectId,
      name: draft.name.trim(),
      billingType: draft.billingType,
      createdOn: store.today,
      sortOrder: store.batches.length,
      reminderLeadMin: draft.reminderLeadMin,
      notes: draft.notes,
    ));
    store.fees[id] = [
      FeePeriod(effective: draft.feeFrom, amount: draft.monthlyFee),
    ];
    for (final s in draft.slots) {
      store.slots.add(Slot(
        id: store.nextId('slot'),
        batchId: id,
        weekday: s.weekday,
        startMin: s.startMin,
        endMin: s.endMin,
        validFrom: draft.slotsFrom,
      ));
    }
    store.notify();
    return id;
  }

  Future<void> _edit(String id, Batch Function(Batch b) f) async {
    final b = await getById(id);
    if (b == null) return;
    store.replaceBatch(f(b));
    store.notify();
  }

  Batch _copy(
    Batch b, {
    String? name,
    BillingType? billingType,
    int? Function()? reminderLeadMin,
    LocalDate? Function()? archivedOn,
    String? Function()? notes,
  }) =>
      Batch(
        id: b.id,
        subjectId: b.subjectId,
        name: name ?? b.name,
        billingType: billingType ?? b.billingType,
        createdOn: b.createdOn,
        sortOrder: b.sortOrder,
        reminderLeadMin:
            reminderLeadMin != null ? reminderLeadMin() : b.reminderLeadMin,
        archivedOn: archivedOn != null ? archivedOn() : b.archivedOn,
        notes: notes != null ? notes() : b.notes,
      );

  @override
  Future<void> rename(String id, String name) =>
      _edit(id, (b) => _copy(b, name: name.trim()));

  @override
  Future<void> setBillingType(String id, BillingType t) =>
      _edit(id, (b) => _copy(b, billingType: t));

  @override
  Future<void> setReminderLead(String id, int? minutes) =>
      _edit(id, (b) => _copy(b, reminderLeadMin: () => minutes));

  @override
  Future<void> setNotes(String id, String? notes) =>
      _edit(id, (b) => _copy(b, notes: () => notes));

  @override
  Stream<List<FeePeriod>> watchFees(String batchId) => store.watch(() {
        final list = List.of(store.fees[batchId] ?? const <FeePeriod>[]);
        list.sort((a, b) => a.effective.compareTo(b.effective));
        return list;
      });

  @override
  Future<int> previewPartialMonths(
          String batchId, int amount, YearMonth from) async =>
      store.partialMonths;

  @override
  Future<void> setFee(String batchId, int amount, YearMonth from) async {
    final list = store.fees[batchId] ??= [];
    list.removeWhere((f) => f.effective == from);
    list.add(FeePeriod(effective: from, amount: amount));
    store.notify();
  }

  @override
  Future<void> archive(String id,
          {required LocalDate on, required YearMonth lastBillableMonth}) =>
      _edit(id, (b) => _copy(b, archivedOn: () => on));

  @override
  Future<SlotCheckResult> previewUnarchive(String id) async =>
      store.clash ?? const SlotCheckResult();

  @override
  Future<int> unarchive(String id,
      {bool acceptClashes = false, bool waiveGap = true}) async {
    if (!acceptClashes) store.throwIfClash();
    await _edit(id, (b) => _copy(b, archivedOn: () => null));
    return store.unarchiveGapMonths;
  }

  @override
  Future<DeleteImpact> deleteImpact(String id) async =>
      const DeleteImpact(sessions: 0, payments: 0, students: 0);

  @override
  Future<void> softDelete(String id) async {
    store.batches.removeWhere((b) => b.id == id);
    store.slots.removeWhere((s) => s.batchId == id);
    store.exceptions.removeWhere((e) => e.batchId == id);
    store.fees.remove(id);
    store.notify();
  }
}

class FakeScheduleRepository implements ScheduleRepository {
  FakeScheduleRepository([FakeStructureStore? store])
      : store = store ?? FakeStructureStore();

  final FakeStructureStore store;

  @override
  Stream<List<BatchSchedule>> watchAllSchedules() =>
      store.watch(store.schedules);

  @override
  Future<SlotCheckResult> checkSlots(String? batchId, List<SlotDraft> slots,
          {required LocalDate from}) async =>
      store.clash ?? const SlotCheckResult();

  @override
  Future<void> replaceSlots(String batchId, List<SlotDraft> slots,
      {required LocalDate from}) async {
    store.throwIfClash();
    store.slots.removeWhere((s) => s.batchId == batchId);
    for (final s in slots) {
      store.slots.add(Slot(
        id: s.id ?? store.nextId('slot'),
        batchId: batchId,
        weekday: s.weekday,
        startMin: s.startMin,
        endMin: s.endMin,
        validFrom: from,
      ));
    }
    store.notify();
  }

  @override
  Future<SlotCheckResult> checkSingle({
    required String batchId,
    required LocalDate date,
    required int startMin,
    required int endMin,
    String? replacingOcc,
  }) async =>
      store.clash ?? const SlotCheckResult();

  @override
  Future<String> addExtra({
    required String batchId,
    required LocalDate date,
    required int startMin,
    required int endMin,
    String? note,
  }) async {
    store.throwIfClash();
    final id = store.nextId('exc');
    store.exceptions.add(ScheduleException(
      id: id,
      batchId: batchId,
      kind: ExceptionKind.extra,
      newDate: date,
      newStartMin: startMin,
      newEndMin: endMin,
      note: note,
    ));
    store.notify();
    return OccId.extra(id);
  }

  void _put(ScheduleException e) {
    store.exceptions.removeWhere((x) => x.id == e.id);
    store.exceptions.add(e);
    store.notify();
  }

  (Slot, LocalDate)? _regular(String occ) {
    final OccRef ref;
    try {
      ref = OccId.parse(occ);
    } on FormatException {
      return null;
    }
    if (ref is! RegularOccRef) return null;
    for (final s in store.slots) {
      if (s.id == ref.slotId) return (s, ref.originalDate);
    }
    return null;
  }

  @override
  Future<void> reschedule(String occ,
      {required LocalDate newDate,
      required int startMin,
      required int endMin}) async {
    store.throwIfClash();
    final reg = _regular(occ);
    if (reg == null) {
      final ref = OccId.parse(occ);
      if (ref is ExtraOccRef) {
        final i = store.exceptions.indexWhere((e) => e.id == ref.exceptionId);
        if (i < 0) return;
        final e = store.exceptions[i];
        _put(ScheduleException(
          id: e.id,
          batchId: e.batchId,
          kind: ExceptionKind.extra,
          newDate: newDate,
          newStartMin: startMin,
          newEndMin: endMin,
          note: e.note,
        ));
      }
      return;
    }
    final (slot, od) = reg;
    _put(ScheduleException(
      id: Ids.exceptionForOcc(occ),
      batchId: slot.batchId,
      kind: ExceptionKind.reschedule,
      slotId: slot.id,
      originalDate: od,
      newDate: newDate,
      newStartMin: startMin,
      newEndMin: endMin,
    ));
  }

  @override
  Future<void> cancel(String occ, {String? note}) async {
    final reg = _regular(occ);
    if (reg == null) {
      await deleteExtra(occ);
      return;
    }
    final (slot, od) = reg;
    _put(ScheduleException(
      id: Ids.exceptionForOcc(occ),
      batchId: slot.batchId,
      kind: ExceptionKind.cancel,
      slotId: slot.id,
      originalDate: od,
      note: note,
    ));
  }

  @override
  Future<void> restore(String occ) async {
    store.throwIfClash();
    store.exceptions.removeWhere((e) => e.id == Ids.exceptionForOcc(occ));
    store.notify();
  }

  @override
  Future<void> deleteExtra(String occ) async {
    final ref = OccId.parse(occ);
    if (ref is! ExtraOccRef) return;
    store.exceptions.removeWhere((e) => e.id == ref.exceptionId);
    store.notify();
  }

  @override
  Future<OccurrenceInfo?> resolve(String occ) async {
    final OccRef ref;
    try {
      ref = OccId.parse(occ);
    } on FormatException {
      return null;
    }
    for (final bs in store.schedules()) {
      switch (ref) {
        case RegularOccRef(:final slotId, :final originalDate):
          for (final s in bs.slots) {
            if (s.id != slotId) continue;
            final cancelled = bs.exceptions.any((e) =>
                e.id == Ids.exceptionForOcc(occ) &&
                e.kind == ExceptionKind.cancel);
            return OccurrenceInfo(
              batch: bs.batch,
              subjectName: bs.subjectName,
              cancelled: cancelled,
              occurrence: Occurrence(
                occ: occ,
                batchId: bs.batch.id,
                date: originalDate,
                startMin: s.startMin,
                endMin: s.endMin,
                kind: OccurrenceKind.regular,
                slotId: s.id,
              ),
            );
          }
        case ExtraOccRef(:final exceptionId):
          for (final e in bs.exceptions) {
            if (e.id != exceptionId) continue;
            return OccurrenceInfo(
              batch: bs.batch,
              subjectName: bs.subjectName,
              occurrence: Occurrence(
                occ: occ,
                batchId: bs.batch.id,
                date: e.newDate!,
                startMin: e.newStartMin!,
                endMin: e.newEndMin!,
                kind: OccurrenceKind.extra,
                exceptionId: e.id,
              ),
            );
          }
      }
    }
    return null;
  }

  @override
  Future<int> cancelRange(DateRange range, {String? note}) async {
    final res =
        ScheduleEngine.expand(range: range, batches: store.schedules());
    var n = 0;
    for (final o in res.occurrences) {
      final slotId = o.slotId;
      if (slotId == null) continue;
      _put(ScheduleException(
        id: Ids.exceptionForOcc(o.occ),
        batchId: o.batchId,
        kind: ExceptionKind.cancel,
        slotId: slotId,
        originalDate: o.originalDate ?? o.date,
        note: note,
      ));
      n++;
    }
    return n;
  }

  @override
  Future<int> undoCancelRange(DateRange range) async {
    final before = store.exceptions.length;
    store.exceptions.removeWhere((e) =>
        e.kind == ExceptionKind.cancel &&
        e.originalDate != null &&
        range.contains(e.originalDate!));
    store.notify();
    return before - store.exceptions.length;
  }
}
