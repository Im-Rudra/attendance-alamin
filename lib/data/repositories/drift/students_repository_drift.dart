import 'dart:typed_data';

import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/errors/error_codes.dart';
import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/core/ids/ids.dart';
import 'package:attendance_alamin/core/time/center_time.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/core/validation/validators.dart';
import 'package:attendance_alamin/data/db/app_database.dart';
import 'package:attendance_alamin/data/db/mappers.dart';
import 'package:attendance_alamin/data/db/sync_stamper.dart';
import 'package:attendance_alamin/data/repositories/drift/people_common.dart';
import 'package:attendance_alamin/data/repositories/students_repository.dart';
import 'package:attendance_alamin/domain/dues/dues_engine.dart';
import 'package:attendance_alamin/domain/models/drafts.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:drift/drift.dart' hide Batch;

class DriftStudentsRepository implements StudentsRepository {
  DriftStudentsRepository(this._db, this._stamper,
      {CenterTime center = CenterTime.dhaka})
      : _center = center;

  final AppDatabase _db;
  final SyncStamper _stamper;
  final CenterTime _center;

  SimpleSelectStatement<$StudentsTable, StudentRow> _live() =>
      _db.select(_db.students)..where((t) => t.deletedAt.isNull());

  static List<Student> _sorted(List<StudentRow> rows) =>
      rows.map(studentFromRow).toList()..sort(compareByRollThenName);

  @override
  Stream<List<Student>> watchAll({StudentStatus? status}) {
    final q = _live();
    if (status != null) q.where((t) => t.status.equals(status.name));
    return q.watch().map(_sorted);
  }

  @override
  Stream<Student?> watchById(String id) {
    final q = _live()..where((t) => t.id.equals(id));
    return q
        .watchSingleOrNull()
        .map((r) => r == null ? null : studentFromRow(r));
  }

  @override
  Future<Student?> getById(String id) async {
    final r = await (_live()..where((t) => t.id.equals(id))).getSingleOrNull();
    return r == null ? null : studentFromRow(r);
  }

  @override
  Future<List<Student>> findDuplicates(
      {required String name, String? phone}) async {
    final n = name.trim().toLowerCase();
    String? p;
    try {
      p = Validators.phone(phone);
    } on ValidationException {
      p = null;
    }
    final rows = await _live().get();
    final hits = rows.where((r) {
      if (n.isNotEmpty && r.name.trim().toLowerCase() == n) return true;
      return p != null && (r.phone == p || r.guardianPhone == p);
    }).toList();
    return _sorted(hits);
  }

  @override
  Future<String> nextRoll() async {
    final rows = await _live().get();
    var max = 0;
    for (final r in rows) {
      final v = rollNumber(r.roll);
      if (v != null && v > max) max = v;
    }
    return (max + 1).toString().padLeft(2, '0');
  }

  /// Validated content columns of a draft (no id, status or sync columns).
  static StudentsCompanion _content(StudentDraft d) {
    final name = Validators.name(d.name);
    final phone = Validators.phone(d.phone);
    String? guardianPhone;
    try {
      guardianPhone = Validators.phone(d.guardianPhone);
    } on ValidationException catch (e) {
      throw ValidationException(e.code, field: 'guardianPhone');
    }
    String? guardianName;
    final g = trimOrNull(d.guardianName);
    if (g != null) {
      try {
        guardianName = Validators.name(g);
      } on ValidationException catch (e) {
        throw ValidationException(e.code, field: 'guardianName');
      }
    }
    final roll = trimOrNull(d.roll);
    return StudentsCompanion(
      name: Value(name),
      roll: Value(roll == null ? null : AppFormat.toAsciiDigits(roll)),
      phone: Value(phone),
      guardianName: Value(guardianName),
      guardianPhone: Value(guardianPhone),
      admissionDate: Value(d.admissionDate.toIso()),
      notes: Value(trimOrNull(d.notes)),
    );
  }

