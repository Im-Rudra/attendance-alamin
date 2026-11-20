import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/errors/error_codes.dart';
import 'package:attendance_alamin/core/ids/ids.dart';
import 'package:attendance_alamin/domain/dues/dues_engine.dart';
import 'package:attendance_alamin/domain/models/drafts.dart';
import 'package:attendance_alamin/domain/models/fee_period.dart';
import 'package:flutter_test/flutter_test.dart';

import 'people_harness.dart';

void main() {
  test('enroll stamps the row, stores the join date and FBM', () async {
    final h = PeopleHarness();
    await h.seedBatches();
    final s = await h.addStudent('Rahim');
    final id = await h.enrollments.enroll(
        studentId: s, batchId: batPhy, joinDate: d('2026-11-10'),
        startMonth: DuesEngine.defaultFirstBillableMonth(d('2026-11-10'), 15));

    final e = (await h.enrollments.watchAll().first).single;
    expect((e.id, e.studentId, e.batchId, e.joinDate, e.startMonth, e.endMonth),
        (id, s, batPhy, d('2026-11-10'), ym(202611), null));
    final row = await h.db.select(h.db.enrollments).getSingle();
    final now = h.stamper.nowMs();
    expect((row.createdAt, row.updatedAt, row.rev, row.deviceId), (now, now, 1, dev));
    expect(await h.enrollments.watchForBatch(batPhy).first, hasLength(1));
    expect(await h.enrollments.watchForBatch(batChem).first, isEmpty);
    expect(await h.enrollments.watchForStudent(s).first, hasLength(1));
    expect(await h.enrollments.watchOverrides(id).first, isEmpty);
  });

  test('guards: duplicate open enrollment, archived batch, unknown ids',
      () async {
    final h = PeopleHarness();
    await h.seedBatches();
    final r = await h.enrolled('Rahim', fbm: 202611);
    Future<String> again({String batchId = batPhy, String? student}) =>
        h.enrollments.enroll(
            studentId: student ?? r.student, batchId: batchId,
            joinDate: d('2026-11-15'), startMonth: ym(202611));

    await expectLater(again(), throwsCode(ErrorCodes.duplicateOpenEnrollment));
    await expectLater(again(batchId: 'nope'), throwsA(isA<NotFoundException>()));
    await expectLater(again(student: 'nope'), throwsA(isA<NotFoundException>()));
    await expectLater(
        h.enrollments.enroll(
            studentId: r.student, batchId: batChem, joinDate: d('2026-11-15'),
            startMonth: ym(202611), feeOverride: -1),
        throwsCode(ErrorCodes.amountInvalid));
    await h.archiveBatch(batChem);
    await expectLater(again(batchId: batChem), throwsCode(ErrorCodes.batchArchived));

    // Re-enrolling after the first enrollment ended is allowed.
    await h.enrollments.end(r.enrollment,
        on: d('2026-11-20'), lastBillableMonth: ym(202611));
    await again();
    expect(await h.enrollments.watchForStudent(r.student).first, hasLength(2));
  });

  test('fee override history with effective-from months (Product 3.1, sc. 11)',
      () async {
    final h = PeopleHarness(today: '2026-11-20');
    await h.seedBatches();
    final r = await h.enrolled('Rahim', fbm: 202611, feeOverride: 800);
    final row = await h.db.select(h.db.enrollmentFees).getSingle();
    expect(row.id, Ids.enrollmentFee(r.enrollment, ym(202611)));

    await h.enrollments.setOverride(r.enrollment, 900, from: ym(202701));
    await h.enrollments.setOverride(r.enrollment, null, from: ym(202703));
    expect(await h.enrollments.watchOverrides(r.enrollment).first, [
      FeePeriod(effective: ym(202611), amount: 800),
      FeePeriod(effective: ym(202701), amount: 900),
      FeePeriod(effective: ym(202703)),
    ]);

    final terms = (await h.enrollments.watchTerms().first)
        .firstWhere((t) => t.enrollmentId == r.enrollment);
    expect(DuesEngine.feeFor(terms, ym(202612)).fee, 800);
    expect(DuesEngine.feeFor(terms, ym(202702)).fee, 900);
    expect(DuesEngine.feeFor(terms, ym(202703)).fee, 1000); // cleared -> batch fee

    // Same month again = same row, updated in place.
    h.clock.tick();
    await h.enrollments.setOverride(r.enrollment, 950, from: ym(202701));
    final jan = (await h.db.select(h.db.enrollmentFees).get())
        .firstWhere((x) => x.effectiveMonth == 202701);
    expect((jan.amount, jan.rev, jan.updatedAt), (950, 2, h.stamper.nowMs()));
    await expectLater(
        h.enrollments.setOverride(r.enrollment, 2000000, from: ym(202702)),
        throwsCode(ErrorCodes.amountTooLarge));
    await expectLater(h.enrollments.setOverride('nope', 1, from: ym(202702)),
        throwsA(isA<NotFoundException>()));
  });

  test('setStartMonth moves the initial override with an earlier FBM',
      () async {
    final h = PeopleHarness(today: '2026-11-20');
    await h.seedBatches();
    final r = await h.enrolled('Rahim', fbm: 202611, feeOverride: 800);

    await h.enrollments.setStartMonth(r.enrollment, ym(202610));

    final e = (await h.enrollments.watchAll().first).single;
    expect(e.startMonth, ym(202610));
    expect(await h.enrollments.watchOverrides(r.enrollment).first,
        [FeePeriod(effective: ym(202610), amount: 800)]);
    final dues = await h.dues(r.enrollment);
    expect(monthOf(dues, 202610).fee, 800);

    // Later FBM: the override already covers it, nothing moves.
    await h.enrollments.setStartMonth(r.enrollment, ym(202612));
    expect(await h.enrollments.watchOverrides(r.enrollment).first,
        [FeePeriod(effective: ym(202610), amount: 800)]);
  });

  test('end (removed from one batch) sets end date + LBM, student stays active',
      () async {
    final h = PeopleHarness(today: '2026-11-12');
    await h.seedBatches();
    final r = await h.enrolled('Sara', fbm: 202610);
    final chem = await h.enrollments.enroll(
        studentId: r.student, batchId: batChem, joinDate: d('2026-10-01'),
        startMonth: ym(202610));
    final lbm = DuesEngine.defaultLastBillableMonth(h.today); // day 12 -> Nov
    expect(lbm, ym(202611));
    h.clock.tick();

    await h.enrollments.end(r.enrollment, on: h.today, lastBillableMonth: lbm);

    final row = (await h.db.select(h.db.enrollments).get())
        .firstWhere((x) => x.id == r.enrollment);
    expect((row.endMonth, row.endDate, row.rev), (202611, '2026-11-12', 2));
    expect((await h.students.getById(r.student))?.status.name, 'active');
    final dues = await h.dues(r.enrollment);
    expect(dues.months.last.month, ym(202611));
    expect(dues.inactive, isTrue);
    expect((await h.dues(chem)).inactive, isFalse);
    await expectLater(
        h.enrollments.end('nope', on: h.today, lastBillableMonth: lbm),
        throwsA(isA<NotFoundException>()));
  });

  test('rosterOn: join/end dates, left students, roll then name', () async {
    final h = PeopleHarness(today: '2026-11-21');
    await h.seedBatches();
    final b = await h.enrolled('Babu', roll: '02', fbm: 202611);
    final a = await h.enrolled('Amin', roll: '10', fbm: 202611);
    final c = await h.enrolled('Cara', roll: '02', fbm: 202611);
    final lateJoiner = await h.addStudent('Late', roll: '01');
    await h.enrollments.enroll(
        studentId: lateJoiner, batchId: batPhy, joinDate: d('2026-11-15'),
        startMonth: ym(202612));
    await h.enrollments.enroll(
        studentId: a.student, batchId: batChem, joinDate: d('2026-11-01'),
        startMonth: ym(202611));

    final on14 = await h.enrollments.rosterOn(batPhy, d('2026-11-14'));
    expect(on14.map((s) => s.name), ['Babu', 'Cara', 'Amin']);
    final on21 = await h.enrollments.rosterOn(batPhy, d('2026-11-21'));
    expect(on21.map((s) => s.name), ['Late', 'Babu', 'Cara', 'Amin']);

    await h.students.markLeft(c.student,
        on: d('2026-11-18'), lastBillableByEnrollment: const {});
    final after = await h.enrollments.rosterOn(batPhy, d('2026-11-21'));
    expect(after.map((s) => s.name), ['Late', 'Babu', 'Amin']);
    expect((await h.enrollments.rosterOn(batPhy, d('2026-11-18'))).map((s) => s.name),
        contains('Cara'));
    expect((await h.enrollments.rosterOn(batChem, d('2026-11-21'))).single.id, a.student);
    expect(await h.enrollments.rosterOn(batChem, d('2026-10-01')), isEmpty);
    expect(b.student, isNotEmpty);
  });

  test('watchTerms reflects enrollments, overrides and left status', () async {
    final h = PeopleHarness(today: '2026-11-20');
    await h.seedBatches();
    final r = await h.enrolled('Rahim', fbm: 202610, feeOverride: 700);
    final terms = (await h.enrollments.watchTerms().first).single;
    expect((terms.studentName, terms.batchName, terms.subjectName, terms.start),
        ('Rahim', 'Physics A', 'Physics', ym(202610)));
    expect(terms.overrides, [FeePeriod(effective: ym(202610), amount: 700)]);
    await h.students.markLeft(r.student,
        on: d('2026-11-20'), lastBillableByEnrollment: const {});
    final after = (await h.enrollments.watchTerms().first).single;
    expect((after.studentLeft, after.enrollmentEnded, after.end),
        (true, true, ym(202611)));
    expect(
        await h.students.create(StudentDraft(name: 'X', admissionDate: h.today)),
        isNotEmpty);
  });
}
