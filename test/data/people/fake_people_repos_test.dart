// Smoke test for test/helpers/fakes/fake_people_repos.dart: the fakes keep the
// observable behaviour widget tests rely on.

import 'package:attendance_alamin/core/errors/error_codes.dart';
import 'package:attendance_alamin/core/ids/ids.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/data/repositories/students_repository.dart';
import 'package:attendance_alamin/domain/models/drafts.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/other_income.dart';
import 'package:attendance_alamin/domain/schedule/occ_id.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes/fake_people_repos.dart';
import 'people_harness.dart' show FakeClashException, throwsCode;

void main() {
  const day = LocalDate(2026, 11, 21);

  test('students: create, watch, failNext', () async {
    final repo = FakeStudentsRepository();
    final id = await repo.create(const StudentDraft(name: 'Rahim', roll: '01', admissionDate: day));
    expect((await repo.watchAll().first).single.id, id);
    expect(await repo.nextRoll(), '02');
    repo.failNext = const FakeClashException();
    await expectLater(repo.create(const StudentDraft(name: 'X', admissionDate: day)),
        throwsCode(ErrorCodes.scheduleClash));
    expect(repo.students, hasLength(1));
    expect(await repo.deleteImpact(id), const DeleteImpact(sessions: 0, payments: 0, students: 1));
  });

  test('enrollments: duplicate guard and roster', () async {
    final students = FakeStudentsRepository();
    final s = await students.create(const StudentDraft(name: 'Rahim', admissionDate: day));
    final repo = FakeEnrollmentsRepository(students: students.students);
    await repo.enroll(studentId: s, batchId: 'b', joinDate: day, startMonth: const YearMonth(2026, 11));
    await expectLater(
        repo.enroll(studentId: s, batchId: 'b', joinDate: day, startMonth: const YearMonth(2026, 11)),
        throwsCode(ErrorCodes.duplicateOpenEnrollment));
    expect((await repo.rosterOn('b', day)).single.id, s);
    expect(await repo.rosterOn('b', const LocalDate(2026, 11, 20)), isEmpty);
  });

  test('payments: one receipt id per record, waivers', () async {
    final repo = FakePaymentsRepository(batchOfEnrollment: {'e': 'b'});
    final receiptId = await repo.record(PaymentDraft(
      studentId: 's',
      enrollmentId: 'e',
      allocations: const [
        Allocation(month: YearMonth(2026, 10), amount: 1000),
        Allocation(month: YearMonth(2026, 11), amount: 500),
      ],
      paidOn: day,
      method: PaymentMethod.cash,
    ));
    final rows = await repo.receipt(receiptId);
    expect(rows.map((p) => (p.batchId, p.amount)), [('b', 1000), ('b', 500)]);
    await repo.waive('e', const YearMonth(2026, 12));
    expect((await repo.watchFacts().first).where((f) => f.waived), hasLength(1));
    await repo.deleteReceipt(receiptId);
    expect(await repo.receipt(receiptId), isEmpty);
  });

  test('attendance: deterministic ids and summaries', () async {
    final repo = FakeAttendanceRepository();
    final occ = OccId.regular('slot', day);
    await repo.saveRollCall(
      occurrence: Occurrence(
          occ: occ, batchId: 'b', date: day, startMin: 960, endMin: 1020,
          kind: OccurrenceKind.regular, slotId: 'slot', originalDate: day),
      statuses: {'s1': AttendanceStatus.present, 's2': AttendanceStatus.absent},
    );
    final (session, records) = (await repo.getSession(occ))!;
    expect(session.id, Ids.sessionForOcc(occ));
    expect(records.map((r) => r.id).toSet(), {Ids.record(occ, 's1'), Ids.record(occ, 's2')});
    final summary = (await repo.watchSummaries().first).single;
    expect((summary.tally.present, summary.tally.absent), (1, 1));
    final adHoc = await repo.saveAdHocRollCall(
        batchId: 'b', date: day, startMin: 600, endMin: 660, statuses: const {});
    expect(OccId.parse(adHoc), isA<ExtraOccRef>());
  });

  test('other income: add and range', () async {
    final repo = FakeOtherIncomeRepository();
    await repo.add(const OtherIncome(
        id: '', label: 'Book', amount: 100, paidOn: day, method: PaymentMethod.cash));
    expect(await repo.watchBetween(day, day).first, hasLength(1));
  });
}
