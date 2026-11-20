import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/providers/schedule_providers.dart';
import 'package:attendance_alamin/app/widgets/state_pill.dart';
import 'package:attendance_alamin/core/ids/ids.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/domain/attendance_stats/attendance_stats.dart';
import 'package:attendance_alamin/domain/schedule/occ_id.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/pump_app.dart';

LocalDate d(String iso) => LocalDate.parse(iso);

void main() {
  late SeededFakes f;
  late ProviderContainer c;

  setUp(() {
    f = seedFakes();
    c = makeContainer(overrides: f.overrides);
  });

  Future<DayPlan> day(String iso) => readData(c, dayPlanProvider(d(iso)));

  test('today (Saturday) has Physics A, not started yet at 10:00', () async {
    final plan = await day('2026-11-21');
    expect(plan.date, kToday);
    expect(plan.classes, hasLength(1));
    final c = plan.classes.single;
    expect(c.occ, OccId.regular(kSlotPhysSat, kToday));
    expect(c.batch.id, kBatPhysA);
    expect(c.subjectName, 'পদার্থবিজ্ঞান');
    expect((c.startMin, c.endMin), (kPhysStart, kPhysEnd));
    expect(c.state, isNull);
    expect(c.enrolledCount, 3); // Rahim, Sara, Nila
    expect(c.taken, isFalse);
    expect(c.cancelled, isFalse);
    expect(plan.movedAway, isEmpty);
  });

  test('the class running right now is marked now', () async {
    final evening = makeContainer(
        overrides: f.overrides, nowUtc: at('2026-11-21', '16:30').fixedUtc);
    final plan = await readData(evening, dayPlanProvider(kToday));
    expect(plan.classes.single.state, ClassState.now);
  });

  test('a day with a saved roll call carries session and tally', () async {
    final plan = await day('2026-11-18');
    final c = plan.classes.single;
    expect(c.taken, isTrue);
    expect(c.session?.occ, physOcc('2026-11-18'));
    expect(c.session?.id, Ids.sessionForOcc(physOcc('2026-11-18')));
    // Rahim absent, Sara and Nila present.
    expect(c.tally, const AttendanceTally(present: 2, absent: 1));
  });

  test('Sunday has Chem B for Karim and Sara', () async {
    final c = (await day('2026-11-22')).classes.single;
    expect(c.batch.id, kBatChemB);
    expect((c.startMin, c.endMin), (kChemStart, kChemEnd));
    expect(c.enrolledCount, 2);
  });

  test('cancelled class stays on the plan, struck, and follows the repo', () async {
    expect((await day('2026-11-23')).classes.single.cancelled, isFalse);

    await f.schedule.cancel(OccId.regular(kSlotPhysMon, d('2026-11-23')));
    final c = (await day('2026-11-23')).classes.single;
    expect(c.cancelled, isTrue);
    expect(c.state, ClassState.cancelled);
    expect(c.occurrence, isNull);
    expect((c.startMin, c.endMin), (kPhysStart, kPhysEnd));
  });

  test('rescheduled class moves to its new day with its origin', () async {
    await f.schedule.reschedule(OccId.regular(kSlotPhysMon, d('2026-11-23')),
        newDate: d('2026-11-24'), startMin: 660, endMin: 720);

    final from = await day('2026-11-23');
    expect(from.classes, isEmpty);
    expect(from.movedAway, hasLength(1));
    expect(from.movedAway.single.newDate, d('2026-11-24'));

    final to = await day('2026-11-24');
    expect(to.classes.map((c) => c.batch.id), [kBatChemB, kBatPhysA]);
    final moved = to.classes.last;
    expect(moved.state, ClassState.moved);
    expect(moved.originalDate, d('2026-11-23'));
    expect(moved.originalStartMin, kPhysStart);
    expect(moved.startMin, 660);
  });

  test('an extra class is tagged and sorted by start time', () async {
    await f.schedule
        .addExtra(batchId: kBatPhysA, date: kToday, startMin: 1080, endMin: 1140);
    final plan = await day('2026-11-21');
    expect(plan.classes.map((c) => c.startMin), [kPhysStart, 1080]);
    expect(plan.classes.last.state, ClassState.extra);
  });

  test('week plan has seven days with the seeded classes', () async {
    final week = await readData(c, weekPlanProvider(kToday));
    expect(week.map((p) => p.date), [for (var i = 0; i < 7; i++) kToday.addDays(i)]);
    // Sat, Sun, Mon, Tue, Wed have one class each; Thu and Fri none.
    expect(week.map((p) => p.classes.length), [1, 1, 1, 1, 1, 0, 0]);
  });

  test('legacy conflicts: none in the seed, one after an overlapping extra', () async {
    expect(await readData(c, legacyConflictsProvider), isEmpty);

    // Sunday 22 Nov 10:30-11:30 overlaps Chem B's 10:00-11:00.
    await f.schedule.addExtra(
        batchId: kBatPhysA, date: d('2026-11-22'), startMin: 630, endMin: 690);
    final clashes = await readData(c, legacyConflictsProvider);
    expect(clashes, hasLength(1));
    expect({clashes.single.candidate.batchId, clashes.single.existing.batchId},
        {kBatPhysA, kBatChemB});
  });
}
