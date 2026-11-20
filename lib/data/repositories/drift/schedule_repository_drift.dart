import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/errors/error_codes.dart';
import 'package:attendance_alamin/core/ids/ids.dart';
import 'package:attendance_alamin/core/time/center_time.dart';
import 'package:attendance_alamin/core/time/date_range.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/data/db/app_database.dart';
import 'package:attendance_alamin/data/db/db_queries.dart';
import 'package:attendance_alamin/data/db/mappers.dart';
import 'package:attendance_alamin/data/db/sync_stamper.dart';
import 'package:attendance_alamin/data/repositories/drift/slot_replace_plan.dart';
import 'package:attendance_alamin/data/repositories/drift/structure_store.dart';
import 'package:attendance_alamin/data/repositories/schedule_repository.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/drafts.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/schedule.dart';
import 'package:attendance_alamin/domain/schedule/occ_id.dart';
import 'package:attendance_alamin/domain/schedule/schedule_engine.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';
import 'package:drift/drift.dart' hide Batch;

/// Placeholder occurrence id of a class that does not exist yet.
const String _pendingOcc = 'x.pending';

/// Where an occurrence id points to (live rows only).
class _Located {
  const _Located({
    required this.bs,
    required this.occ,
    this.slot,
    this.originalDate,
    this.exception,
    required this.exceptionId,
    required this.isExtra,
  });

  final BatchSchedule bs;
  final String occ;

  /// Regular classes only.
  final Slot? slot;
  final LocalDate? originalDate;

  /// The live exception of this occurrence, if any.
  final ScheduleException? exception;
  final String exceptionId;
  final bool isExtra;
}

class DriftScheduleRepository implements ScheduleRepository {
  DriftScheduleRepository(
    this._db,
    this._stamper, {
    CenterTime center = CenterTime.dhaka,
  }) : _store = StructureStore(_db, _stamper, center);

  final AppDatabase _db;
  final SyncStamper _stamper;
  final StructureStore _store;

  // ------------------------------------------------------------ reads

  @override
  Stream<List<BatchSchedule>> watchAllSchedules() =>
      _db.watchComposite(scheduleTables(_db), _store.loadSchedules);

  @override
  Future<OccurrenceInfo?> resolve(String occ) async {
    final all = await _store.loadSchedules();
    final loc = _locate(occ, all);
    if (loc == null) return null;
    final bs = loc.bs;
    final ex = loc.exception;

    if (loc.isExtra) {
      final nd = ex?.newDate;
      final ns = ex?.newStartMin;
      final ne = ex?.newEndMin;
      if (ex == null || nd == null || ns == null || ne == null) return null;
      return OccurrenceInfo(
        batch: bs.batch,
        subjectName: bs.subjectName,
        occurrence: Occurrence(
          occ: occ,
          batchId: bs.batch.id,
          date: nd,
          startMin: ns,
          endMin: ne,
          kind: OccurrenceKind.extra,
          exceptionId: ex.id,
        ),
      );
    }

    final slot = loc.slot!;
    final od = loc.originalDate!;
    if (!_regularExists(slot, od, bs.batch)) {
      return OccurrenceInfo(batch: bs.batch, subjectName: bs.subjectName);
    }
    final regular = Occurrence(
      occ: occ,
      batchId: bs.batch.id,
      date: od,
      startMin: slot.startMin,
      endMin: slot.endMin,
      kind: OccurrenceKind.regular,
      slotId: slot.id,
    );
    if (ex == null) {
      return OccurrenceInfo(
          batch: bs.batch, subjectName: bs.subjectName, occurrence: regular);
    }
    if (ex.kind == ExceptionKind.cancel) {
      return OccurrenceInfo(
        batch: bs.batch,
        subjectName: bs.subjectName,
        occurrence: regular,
        cancelled: true,
      );
    }
    final nd = ex.newDate;
    final ns = ex.newStartMin;
    final ne = ex.newEndMin;
    if (nd == null || ns == null || ne == null) {
      return OccurrenceInfo(
          batch: bs.batch, subjectName: bs.subjectName, occurrence: regular);
    }
    return OccurrenceInfo(
      batch: bs.batch,
      subjectName: bs.subjectName,
      occurrence: Occurrence(
        occ: occ,
        batchId: bs.batch.id,
        date: nd,
        startMin: ns,
        endMin: ne,
        kind: OccurrenceKind.rescheduled,
        slotId: slot.id,
        exceptionId: ex.id,
        originalDate: od,
        originalStartMin: slot.startMin,
        originalEndMin: slot.endMin,
      ),
    );
  }

