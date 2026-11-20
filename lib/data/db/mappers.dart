// Rows <-> domain models (plan M3-A).
//
// `xFromRow` maps a drift row to its domain model. `xToCompanion` maps a
// domain model to a companion holding the id and every content column; the
// sync columns (created_at, updated_at, deleted_at, device_id, rev) are left
// absent for the repository to stamp through `SyncStamper`, e.g.
// `subjectToCompanion(s).copyWith(createdAt: Value(now), updatedAt: Value(now),
// deviceId: Value(stamper.deviceId))`.
//
// Note: `package:drift/drift.dart` exports a `Batch` class that clashes with
// the domain `Batch`; import drift with `show`/`hide` next to domain models.

import 'package:attendance_alamin/core/ids/ids.dart';
import 'package:attendance_alamin/core/time/center_time.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/data/db/app_database.dart';
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
import 'package:drift/drift.dart' show Value;

// ---------------------------------------------------------------- helpers

LocalDate? _dateOrNull(String? iso) => iso == null ? null : LocalDate.parse(iso);

YearMonth? _monthOrNull(int? yyyymm) =>
    yyyymm == null ? null : YearMonth.fromInt(yyyymm);

/// UTC epoch ms of local midnight of [date] at the center. Used for
/// `*_at` columns that the domain exposes as a date (e.g. `batches.archived_at`);
/// `c.dateOfEpochMs(centerMidnightMs(d, c)) == d`.
int centerMidnightMs(LocalDate date, CenterTime c) =>
    c.toUtc(date, 0).millisecondsSinceEpoch;

// ---------------------------------------------------------------- row -> domain

Subject subjectFromRow(SubjectRow r) => Subject(
      id: r.id,
      name: r.name,
      sortOrder: r.sortOrder,
      notes: r.notes,
      archived: r.archivedAt != null,
    );

/// `createdOn` is the center date of `created_at`; `archivedOn` the center
/// date of `archived_at`.
Batch batchFromRow(BatchRow r, CenterTime c) {
  final archivedAt = r.archivedAt;
  return Batch(
    id: r.id,
    subjectId: r.subjectId,
    name: r.name,
    billingType: BillingType.parse(r.billingType),
    createdOn: c.dateOfEpochMs(r.createdAt),
    sortOrder: r.sortOrder,
    reminderLeadMin: r.reminderLeadMin,
    archivedOn: archivedAt == null ? null : c.dateOfEpochMs(archivedAt),
    notes: r.notes,
  );
}

Slot slotFromRow(SlotRow r) => Slot(
      id: r.id,
      batchId: r.batchId,
      weekday: r.weekday,
      startMin: r.startMin,
      endMin: r.endMin,
      validFrom: _dateOrNull(r.validFrom),
      validTo: _dateOrNull(r.validTo),
    );

ScheduleException exceptionFromRow(ExceptionRow r) => ScheduleException(
      id: r.id,
      batchId: r.batchId,
      kind: ExceptionKind.parse(r.kind),
      slotId: r.slotId,
      originalDate: _dateOrNull(r.originalDate),
      newDate: _dateOrNull(r.newDate),
      newStartMin: r.newStartMin,
      newEndMin: r.newEndMin,
      note: r.note,
    );

FeePeriod feeFromRow(BatchFeeRow r) =>
    FeePeriod(effective: YearMonth.fromInt(r.effectiveMonth), amount: r.amount);

/// `amount == null` = override cleared from that month.
FeePeriod overrideFromRow(EnrollmentFeeRow r) =>
    FeePeriod(effective: YearMonth.fromInt(r.effectiveMonth), amount: r.amount);

Student studentFromRow(StudentRow r) => Student(
      id: r.id,
      name: r.name,
      roll: r.roll,
      phone: r.phone,
      guardianName: r.guardianName,
      guardianPhone: r.guardianPhone,
      admissionDate: LocalDate.parse(r.admissionDate),
      status: StudentStatus.parse(r.status),
      leftDate: _dateOrNull(r.leftDate),
      notes: r.notes,
      hasPhoto: r.hasPhoto,
    );

