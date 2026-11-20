// Shared set-up for the M4-B repository tests (not a test file itself).

import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/errors/error_codes.dart';
import 'package:attendance_alamin/core/ids/ids.dart';
import 'package:attendance_alamin/core/time/center_time.dart';
import 'package:attendance_alamin/core/time/clock.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/data/db/app_database.dart';
import 'package:attendance_alamin/data/db/mappers.dart';
import 'package:attendance_alamin/data/db/sync_stamper.dart';
import 'package:attendance_alamin/data/repositories/drift/attendance_repository_drift.dart';
import 'package:attendance_alamin/data/repositories/drift/enrollments_repository_drift.dart';
import 'package:attendance_alamin/data/repositories/drift/other_income_repository_drift.dart';
import 'package:attendance_alamin/data/repositories/drift/payments_repository_drift.dart';
import 'package:attendance_alamin/data/repositories/drift/students_repository_drift.dart';
import 'package:attendance_alamin/domain/dues/dues_engine.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/drafts.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/fee_period.dart';
import 'package:attendance_alamin/domain/models/schedule.dart';
import 'package:attendance_alamin/domain/models/subject.dart';
import 'package:attendance_alamin/domain/schedule/occ_id.dart';
import 'package:drift/drift.dart' hide Batch, isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const dev = 'dev-test';
const center = CenterTime.dhaka;

/// A clock the test can move.
class TestClock implements Clock {
  TestClock(this.now);

  DateTime now;

  @override
  DateTime nowUtc() => now;

  /// 10:00 at the center on [d].
  void setToday(LocalDate d, {int minutes = 600}) =>
      now = center.toUtc(d, minutes);

  /// Moves the clock forward (keeps later writes strictly newer).
  void tick([int ms = 1000]) => now = now.add(Duration(milliseconds: ms));
}

/// Thrown by the fake `addExtra` (stands in for M4-A's ScheduleClashException).
final class FakeClashException extends AppException {
  const FakeClashException() : super(ErrorCodes.scheduleClash);
}

LocalDate d(String iso) => LocalDate.parse(iso);
YearMonth ym(int yyyymm) => YearMonth.fromInt(yyyymm);

// Seed ids (Product 6 scenario seed).
const subPhy = 'sub-phy';
const subChem = 'sub-chem';
const batPhy = 'bat-phy'; // Physics A: prepaid 1000, Sat/Mon/Wed 16:00-17:00
const batChem = 'bat-chem'; // Chem B: postpaid 800, Sun/Tue 10:00-11:00
const slotPhySat = 'slot-phy-sat';
const slotPhyMon = 'slot-phy-mon';
const slotChemSun = 'slot-chem-sun';

/// In-memory DB + every M4-B repository on one movable clock.
class PeopleHarness {
  PeopleHarness({String today = '2026-11-20'})
      : clock = TestClock(center.toUtc(LocalDate.parse(today), 600)) {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    stamper = SyncStamper(clock: clock, deviceId: dev);
    students = DriftStudentsRepository(db, stamper, center: center);
    enrollments = DriftEnrollmentsRepository(db, stamper, center: center);
    payments = DriftPaymentsRepository(db, stamper, center: center);
    attendance = DriftAttendanceRepository(db, stamper,
        addExtra: addExtra, center: center);
    otherIncome = DriftOtherIncomeRepository(db, stamper);
  }

  final TestClock clock;
  late final AppDatabase db;
  late final SyncStamper stamper;
  late final DriftStudentsRepository students;
  late final DriftEnrollmentsRepository enrollments;
  late final DriftPaymentsRepository payments;
  late final DriftAttendanceRepository attendance;
  late final DriftOtherIncomeRepository otherIncome;

  LocalDate get today => center.today(clock);
  void setToday(String iso) => clock.setToday(LocalDate.parse(iso));

  /// When set, the fake `addExtra` throws it (a schedule clash).
  AppException? clash;

  /// Calls received by the fake `addExtra`.
  final List<({String batchId, LocalDate date, int startMin, int endMin})>
      extraCalls = [];

  /// Minimal stand-in for `ScheduleRepository.addExtra` (M4-A): inserts an
  /// extra exception through the same DB (so it joins the caller's
  /// transaction) unless [clash] is set.
  Future<String> addExtra({
    required String batchId,
    required LocalDate date,
    required int startMin,
    required int endMin,
    String? note,
  }) async {
    final c = clash;
    if (c != null) throw c;
    extraCalls.add(
        (batchId: batchId, date: date, startMin: startMin, endMin: endMin));
    final id = Ids.v4();
    await insertExtra(id, batchId, date, startMin, endMin);
    return OccId.extra(id);
  }

  Future<void> insertExtra(
      String id, String batchId, LocalDate date, int startMin, int endMin) {
    return db.into(db.scheduleExceptions).insert(exceptionToCompanion(
          ScheduleException(
            id: id,
            batchId: batchId,
            kind: ExceptionKind.extra,
            newDate: date,
            newStartMin: startMin,
            newEndMin: endMin,
          ),
        ).copyWith(
            createdAt: Value(stamper.nowMs()),
            updatedAt: Value(stamper.nowMs()),
            deviceId: const Value(dev)));
  }