  // ------------------------------------------------------------ slot checks

  @override
  Future<SlotCheckResult> checkSlots(String? batchId, List<SlotDraft> slots,
      {required LocalDate from}) async {
    StructureStore.checkSlotDrafts(slots);
    final all = await _store.loadSchedules();
    final today = _store.today();
    final window = await _store.dayWindow();

    if (batchId == null) {
      final proposed = BatchSchedule(
        batch: Batch(
          id: '',
          subjectId: '',
          name: '',
          billingType: BillingType.prepaid,
          createdOn: today,
          sortOrder: 0,
        ),
        subjectName: '',
        slots: [
          for (var i = 0; i < slots.length; i++)
            Slot(
              id: 'new.$i',
              batchId: '',
              weekday: slots[i].weekday,
              startMin: slots[i].startMin,
              endMin: slots[i].endMin,
              validFrom: from,
            ),
        ],
      );
      return ScheduleEngine.checkSlotEdit(
        proposed: proposed,
        others: all,
        from: from,
        today: today,
        dayStartMin: window.start,
        dayEndMin: window.end,
      );
    }

    final current = _batchOrThrow(all, batchId);
    var n = 0;
    final plan = planSlotReplace(
      batchId: batchId,
      currentSlots: current.slots,
      currentExceptions: current.exceptions,
      drafts: slots,
      from: from,
      newSlotId: () => 'new.${n++}',
    );
    return _checkPlan(current, plan, all, from, today, window);
  }

  SlotCheckResult _checkPlan(
    BatchSchedule current,
    SlotPlan plan,
    List<BatchSchedule> all,
    LocalDate from,
    LocalDate today,
    ({int start, int end}) window,
  ) {
    return ScheduleEngine.checkSlotEdit(
      proposed: BatchSchedule(
        batch: current.batch,
        subjectName: current.subjectName,
        slots: plan.slotsAfter,
        exceptions: plan.exceptionsAfter,
      ),
      others: all,
      from: from,
      today: today,
      onlySlotIds: plan.focusSlotIds,
      dayStartMin: window.start,
      dayEndMin: window.end,
    );
  }

  @override
  Future<void> replaceSlots(String batchId, List<SlotDraft> slots,
      {required LocalDate from}) async {
    StructureStore.checkSlotDrafts(slots);
    await _db.transaction(() async {
      await _store.requireLiveBatch(batchId);
      final all = await _store.loadSchedules();
      final current = _batchOrThrow(all, batchId);
      final plan = planSlotReplace(
        batchId: batchId,
        currentSlots: current.slots,
        currentExceptions: current.exceptions,
        drafts: slots,
        from: from,
        newSlotId: Ids.v4,
      );
      final result = _checkPlan(
          current, plan, all, from, _store.today(), await _store.dayWindow());
      if (!result.ok) throw ScheduleClashException(result);

      for (final op in plan.ops) {
        switch (op) {
          case InsertSlotOp(:final slot):
            await _store.insertSlot(slot);
          case UpdateSlotOp(:final slot):
            await _store.updateSlotContent(slot);
          case CloseSlotOp(:final slotId, :final validTo):
            await _store.closeSlot(slotId, validTo);
          case TombstoneSlotOp(:final slotId):
            await _store.tombstoneSlot(slotId);
          case PutExceptionOp(:final exception):
            await _store.putException(exception);
          case TombstoneExceptionOp(:final exceptionId):
            await _store.tombstoneException(exceptionId);
        }
      }
    });
  }

