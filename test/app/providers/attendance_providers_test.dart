import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/providers/attendance_providers.dart';
import 'package:attendance_alamin/core/ids/ids.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/data/repositories/local_meta_repository.dart';
import 'package:attendance_alamin/domain/attendance_stats/attendance_stats.dart';
import 'package:attendance_alamin/domain/models/attendance.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/pump_app.dart';

({String studentId, String batchId, YearMonth? month}) key(
        String student, String batch, [YearMonth? month]) =>
    (studentId: student, batchId: batch, month: month);

void main() {
  late SeededFakes f;
  late ProviderContainer c;

  void startContainer() {
    c = makeContainer(overrides: f.overrides);
  }

  setUp(() {
    f = seedFakes();
  });

  group('attendanceTallyProvider', () {
    test('counts every mark of the student in that batch', () async {
      startContainer();
      final rahim = await readData(c, attendanceTallyProvider(key(kStuRahim, kBatPhysA)));
      expect(rahim, const AttendanceTally(present: 3, absent: 3));
      expect(rahim.percent, 50);

      final sara = await readData(c, attendanceTallyProvider(key(kStuSara, kBatPhysA)));
      expect(sara, const AttendanceTally(present: 4, late: 1, leave: 1));
      expect(sara.percent, 100); // leave is not held against her
    });

    test('is bounded by the enrollment dates', () async {
      // A stray absent mark the day before Nila joined (10 Nov) is ignored.
      f.attendance.records.add(AttendanceRecord(
        id: 'stray',
        sessionId: Ids.sessionForOcc(physOcc('2026-11-09')),
        batchId: kBatPhysA,
        studentId: kStuNila,
        date: const LocalDate(2026, 11, 9),
        status: AttendanceStatus.absent,
      ));
      startContainer();
      final nila = await readData(c, attendanceTallyProvider(key(kStuNila, kBatPhysA)));
      expect(nila, const AttendanceTally(present: 3, absent: 1));
    });

    test('month filter', () async {
      startContainer();
      final nov = await readData(
          c, attendanceTallyProvider(key(kStuRahim, kBatPhysA, const YearMonth(2026, 11))));
      expect(nov.held, 6);
      final oct = await readData(
          c, attendanceTallyProvider(key(kStuRahim, kBatPhysA, const YearMonth(2026, 10))));
      expect(oct.held, 0);
      expect(oct.percent, isNull);
    });

    test('a student with no enrollment in the batch has an empty tally', () async {
      startContainer();
      final t = await readData(c, attendanceTallyProvider(key(kStuKarim, kBatPhysA)));
      expect(t, const AttendanceTally());
    });

    test('follows a new roll call', () async {
      startContainer();
      await readData(c, attendanceTallyProvider(key(kStuRahim, kBatPhysA)));
      await f.attendance.saveRollCall(
        occurrence: _occ(kToday),
        statuses: {kStuRahim: AttendanceStatus.late},
      );
      final t = await readData(c, attendanceTallyProvider(key(kStuRahim, kBatPhysA)));
      expect(t.late, 1);
      expect(t.held, 7);
    });
  });

  group('absenceAlertsProvider', () {
    final lastAbsence = Ids.sessionForOcc(physOcc('2026-11-18'));

    test('Rahim, absent in the last three held sessions, is alerted', () async {
      startContainer();
      final alerts = await readData(c, absenceAlertsProvider);
      expect(alerts, hasLength(1));
      final a = alerts.single;
      expect(a.student.id, kStuRahim);
      expect(a.batch.id, kBatPhysA);
      expect(a.enrollmentId, kEnrRahimPhys);
      expect(a.lastSessionId, lastAbsence);
    });

    test('dismissed until the next absence', () async {
      startContainer();
      expect(await readData(c, absenceAlertsProvider), hasLength(1));

      await f.localMeta.setRaw(LocalMetaKeys.absenceDismissed(kEnrRahimPhys), lastAbsence);
      expect(await readData(c, absenceAlertsProvider), isEmpty);

      // Absent again at the next class: a new streak end, alert returns.
      await f.attendance.saveRollCall(
        occurrence: _occ(kToday),
        statuses: {
          kStuRahim: AttendanceStatus.absent,
          kStuSara: AttendanceStatus.present,
          kStuNila: AttendanceStatus.present,
        },
      );
      final back = await readData(c, absenceAlertsProvider);
      expect(back, hasLength(1));
      expect(back.single.lastSessionId, Ids.sessionForOcc(_occ(kToday).occ));
    });

    test('a present mark resets the streak', () async {
      startContainer();
      await readData(c, absenceAlertsProvider);
      await f.attendance.saveRollCall(
        occurrence: _occ(kToday),
        statuses: {kStuRahim: AttendanceStatus.present},
      );
      expect(await readData(c, absenceAlertsProvider), isEmpty);
    });

    test('a student who has left is not alerted', () async {
      f.students.students.removeWhere((s) => s.id == kStuRahim);
      f.students.students.add(const Student(
        id: kStuRahim,
        name: 'রহিম উদ্দিন',
        admissionDate: LocalDate(2026, 9, 5),
        status: StudentStatus.left,
        leftDate: LocalDate(2026, 11, 19),
      ));
      startContainer();
      expect(await readData(c, absenceAlertsProvider), isEmpty);
    });
  });
}

Occurrence _occ(LocalDate date) => Occurrence(
      occ: physOcc(date.toIso()),
      batchId: kBatPhysA,
      date: date,
      startMin: kPhysStart,
      endMin: kPhysEnd,
      kind: OccurrenceKind.regular,
      slotId: kSlotPhysSat,
    );