  Future<void> insertCancel(String occ, String slotId, String batchId,
      LocalDate originalDate) {
    return db.into(db.scheduleExceptions).insert(exceptionToCompanion(
          ScheduleException(
            id: Ids.exceptionForOcc(occ),
            batchId: batchId,
            kind: ExceptionKind.cancel,
            slotId: slotId,
            originalDate: originalDate,
          ),
        ).copyWith(
            createdAt: Value(stamper.nowMs()),
            updatedAt: Value(stamper.nowMs()),
            deviceId: const Value(dev)));
  }

  /// Subjects, Physics A (prepaid, ৳1000 from Jan 2026, Sat + Mon 16:00-17:00)
  /// and Chem B (postpaid, ৳800, Sun 10:00-11:00).
  Future<void> seedBatches() async {
    final now = stamper.nowMs();
    T s<T>(T Function({Value<int> createdAt, Value<int> updatedAt, Value<String> deviceId}) copy) =>
        copy(createdAt: Value(now), updatedAt: Value(now), deviceId: const Value(dev));
    await db.into(db.subjects).insert(s(subjectToCompanion(
            const Subject(id: subPhy, name: 'Physics', sortOrder: 0))
        .copyWith));
    await db.into(db.subjects).insert(s(subjectToCompanion(
            const Subject(id: subChem, name: 'Chemistry', sortOrder: 1))
        .copyWith));
    for (final b in [
      Batch(
          id: batPhy,
          subjectId: subPhy,
          name: 'Physics A',
          billingType: BillingType.prepaid,
          createdOn: d('2026-01-01'),
          sortOrder: 0),
      Batch(
          id: batChem,
          subjectId: subChem,
          name: 'Chem B',
          billingType: BillingType.postpaid,
          createdOn: d('2026-01-01'),
          sortOrder: 1,
          reminderLeadMin: 30),
    ]) {
      await db.into(db.batches).insert(s(batchToCompanion(b, center).copyWith));
    }
    await db.into(db.batchFees).insert(
        s(batchFeeToCompanion(batPhy, FeePeriod(effective: ym(202601), amount: 1000)).copyWith));
    await db.into(db.batchFees).insert(
        s(batchFeeToCompanion(batChem, FeePeriod(effective: ym(202601), amount: 800)).copyWith));
    for (final slot in [
      const Slot(id: slotPhySat, batchId: batPhy, weekday: 6, startMin: 960, endMin: 1020),
      const Slot(id: slotPhyMon, batchId: batPhy, weekday: 1, startMin: 960, endMin: 1020),
      const Slot(id: slotChemSun, batchId: batChem, weekday: 7, startMin: 600, endMin: 660),
    ]) {
      await db.into(db.batchSlots).insert(s(slotToCompanion(slot).copyWith));
    }
  }

  /// Archives [batchId] directly (M4-A owns the real archive flow).
  Future<void> archiveBatch(String batchId) => (db.update(db.batches)
        ..where((t) => t.id.equals(batchId)))
      .write(BatchesCompanion(archivedAt: Value(stamper.nowMs())));

  Future<String> addStudent(String name, {String? roll, String? phone}) =>
      students.create(StudentDraft(
          name: name, roll: roll, phone: phone, admissionDate: d('2026-01-01')));

  /// Student + enrollment in [batchId] with FBM [fbm] (join = 1st of FBM).
  Future<({String student, String enrollment})> enrolled(String name,
      {String batchId = batPhy, int fbm = 202611, int? feeOverride, String? roll}) async {
    final student = await addStudent(name, roll: roll);
    final enrollment = await enrollments.enroll(
      studentId: student,
      batchId: batchId,
      joinDate: ym(fbm).firstDay,
      startMonth: ym(fbm),
      feeOverride: feeOverride,
    );
    return (student: student, enrollment: enrollment);
  }

  /// Dues of one enrollment straight from the repositories' streams.
  Future<EnrollmentDues> dues(String enrollmentId) async {
    final terms = await enrollments.watchTerms().first;
    final facts = await payments.watchFacts().first;
    final t = terms.firstWhere((x) => x.enrollmentId == enrollmentId);
    return DuesEngine.forEnrollment(terms: t, payments: facts, today: today);
  }

  Future<DuesReport> report() async => DuesEngine.report(
        today: today,
        terms: await enrollments.watchTerms().first,
        payments: await payments.watchFacts().first,
      );

  Future<List<PaymentRow>> allPaymentRows() => db.select(db.payments).get();

  PaymentDraft draft(String student, String enrollment, Map<int, int> alloc,
          {PaymentMethod method = PaymentMethod.cash, String? note}) =>
      PaymentDraft(
        studentId: student,
        enrollmentId: enrollment,
        allocations: [
          for (final e in alloc.entries)
            Allocation(month: ym(e.key), amount: e.value),
        ],
        paidOn: today,
        method: method,
        note: note,
      );
}

/// Matches an [AppException] with [code].
Matcher throwsCode(String code) => throwsA(isA<AppException>()
    .having((e) => e.code, 'code', code));

MonthDue monthOf(EnrollmentDues dues, int yyyymm) =>
    dues.months.firstWhere((m) => m.month == ym(yyyymm));