  @override
  Future<String> create(StudentDraft d) async {
    final content = _content(d);
    return _db.transaction(() async {
      final id = Ids.v4();
      final now = _stamper.nowMs();
      await _db.into(_db.students).insert(content.copyWith(
            id: Value(id),
            status: Value(StudentStatus.active.name),
            hasPhoto: const Value(false),
            createdAt: Value(now),
            updatedAt: Value(now),
            deviceId: Value(_stamper.deviceId),
          ));
      return id;
    });
  }

  @override
  Future<void> update(String id, StudentDraft d) async {
    final content = _content(d);
    return _db.transaction(() async {
      final old = await requireStudent(_db, id);
      await (_db.update(_db.students)..where((t) => t.id.equals(id)))
          .write(content.copyWith(
        updatedAt: Value(_stamper.nextUpdatedAt(old.updatedAt)),
        rev: Value(_stamper.nextRev(old.rev)),
        deviceId: Value(_stamper.deviceId),
      ));
    });
  }

  @override
  Future<void> markLeft(String id,
      {required LocalDate on,
      required Map<String, YearMonth> lastBillableByEnrollment}) {
    return _db.transaction(() async {
      final s = await requireStudent(_db, id);
      await (_db.update(_db.students)..where((t) => t.id.equals(id)))
          .write(StudentsCompanion(
        status: Value(StudentStatus.left.name),
        leftDate: Value(on.toIso()),
        updatedAt: Value(_stamper.nextUpdatedAt(s.updatedAt)),
        rev: Value(_stamper.nextRev(s.rev)),
        deviceId: Value(_stamper.deviceId),
      ));
      final open = await (_db.select(_db.enrollments)
            ..where((t) =>
                t.studentId.equals(id) &
                t.deletedAt.isNull() &
                t.endDate.isNull()))
          .get();
      for (final e in open) {
        final lbm = lastBillableByEnrollment[e.id] ??
            DuesEngine.defaultLastBillableMonth(on);
        await (_db.update(_db.enrollments)..where((t) => t.id.equals(e.id)))
            .write(EnrollmentsCompanion(
          endDate: Value(on.toIso()),
          endMonth: Value(lbm.toInt()),
          updatedAt: Value(_stamper.nextUpdatedAt(e.updatedAt)),
          rev: Value(_stamper.nextRev(e.rev)),
          deviceId: Value(_stamper.deviceId),
        ));
      }
    });
  }

  @override
  Future<int> rejoin(String id, {required bool waiveGap, LocalDate? on}) {
    return _db.transaction(() async {
      final s = await requireStudent(_db, id);
      if (s.status != StudentStatus.left.name) return 0;
      final today = todayOf(_stamper, _center);
      final LocalDate back = on ?? today;
      final LocalDate? leftOn = LocalDate.tryParse(s.leftDate);
      if (leftOn != null && back.isBefore(leftOn)) {
        throw const ValidationException(ErrorCodes.dateInvalid, field: 'on');
      }
      await (_db.update(_db.students)..where((t) => t.id.equals(id)))
          .write(StudentsCompanion(
        status: Value(StudentStatus.active.name),
        leftDate: const Value(null),
        updatedAt: Value(_stamper.nextUpdatedAt(s.updatedAt)),
        rev: Value(_stamper.nextRev(s.rev)),
        deviceId: Value(_stamper.deviceId),
      ));
      final leftIso = s.leftDate;
      if (leftIso == null) return 0;
      final ended = await (_db.select(_db.enrollments)
            ..where((t) =>
                t.studentId.equals(id) &
                t.deletedAt.isNull() &
                t.endDate.equals(leftIso)))
          .get();
      final gap = <YearMonth>{};
      for (final e in ended) {
        await (_db.update(_db.enrollments)..where((t) => t.id.equals(e.id)))
            .write(EnrollmentsCompanion(
          endDate: const Value(null),
          endMonth: const Value(null),
          updatedAt: Value(_stamper.nextUpdatedAt(e.updatedAt)),
          rev: Value(_stamper.nextRev(e.rev)),
          deviceId: Value(_stamper.deviceId),
        ));
        final endMonth = e.endMonth;
        if (endMonth == null) continue;
        final start = YearMonth.fromInt(e.startMonth);
        var m = YearMonth.fromInt(endMonth).addMonths(1);
        if (m.isBefore(start)) m = start;
        for (; m.isBefore(back.yearMonth); m = m.addMonths(1)) {
          gap.add(m);
          if (waiveGap) {
            await writeWaiver(_db, _stamper, e, m, on: today);
          }
        }
      }
      return gap.length;
    });
  }