  // ------------------------------------------------------------ single checks

  @override
  Future<SlotCheckResult> checkSingle({
    required String batchId,
    required LocalDate date,
    required int startMin,
    required int endMin,
    String? replacingOcc,
  }) async {
    StructureStore.checkTimes(startMin, endMin);
    final all = await _store.loadSchedules();
    _batchOrThrow(all, batchId);
    final replacing = replacingOcc;
    final candidate = Occurrence(
      occ: replacing ?? _pendingOcc,
      batchId: batchId,
      date: date,
      startMin: startMin,
      endMin: endMin,
      kind: replacing == null
          ? OccurrenceKind.extra
          : (replacing.startsWith('x.')
              ? OccurrenceKind.extra
              : OccurrenceKind.rescheduled),
    );
    return _checkCandidate(all, candidate, replacing);
  }

  Future<SlotCheckResult> _checkCandidate(
      List<BatchSchedule> all, Occurrence candidate, String? excludeOcc) async {
    final window = await _store.dayWindow();
    return ScheduleEngine.checkSingle(
      candidate: candidate,
      all: all,
      excludeOcc: excludeOcc,
      dayStartMin: window.start,
      dayEndMin: window.end,
    );
  }

  Future<void> _requireNoClash(
      List<BatchSchedule> all, Occurrence candidate, String? excludeOcc) async {
    final result = await _checkCandidate(all, candidate, excludeOcc);
    if (!result.ok) throw ScheduleClashException(result);
  }

  // ------------------------------------------------------------ extras

  @override
  Future<String> addExtra({
    required String batchId,
    required LocalDate date,
    required int startMin,
    required int endMin,
    String? note,
  }) async {
    StructureStore.checkTimes(startMin, endMin);
    return _db.transaction(() async {
      await _store.requireLiveBatch(batchId);
      final all = await _store.loadSchedules();
      final id = Ids.v4();
      final occ = OccId.extra(id);
      await _requireNoClash(
        all,
        Occurrence(
          occ: occ,
          batchId: batchId,
          date: date,
          startMin: startMin,
          endMin: endMin,
          kind: OccurrenceKind.extra,
          exceptionId: id,
        ),
        null,
      );
      await _store.putException(ScheduleException(
        id: id,
        batchId: batchId,
        kind: ExceptionKind.extra,
        newDate: date,
        newStartMin: startMin,
        newEndMin: endMin,
        note: StructureStore.cleanNote(note),
      ));
      return occ;
    });
  }

  @override
  Future<void> deleteExtra(String occ) async {
    await _db.transaction(() async {
      final loc = _locate(occ, await _store.loadSchedules());
      if (loc == null || !loc.isExtra) {
        throw NotFoundException(ErrorCodes.notFound, detail: occ);
      }
      await _store.tombstoneException(loc.exceptionId);
    });
  }

  // ------------------------------------------------------------ cancel / move

  @override
  Future<void> cancel(String occ, {String? note}) async {
    await _db.transaction(() async {
      final loc = _locate(occ, await _store.loadSchedules());
      if (loc == null) {
        throw NotFoundException(ErrorCodes.notFound, detail: occ);
      }
      _requireLive(loc.bs);
      if (loc.isExtra) {
        await _store.tombstoneException(loc.exceptionId);
        return;
      }
      final slot = loc.slot!;
      final od = loc.originalDate!;
      if (!_regularExists(slot, od, loc.bs.batch)) {
        throw NotFoundException(ErrorCodes.notFound, detail: occ);
      }
      await _store.putException(ScheduleException(
        id: loc.exceptionId,
        batchId: loc.bs.batch.id,
        kind: ExceptionKind.cancel,
        slotId: slot.id,
        originalDate: od,
        note: StructureStore.cleanNote(note),
      ));
    });
  }

