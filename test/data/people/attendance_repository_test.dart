import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/errors/error_codes.dart';
import 'package:attendance_alamin/core/ids/ids.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/domain/attendance_stats/attendance_stats.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/schedule/occ_id.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'people_harness.dart';

const p = AttendanceStatus.present;
const a = AttendanceStatus.absent;
const l = AttendanceStatus.late;

Occurrence regular(LocalDate date,
        {String slotId = slotPhySat,
        String batchId = batPhy,
        int start = 960,
        int end = 1020}) =>
    Occurrence(
      occ: OccId.regular(slotId, date),
      batchId: batchId,
      date: date,
      startMin: start,
      endMin: end,
      kind: OccurrenceKind.regular,
      slotId: slotId,
      originalDate: date,
    );

Occurrence extra(String exceptionId, LocalDate date, int start, int end,
        {String batchId = batPhy}) =>
    Occurrence(
      occ: OccId.extra(exceptionId),
      batchId: batchId,
      date: date,
      startMin: start,
      endMin: end,
      kind: OccurrenceKind.extra,
      exceptionId: exceptionId,
    );

void main() {
  late PeopleHarness h;
  late String rahim;
  late String karim;

  Future<void> setUpBatch(String today) async {
    h = PeopleHarness(today: today);
    await h.seedBatches();
    rahim = (await h.enrolled('Rahim', roll: '01', fbm: 202611)).student;
    karim = (await h.enrolled('Karim', roll: '02', fbm: 202611)).student;
  }

  test('25: two classes of one batch in a day = two sessions, separate marks',
      () async {
    await setUpBatch('2026-12-12'); // a Saturday
    final day = d('2026-12-12');
    await h.insertExtra('ex-eve', batPhy, day, 1080, 1140);
    final morning = regular(day);
    final evening = extra('ex-eve', day, 1080, 1140);

    await h.attendance.saveRollCall(
        occurrence: morning, statuses: {rahim: p, karim: a});
    await h.attendance.saveRollCall(
        occurrence: evening, statuses: {rahim: a, karim: p}, note: ' exam ');

    final sessions = await h.db.select(h.db.attendanceSessions).get();
    expect(sessions.map((s) => s.id).toSet(),
        {Ids.sessionForOcc(morning.occ), Ids.sessionForOcc(evening.occ)});
    final eve = sessions.firstWhere((s) => s.occ == evening.occ);
    expect((eve.exceptionId, eve.slotId, eve.note, eve.date),
        ('ex-eve', null, 'exam', '2026-12-12'));
    final marks = await h.db.select(h.db.attendanceRecords).get();
    expect(marks.map((m) => m.id).toSet(), {
      Ids.record(morning.occ, rahim),
      Ids.record(morning.occ, karim),
      Ids.record(evening.occ, rahim),
      Ids.record(evening.occ, karim),
    });

    final summaries = await h.attendance.watchSummaries(batchId: batPhy).first;
    expect(summaries.map((s) => s.session.occ), [morning.occ, evening.occ]);
    expect(summaries.map((s) => s.tally.held), [2, 2]);

    final rahimMarks = await h.attendance.watchRecords(studentId: rahim).first;
    expect(rahimMarks.map((m) => m.status), [p, a]); // by start time
    final tally = AttendanceStats.tally(rahimMarks.map((m) => m.status));
    expect((tally.held, tally.percent), (2, 50));

    final (session, records) = (await h.attendance.getSession(evening.occ))!;
    expect(session.occ, evening.occ);
    expect({for (final r in records) r.studentId: r.status}, {rahim: a, karim: p});
  });

  test('roll call is idempotent: same ids, only changes rewritten', () async {
    await setUpBatch('2026-11-21');
    final occ = regular(d('2026-11-21'));
    await h.attendance.saveRollCall(occurrence: occ, statuses: {rahim: p, karim: a});
    final now = h.stamper.nowMs();
    final session = await h.db.select(h.db.attendanceSessions).getSingle();
    expect((session.createdAt, session.updatedAt, session.rev, session.deviceId),
        (now, now, 1, dev));

    h.clock.tick();
    // Scenario 12: reopen the date and change one student to late.
    await h.attendance.saveRollCall(occurrence: occ, statuses: {rahim: p, karim: l});
    var rows = {
      for (final r in await h.db.select(h.db.attendanceRecords).get()) r.studentId: r
    };
    expect(rows, hasLength(2));
    expect((rows[rahim]!.rev, rows[rahim]!.status), (1, 'P'));
    expect((rows[karim]!.rev, rows[karim]!.status, rows[karim]!.updatedAt),
        (2, 'L', h.stamper.nowMs()));
    expect((await h.db.select(h.db.attendanceSessions).getSingle()).rev, 1);
    final karimTally = AttendanceStats.tally(
        (await h.attendance.watchRecords(studentId: karim).first).map((m) => m.status));
    expect(karimTally.percent, 100); // late counts as attended

    h.clock.tick();
    await h.attendance.saveRollCall(occurrence: occ, statuses: {rahim: p});
    rows = {
      for (final r in await h.db.select(h.db.attendanceRecords).get()) r.studentId: r
    };
    expect((rows[karim]!.deletedAt, rows[karim]!.rev), (h.stamper.nowMs(), 3));
    final (_, records) = (await h.attendance.getSession(occ.occ))!;
    expect(records.map((r) => r.studentId), [rahim]);

    h.clock.tick();
    await h.attendance.saveRollCall(occurrence: occ, statuses: {rahim: p, karim: a});
    rows = {
      for (final r in await h.db.select(h.db.attendanceRecords).get()) r.studentId: r
    };
    expect((rows[karim]!.deletedAt, rows[karim]!.rev, rows[karim]!.status),
        (null, 4, 'A'));
  });

  test('guards: future date, archived batch, bad times, unknown student',
      () async {
    await setUpBatch('2026-11-21');
    await expectLater(
        h.attendance.saveRollCall(
            occurrence: regular(d('2026-11-28')), statuses: {rahim: p}),
        throwsCode(ErrorCodes.rollCallFutureDate));
    await expectLater(
        h.attendance.saveRollCall(
            occurrence: regular(d('2026-11-21'), start: 1020, end: 960),
            statuses: {rahim: p}),
        throwsCode(ErrorCodes.slotTimeInvalid));
    await expectLater(
        h.attendance.saveRollCall(
            occurrence: regular(d('2026-11-21')), statuses: {'ghost': p}),
        throwsA(isA<NotFoundException>()));
    await expectLater(
        h.attendance.saveRollCall(
            occurrence: regular(d('2026-11-21'), slotId: 'no-slot'),
            statuses: {rahim: p}),
        throwsA(isA<NotFoundException>()));
    await h.archiveBatch(batPhy);
    await expectLater(
        h.attendance.saveRollCall(
            occurrence: regular(d('2026-11-14')), statuses: {rahim: p}),
        throwsCode(ErrorCodes.batchArchived));
    expect(await h.db.select(h.db.attendanceSessions).get(), isEmpty);
    expect(await h.db.select(h.db.attendanceRecords).get(), isEmpty);
  });

  test('taking a cancelled class removes the cancel in the same save', () async {
    await setUpBatch('2026-11-21');
    final occ = regular(d('2026-11-21'));
    await h.insertCancel(occ.occ, slotPhySat, batPhy, d('2026-11-21'));
    h.clock.tick();

    await h.attendance.saveRollCall(
        occurrence: occ, statuses: {rahim: p}, removeCancel: true);

    final exc = await h.db.select(h.db.scheduleExceptions).getSingle();
    expect((exc.id, exc.deletedAt, exc.rev),
        (Ids.exceptionForOcc(occ.occ), h.stamper.nowMs(), 2));
    expect(await h.attendance.getSession(occ.occ), isNotNull);
  });

  group('ad-hoc roll call (no scheduled class)', () {
    test('creates the extra class first, then session + marks', () async {
      await setUpBatch('2026-11-21');
      final occ = await h.attendance.saveAdHocRollCall(
          batchId: batPhy, date: d('2026-11-20'), startMin: 1080, endMin: 1140,
          statuses: {rahim: p, karim: a});

      expect(h.extraCalls.single,
          (batchId: batPhy, date: d('2026-11-20'), startMin: 1080, endMin: 1140));
      final ref = OccId.parse(occ);
      expect(ref, isA<ExtraOccRef>());
      final exceptionId = (ref as ExtraOccRef).exceptionId;
      final (session, records) = (await h.attendance.getSession(occ))!;
      expect((session.id, session.exceptionId, session.slotId, session.date,
              session.startMin, session.endMin),
          (Ids.sessionForOcc(occ), exceptionId, null, d('2026-11-20'), 1080, 1140));
      expect(records.map((r) => r.id).toSet(),
          {Ids.record(occ, rahim), Ids.record(occ, karim)});
      final exc = await h.db.select(h.db.scheduleExceptions).getSingle();
      expect((exc.id, exc.kind), (exceptionId, 'extra'));
    });

    test('a clash refuses the save and writes nothing', () async {
      await setUpBatch('2026-11-21');
      h.clash = const FakeClashException();
      await expectLater(
          h.attendance.saveAdHocRollCall(
              batchId: batPhy, date: d('2026-11-21'), startMin: 990, endMin: 1050,
              statuses: {rahim: p}),
          throwsCode(ErrorCodes.scheduleClash));
      expect(await h.db.select(h.db.attendanceSessions).get(), isEmpty);
      expect(await h.db.select(h.db.attendanceRecords).get(), isEmpty);
    });

    test('a failure after the extra was created rolls the extra back too',
        () async {
      await setUpBatch('2026-11-21');
      await h.db.customStatement(
          'CREATE TRIGGER fail_marks BEFORE INSERT ON attendance_records '
          "BEGIN SELECT RAISE(ABORT, 'boom'); END");
      await expectLater(
          h.attendance.saveAdHocRollCall(
              batchId: batPhy, date: d('2026-11-21'), startMin: 1080, endMin: 1140,
              statuses: {rahim: p}),
          throwsA(anything));
      expect(h.extraCalls, hasLength(1)); // it ran ...
      expect(await h.db.select(h.db.scheduleExceptions).get(), isEmpty); // ... and was undone
      expect(await h.db.select(h.db.attendanceSessions).get(), isEmpty);
    });

    test('future dates and archived batches are refused before scheduling',
        () async {
      await setUpBatch('2026-11-21');
      await expectLater(
          h.attendance.saveAdHocRollCall(
              batchId: batPhy, date: d('2026-11-22'), startMin: 600, endMin: 660,
              statuses: {rahim: p}),
          throwsCode(ErrorCodes.rollCallFutureDate));
      await h.archiveBatch(batPhy);
      await expectLater(
          h.attendance.saveAdHocRollCall(
              batchId: batPhy, date: d('2026-11-21'), startMin: 600, endMin: 660,
              statuses: {rahim: p}),
          throwsCode(ErrorCodes.batchArchived));
      expect(h.extraCalls, isEmpty);
    });
  });

  test('deleteSession tombstones session and marks; re-save revives ids',
      () async {
    await setUpBatch('2026-11-21');
    final occ = regular(d('2026-11-21'));
    await h.attendance.saveRollCall(occurrence: occ, statuses: {rahim: p, karim: a});
    h.clock.tick();

    await h.attendance.deleteSession(occ.occ);

    expect(await h.attendance.getSession(occ.occ), isNull);
    expect(await h.attendance.watchSummaries().first, isEmpty);
    expect(await h.attendance.watchRecords(batchId: batPhy).first, isEmpty);
    for (final r in await h.db.select(h.db.attendanceRecords).get()) {
      expect((r.deletedAt, r.rev, r.deviceId), (h.stamper.nowMs(), 2, dev));
    }
    expect((await h.db.select(h.db.attendanceSessions).getSingle()).deletedAt,
        h.stamper.nowMs());
    await expectLater(h.attendance.deleteSession(occ.occ),
        throwsA(isA<AppException>()));

    h.clock.tick();
    await h.attendance.saveRollCall(occurrence: occ, statuses: {rahim: p});
    final session = await h.db.select(h.db.attendanceSessions).getSingle();
    expect((session.deletedAt, session.rev), (null, 3));
    expect(await h.db.select(h.db.attendanceRecords).get(), hasLength(2));
    expect(await h.attendance.watchRecords().first, hasLength(1));
  });

  test('watchSummaries filters by batch and inclusive date range', () async {
    await setUpBatch('2026-11-30');
    final chemStudent = await h.addStudent('Chem only');
    await h.enrollments.enroll(
        studentId: chemStudent, batchId: batChem, joinDate: d('2026-11-01'),
        startMonth: ym(202611));
    for (final day in ['2026-11-14', '2026-11-21', '2026-11-28']) {
      await h.attendance.saveRollCall(
          occurrence: regular(d(day)), statuses: {rahim: p, karim: p});
    }
    await h.attendance.saveRollCall(
        occurrence: regular(d('2026-11-22'),
            slotId: slotChemSun, batchId: batChem, start: 600, end: 660),
        statuses: {chemStudent: a});

    final phy = await h.attendance
        .watchSummaries(batchId: batPhy, from: d('2026-11-21'), to: d('2026-11-28'))
        .first;
    expect(phy.map((s) => s.session.date), [d('2026-11-21'), d('2026-11-28')]);
    final all = await h.attendance.watchSummaries(to: d('2026-11-22')).first;
    expect(all.map((s) => s.session.batchId), [batPhy, batPhy, batChem]);
    expect(all.last.tally.absent, 1);
    final chemMarks = await h.attendance.watchRecords(batchId: batChem).first;
    expect(chemMarks.single.studentId, chemStudent);
  });
}