Enrollment enrollmentFromRow(EnrollmentRow r) => Enrollment(
      id: r.id,
      studentId: r.studentId,
      batchId: r.batchId,
      joinDate: LocalDate.parse(r.joinDate),
      startMonth: YearMonth.fromInt(r.startMonth),
      endMonth: _monthOrNull(r.endMonth),
      endDate: _dateOrNull(r.endDate),
      notes: r.notes,
    );

Payment paymentFromRow(PaymentRow r) => Payment(
      id: r.id,
      receiptId: r.receiptId,
      studentId: r.studentId,
      enrollmentId: r.enrollmentId,
      batchId: r.batchId,
      billingMonth: YearMonth.fromInt(r.billingMonth),
      amount: r.amount,
      paidOn: LocalDate.parse(r.paidOn),
      method: PaymentMethod.parse(r.method),
      note: r.note,
      waived: r.waived,
    );

AttendanceSession sessionFromRow(SessionRow r) => AttendanceSession(
      id: r.id,
      occ: r.occ,
      batchId: r.batchId,
      slotId: r.slotId,
      originalDate: _dateOrNull(r.originalDate),
      exceptionId: r.exceptionId,
      date: LocalDate.parse(r.date),
      startMin: r.startMin,
      endMin: r.endMin,
      note: r.note,
    );

AttendanceRecord recordFromRow(RecordRow r) => AttendanceRecord(
      id: r.id,
      sessionId: r.sessionId,
      batchId: r.batchId,
      studentId: r.studentId,
      date: LocalDate.parse(r.date),
      status: AttendanceStatus.parse(r.status),
    );

OtherIncome otherIncomeFromRow(OtherIncomeRow r) => OtherIncome(
      id: r.id,
      studentId: r.studentId,
      label: r.label,
      amount: r.amount,
      paidOn: LocalDate.parse(r.paidOn),
      method: PaymentMethod.parse(r.method),
      note: r.note,
    );

// ---------------------------------------------------------------- domain -> companion

/// `archived_at` is left absent: the domain only carries a flag, the
/// repository stamps the archive instant itself.
SubjectsCompanion subjectToCompanion(Subject s) => SubjectsCompanion(
      id: Value(s.id),
      name: Value(s.name),
      sortOrder: Value(s.sortOrder),
      notes: Value(s.notes),
    );

/// `createdOn` is derived from `created_at` and therefore not written here.
BatchesCompanion batchToCompanion(Batch b, CenterTime c) {
  final archivedOn = b.archivedOn;
  return BatchesCompanion(
    id: Value(b.id),
    subjectId: Value(b.subjectId),
    name: Value(b.name),
    billingType: Value(b.billingType.name),
    reminderLeadMin: Value(b.reminderLeadMin),
    archivedAt:
        Value(archivedOn == null ? null : centerMidnightMs(archivedOn, c)),
    sortOrder: Value(b.sortOrder),
    notes: Value(b.notes),
  );
}

BatchSlotsCompanion slotToCompanion(Slot s) => BatchSlotsCompanion(
      id: Value(s.id),
      batchId: Value(s.batchId),
      weekday: Value(s.weekday),
      startMin: Value(s.startMin),
      endMin: Value(s.endMin),
      validFrom: Value(s.validFrom?.toIso()),
      validTo: Value(s.validTo?.toIso()),
    );

ScheduleExceptionsCompanion exceptionToCompanion(ScheduleException e) =>
    ScheduleExceptionsCompanion(
      id: Value(e.id),
      batchId: Value(e.batchId),
      kind: Value(e.kind.name),
      slotId: Value(e.slotId),
      originalDate: Value(e.originalDate?.toIso()),
      newDate: Value(e.newDate?.toIso()),
      newStartMin: Value(e.newStartMin),
      newEndMin: Value(e.newEndMin),
      note: Value(e.note),
    );

