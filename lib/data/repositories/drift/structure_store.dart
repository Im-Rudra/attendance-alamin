import 'dart:convert';

import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/errors/error_codes.dart';
import 'package:attendance_alamin/core/ids/ids.dart';
import 'package:attendance_alamin/core/settings/setting_keys.dart';
import 'package:attendance_alamin/core/time/center_time.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/validation/validators.dart';
import 'package:attendance_alamin/data/db/app_database.dart';
import 'package:attendance_alamin/data/db/db_queries.dart';
import 'package:attendance_alamin/data/db/mappers.dart';
import 'package:attendance_alamin/data/db/sync_stamper.dart';
import 'package:attendance_alamin/domain/models/drafts.dart';
import 'package:attendance_alamin/domain/models/schedule.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';
import 'package:drift/drift.dart' hide Batch;

/// Shared write helpers of the structure repositories (subjects, batches,
/// slots, exceptions, fees). Every method that writes expects to be called
/// inside `db.transaction`; it stamps sync columns through [stamper] and never
/// hard-deletes.
class StructureStore {
  StructureStore(this.db, this.stamper, this.center);

  final AppDatabase db;
  final SyncStamper stamper;
  final CenterTime center;

  /// The center's current date (from the stamper's clock).
  LocalDate today() => center.dateOfEpochMs(stamper.nowMs());

  // ------------------------------------------------------------ held classes

  /// The live saved roll call of occurrence [occ], if any.
  Future<SessionRow?> liveSession(String occ) =>
      (db.select(db.attendanceSessions)
            ..where((t) =>
                (t.id.equals(Ids.sessionForOcc(occ)) | t.occ.equals(occ)) &
                t.deletedAt.isNull())
            ..limit(1))
          .getSingleOrNull();

  /// QA-04: a held class (saved roll call) never moves to a date after
  /// today; roll calls are never in the future (Product 3.6).
  void checkHeldMove(SessionRow? session, LocalDate newDate) {
    if (session != null && newDate.isAfter(today())) {
      throw const ValidationException(ErrorCodes.heldClassToFuture,
          field: 'date');
    }
  }

  /// The saved roll call moves with its occurrence (Product 3.6).
  Future<void> moveSession(
      SessionRow? session, LocalDate date, int startMin, int endMin) async {
    if (session == null) return;
    final iso = date.toIso();
    if (session.date == iso &&
        session.startMin == startMin &&
        session.endMin == endMin) {
      return;
    }
    await (db.update(db.attendanceSessions)
          ..where((t) => t.id.equals(session.id)))
        .write(AttendanceSessionsCompanion(
      date: Value(iso),
      startMin: Value(startMin),
      endMin: Value(endMin),
      updatedAt: Value(stamper.nextUpdatedAt(session.updatedAt)),
      rev: Value(stamper.nextRev(session.rev)),
      deviceId: Value(stamper.deviceId),
    ));
  }

  Future<List<BatchSchedule>> loadSchedules() => loadAllSchedules(db, center);

  /// The free-slot suggestion window (synced settings, with defaults).
  Future<({int start, int end})> dayWindow() async {
    Future<int> read(SettingKey<int> key) async {
      final row = await (db.select(db.syncedSettings)
            ..where((t) => t.id.equals(key.id) & t.deletedAt.isNull()))
          .getSingleOrNull();
      if (row == null) return key.defaultValue;
      try {
        return key.decode(jsonDecode(row.value));
      } on FormatException {
        return key.defaultValue;
      }
    }

    final start = await read(SettingKeys.dayWindowStart);
    final end = await read(SettingKeys.dayWindowEnd);
    if (start >= end) {
      return (
        start: SettingKeys.dayWindowStart.defaultValue,
        end: SettingKeys.dayWindowEnd.defaultValue,
      );
    }
    return (start: start, end: end);
  }

  // ------------------------------------------------------------ validation

  /// Throws `slotTimeInvalid` unless the time range is `0 <= start < end <= 1440`.
  static void checkTimes(int startMin, int endMin) {
    if (startMin < 0 || startMin >= endMin || endMin > 1440) {
      throw const ValidationException(ErrorCodes.slotTimeInvalid,
          field: 'time');
    }
  }

  static void checkSlotDrafts(List<SlotDraft> slots) {
    if (slots.isEmpty) {
      throw const ValidationException(ErrorCodes.slotsEmpty, field: 'slots');
    }
    for (final s in slots) {
      if (s.weekday < 1 || s.weekday > 7) {
        throw const ValidationException(ErrorCodes.slotTimeInvalid,
            field: 'weekday');
      }
      checkTimes(s.startMin, s.endMin);
    }
  }

  static void checkAmount(int amount) {
    if (amount < 0) {
      throw const ValidationException(ErrorCodes.amountInvalid,
          field: 'amount');
    }
    if (amount > Validators.amountMax) {
      throw const ValidationException(ErrorCodes.amountTooLarge,
          field: 'amount');
    }
  }