  @override
  Future<void> reschedule(String occ,
      {required LocalDate newDate,
      required int startMin,
      required int endMin}) async {
    StructureStore.checkTimes(startMin, endMin);
    await _db.transaction(() async {
      final all = await _store.loadSchedules();
      final loc = _locate(occ, all);
      if (loc == null) {
        throw NotFoundException(ErrorCodes.notFound, detail: occ);
      }
      _requireLive(loc.bs);
      final batchId = loc.bs.batch.id;

      if (loc.isExtra) {
        await _requireNoClash(
          all,
          Occurrence(
            occ: occ,
            batchId: batchId,
            date: newDate,
            startMin: startMin,
            endMin: endMin,
            kind: OccurrenceKind.extra,
            exceptionId: loc.exceptionId,
          ),
          occ,
        );
        await _store.putException(ScheduleException(
          id: loc.exceptionId,
          batchId: batchId,
          kind: ExceptionKind.extra,
          newDate: newDate,
          newStartMin: startMin,
          newEndMin: endMin,
          note: loc.exception?.note,
        ));
        return;
      }

      final slot = loc.slot!;
      final od = loc.originalDate!;
      if (!_regularExists(slot, od, loc.bs.batch)) {
        throw NotFoundException(ErrorCodes.notFound, detail: occ);
      }
      final backToOriginal = newDate == od &&
          startMin == slot.startMin &&
          endMin == slot.endMin;
      await _requireNoClash(
        all,
        Occurrence(
          occ: occ,
          batchId: batchId,
          date: newDate,
          startMin: startMin,
          endMin: endMin,
          kind: backToOriginal
              ? OccurrenceKind.regular
              : OccurrenceKind.rescheduled,
          slotId: slot.id,
        ),
        occ,
      );
      if (backToOriginal) {
        await _store.tombstoneException(loc.exceptionId);
        return;
      }
      final existing = loc.exception;
      await _store.putException(ScheduleException(
        id: loc.exceptionId,
        batchId: batchId,
        kind: ExceptionKind.reschedule,
        slotId: slot.id,
        originalDate: od,
        newDate: newDate,
        newStartMin: startMin,
        newEndMin: endMin,
        note: existing?.kind == ExceptionKind.reschedule ? existing?.note : null,
      ));
    });
  }

  @override
  Future<void> restore(String occ) async {
    await _db.transaction(() async {
      final all = await _store.loadSchedules();
      final loc = _locate(occ, all);

      if (loc == null) {
        // A removed extra class comes back (undo of delete / cancel).
        OccRef? ref;
        try {
          ref = OccId.parse(occ);
        } on FormatException {
          ref = null;
        }
        if (ref is! ExtraOccRef) {
          throw NotFoundException(ErrorCodes.notFound, detail: occ);
        }
        final row = await _store.exceptionRowAnyState(ref.exceptionId);
        if (row == null || row.kind != ExceptionKind.extra.name) {
          throw NotFoundException(ErrorCodes.notFound, detail: occ);
        }
        final ex = exceptionFromRow(row);
        final bs = _batchOrThrow(all, ex.batchId);
        _requireLive(bs);
        await _requireNoClash(
          all,
          Occurrence(
            occ: occ,
            batchId: ex.batchId,
            date: ex.newDate!,
            startMin: ex.newStartMin!,
            endMin: ex.newEndMin!,
            kind: OccurrenceKind.extra,
            exceptionId: ex.id,
          ),
          null,
        );
        await _store.putException(ex);
        return;
      }

      _requireLive(loc.bs);
      if (loc.isExtra || loc.exception == null) return;
      final slot = loc.slot!;
      final od = loc.originalDate!;
      if (!_regularExists(slot, od, loc.bs.batch)) {
        throw NotFoundException(ErrorCodes.notFound, detail: occ);
      }
      await _requireNoClash(all, _regularOccurrence(loc.bs, slot, od), occ);
      await _store.tombstoneException(loc.exceptionId);
    });
  }

  // ------------------------------------------------------------ ranges

