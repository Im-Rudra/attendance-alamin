// Today's pure logic: which class the hero shows, the day's attendance, the
// month's collection, recent receipts, the backup nudge and reminder-window
// rules, and the bento layout (every row sums to 12 columns).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/providers/schedule_providers.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/domain/attendance_stats/attendance_stats.dart';
import 'package:attendance_alamin/domain/models/attendance.dart';
import 'package:attendance_alamin/features/home/controllers/bento_layout.dart';
import 'package:attendance_alamin/features/home/controllers/today_model.dart';

import '../../helpers/fixtures.dart';

const int _day = 86400000;

DayClass cls(
  String occ,
  int start,
  int end, {
  bool taken = false,
  ClassState? state,
  AttendanceTally? tally,
}) =>
    DayClass(
      occ: occ,
      batch: kBatches.first,
      subjectName: 'S',
      startMin: start,
      endMin: end,
      state: state,
      session: taken
          ? AttendanceSession(
              id: 'sess-$occ',
              occ: occ,
              batchId: kBatPhysA,
              date: kToday,
              startMin: start,
              endMin: end,
            )
          : null,
      tally: tally,
    );

HeroState hero(List<DayClass> classes,
        {int nowMin = 600, bool batches = true, LocalDate? date}) =>
    buildHero(
      hasBatches: batches,
      date: date ?? kToday,
      today: kToday,
      nowMin: nowMin,
      classes: classes,
    );

