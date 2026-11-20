import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/errors/error_codes.dart';
import 'package:attendance_alamin/core/ids/ids.dart';
import 'package:attendance_alamin/core/time/center_time.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/data/db/app_database.dart';
import 'package:attendance_alamin/data/db/mappers.dart';
import 'package:attendance_alamin/data/db/sync_stamper.dart';
import 'package:attendance_alamin/data/repositories/attendance_repository.dart';
import 'package:attendance_alamin/data/repositories/drift/people_common.dart';
import 'package:attendance_alamin/domain/attendance_stats/attendance_stats.dart';
import 'package:attendance_alamin/domain/models/attendance.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/schedule/occ_id.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';
import 'package:drift/drift.dart' hide Batch;

class DriftAttendanceRepository implements AttendanceRepository {
  DriftAttendanceRepository(this._db, this._stamper,
      {required AddExtraClass addExtra, CenterTime center = CenterTime.dhaka})
      : _addExtra = addExtra,
        _center = center;

  final AppDatabase _db;
  final SyncStamper _stamper;
  final AddExtraClass _addExtra;
  final CenterTime _center;

  // ------------------------------------------------------------------ reads

  @override
  Future<(AttendanceSession, List<AttendanceRecord>)?> getSession(
      String occ) async {
    final sessionId = Ids.sessionForOcc(occ);
    final s = await (_db.select(_db.attendanceSessions)
          ..where((t) => t.id.equals(sessionId) & t.deletedAt.isNull()))
        .getSingleOrNull();
    if (s == null) return null;
    final records = await (_db.select(_db.attendanceRecords)
          ..where((t) => t.sessionId.equals(sessionId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.studentId)]))
        .get();
    return (sessionFromRow(s), records.map(recordFromRow).toList());
  }

  @override
  Stream<List<SessionSummary>> watchSummaries(
      {String? batchId, LocalDate? from, LocalDate? to}) {
    return _db.watchComposite(
      {_db.attendanceSessions, _db.attendanceRecords},
      () async {
        final q = _db.select(_db.attendanceSessions)
          ..where((t) => t.deletedAt.isNull());
        if (batchId != null) q.where((t) => t.batchId.equals(batchId));
        if (from != null) {
          q.where((t) => t.date.isBiggerOrEqualValue(from.toIso()));
        }
        if (to != null) q.where((t) => t.date.isSmallerOrEqualValue(to.toIso()));
        final sessions = await q.get();

        final rq = _db.select(_db.attendanceRecords)
          ..where((t) => t.deletedAt.isNull());
        if (batchId != null) rq.where((t) => t.batchId.equals(batchId));
        final bySession = <String, List<AttendanceStatus>>{};
        for (final r in await rq.get()) {
          (bySession[r.sessionId] ??= []).add(AttendanceStatus.parse(r.status));
        }

        final out = [
          for (final s in sessions)
            SessionSummary(
              session: sessionFromRow(s),
              tally: AttendanceStats.tally(bySession[s.id] ?? const []),
            ),
        ];
        out.sort((a, b) => _bySessionTime(a.session, b.session));
        return out;
      },
    );
  }

  static int _bySessionTime(AttendanceSession a, AttendanceSession b) {
    final d = a.date.compareTo(b.date);
    if (d != 0) return d;
    final s = a.startMin.compareTo(b.startMin);
    if (s != 0) return s;
    return a.id.compareTo(b.id);
  }

  @override
  Stream<List<AttendanceRecord>> watchRecords(
      {String? studentId, String? batchId}) {
    return _db.watchComposite(
      {_db.attendanceSessions, _db.attendanceRecords},
      () async {
        final rq = _db.select(_db.attendanceRecords)
          ..where((t) => t.deletedAt.isNull());
        if (studentId != null) rq.where((t) => t.studentId.equals(studentId));
        if (batchId != null) rq.where((t) => t.batchId.equals(batchId));
        final records = await rq.get();

        final sq = _db.select(_db.attendanceSessions)
          ..where((t) => t.deletedAt.isNull());
        if (batchId != null) sq.where((t) => t.batchId.equals(batchId));
        final sessions = {
          for (final s in await sq.get()) s.id: sessionFromRow(s),
        };

        final live = <(AttendanceSession, AttendanceRecord)>[
          for (final r in records)
            if (sessions[r.sessionId] case final s?) (s, recordFromRow(r)),
        ];
        live.sort((a, b) {
          final c = _bySessionTime(a.$1, b.$1);
          return c != 0 ? c : a.$2.studentId.compareTo(b.$2.studentId);
        });
        return [for (final e in live) e.$2];
      },
    );
  }

  // ----------------------------------------------------------------- writes

  /// Live, not archived batch (roll call on an archived batch is read-only).
  Future<void> _requireOpenBatch(String batchId) async {
    final b = await requireBatch(_db, batchId);
    if (b.archivedAt != null) {
      throw const ValidationException(ErrorCodes.batchArchived,
          field: 'batchId');
    }
  }

  Future<void> _requireStudents(Iterable<String> ids) async {
    final wanted = ids.toSet();
    if (wanted.isEmpty) return;
    final rows = await (_db.select(_db.students)
          ..where((t) => t.id.isIn(wanted) & t.deletedAt.isNull()))
        .get();
    if (rows.length != wanted.length) {
      final found = {for (final r in rows) r.id};
      throw notFound('students ${wanted.difference(found).join(',')}');
    }
  }

  Future<void> _requireSlot(String? slotId) async {
    if (slotId == null) return;
    final row = await (_db.select(_db.batchSlots)
          ..where((t) => t.id.equals(slotId)))
        .getSingleOrNull();
    if (row == null) throw notFound('slot $slotId');
  }

  Future<void> _requireException(String? exceptionId) async {
    if (exceptionId == null) return;
    final row = await (_db.select(_db.scheduleExceptions)
          ..where((t) => t.id.equals(exceptionId)))
        .getSingleOrNull();
    if (row == null) throw notFound('exception $exceptionId');
  }

  void _checkNotFuture(LocalDate date) {
    if (date.isAfter(todayOf(_stamper, _center))) {
      throw const ValidationException(ErrorCodes.rollCallFutureDate,
          field: 'date');
    }
  }

  Future<void> _upsertSession(AttendanceSession s) async {
    final existing = await (_db.select(_db.attendanceSessions)
          ..where((t) => t.id.equals(s.id)))
        .getSingleOrNull();
    if (existing == null) {
      final now = _stamper.nowMs();
      await _db.into(_db.attendanceSessions).insert(sessionToCompanion(s)
          .copyWith(
              createdAt: Value(now),
              updatedAt: Value(now),
              deviceId: Value(_stamper.deviceId)));
      return;
    }
    if (existing.deletedAt == null && sessionFromRow(existing) == s) return;
    await (_db.update(_db.attendanceSessions)..where((t) => t.id.equals(s.id)))
        .write(sessionToCompanion(s).copyWith(
      deletedAt: const Value(null),
      updatedAt: Value(_stamper.nextUpdatedAt(existing.updatedAt)),
      rev: Value(_stamper.nextRev(existing.rev)),
      deviceId: Value(_stamper.deviceId),
    ));
  }

  /// One mark per listed student (deterministic ids); marks of students no
  /// longer listed are tombstoned; unchanged live marks are not rewritten.
  Future<void> _writeMarks(AttendanceSession s,
      Map<String, AttendanceStatus> statuses) async {
    final existing = await (_db.select(_db.attendanceRecords)
          ..where((t) => t.sessionId.equals(s.id)))
        .get();
    final byId = {for (final r in existing) r.id: r};
    final listed = <String>{};
    for (final e in statuses.entries) {
      final rec = AttendanceRecord(
        id: Ids.record(s.occ, e.key),
        sessionId: s.id,
        batchId: s.batchId,
        studentId: e.key,
        date: s.date,
        status: e.value,
      );
      listed.add(rec.id);
      final old = byId[rec.id];
      if (old == null) {
        final now = _stamper.nowMs();
        await _db.into(_db.attendanceRecords).insert(recordToCompanion(rec)
            .copyWith(
                createdAt: Value(now),
                updatedAt: Value(now),
                deviceId: Value(_stamper.deviceId)));
      } else if (old.deletedAt != null || recordFromRow(old) != rec) {
        await (_db.update(_db.attendanceRecords)
              ..where((t) => t.id.equals(rec.id)))
            .write(recordToCompanion(rec).copyWith(
          deletedAt: const Value(null),
          updatedAt: Value(_stamper.nextUpdatedAt(old.updatedAt)),
          rev: Value(_stamper.nextRev(old.rev)),
          deviceId: Value(_stamper.deviceId),
        ));
      }
    }
    for (final r in existing) {
      if (r.deletedAt == null && !listed.contains(r.id)) {
        await tombstoneId(_db, _stamper, _db.attendanceRecords, r.id);
      }
    }
  }

  @override
  Future<void> saveRollCall({
    required Occurrence occurrence,
    required Map<String, AttendanceStatus> statuses,
    String? note,
    bool removeCancel = false,
  }) async {
    final o = occurrence;
    checkTimes(o.startMin, o.endMin);
    _checkNotFuture(o.date);
    final session = AttendanceSession(
      id: Ids.sessionForOcc(o.occ),
      occ: o.occ,
      batchId: o.batchId,
      slotId: o.slotId,
      originalDate: o.originalDate,
      exceptionId: o.exceptionId,
      date: o.date,
      startMin: o.startMin,
      endMin: o.endMin,
      note: trimOrNull(note),
    );
    await _db.transaction(() async {
      await _requireOpenBatch(o.batchId);
      await _requireSlot(o.slotId);
      await _requireException(o.exceptionId);
      await _requireStudents(statuses.keys);
      if (removeCancel) {
        await tombstoneWhere(_db, _stamper, _db.scheduleExceptions,
            "id = ? AND kind = 'cancel'",
            [Variable.withString(Ids.exceptionForOcc(o.occ))]);
      }
      await _upsertSession(session);
      await _writeMarks(session, statuses);
    });
  }

  @override
  Future<String> saveAdHocRollCall({
    required String batchId,
    required LocalDate date,
    required int startMin,
    required int endMin,
    required Map<String, AttendanceStatus> statuses,
  }) async {
    checkTimes(startMin, endMin);
    _checkNotFuture(date);
    return _db.transaction(() async {
      await _requireOpenBatch(batchId);
      await _requireStudents(statuses.keys);
      final occ = await _addExtra(
          batchId: batchId, date: date, startMin: startMin, endMin: endMin);
      final exceptionId = switch (OccId.parse(occ)) {
        ExtraOccRef(exceptionId: final id) => id,
        RegularOccRef() => null,
      };
      await _requireException(exceptionId);
      final session = AttendanceSession(
        id: Ids.sessionForOcc(occ),
        occ: occ,
        batchId: batchId,
        exceptionId: exceptionId,
        date: date,
        startMin: startMin,
        endMin: endMin,
      );
      await _upsertSession(session);
      await _writeMarks(session, statuses);
      return occ;
    });
  }

  @override
  Future<void> deleteSession(String occ) {
    return _db.transaction(() async {
      final sessionId = Ids.sessionForOcc(occ);
      final n =
          await tombstoneId(_db, _stamper, _db.attendanceSessions, sessionId);
      if (n == 0) throw notFound('session $occ');
      await tombstoneWhere(_db, _stamper, _db.attendanceRecords,
          'session_id = ?', [Variable.withString(sessionId)]);
    });
  }
}
