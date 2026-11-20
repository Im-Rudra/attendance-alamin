import 'package:attendance_alamin/core/errors/error_codes.dart';
import 'package:attendance_alamin/core/ids/ids.dart';
import 'package:attendance_alamin/data/db/mappers.dart';
import 'package:attendance_alamin/data/repositories/drift/attendance_repository_drift.dart';
import 'package:attendance_alamin/domain/models/enrollment.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'structure_fixtures.dart';

void main() {
  test('ad-hoc roll call creates the extra class and the session through the '
      'real schedule repository', () async {
    final h = Harness();
    final physics = await h.physicsA();
    await h.db.into(h.db.students).insert(stamped(studentToCompanion(Student(
          id: 'stu-1',
          name: 'Rahim',
          admissionDate: today,
          status: StudentStatus.active,
        )).copyWith));
    await h.db.into(h.db.enrollments).insert(stamped(enrollmentToCompanion(
            Enrollment(
                id: 'enr-1',
                studentId: 'stu-1',
                batchId: physics,
                joinDate: today,
                startMonth: today.yearMonth))
        .copyWith));

    final attendance = DriftAttendanceRepository(h.db, h.stamper,
        addExtra: h.schedule.addExtra);

    // Friday 18:00-19:00: Physics has no class today.
    final occ = await attendance.saveAdHocRollCall(
        batchId: physics,
        date: today,
        startMin: 1080,
        endMin: 1140,
        statuses: {'stu-1': AttendanceStatus.present});
    expect(occ, startsWith('x.'));
    final exc = await h.exceptionRow(occ.substring(2));
    expect(exc.kind, 'extra');
    expect(exc.newDate, '2026-11-20');
    final (session, records) = (await attendance.getSession(occ))!;
    expect(session.id, Ids.sessionForOcc(occ));
    expect(session.exceptionId, exc.id);
    expect(records, hasLength(1));

    // A clash through the real repository refuses and writes nothing more.
    final chem = await h.chemB();
    await h.schedule.addExtra(
        batchId: chem, date: today, startMin: 1200, endMin: 1260);
    final before = (await h.db.select(h.db.scheduleExceptions).get()).length;
    await expectLater(
        attendance.saveAdHocRollCall(
            batchId: physics,
            date: today,
            startMin: 1210,
            endMin: 1270,
            statuses: {'stu-1': AttendanceStatus.present}),
        throwsA(isA<ScheduleClashException>()
            .having((e) => e.code, 'code', ErrorCodes.scheduleClash)));
    expect((await h.db.select(h.db.scheduleExceptions).get()).length, before);
    expect((await h.db.select(h.db.attendanceSessions).get()).length, 1);
  });
}
