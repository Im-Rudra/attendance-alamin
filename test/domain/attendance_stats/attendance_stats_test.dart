import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/domain/attendance_stats/attendance_stats.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';

const _p = AttendanceStatus.present;
const _a = AttendanceStatus.absent;
const _l = AttendanceStatus.late;
const _e = AttendanceStatus.leave;

void main() {
  group('AttendanceTally', () {
    test('empty has no percent', () {
      const t = AttendanceTally();
      expect(t.held, 0);
      expect(t.percent, isNull);
    });

    test('add increments only the matching counter', () {
      expect(const AttendanceTally().add(_p), const AttendanceTally(present: 1));
      expect(const AttendanceTally().add(_a), const AttendanceTally(absent: 1));
      expect(const AttendanceTally().add(_l), const AttendanceTally(late: 1));
      expect(const AttendanceTally().add(_e), const AttendanceTally(leave: 1));
    });

    final cases = <String, (AttendanceTally, int?)>{
      'all present': (const AttendanceTally(present: 10), 100),
      'all absent': (const AttendanceTally(absent: 4), 0),
      'late counts as attended':
          (const AttendanceTally(late: 2, absent: 2), 50),
      'leave excluded from denominator':
          (const AttendanceTally(present: 3, absent: 1, leave: 4), 75),
      'only leave -> null': (const AttendanceTally(leave: 3), null),
      '2 of 3 = 66.67 -> 67':
          (const AttendanceTally(present: 2, absent: 1), 67),
      '1 of 3 = 33.33 -> 33':
          (const AttendanceTally(present: 1, absent: 2), 33),
      '1 of 8 = 12.5 -> 13 (half up)':
          (const AttendanceTally(present: 1, absent: 7), 13),
      '3 of 8 = 37.5 -> 38 (half up)':
          (const AttendanceTally(present: 2, late: 1, absent: 5), 38),
    };
    cases.forEach((name, c) {
      test('percent: $name', () => expect(c.$1.percent, c.$2));
    });

    test('held includes leave', () {
      expect(
          const AttendanceTally(present: 1, absent: 1, late: 1, leave: 1).held,
          4);
    });
  });

  group('AttendanceStats.tally', () {
    test('counts multiple sessions on the same day separately', () {
      expect(AttendanceStats.tally([_p, _a, _p]).percent, 67);
      expect(AttendanceStats.tally([_p, _a, _p]).held, 3);
    });
    test('empty iterable', () {
      expect(AttendanceStats.tally(const []).percent, isNull);
    });
  });

  group('AttendanceStats.tallyWithin (enrollment bounds)', () {
    final sessions = <({LocalDate date, AttendanceStatus status})>[
      (date: const LocalDate(2026, 11, 1), status: _a), // before join
      (date: const LocalDate(2026, 11, 5), status: _p),
      (date: const LocalDate(2026, 11, 5), status: _a), // second class same day
      (date: const LocalDate(2026, 11, 10), status: _l),
      (date: const LocalDate(2026, 11, 20), status: _a), // after leaving
    ];
    test('join and end date bound the denominator (inclusive)', () {
      final t = AttendanceStats.tallyWithin(sessions,
          from: const LocalDate(2026, 11, 5),
          to: const LocalDate(2026, 11, 10));
      expect(t, const AttendanceTally(present: 1, absent: 1, late: 1));
      expect(t.percent, 67);
    });
    test('open-ended enrollment keeps later sessions', () {
      final t = AttendanceStats.tallyWithin(sessions,
          from: const LocalDate(2026, 11, 5));
      expect(t.held, 4);
    });
    test('no bounds counts everything', () {
      expect(AttendanceStats.tallyWithin(sessions).held, 5);
    });
    test('no sessions in range -> null percent', () {
      final t = AttendanceStats.tallyWithin(sessions,
          from: const LocalDate(2026, 12, 1));
      expect(t.percent, isNull);
    });
  });

  group('AttendanceStats.meanPercent', () {
    test('mean of non-null percents, nulls ignored', () {
      final m = AttendanceStats.meanPercent(const [
        AttendanceTally(present: 1), // 100
        AttendanceTally(absent: 1), // 0
        AttendanceTally(leave: 2), // null
      ]);
      expect(m, 50);
    });
    test('all null -> null', () {
      expect(AttendanceStats.meanPercent(const [AttendanceTally()]), isNull);
      expect(AttendanceStats.meanPercent(const []), isNull);
    });
    test('rounds half up', () {
      // 100 and 67 -> 83.5 -> 84
      expect(
          AttendanceStats.meanPercent(const [
            AttendanceTally(present: 1),
            AttendanceTally(present: 2, absent: 1),
          ]),
          84);
    });
  });

  group('AttendanceStats.absenceStreak', () {
    final cases = <String, (List<AttendanceStatus>, bool)>{
      'three absences': ([_a, _a, _a], true),
      'only last three matter': ([_p, _a, _a, _a], true),
      'two absences not enough': ([_a, _a], false),
      'empty': ([], false),
      'present breaks': ([_a, _a, _p, _a], false),
      'late breaks': ([_a, _a, _l, _a], false),
      'latest present resets': ([_a, _a, _a, _p], false),
      'latest late resets': ([_a, _a, _a, _l], false),
      'leave does not break': ([_a, _e, _a, _e, _a], true),
      'leave at end is skipped': ([_a, _a, _a, _e], true),
      'leave does not count toward length': ([_a, _a, _e], false),
      'leave then present still breaks': ([_a, _a, _p, _e, _a], false),
      'two absences on one day count as two': ([_p, _a, _a, _a], true),
    };
    cases.forEach((name, c) {
      test(name, () => expect(AttendanceStats.absenceStreak(c.$1), c.$2));
    });
    test('custom length', () {
      expect(AttendanceStats.absenceStreak([_p, _a, _a], length: 2), isTrue);
      expect(AttendanceStats.absenceStreak([_a, _a], length: 5), isFalse);
    });
  });
}