  static String? cleanNote(String? raw) {
    final t = raw?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  // ------------------------------------------------------------ batches

  Future<BatchRow> requireBatch(String id) async {
    final row = await (db.select(db.batches)
          ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
        .getSingleOrNull();
    if (row == null) {
      throw NotFoundException(ErrorCodes.notFound, detail: 'batch $id');
    }
    return row;
  }

  Future<BatchRow> requireLiveBatch(String id) async {
    final row = await requireBatch(id);
    if (row.archivedAt != null) {
      throw const ValidationException(ErrorCodes.batchArchived);
    }
    return row;
  }

  Future<void> updateBatch(BatchRow old, BatchesCompanion changes) =>
      (db.update(db.batches)..where((t) => t.id.equals(old.id))).write(
        changes.copyWith(
          updatedAt: Value(stamper.nextUpdatedAt(old.updatedAt)),
          rev: Value(stamper.nextRev(old.rev)),
          deviceId: Value(stamper.deviceId),
        ),
      );

  // ------------------------------------------------------------ slots

  Future<void> insertSlot(Slot s) {
    final now = stamper.nowMs();
    return db.into(db.batchSlots).insert(slotToCompanion(s).copyWith(
          createdAt: Value(now),
          updatedAt: Value(now),
          deviceId: Value(stamper.deviceId),
          rev: const Value(1),
        ));
  }

  Future<void> _updateSlotRow(String id, BatchSlotsCompanion changes) async {
    final old = await (db.select(db.batchSlots)
          ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
        .getSingleOrNull();
    if (old == null) return;
    await (db.update(db.batchSlots)..where((t) => t.id.equals(id))).write(
      changes.copyWith(
        updatedAt: Value(stamper.nextUpdatedAt(old.updatedAt)),
        rev: Value(stamper.nextRev(old.rev)),
        deviceId: Value(stamper.deviceId),
      ),
    );
  }

  Future<void> updateSlotContent(Slot s) => _updateSlotRow(
        s.id,
        BatchSlotsCompanion(
          weekday: Value(s.weekday),
          startMin: Value(s.startMin),
          endMin: Value(s.endMin),
          validFrom: Value(s.validFrom?.toIso()),
          validTo: Value(s.validTo?.toIso()),
        ),
      );

  Future<void> closeSlot(String id, LocalDate validTo) => _updateSlotRow(
        id,
        BatchSlotsCompanion(validTo: Value(validTo.toIso())),
      );

  Future<void> tombstoneSlot(String id) async {
    final old = await (db.select(db.batchSlots)
          ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
        .getSingleOrNull();
    if (old == null) return;
    final ts = stamper.nextUpdatedAt(old.updatedAt);
    await (db.update(db.batchSlots)..where((t) => t.id.equals(id))).write(
      BatchSlotsCompanion(
        deletedAt: Value(ts),
        updatedAt: Value(ts),
        rev: Value(stamper.nextRev(old.rev)),
        deviceId: Value(stamper.deviceId),
      ),
    );
  }

  // ------------------------------------------------------------ exceptions

  /// Inserts the exception, or overwrites (and revives) the row with the same
  /// id. A live identical row is left untouched.
  Future<void> putException(ScheduleException e) async {
    final old = await (db.select(db.scheduleExceptions)
          ..where((t) => t.id.equals(e.id)))
        .getSingleOrNull();
    final content = exceptionToCompanion(e);
    if (old == null) {
      final now = stamper.nowMs();
      await db.into(db.scheduleExceptions).insert(content.copyWith(
            createdAt: Value(now),
            updatedAt: Value(now),
            deviceId: Value(stamper.deviceId),
            rev: const Value(1),
          ));
      return;
    }
    if (old.deletedAt == null && exceptionFromRow(old) == e) return;
    await (db.update(db.scheduleExceptions)..where((t) => t.id.equals(e.id)))
        .write(content.copyWith(
      deletedAt: const Value<int?>(null),
      updatedAt: Value(stamper.nextUpdatedAt(old.updatedAt)),
      rev: Value(stamper.nextRev(old.rev)),
      deviceId: Value(stamper.deviceId),
    ));
  }

  /// The row of exception [id], tombstoned or not.
  Future<ExceptionRow?> exceptionRowAnyState(String id) =>
      (db.select(db.scheduleExceptions)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<void> tombstoneException(String id) async {
    final old = await (db.select(db.scheduleExceptions)
          ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
        .getSingleOrNull();
    if (old == null) return;
    final ts = stamper.nextUpdatedAt(old.updatedAt);
    await (db.update(db.scheduleExceptions)..where((t) => t.id.equals(id)))
        .write(ScheduleExceptionsCompanion(
      deletedAt: Value(ts),
      updatedAt: Value(ts),
      rev: Value(stamper.nextRev(old.rev)),
      deviceId: Value(stamper.deviceId),
    ));
  }

  // ------------------------------------------------------------ bulk

  /// Tombstones every live row of [table] whose [column] is in [values], with
  /// the same stamping as a single-row soft delete (`updated_at =
  /// max(now, old + 1)`, `rev + 1`). Returns the number of rows.
  Future<int> tombstoneWhere(
    TableInfo<Table, dynamic> table,
    String column,
    Iterable<String> values,
  ) async {
    final list = values.toList();
    if (list.isEmpty) return 0;
    final marks = List.filled(list.length, '?').join(', ');
    final now = stamper.nowMs();
    return db.customUpdate(
      'UPDATE ${table.actualTableName} SET '
      'deleted_at = MAX(?, updated_at + 1), '
      'updated_at = MAX(?, updated_at + 1), '
      'rev = rev + 1, device_id = ? '
      'WHERE deleted_at IS NULL AND $column IN ($marks)',
      variables: [
        Variable.withInt(now),
        Variable.withInt(now),
        Variable.withString(stamper.deviceId),
        for (final v in list) Variable.withString(v),
      ],
      updates: {table},
    );
  }
}