/// id = `Ids.batchFee(batchId, f.effective)`. A batch fee always has an
/// amount; throws [ArgumentError] when `f.amount` is null.
BatchFeesCompanion batchFeeToCompanion(String batchId, FeePeriod f) {
  final amount = f.amount;
  if (amount == null) {
    throw ArgumentError.value(f, 'f', 'A batch fee needs an amount');
  }
  return BatchFeesCompanion(
    id: Value(Ids.batchFee(batchId, f.effective)),
    batchId: Value(batchId),
    effectiveMonth: Value(f.effective.toInt()),
    amount: Value(amount),
  );
}

/// id = `Ids.enrollmentFee(enrollmentId, f.effective)`; null amount = cleared.
EnrollmentFeesCompanion enrollmentFeeToCompanion(
        String enrollmentId, FeePeriod f) =>
    EnrollmentFeesCompanion(
      id: Value(Ids.enrollmentFee(enrollmentId, f.effective)),
      enrollmentId: Value(enrollmentId),
      effectiveMonth: Value(f.effective.toInt()),
      amount: Value(f.amount),
    );

StudentsCompanion studentToCompanion(Student s) => StudentsCompanion(
      id: Value(s.id),
      name: Value(s.name),
      roll: Value(s.roll),
      phone: Value(s.phone),
      guardianName: Value(s.guardianName),
      guardianPhone: Value(s.guardianPhone),
      admissionDate: Value(s.admissionDate.toIso()),
      status: Value(s.status.name),
      leftDate: Value(s.leftDate?.toIso()),
      notes: Value(s.notes),
      hasPhoto: Value(s.hasPhoto),
    );

EnrollmentsCompanion enrollmentToCompanion(Enrollment e) =>
    EnrollmentsCompanion(
      id: Value(e.id),
      studentId: Value(e.studentId),
      batchId: Value(e.batchId),
      joinDate: Value(e.joinDate.toIso()),
      startMonth: Value(e.startMonth.toInt()),
      endMonth: Value(e.endMonth?.toInt()),
      endDate: Value(e.endDate?.toIso()),
      notes: Value(e.notes),
    );

PaymentsCompanion paymentToCompanion(Payment p) => PaymentsCompanion(
      id: Value(p.id),
      receiptId: Value(p.receiptId),
      studentId: Value(p.studentId),
      enrollmentId: Value(p.enrollmentId),
      batchId: Value(p.batchId),
      billingMonth: Value(p.billingMonth.toInt()),
      amount: Value(p.amount),
      paidOn: Value(p.paidOn.toIso()),
      method: Value(p.method.code),
      note: Value(p.note),
      waived: Value(p.waived),
    );

AttendanceSessionsCompanion sessionToCompanion(AttendanceSession s) =>
    AttendanceSessionsCompanion(
      id: Value(s.id),
      occ: Value(s.occ),
      batchId: Value(s.batchId),
      slotId: Value(s.slotId),
      originalDate: Value(s.originalDate?.toIso()),
      exceptionId: Value(s.exceptionId),
      date: Value(s.date.toIso()),
      startMin: Value(s.startMin),
      endMin: Value(s.endMin),
      note: Value(s.note),
    );

AttendanceRecordsCompanion recordToCompanion(AttendanceRecord r) =>
    AttendanceRecordsCompanion(
      id: Value(r.id),
      sessionId: Value(r.sessionId),
      batchId: Value(r.batchId),
      studentId: Value(r.studentId),
      date: Value(r.date.toIso()),
      status: Value(r.status.code),
    );

OtherIncomeCompanion otherIncomeToCompanion(OtherIncome o) =>
    OtherIncomeCompanion(
      id: Value(o.id),
      studentId: Value(o.studentId),
      label: Value(o.label),
      amount: Value(o.amount),
      paidOn: Value(o.paidOn.toIso()),
      method: Value(o.method.code),
      note: Value(o.note),
    );
