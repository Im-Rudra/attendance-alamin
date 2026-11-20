import 'dart:typed_data';

import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/errors/error_codes.dart';
import 'package:attendance_alamin/core/ids/ids.dart';
import 'package:attendance_alamin/data/repositories/students_repository.dart';
import 'package:attendance_alamin/domain/dues/dues_engine.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/drafts.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/schedule/occ_id.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'people_harness.dart';

void main() {
  group('create / update', () {
    test('validates, normalises and stamps', () async {
      final h = PeopleHarness();
      final id = await h.students.create(StudentDraft(
        name: '  Rahim  ',
        roll: '০৭',
        phone: '+880 1711-111111',
        guardianName: ' Karim ',
        guardianPhone: '01811111111',
        admissionDate: d('2026-11-02'),
        notes: '   ',
      ));
      final s = await h.students.getById(id);
      expect(s, isNotNull);
      expect((s!.name, s.roll, s.phone, s.guardianName, s.guardianPhone, s.notes),
          ('Rahim', '07', '01711111111', 'Karim', '01811111111', null));
      expect((s.status, s.hasPhoto, s.leftDate), (StudentStatus.active, false, null));
      final row = await h.db.select(h.db.students).getSingle();
      final now = h.stamper.nowMs();
      expect((row.createdAt, row.updatedAt, row.rev, row.deviceId), (now, now, 1, dev));

      h.clock.tick();
      await h.students.update(id,
          StudentDraft(name: 'Rahim Uddin', admissionDate: d('2026-11-02')));
      final updated = await h.db.select(h.db.students).getSingle();
      expect((updated.name, updated.phone, updated.rev, updated.updatedAt),
          ('Rahim Uddin', null, 2, h.stamper.nowMs()));
    });

    test('rejects bad input with field-specific codes', () async {
      final h = PeopleHarness();
      final when = d('2026-11-02');
      await expectLater(h.students.create(StudentDraft(name: ' ', admissionDate: when)),
          throwsCode(ErrorCodes.nameRequired));
      await expectLater(
          h.students.create(StudentDraft(name: 'A', phone: '123', admissionDate: when)),
          throwsCode(ErrorCodes.phoneInvalid));
      await expectLater(
          h.students.create(
              StudentDraft(name: 'A', guardianPhone: '99', admissionDate: when)),
          throwsA(isA<ValidationException>()
              .having((e) => e.field, 'field', 'guardianPhone')));
      expect(await h.db.select(h.db.students).get(), isEmpty);
      await expectLater(
          h.students.update('missing', StudentDraft(name: 'A', admissionDate: when)),
          throwsA(isA<NotFoundException>()));
    });
  });

  test('nextRoll, findDuplicates, watchAll order and status filter', () async {
    final h = PeopleHarness();
    expect(await h.students.nextRoll(), '01');
    await h.students.create(StudentDraft(
        name: 'Zara', roll: '09', guardianPhone: '01922222222',
        admissionDate: d('2026-01-01')));
    await h.students.create(
        StudentDraft(name: 'Amin', roll: '10', admissionDate: d('2026-01-01')));
    await h.students.create(
        StudentDraft(name: 'Babu', roll: 'X1', admissionDate: d('2026-01-01')));
    final noRoll = await h.students
        .create(StudentDraft(name: 'Cara', admissionDate: d('2026-01-01')));
    expect(await h.students.nextRoll(), '11');

    expect([for (final s in await h.students.watchAll().first) s.name],
        ['Zara', 'Amin', 'Babu', 'Cara']);
    expect((await h.students.findDuplicates(name: ' zara ')).single.name, 'Zara');
    expect(
        (await h.students.findDuplicates(name: 'nobody', phone: '01922-222222'))
            .single
            .name,
        'Zara');
    expect(await h.students.findDuplicates(name: 'nobody', phone: 'junk'), isEmpty);

    await h.students.markLeft(noRoll, on: d('2026-11-20'), lastBillableByEnrollment: const {});
    expect([for (final s in await h.students.watchAll(status: StudentStatus.left).first) s.name],
        ['Cara']);
    expect(await h.students.watchAll(status: StudentStatus.active).first, hasLength(3));
    expect((await h.students.watchById(noRoll).first)?.status, StudentStatus.left);
  });

  group('left / rejoin (Product 3.2)', () {
    test('8: left on 11-05 -> LBM Oct, Nov not billable, grey group, off roll',
        () async {
      final h = PeopleHarness(today: '2026-11-05');
      await h.seedBatches();
      final r = await h.enrolled('Rahim', fbm: 202610);
      final other = await h.enrolled('Karim', fbm: 202611);
      var report = await h.report();
      expect(report.active.map((s) => s.name), containsAll(['Rahim', 'Karim']));

      await h.students.markLeft(r.student,
          on: d('2026-11-05'), lastBillableByEnrollment: const {});

      final student = await h.students.getById(r.student);
      expect((student?.status, student?.leftDate),
          (StudentStatus.left, d('2026-11-05')));
      final e = (await h.enrollments.watchForStudent(r.student).first).single;
      expect((e.endMonth, e.endDate), (ym(202610), d('2026-11-05')));

      final dues = await h.dues(r.enrollment);
      expect(dues.months.map((m) => m.month), [ym(202610)]); // Nov not billable
      expect(dues.totalOutstanding, 1000);
      report = await h.report();
      expect(report.active.map((s) => s.name), ['Karim']);
      expect(report.inactive.single.name, 'Rahim');
      expect(report.inactive.single.worst, isNull);
      expect(report.totalOutstandingInactive, 1000);

      final onLeftDay = await h.enrollments.rosterOn(batPhy, d('2026-11-05'));
      final after = await h.enrollments.rosterOn(batPhy, d('2026-11-07'));
      expect(onLeftDay.map((s) => s.id), containsAll([r.student, other.student]));
      expect(after.map((s) => s.id), [other.student]);
    });

    test('LBM from the dialog wins; only open enrollments end', () async {
      final h = PeopleHarness(today: '2026-11-20');
      await h.seedBatches();
      final r = await h.enrolled('Rahim', fbm: 202609);
      final chem = await h.enrollments.enroll(
          studentId: r.student, batchId: batChem, joinDate: d('2026-09-01'),
          startMonth: ym(202609));
      await h.enrollments.end(chem, on: d('2026-10-03'), lastBillableMonth: ym(202609));

      await h.students.markLeft(r.student,
          on: d('2026-11-20'), lastBillableByEnrollment: {r.enrollment: ym(202610)});

      final byId = {
        for (final e in await h.enrollments.watchForStudent(r.student).first) e.id: e
      };
      expect(byId[r.enrollment]?.endMonth, ym(202610)); // dialog value, not Nov
      expect(byId[chem]?.endDate, d('2026-10-03')); // untouched
      expect(DuesEngine.defaultLastBillableMonth(d('2026-11-20')), ym(202611));
    });

    test('rejoin re-opens, returns gap months and waives them on request',
        () async {
      final h = PeopleHarness(today: '2026-08-05');
      await h.seedBatches();
      final r = await h.enrolled('Rahim', fbm: 202606);
      final early = await h.enrollments.enroll(
          studentId: r.student, batchId: batChem, joinDate: d('2026-06-01'),
          startMonth: ym(202606));
      await h.enrollments.end(early, on: d('2026-07-01'), lastBillableMonth: ym(202606));
      await h.students.markLeft(r.student,
          on: d('2026-08-05'), lastBillableByEnrollment: const {}); // LBM Jul

      h.setToday('2026-11-20');
      final gap = await h.students.rejoin(r.student, waiveGap: true);

      expect(gap, 3); // Aug, Sep, Oct
      final s = await h.students.getById(r.student);
      expect((s?.status, s?.leftDate), (StudentStatus.active, null));
      final byId = {
        for (final e in await h.enrollments.watchForStudent(r.student).first) e.id: e
      };
      expect((byId[r.enrollment]?.endMonth, byId[r.enrollment]?.endDate), (null, null));
      expect(byId[early]?.endMonth, ym(202606)); // ended earlier: stays ended
      final dues = await h.dues(r.enrollment);
      for (final m in [202608, 202609, 202610]) {
        expect(monthOf(dues, m).state, MonthState.waived);
      }
      expect(monthOf(dues, 202611).state, MonthState.unpaid);
      final waiverIds = {
        for (final p in await h.payments.watchFacts().first)
          if (p.waived) p.month.toInt()
      };
      expect(waiverIds, {202608, 202609, 202610});

      expect(await h.students.rejoin(r.student, waiveGap: true), 0); // not left
    });

    test('rejoin without waiving leaves the gap billable', () async {
      final h = PeopleHarness(today: '2026-09-15');
      await h.seedBatches();
      final r = await h.enrolled('Rahim', fbm: 202606);
      await h.students.markLeft(r.student,
          on: d('2026-09-15'), lastBillableByEnrollment: const {}); // LBM Sep
      h.setToday('2026-11-20');
      expect(await h.students.rejoin(r.student, waiveGap: false), 1); // Oct
      final dues = await h.dues(r.enrollment);
      expect(monthOf(dues, 202610).state, MonthState.unpaid);
      expect((await h.payments.watchFacts().first), isEmpty);
    });
  });

  group('photos', () {
    test('set, replace, remove, oversize', () async {
      final h = PeopleHarness();
      final id = await h.addStudent('Rahim');
      expect(await h.students.getPhoto(id), isNull);

      await h.students.setPhoto(id, Uint8List.fromList([1, 2, 3]));
      expect(await h.students.getPhoto(id), [1, 2, 3]);
      expect((await h.students.getById(id))?.hasPhoto, isTrue);

      await expectLater(
          h.students.setPhoto(id, Uint8List(kMaxPhotoBytes + 1)),
          throwsCode(ErrorCodes.photoTooLarge));
      await h.students.setPhoto(id, Uint8List(kMaxPhotoBytes)); // exactly 200 KB
      expect((await h.students.getPhoto(id))?.length, kMaxPhotoBytes);

      h.clock.tick();
      await h.students.setPhoto(id, null);
      expect(await h.students.getPhoto(id), isNull);
      expect((await h.students.getById(id))?.hasPhoto, isFalse);
      final photo = await h.db.select(h.db.studentPhotos).getSingle();
      expect((photo.deletedAt, photo.rev), (h.stamper.nowMs(), 3));

      await h.students.setPhoto(id, Uint8List.fromList([9]));
      expect(await h.students.getPhoto(id), [9]);
      await expectLater(h.students.setPhoto('missing', Uint8List.fromList([1])),
          throwsA(isA<NotFoundException>()));
    });
  });

  test('deleteImpact and softDelete cascade as tombstones', () async {
    final h = PeopleHarness(today: '2026-11-21');
    await h.seedBatches();
    final r = await h.enrolled('Rahim', fbm: 202610, feeOverride: 900);
    final keep = await h.enrolled('Karim', fbm: 202610);
    await h.payments.record(h.draft(r.student, r.enrollment, {202610: 900}));
    await h.payments.record(h.draft(r.student, r.enrollment, {202611: 900}));
    await h.payments.waive(r.enrollment, ym(202612));
    await h.students.setPhoto(r.student, Uint8List.fromList([1]));
    final date = d('2026-11-21');
    final occ = OccId.regular(slotPhySat, date);
    await h.attendance.saveRollCall(
      occurrence: Occurrence(
          occ: occ, batchId: batPhy, date: date, startMin: 960, endMin: 1020,
          kind: OccurrenceKind.regular, slotId: slotPhySat, originalDate: date),
      statuses: {
        r.student: AttendanceStatus.present,
        keep.student: AttendanceStatus.absent,
      },
    );

    expect(await h.students.deleteImpact(r.student),
        const DeleteImpact(sessions: 1, payments: 2, students: 1));

    h.clock.tick();
    await h.students.softDelete(r.student);

    expect(await h.students.getById(r.student), isNull);
    expect(await h.students.getPhoto(r.student), isNull);
    expect(await h.students.watchAll().first, hasLength(1));
    expect(await h.enrollments.watchForStudent(r.student).first, isEmpty);
    expect(await h.payments.watchForStudent(r.student).first, isEmpty);
    expect(await h.enrollments.watchOverrides(r.enrollment).first, isEmpty);
    final marks = await h.attendance.watchRecords().first;
    expect(marks.map((m) => m.studentId), [keep.student]);
    expect(await h.db.select(h.db.payments).get(), hasLength(3)); // tombstones kept
    final rec = (await h.db.select(h.db.attendanceRecords).get())
        .firstWhere((x) => x.id == Ids.record(occ, r.student));
    expect((rec.deletedAt, rec.rev, rec.deviceId), (h.stamper.nowMs(), 2, dev));
    await expectLater(h.students.softDelete(r.student),
        throwsA(isA<NotFoundException>()));
  });
}
