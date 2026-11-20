import 'dart:convert';

import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/errors/error_codes.dart';
import 'package:attendance_alamin/core/ids/ids.dart';
import 'package:attendance_alamin/core/settings/setting_keys.dart';
import 'package:attendance_alamin/core/time/center_time.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/core/validation/validators.dart';
import 'package:attendance_alamin/data/db/app_database.dart';
import 'package:attendance_alamin/data/db/mappers.dart';
import 'package:attendance_alamin/data/db/sync_stamper.dart';
import 'package:attendance_alamin/data/repositories/batches_repository.dart';
import 'package:attendance_alamin/data/repositories/drift/structure_store.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/drafts.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/fee_period.dart';
import 'package:attendance_alamin/domain/models/schedule.dart';
import 'package:attendance_alamin/domain/schedule/schedule_engine.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';
import 'package:drift/drift.dart' hide Batch;

/// Tombstones a batch and everything that belongs to it: attendance
/// (records, sessions), payments, enrollments with their fee overrides, slots,
/// exceptions and fee history. Call inside a transaction.
Future<void> cascadeDeleteBatch(StructureStore s, String batchId) async {
  final db = s.db;
  final enrollmentIds = [
    for (final e in await (db.select(db.enrollments)
          ..where((t) => t.batchId.equals(batchId) & t.deletedAt.isNull()))
        .get())
      e.id,
  ];
  await s.tombstoneWhere(db.enrollmentFees, 'enrollment_id', enrollmentIds);
  await s.tombstoneWhere(db.attendanceRecords, 'batch_id', [batchId]);
  await s.tombstoneWhere(db.attendanceSessions, 'batch_id', [batchId]);
  await s.tombstoneWhere(db.payments, 'batch_id', [batchId]);
  await s.tombstoneWhere(db.enrollments, 'batch_id', [batchId]);
  await s.tombstoneWhere(db.scheduleExceptions, 'batch_id', [batchId]);
  await s.tombstoneWhere(db.batchSlots, 'batch_id', [batchId]);
  await s.tombstoneWhere(db.batchFees, 'batch_id', [batchId]);
  final row = await (db.select(db.batches)
        ..where((t) => t.id.equals(batchId) & t.deletedAt.isNull()))
      .getSingleOrNull();
  if (row == null) return;
  final ts = s.stamper.nextUpdatedAt(row.updatedAt);
  await (db.update(db.batches)..where((t) => t.id.equals(batchId))).write(
    BatchesCompanion(
      deletedAt: Value(ts),
      updatedAt: Value(ts),
      rev: Value(s.stamper.nextRev(row.rev)),
      deviceId: Value(s.stamper.deviceId),
    ),
  );
}

class DriftBatchesRepository implements BatchesRepository {
  DriftBatchesRepository(
    this._db,
    this._stamper, {
    CenterTime center = CenterTime.dhaka,
  })  : _center = center,
        _store = StructureStore(_db, _stamper, center);

  final AppDatabase _db;
  final SyncStamper _stamper;
  final CenterTime _center;
  final StructureStore _store;

  // ------------------------------------------------------------ reads

  @override
  Stream<List<Batch>> watchAll({bool includeArchived = false}) {
    final q = _db.select(_db.batches)
      ..where((t) => includeArchived
          ? t.deletedAt.isNull()
          : t.deletedAt.isNull() & t.archivedAt.isNull())
      ..orderBy([
        (t) => OrderingTerm.asc(t.sortOrder),
        (t) => OrderingTerm.asc(t.name),
        (t) => OrderingTerm.asc(t.id),
      ]);
    return q
        .watch()
        .map((rows) => [for (final r in rows) batchFromRow(r, _center)]);
  }

  @override
  Stream<Batch?> watchById(String id) {
    final q = _db.select(_db.batches)
      ..where((t) => t.id.equals(id) & t.deletedAt.isNull());
    return q
        .watchSingleOrNull()
        .map((r) => r == null ? null : batchFromRow(r, _center));
  }

  @override
  Future<Batch?> getById(String id) async {
    final r = await (_db.select(_db.batches)
          ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
        .getSingleOrNull();
    return r == null ? null : batchFromRow(r, _center);
  }

  @override
  Stream<List<FeePeriod>> watchFees(String batchId) {
    final q = _db.select(_db.batchFees)
      ..where((t) => t.batchId.equals(batchId) & t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.asc(t.effectiveMonth)]);
    return q.watch().map((rows) => [for (final r in rows) feeFromRow(r)]);
  }

  // ------------------------------------------------------------ create

