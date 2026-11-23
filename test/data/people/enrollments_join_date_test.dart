// Teacher feedback items 6 and 11 on the repositories: moving an enrolment's
// join date (validated, billing untouched) and rejoining from an earlier
// "back from" date.

import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/errors/error_codes.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/enrollment.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';

import 'people_harness.dart';

Matcher _throwsField(String field) => throwsA(isA<ValidationException>()
    .having((ValidationException e) => e.code, 'code', ErrorCodes.dateInvalid)
    .having((ValidationException e) => e.field, 'field', field));

void main() {
  group('updateJoinDate', () {
    test('moves the join date back; billing start, rev and stamps follow the rules',
        () async {
      final h = PeopleHarness(today: '2026-11-20');
      await h.seedBatches();
      final r = await h.enrolled('Rafin', fbm: 202611); // joined 1 Nov
      h.clock.tick();

      await h.enrollments.updateJoinDate(r.enrollment, DateTime(2026, 10, 18, 15, 30));

      final Enrollment e = (await h.enrollments.watchAll().first).single;
      expect(e.joinDate, d('2026-10-18'));
      expect(e.startMonth, ym(202611), reason: 'the billing start month is untouched');
      final row = await h.db.select(h.db.enrollments).getSingle();
      expect((row.rev, row.updatedAt, row.deviceId), (2, h.stamper.nowMs(), dev));
      // The roll call of 18 Oct now lists Rafin.
      final roster = await h.enrollments.rosterOn(batPhy, d('2026-10-18'));
      expect(roster.map((s) => s.id), contains(r.student));
    });

    test('the same date again writes nothing', () async {
      final h = PeopleHarness();
      await h.seedBatches();
      final r = await h.enrolled('Rafin', fbm: 202611);
      await h.enrollments.updateJoinDate(r.enrollment, DateTime(2026, 11, 1));
      final row = await h.db.select(h.db.enrollments).getSingle();
      expect(row.rev, 1);
    });

    test('rejects a date after the end date or before 2015', () async {
      final h = PeopleHarness(today: '2026-11-20');
      await h.seedBatches();
      final r = await h.enrolled('Rafin', fbm: 202609);
      await h.enrollments.end(r.enrollment, on: d('2026-10-15'), lastBillableMonth: ym(202610));

      await expectLater(
          h.enrollments.updateJoinDate(r.enrollment, DateTime(2026, 10, 16)), _throwsField('joinDate'));
      await expectLater(
          h.enrollments.updateJoinDate(r.enrollment, DateTime(2014, 12, 31)), _throwsField('joinDate'));
      // The end day itself is fine.
      await h.enrollments.updateJoinDate(r.enrollment, DateTime(2026, 10, 15));
      expect((await h.enrollments.watchAll().first).single.joinDate, d('2026-10-15'));
      await expectLater(h.enrollments.updateJoinDate('nope', DateTime(2026, 10, 1)),
          throwsA(isA<NotFoundException>()));
    });

    test('rejects an overlap with another enrolment of the same student in the same batch',
        () async {
      final h = PeopleHarness(today: '2026-11-20');
      await h.seedBatches();
      final first = await h.enrolled('Rafin', fbm: 202606); // 1 Jun
      await h.enrollments.end(first.enrollment, on: d('2026-09-30'), lastBillableMonth: ym(202609));
      final String again = await h.enrollments.enroll(
          studentId: first.student, batchId: batPhy, joinDate: d('2026-11-10'), startMonth: ym(202611));
      // Another batch never counts.
      await h.enrollments.enroll(
          studentId: first.student, batchId: batChem, joinDate: d('2026-01-05'), startMonth: ym(202601));

      await expectLater(h.enrollments.updateJoinDate(again, DateTime(2026, 9, 30)), _throwsField('overlap'));
      await expectLater(h.enrollments.updateJoinDate(again, DateTime(2026, 8, 1)), _throwsField('overlap'));
      await h.enrollments.updateJoinDate(again, DateTime(2026, 10, 1));
      final Enrollment moved =
          (await h.enrollments.watchAll().first).firstWhere((Enrollment e) => e.id == again);
      expect((moved.joinDate, moved.startMonth), (d('2026-10-01'), ym(202611)));

      // The ended one cannot reach into the open one either.
      await expectLater(
          h.enrollments.updateJoinDate(first.enrollment, DateTime(2026, 10, 1)), _throwsField('joinDate'));
    });
  });

  group('rejoin from an earlier date (item 11)', () {
    test('only the months before the back-from month are the gap', () async {
      final h = PeopleHarness(today: '2026-08-05');
      await h.seedBatches();
      final r = await h.enrolled('Rahim', fbm: 202606);
      await h.students.markLeft(r.student,
          on: d('2026-08-05'), lastBillableByEnrollment: const {}); // LBM Jul
      h.setToday('2026-11-20');

      final int gap = await h.students.rejoin(r.student, waiveGap: true, on: d('2026-09-10'));

      expect(gap, 1); // Aug only
      final s = await h.students.getById(r.student);
      expect(s?.status, StudentStatus.active);
      final dues = await h.dues(r.enrollment);
      expect(monthOf(dues, 202608).state, MonthState.waived);
      expect(monthOf(dues, 202609).state, isNot(MonthState.waived));
      expect(monthOf(dues, 202610).state, isNot(MonthState.waived));
    });

    test('a back-from date before the leave is refused', () async {
      final h = PeopleHarness(today: '2026-08-05');
      await h.seedBatches();
      final r = await h.enrolled('Rahim', fbm: 202606);
      await h.students.markLeft(r.student, on: d('2026-08-05'), lastBillableByEnrollment: const {});
      h.setToday('2026-11-20');
      await expectLater(
          h.students.rejoin(r.student, waiveGap: false, on: d('2026-08-04')), throwsCode(ErrorCodes.dateInvalid));
      final s = await h.students.getById(r.student);
      expect(s?.status, StudentStatus.left, reason: 'nothing changed');
    });
  });
}
