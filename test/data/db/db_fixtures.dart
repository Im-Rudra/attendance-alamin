// Shared fixtures for test/data/db (not a test file itself).

import 'package:attendance_alamin/core/time/center_time.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/data/db/app_database.dart';
import 'package:attendance_alamin/data/db/mappers.dart';
import 'package:attendance_alamin/domain/models/attendance.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/enrollment.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/fee_period.dart';
import 'package:attendance_alamin/domain/models/other_income.dart';
import 'package:attendance_alamin/domain/models/payment.dart';
import 'package:attendance_alamin/domain/models/schedule.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/domain/models/subject.dart';
import 'package:drift/drift.dart' hide Batch;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026-11-20 09:00 UTC (15:00 in Dhaka).
const t0 = 1795165200000;
const dev = 'device-test';
const center = CenterTime.dhaka;

AppDatabase openMemoryDb() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  return db;
}

/// Fills the sync columns of an insert: created = updated = [at], rev 1.
T stamp<T>(T Function({Value<int> createdAt, Value<int> updatedAt, Value<String> deviceId}) copy,
        {int at = t0}) =>
    copy(createdAt: Value(at), updatedAt: Value(at), deviceId: const Value(dev));

/// Matches a sqlite error whose message contains [fragment]
/// (e.g. `CHECK constraint failed`, `FOREIGN KEY constraint failed`).
Matcher sqlFails(String fragment) => throwsA(
    predicate((Object? e) => e.toString().contains(fragment), 'fails with "$fragment"'));

final checkFails = sqlFails('CHECK constraint failed');
final fkFails = sqlFails('FOREIGN KEY constraint failed');

// ----------------------------------------------------------- domain fixtures

const subjectA = Subject(id: 'sub-1', name: 'Physics', sortOrder: 2, notes: 'n');

final batchA = Batch(
  id: 'bat-1',
  subjectId: 'sub-1',
  name: 'HSC 1',
  billingType: BillingType.postpaid,
  createdOn: center.dateOfEpochMs(t0),
  sortOrder: 1,
  reminderLeadMin: 30,
  notes: 'evening',
);

final slotA = Slot(
  id: 'slot-1',
  batchId: 'bat-1',
  weekday: 6,
  startMin: 960,
  endMin: 1050,
  validFrom: LocalDate.parse('2026-11-01'),
);

final studentA = Student(
  id: 'stu-1',
  name: 'Rahim',
  roll: '01',
  phone: '01711111111',
  guardianName: 'Karim',
  guardianPhone: '01811111111',
  admissionDate: LocalDate.parse('2026-11-02'),
  status: StudentStatus.active,
  notes: 'x',
  hasPhoto: true,
);

final enrollmentA = Enrollment(
  id: 'enr-1',
  studentId: 'stu-1',
  batchId: 'bat-1',
  joinDate: LocalDate.parse('2026-11-02'),
  startMonth: YearMonth.fromInt(202611),
  notes: 'first',
);

/// Inserts subject, batch, slot, student and enrollment A.
Future<void> seedBasics(AppDatabase db) async {
  await db.into(db.subjects).insert(stamp(subjectToCompanion(subjectA).copyWith));
  await db.into(db.batches).insert(stamp(batchToCompanion(batchA, center).copyWith));
  await db.into(db.batchSlots).insert(stamp(slotToCompanion(slotA).copyWith));
  await db.into(db.students).insert(stamp(studentToCompanion(studentA).copyWith));
  await db.into(db.enrollments).insert(stamp(enrollmentToCompanion(enrollmentA).copyWith));
}

AttendanceSession sessionFor(String occ, {String batchId = 'bat-1', String? slotId = 'slot-1'}) =>
    AttendanceSession(
      id: 'ses-$occ',
      occ: occ,
      batchId: batchId,
      slotId: slotId,
      originalDate: LocalDate.parse('2026-11-21'),
      date: LocalDate.parse('2026-11-21'),
      startMin: 960,
      endMin: 1050,
      note: 'ok',
    );

Payment paymentFor(String id, {int amount = 1500, bool waived = false, PaymentMethod method = PaymentMethod.cash}) =>
    Payment(
      id: id,
      receiptId: 'rcpt-1',
      studentId: 'stu-1',
      enrollmentId: 'enr-1',
      batchId: 'bat-1',
      billingMonth: YearMonth.fromInt(202611),
      amount: amount,
      paidOn: LocalDate.parse('2026-11-20'),
      method: method,
      note: 'n',
      waived: waived,
    );

OtherIncome incomeFor(String id, {PaymentMethod method = PaymentMethod.bkash, String? studentId = 'stu-1'}) =>
    OtherIncome(
      id: id,
      studentId: studentId,
      label: 'Exam fee',
      amount: 200,
      paidOn: LocalDate.parse('2026-11-20'),
      method: method,
      note: 'n',
    );

FeePeriod fee(int yyyymm, int? amount) =>
    FeePeriod(effective: YearMonth.fromInt(yyyymm), amount: amount);

AttendanceRecord recordFor(String occ, AttendanceStatus status) => AttendanceRecord(
      id: 'rec-$occ',
      sessionId: 'ses-$occ',
      batchId: 'bat-1',
      studentId: 'stu-1',
      date: LocalDate.parse('2026-11-21'),
      status: status,
    );