  @override
  Future<String> create(BatchDraft draft) async {
    final name = Validators.name(draft.name);
    StructureStore.checkAmount(draft.monthlyFee);
    _checkLead(draft.reminderLeadMin);
    StructureStore.checkSlotDrafts(draft.slots);
    final notes = StructureStore.cleanNote(draft.notes);

    return _db.transaction(() async {
      final subject = await (_db.select(_db.subjects)
            ..where(
                (t) => t.id.equals(draft.subjectId) & t.deletedAt.isNull()))
          .getSingleOrNull();
      if (subject == null) {
        throw NotFoundException(ErrorCodes.notFound,
            detail: 'subject ${draft.subjectId}');
      }

      final id = Ids.v4();
      final today = _store.today();
      final slots = [
        for (final d in draft.slots)
          Slot(
            id: Ids.v4(),
            batchId: id,
            weekday: d.weekday,
            startMin: d.startMin,
            endMin: d.endMin,
            validFrom: draft.slotsFrom,
          ),
      ];

      final sortRow = await (_db.select(_db.batches)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.desc(t.sortOrder)])
            ..limit(1))
          .getSingleOrNull();
      final sortOrder = sortRow == null ? 0 : sortRow.sortOrder + 1;

      final proposed = BatchSchedule(
        batch: Batch(
          id: id,
          subjectId: draft.subjectId,
          name: name,
          billingType: draft.billingType,
          createdOn: today,
          sortOrder: sortOrder,
        ),
        subjectName: subject.name,
        slots: slots,
      );
      final window = await _store.dayWindow();
      final result = ScheduleEngine.checkSlotEdit(
        proposed: proposed,
        others: await _store.loadSchedules(),
        from: draft.slotsFrom,
        today: today,
        dayStartMin: window.start,
        dayEndMin: window.end,
      );
      if (!result.ok) throw ScheduleClashException(result);

      final now = _stamper.nowMs();
      await _db.into(_db.batches).insert(BatchesCompanion(
            id: Value(id),
            subjectId: Value(draft.subjectId),
            name: Value(name),
            billingType: Value(draft.billingType.name),
            reminderLeadMin: Value(draft.reminderLeadMin),
            sortOrder: Value(sortOrder),
            notes: Value(notes),
            createdAt: Value(now),
            updatedAt: Value(now),
            deviceId: Value(_stamper.deviceId),
            rev: const Value(1),
          ));
      await _putFee(id, draft.monthlyFee, draft.feeFrom);
      for (final s in slots) {
        await _store.insertSlot(s);
      }
      await _db.into(_db.localMeta).insertOnConflictUpdate(LocalMetaCompanion(
            metaKey: Value(SettingKeys.lastBillingType.id),
            metaValue:
                Value(jsonEncode(SettingKeys.lastBillingType.encode(
                    draft.billingType.name))),
          ));
      return id;
    });
  }

  // ------------------------------------------------------------ simple edits

  @override
  Future<void> rename(String id, String name) async {
    final clean = Validators.name(name);
    await _db.transaction(() async {
      final old = await _store.requireBatch(id);
      await _store.updateBatch(old, BatchesCompanion(name: Value(clean)));
    });
  }

  @override
  Future<void> setBillingType(String id, BillingType t) async {
    await _db.transaction(() async {
      final old = await _store.requireBatch(id);
      await _store.updateBatch(
          old, BatchesCompanion(billingType: Value(t.name)));
    });
  }

  @override
  Future<void> setReminderLead(String id, int? minutes) async {
    _checkLead(minutes);
    await _db.transaction(() async {
      final old = await _store.requireBatch(id);
      await _store.updateBatch(
          old, BatchesCompanion(reminderLeadMin: Value(minutes)));
    });
  }

  @override
  Future<void> setNotes(String id, String? notes) async {
    final clean = StructureStore.cleanNote(notes);
    await _db.transaction(() async {
      final old = await _store.requireBatch(id);
      await _store.updateBatch(old, BatchesCompanion(notes: Value(clean)));
    });
  }

  static void _checkLead(int? minutes) {
    if (minutes != null && (minutes < 0 || minutes > 720)) {
      throw const ValidationException(ErrorCodes.amountInvalid,
          field: 'reminderLeadMin');
    }
  }

  // ------------------------------------------------------------ fees

  @override
  Future<int> previewPartialMonths(
      String batchId, int amount, YearMonth from) async {
    StructureStore.checkAmount(amount);
    await _store.requireBatch(batchId);

    final feeRows = await (_db.select(_db.batchFees)
          ..where((t) => t.batchId.equals(batchId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.effectiveMonth)]))
        .get();
    final fees = [for (final r in feeRows) feeFromRow(r)];
    YearMonth? nextRow;
    for (final f in fees) {
      if (f.effective.isAfter(from)) {
        nextRow = f.effective;
        break;
      }
    }

    final enrollments = await (_db.select(_db.enrollments)
          ..where((t) => t.batchId.equals(batchId) & t.deletedAt.isNull()))
        .get();
    if (enrollments.isEmpty) return 0;
    final enrollmentIds = [for (final e in enrollments) e.id];

    final overrideRows = await (_db.select(_db.enrollmentFees)
          ..where((t) =>
              t.enrollmentId.isIn(enrollmentIds) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.effectiveMonth)]))
        .get();
    final overrides = <String, List<FeePeriod>>{};
    for (final r in overrideRows) {
      (overrides[r.enrollmentId] ??= []).add(overrideFromRow(r));
    }

    final paymentRows = await (_db.select(_db.payments)
          ..where((t) => t.batchId.equals(batchId) & t.deletedAt.isNull()))
        .get();
    final paid = <String, Map<YearMonth, int>>{};
    final waived = <String, Set<YearMonth>>{};
    for (final p in paymentRows) {
      final m = YearMonth.fromInt(p.billingMonth);
      if (p.waived) {
        (waived[p.enrollmentId] ??= {}).add(m);
      } else {
        final byMonth = paid[p.enrollmentId] ??= {};
        byMonth[m] = (byMonth[m] ?? 0) + p.amount;
      }
    }

    int? latestAmount(List<FeePeriod> list, YearMonth m) {
      FeePeriod? best;
      for (final f in list) {
        if (!f.effective.isAfter(m)) best = f;
      }
      return best?.amount;
    }

    var count = 0;
    for (final e in enrollments) {
      final byMonth = paid[e.id];
      if (byMonth == null) continue;
      final start = YearMonth.fromInt(e.startMonth);
      final endInt = e.endMonth;
      final end = endInt == null ? null : YearMonth.fromInt(endInt);
      for (final entry in byMonth.entries) {
        final m = entry.key;
        if (m.isBefore(from)) continue;
        if (nextRow != null && !m.isBefore(nextRow)) continue;
        if (m.isBefore(start) || (end != null && m.isAfter(end))) continue;
        if (waived[e.id]?.contains(m) ?? false) continue;
        final overrideAmount = latestAmount(overrides[e.id] ?? const [], m);
        if (overrideAmount != null) continue;
        final oldFee = latestAmount(fees, m);
        if (oldFee == null) continue;
        if (entry.value >= oldFee && entry.value < amount) count++;
      }
    }
    return count;
  }

  @override
  Future<void> setFee(String batchId, int amount, YearMonth from) async {
    StructureStore.checkAmount(amount);
    await _db.transaction(() async {
      await _store.requireBatch(batchId);
      await _putFee(batchId, amount, from);
    });
  }

  Future<void> _putFee(String batchId, int amount, YearMonth from) async {
    final id = Ids.batchFee(batchId, from);
    final old = await (_db.select(_db.batchFees)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    final content = batchFeeToCompanion(
        batchId, FeePeriod(effective: from, amount: amount));
    if (old == null) {
      final now = _stamper.nowMs();
      await _db.into(_db.batchFees).insert(content.copyWith(
            createdAt: Value(now),
            updatedAt: Value(now),
            deviceId: Value(_stamper.deviceId),
            rev: const Value(1),
          ));
      return;
    }
    if (old.deletedAt == null && old.amount == amount) return;
    await (_db.update(_db.batchFees)..where((t) => t.id.equals(id))).write(
      content.copyWith(
        deletedAt: const Value<int?>(null),
        updatedAt: Value(_stamper.nextUpdatedAt(old.updatedAt)),
        rev: Value(_stamper.nextRev(old.rev)),
        deviceId: Value(_stamper.deviceId),
      ),
    );
  }

  // ------------------------------------------------------------ archive

  @override
  Future<void> archive(String id,
      {required LocalDate on, required YearMonth lastBillableMonth}) async {
    await _db.transaction(() async {
      final old = await _store.requireBatch(id);
      if (old.archivedAt != null) {
        throw const ValidationException(ErrorCodes.batchArchived);
      }
      await _store.updateBatch(
        old,
        BatchesCompanion(archivedAt: Value(centerMidnightMs(on, _center))),
      );
      final open = await (_db.select(_db.enrollments)
            ..where((t) =>
                t.batchId.equals(id) &
                t.deletedAt.isNull() &
                t.endMonth.isNull()))
          .get();
      for (final e in open) {
        await _updateEnrollment(
            e, EnrollmentsCompanion(endMonth: Value(lastBillableMonth.toInt())));
      }
    });
  }

  @override
  Future<SlotCheckResult> previewUnarchive(String id) async {
    await _store.requireBatch(id);
    return _unarchiveCheck(id);
  }

  Future<SlotCheckResult> _unarchiveCheck(String id) async {
    final all = await _store.loadSchedules();
    BatchSchedule? mine;
    for (final b in all) {
      if (b.batch.id == id) mine = b;
    }
    if (mine == null) {
      throw NotFoundException(ErrorCodes.notFound, detail: 'batch $id');
    }
    final today = _store.today();
    final window = await _store.dayWindow();
    return ScheduleEngine.checkSlotEdit(
      proposed: mine,
      others: all,
      from: today,
      today: today,
      dayStartMin: window.start,
      dayEndMin: window.end,
    );
  }

  @override
  Future<int> unarchive(String id,
      {bool acceptClashes = false, bool waiveGap = true}) {
    return _db.transaction(() async {
      final old = await _store.requireBatch(id);
      if (old.archivedAt == null) return 0;
      if (!acceptClashes) {
        final result = await _unarchiveCheck(id);
        if (!result.ok) throw ScheduleClashException(result);
      }
      await _store.updateBatch(
          old, const BatchesCompanion(archivedAt: Value<int?>(null)));

      final today = _store.today();
      final lastGapMonth = today.yearMonth.addMonths(-1);
      final ended = await (_db.select(_db.enrollments)
            ..where((t) =>
                t.batchId.equals(id) &
                t.deletedAt.isNull() &
                t.endMonth.isNotNull() &
                t.endDate.isNull()))
          .get();
      var maxGap = 0;
      for (final e in ended) {
        final endMonth = YearMonth.fromInt(e.endMonth!);
        final start = YearMonth.fromInt(e.startMonth);
        final first = start.isAfter(endMonth.addMonths(1))
            ? start
            : endMonth.addMonths(1);
        final gap = first.monthsUntil(lastGapMonth) + 1;
        if (gap > maxGap) maxGap = gap;
        await _updateEnrollment(
            e, const EnrollmentsCompanion(endMonth: Value<int?>(null)));
        if (waiveGap) {
          for (var i = 0; i < gap; i++) {
            await _putWaiver(e, first.addMonths(i), today);
          }
        }
      }
      return maxGap;
    });
  }

  Future<void> _updateEnrollment(
      EnrollmentRow old, EnrollmentsCompanion changes) {
    return (_db.update(_db.enrollments)..where((t) => t.id.equals(old.id)))
        .write(changes.copyWith(
      updatedAt: Value(_stamper.nextUpdatedAt(old.updatedAt)),
      rev: Value(_stamper.nextRev(old.rev)),
      deviceId: Value(_stamper.deviceId),
    ));
  }

  /// A waived month: `payments` row with `waived = 1, amount = 0`, id
  /// `Ids.waiver(enrollment, month)` (also its own receipt).
  Future<void> _putWaiver(
      EnrollmentRow e, YearMonth month, LocalDate today) async {
    final id = Ids.waiver(e.id, month);
    final old = await (_db.select(_db.payments)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    final content = PaymentsCompanion(
      id: Value(id),
      receiptId: Value(id),
      studentId: Value(e.studentId),
      enrollmentId: Value(e.id),
      batchId: Value(e.batchId),
      billingMonth: Value(month.toInt()),
      amount: const Value(0),
      paidOn: Value(today.toIso()),
      method: Value(PaymentMethod.other.code),
      note: const Value<String?>(null),
      waived: const Value(true),
    );
    if (old == null) {
      final now = _stamper.nowMs();
      await _db.into(_db.payments).insert(content.copyWith(
            createdAt: Value(now),
            updatedAt: Value(now),
            deviceId: Value(_stamper.deviceId),
            rev: const Value(1),
          ));
      return;
    }
    if (old.deletedAt == null && old.waived) return;
    await (_db.update(_db.payments)..where((t) => t.id.equals(id))).write(
      content.copyWith(
        deletedAt: const Value<int?>(null),
        updatedAt: Value(_stamper.nextUpdatedAt(old.updatedAt)),
        rev: Value(_stamper.nextRev(old.rev)),
        deviceId: Value(_stamper.deviceId),
      ),
    );
  }

  // ------------------------------------------------------------ delete

  @override
  Future<DeleteImpact> deleteImpact(String id) async {
    await _store.requireBatch(id);
    final sessions = await (_db.select(_db.attendanceSessions)
          ..where((t) => t.batchId.equals(id) & t.deletedAt.isNull()))
        .get();
    final payments = await (_db.select(_db.payments)
          ..where((t) => t.batchId.equals(id) & t.deletedAt.isNull()))
        .get();
    final enrollments = await (_db.select(_db.enrollments)
          ..where((t) => t.batchId.equals(id) & t.deletedAt.isNull()))
        .get();
    return DeleteImpact(
      sessions: sessions.length,
      payments: {for (final p in payments) p.receiptId}.length,
      students: {for (final e in enrollments) e.studentId}.length,
    );
  }

  @override
  Future<void> softDelete(String id) async {
    await _db.transaction(() async {
      await _store.requireBatch(id);
      await cascadeDeleteBatch(_store, id);
    });
  }
}