  @override
  Future<Uint8List?> getPhoto(String id) async {
    final r = await (_db.select(_db.studentPhotos)
          ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
        .getSingleOrNull();
    return r?.jpeg;
  }

  @override
  Future<void> setPhoto(String id, Uint8List? jpeg) async {
    final bytes = (jpeg == null || jpeg.isEmpty) ? null : jpeg;
    if (bytes != null && bytes.length > kMaxPhotoBytes) {
      throw const ValidationException(ErrorCodes.photoTooLarge,
          field: 'photo');
    }
    return _db.transaction(() async {
      final s = await requireStudent(_db, id);
      final existing = await (_db.select(_db.studentPhotos)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      if (bytes == null) {
        await tombstoneId(_db, _stamper, _db.studentPhotos, id);
      } else if (existing == null) {
        final now = _stamper.nowMs();
        await _db.into(_db.studentPhotos).insert(StudentPhotosCompanion.insert(
              id: id,
              createdAt: now,
              updatedAt: now,
              deviceId: _stamper.deviceId,
              jpeg: bytes,
            ));
      } else {
        await (_db.update(_db.studentPhotos)..where((t) => t.id.equals(id)))
            .write(StudentPhotosCompanion(
          jpeg: Value(bytes),
          deletedAt: const Value(null),
          updatedAt: Value(_stamper.nextUpdatedAt(existing.updatedAt)),
          rev: Value(_stamper.nextRev(existing.rev)),
          deviceId: Value(_stamper.deviceId),
        ));
      }
      final hasPhoto = bytes != null;
      if (s.hasPhoto != hasPhoto) {
        await (_db.update(_db.students)..where((t) => t.id.equals(id)))
            .write(StudentsCompanion(
          hasPhoto: Value(hasPhoto),
          updatedAt: Value(_stamper.nextUpdatedAt(s.updatedAt)),
          rev: Value(_stamper.nextRev(s.rev)),
          deviceId: Value(_stamper.deviceId),
        ));
      }
    });
  }

  @override
  Future<DeleteImpact> deleteImpact(String id) async {
    await requireStudent(_db, id);
    final marks = await (_db.select(_db.attendanceRecords)
          ..where((t) => t.studentId.equals(id) & t.deletedAt.isNull()))
        .get();
    final payments = await (_db.select(_db.payments)
          ..where((t) =>
              t.studentId.equals(id) &
              t.deletedAt.isNull() &
              t.waived.equals(false)))
        .get();
    return DeleteImpact(
      sessions: marks.length,
      payments: {for (final p in payments) p.receiptId}.length,
      students: 1,
    );
  }

  @override
  Future<void> softDelete(String id) {
    return _db.transaction(() async {
      await requireStudent(_db, id);
      final byStudent = [Variable.withString(id)];
      await tombstoneWhere(_db, _stamper, _db.enrollmentFees,
          'enrollment_id IN (SELECT id FROM enrollments WHERE student_id = ?)',
          byStudent);
      await tombstoneWhere(
          _db, _stamper, _db.enrollments, 'student_id = ?', byStudent);
      await tombstoneWhere(
          _db, _stamper, _db.payments, 'student_id = ?', byStudent);
      await tombstoneWhere(
          _db, _stamper, _db.attendanceRecords, 'student_id = ?', byStudent);
      await tombstoneId(_db, _stamper, _db.studentPhotos, id);
      await tombstoneId(_db, _stamper, _db.students, id);
    });
  }
}