void main() {
  group('hero', () {
    test('no batch at all gives the setup state', () {
      expect(hero(const <DayClass>[], batches: false).kind, HeroKind.noBatches);
    });

    test('a day without classes', () {
      expect(hero(const <DayClass>[]).kind, HeroKind.noClasses);
      // Only a cancelled class is still "no class".
      final DayClass c = DayClass(
        occ: 'c',
        batch: kBatches.first,
        subjectName: 'S',
        startMin: 700,
        endMin: 760,
        state: ClassState.cancelled,
      );
      expect(hero(<DayClass>[c]).kind, HeroKind.noClasses);
    });

    test('before the first class: next, with the minutes to wait', () {
      final HeroState h = hero(<DayClass>[cls('a', 960, 1020)]);
      expect(h.kind, HeroKind.next);
      expect(h.minutes, 360);
      expect(h.focus?.occ, 'a');
      expect((h.taken, h.total), (0, 1));
    });

    test('during a class: current, with the minutes left', () {
      final HeroState h = hero(<DayClass>[cls('a', 960, 1020)], nowMin: 990);
      expect(h.kind, HeroKind.current);
      expect(h.minutes, 30);
    });

    test('a taken class is skipped for the next one', () {
      final HeroState h = hero(
        <DayClass>[cls('a', 600, 660, taken: true), cls('b', 720, 780)],
        nowMin: 630,
      );
      expect(h.kind, HeroKind.next);
      expect(h.focus?.occ, 'b');
      expect(h.minutes, 90);
    });

    test('classes are over but one has no roll call: pending, the latest', () {
      final HeroState h = hero(
        <DayClass>[cls('a', 480, 540), cls('b', 600, 660, taken: true), cls('c', 700, 760)],
        nowMin: 900,
      );
      expect(h.kind, HeroKind.pending);
      expect(h.focus?.occ, 'c');
      expect((h.taken, h.total), (1, 3));
    });

    test('every class taken: all done with the counts', () {
      final HeroState h = hero(
        <DayClass>[cls('a', 480, 540, taken: true), cls('b', 600, 660, taken: true)],
        nowMin: 900,
      );
      expect(h.kind, HeroKind.allDone);
      expect((h.taken, h.total), (2, 2));
    });

    test('another date: counts, and a pill only for a past class without roll call', () {
      final List<DayClass> classes = <DayClass>[cls('a', 480, 540), cls('b', 600, 660, taken: true)];
      final HeroState future = hero(classes, date: kToday.addDays(5));
      expect(future.kind, HeroKind.otherDay);
      expect(future.focus, isNull);
      expect((future.taken, future.total), (1, 2));
      final HeroState past = hero(classes, date: kToday.addDays(-2));
      expect(past.focus?.occ, 'a');
    });
  });

  group('day attendance', () {
    test('sums roll calls and names the weakest class (two or more)', () {
      final DayAttendance a = buildDayAttendance(<DayClass>[
        cls('a', 480, 540, taken: true, tally: const AttendanceTally(present: 9, absent: 1)),
        cls('b', 600, 660, taken: true, tally: const AttendanceTally(present: 5, absent: 5)),
        cls('c', 700, 760),
      ]);
      expect((a.total, a.taken), (3, 2));
      expect(a.percent, 70); // 14 present of 20
      expect(a.lowest?.occ, 'b');
      expect(a.lowestPercent, 50);
    });

    test('one roll call has no "lowest"; none has no percent', () {
      final DayAttendance one = buildDayAttendance(<DayClass>[
        cls('a', 480, 540, taken: true, tally: const AttendanceTally(present: 3)),
      ]);
      expect(one.percent, 100);
      expect(one.lowest, isNull);
      final DayAttendance none = buildDayAttendance(<DayClass>[cls('a', 480, 540)]);
      expect(none.percent, isNull);
      expect((none.total, none.taken), (1, 0));
    });
  });

  group('collection', () {
    test('this month: money received by payment date, fees of the month, methods', () {
      final MonthCollection c = buildMonthCollection(
        today: kToday,
        terms: termsFor(kEnrollments),
        facts: const [],
        payments: kPayments,
      );
      // Only Sara's November payment (2 Nov, bKash) lies in the month.
      expect(c.collected, 1000);
      expect(c.byMethod.single.method.code, 'bkash');
      // Rahim + Sara + Nila in Physics A (1000) and Karim + Sara in Chem B (800).
      expect(c.expected, 4600);
      expect(c.percent, 21);
      expect(c.fraction, closeTo(1000 / 4600, 1e-9));
    });

    test('nobody enrolled: nothing expected, no percent', () {
      final MonthCollection c = buildMonthCollection(
        today: kToday,
        terms: const [],
        facts: const [],
        payments: const [],
      );
      expect((c.collected, c.expected), (0, 0));
      expect(c.percent, isNull);
      expect(c.byMethod, isEmpty);
    });
  });

  group('recent receipts', () {
    test('newest payment date first, one entry per receipt, limited', () {
      final List<RecentReceipt> r = recentReceipts(kPayments);
      expect(r.map((RecentReceipt x) => x.receiptId).toList(),
          <String>['rcp-4', 'rcp-2', 'rcp-3', 'rcp-1']);
      expect(recentReceipts(kPayments, limit: 2), hasLength(2));
      expect(r.first.total, 1000);
    });
  });

  group('backup nudge (F18)', () {
    BackupStatus s(int? last, {int days = 7, int students = 0, int now = 100 * _day}) =>
        backupStatus(lastExportMs: last, nowMs: now, reminderDays: days, studentCount: students);

    test('older than the reminder period is due', () {
      expect(s(100 * _day - 8 * _day).due, isTrue);
      expect(s(100 * _day - 8 * _day).daysAgo, 8);
      expect(s(100 * _day - 7 * _day).due, isFalse);
      expect(s(100 * _day - 1 * _day).daysAgo, 1);
    });

    test('never exported: due from ten students on', () {
      expect(s(null, students: 9).due, isFalse);
      expect(s(null, students: 10).due, isTrue);
      expect(s(null, students: 10).daysAgo, isNull);
    });

    test('reminders off: never due', () {
      expect(s(null, days: 0, students: 50).due, isFalse);
      expect(s(0, days: 0).due, isFalse);
    });
  });

  group('reminder window hint', () {
    int? left(bool enabled, int? until) =>
        reminderDaysLeft(enabled: enabled, plannedUntilMs: until, nowMs: 10 * _day);

    test('under three days left shows the hint with whole days', () {
      expect(left(true, 10 * _day + _day + 5), 1);
      expect(left(true, 10 * _day + 2 * _day + 5), 2);
      expect(left(true, 9 * _day), 0);
    });

    test('three days or more, off, or never planned: no hint', () {
      expect(left(true, 13 * _day), isNull);
      expect(left(false, 10 * _day), isNull);
      expect(left(true, null), isNull);
    });
  });

  group('week helpers', () {
    test('weeks start on the chosen weekday', () {
      // 2026-11-21 is a Saturday.
      expect(weekStartFor(kToday, 6), kToday);
      expect(weekStartFor(kToday.addDays(3), 6), kToday); // Tuesday
      expect(weekStartFor(kToday, 1), kToday.addDays(-5)); // Monday start
      expect(weekStartFor(kToday.addDays(6), 6), kToday); // Friday
    });

    test('the escalation bar rings today only in the first ten days', () {
      expect(escalationDayOf(const LocalDate(2026, 11, 5)), 5);
      expect(escalationDayOf(const LocalDate(2026, 11, 10)), 10);
      expect(escalationDayOf(const LocalDate(2026, 11, 11)), isNull);
    });
  });

  group('bento layout', () {
    for (final WindowClass wc in <WindowClass>[
      WindowClass.expanded,
      WindowClass.large,
      WindowClass.extraLarge,
    ]) {
      test('${wc.name}: tiles tile the 12-column grid exactly, every row sums to 12', () {
        final List<TileSlot> slots = bentoSlots(wc);
        final int rows = bentoRowCount(wc);
        final List<BentoPlacement> placements = <BentoPlacement>[
          for (final TileSlot s in slots)
            BentoPlacement(
              col: s.col,
              row: s.row,
              colSpan: s.colSpan,
              rowSpan: s.rowSpan,
              child: const SizedBox(),
            ),
        ];
        expect(BentoGrid.validate(placements, rows, 12), isNull);
        for (int r = 0; r < rows; r++) {
          final int sum = slots
              .where((TileSlot s) => s.row <= r && r < s.row + s.rowSpan)
              .fold<int>(0, (int a, TileSlot s) => a + s.colSpan);
          expect(sum, 12, reason: 'row $r of ${wc.name}');
        }
        // The timeline is the one tall tile: rows 2-3.
        final TileSlot tl = slots.firstWhere((TileSlot s) => s.tile == TodayTile.timeline);
        expect((tl.row, tl.rowSpan), (1, 2));
      });
    }

    test('expanded has four rows with quick actions; larger ones have three', () {
      expect(bentoRowCount(WindowClass.expanded), 4);
      expect(bentoRowCount(WindowClass.large), 3);
      expect(bentoRowCount(WindowClass.extraLarge), 3);
      expect(quickActionsInTopBar(WindowClass.expanded), isFalse);
      expect(quickActionsInTopBar(WindowClass.large), isTrue);
      expect(
        bentoSlots(WindowClass.extraLarge).any((TileSlot s) => s.tile == TodayTile.week),
        isTrue,
      );
      expect(
        bentoSlots(WindowClass.large).any((TileSlot s) => s.tile == TodayTile.recent),
        isTrue,
      );
    });
  });
}
