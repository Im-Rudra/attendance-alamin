import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('YearMonth.fromInt / toInt', () {
    test('round trip', () {
      expect(YearMonth.fromInt(202611), const YearMonth(2026, 11));
      expect(const YearMonth(2026, 1).toInt(), 202601);
      expect(const YearMonth(2026, 12).toInt(), 202612);
      for (var y = 1999; y <= 2030; y++) {
        for (var m = 1; m <= 12; m++) {
          final ym = YearMonth(y, m);
          expect(YearMonth.fromInt(ym.toInt()), ym);
        }
      }
    });

    for (final bad in [202600, 202613, 202699, 0, 2026]) {
      test('fromInt($bad) throws', () {
        expect(() => YearMonth.fromInt(bad), throwsFormatException);
      });
    }
  });

  group('YearMonth.addMonths', () {
    // (start, n, expected)
    const table = <(YearMonth, int, YearMonth)>[
      (YearMonth(2026, 11), 0, YearMonth(2026, 11)),
      (YearMonth(2026, 11), 1, YearMonth(2026, 12)),
      (YearMonth(2026, 11), 2, YearMonth(2027, 1)),
      (YearMonth(2026, 12), 1, YearMonth(2027, 1)),
      (YearMonth(2026, 1), -1, YearMonth(2025, 12)),
      (YearMonth(2026, 11), -10, YearMonth(2026, 1)),
      (YearMonth(2026, 11), -11, YearMonth(2025, 12)),
      (YearMonth(2026, 11), -12, YearMonth(2025, 11)),
      (YearMonth(2026, 11), 12, YearMonth(2027, 11)),
      (YearMonth(2026, 11), 25, YearMonth(2028, 12)),
      (YearMonth(2026, 11), -23, YearMonth(2024, 12)),
      (YearMonth(2026, 11), -35, YearMonth(2023, 12)),
      (YearMonth(2026, 12), 12, YearMonth(2027, 12)),
      (YearMonth(2026, 1), 11, YearMonth(2026, 12)),
      (YearMonth(2026, 1), 12, YearMonth(2027, 1)),
    ];
    for (final (start, n, expected) in table) {
      test('$start + $n = $expected', () {
        expect(start.addMonths(n), expected);
        expect(start.monthsUntil(expected), n);
        expect(expected.monthsUntil(start), -n);
        expect(expected.addMonths(-n), start);
      });
    }
  });

  group('YearMonth days and ordering', () {
    // (month, lastDay)
    const lastDays = <(YearMonth, int)>[
      (YearMonth(2026, 1), 31),
      (YearMonth(2026, 2), 28),
      (YearMonth(2024, 2), 29),
      (YearMonth(1900, 2), 28),
      (YearMonth(2000, 2), 29),
      (YearMonth(2026, 4), 30),
      (YearMonth(2026, 9), 30),
      (YearMonth(2026, 11), 30),
      (YearMonth(2026, 12), 31),
    ];
    for (final (ym, last) in lastDays) {
      test('$ym has $last days', () {
        expect(ym.firstDay, LocalDate(ym.year, ym.month, 1));
        expect(ym.lastDay, LocalDate(ym.year, ym.month, last));
        expect(ym.lastDay.addDays(1), ym.addMonths(1).firstDay);
      });
    }

    test('compare, equality, hashCode, toString', () {
      const a = YearMonth(2026, 11);
      const b = YearMonth(2026, 12);
      const c = YearMonth(2027, 1);
      expect(a.isBefore(b), isTrue);
      expect(b.isBefore(c), isTrue);
      expect(c.isAfter(a), isTrue);
      expect(a.isBefore(a), isFalse);
      expect(a.isAfter(a), isFalse);
      expect(a.compareTo(a), 0);
      expect(c.compareTo(a), greaterThan(0));
      expect(a == const YearMonth(2026, 11), isTrue);
      expect(a.hashCode, const YearMonth(2026, 11).hashCode);
      expect(a == b, isFalse);
      expect(a.toString(), '2026-11');
      expect(const YearMonth(2026, 3).toString(), '2026-03');
      final sorted = [c, a, b]..sort();
      expect(sorted, [a, b, c]);
    });

    test('monthsUntil across years', () {
      expect(const YearMonth(2026, 11).monthsUntil(const YearMonth(2027, 2)), 3);
      expect(const YearMonth(2026, 1).monthsUntil(const YearMonth(2026, 1)), 0);
      expect(const YearMonth(2027, 1).monthsUntil(const YearMonth(2026, 1)), -12);
    });
  });
}