  @override
  Future<int> cancelRange(DateRange range, {String? note}) {
    return _db.transaction(() async {
      final all = await _store.loadSchedules();
      final expanded = ScheduleEngine.expand(range: range, batches: all);
      final cleanNote = StructureStore.cleanNote(note);
      var count = 0;
      for (final o in expanded.occurrences) {
        final slotId = o.slotId;
        if (o.kind == OccurrenceKind.extra || slotId == null) continue;
        await _store.putException(ScheduleException(
          id: Ids.exceptionForOcc(o.occ),
          batchId: o.batchId,
          kind: ExceptionKind.cancel,
          slotId: slotId,
          originalDate: o.originalDate ?? o.date,
          note: cleanNote,
        ));
        count++;
      }
      return count;
    });
  }

  @override
  Future<int> undoCancelRange(DateRange range) {
    return _db.transaction(() async {
      final all = await _store.loadSchedules();
      final toRestore = <(String, Occurrence)>[];
      for (final bs in all) {
        if (bs.batch.archived) continue;
        final slotsById = {for (final s in bs.slots) s.id: s};
        for (final ex in bs.exceptions) {
          if (ex.kind != ExceptionKind.cancel) continue;
          final od = ex.originalDate;
          final slot = slotsById[ex.slotId];
          if (od == null || slot == null || !range.contains(od)) continue;
          if (!_regularExists(slot, od, bs.batch)) continue;
          toRestore.add((ex.id, _regularOccurrence(bs, slot, od)));
        }
      }
      for (final (_, candidate) in toRestore) {
        await _requireNoClash(all, candidate, candidate.occ);
      }
      for (final (exceptionId, _) in toRestore) {
        await _store.tombstoneException(exceptionId);
      }
      return toRestore.length;
    });
  }

  // ------------------------------------------------------------ helpers

  static bool _regularExists(Slot s, LocalDate d, Batch b) =>
      s.weekday == d.isoWeekday && s.activeOn(d) && !d.isBefore(b.createdOn);

  static Occurrence _regularOccurrence(
          BatchSchedule bs, Slot slot, LocalDate date) =>
      Occurrence(
        occ: OccId.regular(slot.id, date),
        batchId: bs.batch.id,
        date: date,
        startMin: slot.startMin,
        endMin: slot.endMin,
        kind: OccurrenceKind.regular,
        slotId: slot.id,
      );

  static void _requireLive(BatchSchedule bs) {
    if (bs.batch.archived) {
      throw const ValidationException(ErrorCodes.batchArchived);
    }
  }

  static BatchSchedule _batchOrThrow(List<BatchSchedule> all, String id) {
    for (final b in all) {
      if (b.batch.id == id) return b;
    }
    throw NotFoundException(ErrorCodes.notFound, detail: 'batch $id');
  }

  /// Finds the live slot / exception an occurrence id points to; `null` when
  /// the id is malformed or its slot / extra is not live.
  static _Located? _locate(String occ, List<BatchSchedule> all) {
    final OccRef ref;
    try {
      ref = OccId.parse(occ);
    } on FormatException {
      return null;
    }
    switch (ref) {
      case RegularOccRef(:final slotId, :final originalDate):
        final exceptionId = Ids.exceptionForOcc(occ);
        for (final bs in all) {
          for (final slot in bs.slots) {
            if (slot.id != slotId) continue;
            ScheduleException? ex;
            for (final e in bs.exceptions) {
              if (e.id == exceptionId) ex = e;
            }
            return _Located(
              bs: bs,
              occ: occ,
              slot: slot,
              originalDate: originalDate,
              exception: ex,
              exceptionId: exceptionId,
              isExtra: false,
            );
          }
        }
        return null;
      case ExtraOccRef(:final exceptionId):
        for (final bs in all) {
          for (final e in bs.exceptions) {
            if (e.id == exceptionId && e.kind == ExceptionKind.extra) {
              return _Located(
                bs: bs,
                occ: occ,
                exception: e,
                exceptionId: exceptionId,
                isExtra: true,
              );
            }
          }
        }
        return null;
    }
  }
}
