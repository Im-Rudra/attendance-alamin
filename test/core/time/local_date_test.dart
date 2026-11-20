import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalDate.epochDay / fromEpochDay', () {
    // Reference values computed independently (Python datetime.date).
    const table = <(String, int, int)>[
      ('1970-01-01', 0, 4),
      ('1969-12-31', -1, 3),
      ('2000-01-01', 10957, 6),
      ('2000-02-29', 11016, 2),
      ('2024-02-29', 19782, 4),
      ('2026-11-21', 20778, 6),
      ('2026-12-31', 20818, 4),
      ('2027-01-01', 20819, 5),
      ('1900-03-01', -25508, 4),
      ('2100-03-01', 47541, 1),
      ('0001-01-01', -719162, 1),
      ('9999-12-31', 2932896, 5),
    ];
    for (final (iso, epochDay, weekday) in table) {
      test('$iso = day $epochDay, ISO weekday $weekday', () {
        final d = LocalDate.parse(iso);
        expect(d.epochDay, epochDay);
        expect(d.isoWeekday, weekday);
        expect(LocalDate.fromEpochDay(epochDay), d);
      });
    }

    test('matches DateTime.utc for every day in -40000..60000', () {
      for (var e = -40000; e <= 60000; e++) {
        final ref = DateTime.fromMillisecondsSinceEpoch(
          e * 86400000,
          isUtc: true,
        );
        final d = LocalDate.fromEpochDay(e);
        if (d.year != ref.year ||
            d.month != ref.month ||
            d.day != ref.day ||
            d.isoWeekday != ref.weekday ||
            d.epochDay != e) {
          fail('epochDay $e: got $d / weekday ${d.isoWeekday}, '
              'expected ${ref.year}-${ref.month}-${ref.day} / ${ref.weekday}');
        }
      }
    });

    test('2026-11-21 is a Saturday (acceptance seed date)', () {
      expect(const LocalDate(2026, 11, 21).isoWeekday, 6);
      expect(const LocalDate(2026, 11, 22).isoWeekday, 7);
      expect(const LocalDate(2026, 11, 23).isoWeekday, 1);
    });
  });

  group('LocalDate.parse / tryParse / compact', () {
    test('parses valid ISO dates', () {
      expect(LocalDate.parse('2026-11-05'), const LocalDate(2026, 11, 5));
      expect(LocalDate.parse('2024-02-29'), const LocalDate(2024, 2, 29));
    });

    const invalid = <String>[
      '',
      '2026-1-1',
      '2026-11-5',
      '26-11-05',
      '2026/11/05',
      '2026-11-05 ',
      ' 2026-11-05',
      '2026-13-01',
      '2026-00-10',
      '2026-11-00',
      '2026-11-31',
      '2026-02-29',
      '2026-02-30',
      '1900-02-29',
      '২০২৬-১১-০৫',
      'abcd-ef-gh',
    ];
    for (final s in invalid) {
      test('rejects "$s"', () {
        expect(() => LocalDate.parse(s), throwsFormatException);
        expect(LocalDate.tryParse(s), isNull);
      });
    }

    test('tryParse(null) is null', () {
      expect(LocalDate.tryParse(null), isNull);
    });

    test('leap years', () {
      expect(LocalDate.tryParse('2000-02-29'), isNotNull);
      expect(LocalDate.tryParse('2024-02-29'), isNotNull);
      expect(LocalDate.tryParse('1900-02-29'), isNull);
      expect(LocalDate.tryParse('2100-02-29'), isNull);
      expect(LocalDate.isLeapYear(2000), isTrue);
      expect(LocalDate.isLeapYear(1900), isFalse);
      expect(LocalDate.isLeapYear(2028), isTrue);
      expect(LocalDate.isLeapYear(2026), isFalse);
    });

    test('daysInMonth', () {
      const expected2026 = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
      for (var m = 1; m <= 12; m++) {
        expect(LocalDate.daysInMonth(2026, m), expected2026[m - 1]);
      }
      expect(LocalDate.daysInMonth(2024, 2), 29);
    });

    test('toIso / toCompact / parseCompact round trip', () {
      const d = LocalDate(2026, 3, 7);
      expect(d.toIso(), '2026-03-07');
      expect(d.toCompact(), '20260307');
      expect(d.toString(), '2026-03-07');
      expect(LocalDate.parseCompact('20260307'), d);
      expect(const LocalDate(5, 1, 2).toIso(), '0005-01-02');
      for (var e = 19000; e < 22000; e += 7) {
        final x = LocalDate.fromEpochDay(e);
        expect(LocalDate.parse(x.toIso()), x);
        expect(LocalDate.parseCompact(x.toCompact()), x);
      }
    });

    for (final s in ['2026-11-05', '2026110', '202611055', 'abcdefgh', '', '20261305']) {
      test('parseCompact rejects "$s"', () {
        expect(() => LocalDate.parseCompact(s), throwsFormatException);
      });
    }
  });

  group('LocalDate.addDays / daysUntil', () {
    // (start, n, expected)
    const table = <(String, int, String)>[
      ('2026-11-05', 0, '2026-11-05'),
      ('2026-11-05', 1, '2026-11-06'),
      ('2026-11-30', 1, '2026-12-01'),
      ('2026-12-31', 1, '2027-01-01'),
      ('2027-01-01', -1, '2026-12-31'),
      ('2024-02-28', 1, '2024-02-29'),
      ('2024-02-28', 2, '2024-03-01'),
      ('2024-03-01', -1, '2024-02-29'),
      ('2026-02-28', 1, '2026-03-01'),
      ('2026-03-01', -1, '2026-02-28'),
      ('2026-01-31', 30, '2026-03-02'),
      ('2026-11-21', 7, '2026-11-28'),
      ('2026-11-21', -21, '2026-10-31'),
      ('2026-01-01', 365, '2027-01-01'),
      ('2024-01-01', 366, '2025-01-01'),
      ('2026-11-21', 400, '2027-12-26'),
      ('1999-12-31', 1, '2000-01-01'),
      ('2000-03-01', -1, '2000-02-29'),
    ];
    for (final (start, n, expected) in table) {
      test('$start + $n = $expected', () {
        final d = LocalDate.parse(start).addDays(n);
        expect(d.toIso(), expected);
        expect(LocalDate.parse(start).daysUntil(d), n);
        expect(d.daysUntil(LocalDate.parse(start)), -n);
      });
    }

    test('isBefore / isAfter / compareTo / equality / hashCode', () {
      const a = LocalDate(2026, 11, 5);
      const b = LocalDate(2026, 11, 6);
      const c = LocalDate(2026, 12, 1);
      const d = LocalDate(2027, 1, 1);
      expect(a.isBefore(b), isTrue);
      expect(b.isBefore(a), isFalse);
      expect(a.isBefore(a), isFalse);
      expect(d.isAfter(c), isTrue);
      expect(a.isAfter(a), isFalse);
      expect(a.compareTo(a), 0);
      expect(a.compareTo(b), lessThan(0));
      expect(d.compareTo(c), greaterThan(0));
      expect(c.compareTo(b), greaterThan(0));
      expect(a == const LocalDate(2026, 11, 5), isTrue);
      expect(a.hashCode, const LocalDate(2026, 11, 5).hashCode);
      expect(a == b, isFalse);
      final sorted = [d, b, c, a]..sort();
      expect(sorted, [a, b, c, d]);
    });

    test('yearMonth', () {
      expect(const LocalDate(2026, 11, 5).yearMonth.toInt(), 202611);
    });
  });

  group('LocalDate.fromUtc / toUtc (UTC+6 boundary)', () {
    test('17:59:59.999 UTC is still the previous day at UTC+6', () {
      final d = LocalDate.fromUtc(DateTime.utc(2026, 11, 20, 17, 59, 59, 999), 360);
      expect(d, const LocalDate(2026, 11, 20));
    });

    test('18:00 UTC is the next day at UTC+6', () {
      final d = LocalDate.fromUtc(DateTime.utc(2026, 11, 20, 18), 360);
      expect(d, const LocalDate(2026, 11, 21));
    });

    test('year rollover at UTC+6', () {
      expect(
        LocalDate.fromUtc(DateTime.utc(2026, 12, 31, 18), 360),
        const LocalDate(2027, 1, 1),
      );
      expect(
        LocalDate.fromUtc(DateTime.utc(2026, 12, 31, 17, 59), 360),
        const LocalDate(2026, 12, 31),
      );
    });

    test('leap day boundary at UTC+6', () {
      expect(
        LocalDate.fromUtc(DateTime.utc(2024, 2, 28, 18), 360),
        const LocalDate(2024, 2, 29),
      );
      expect(
        LocalDate.fromUtc(DateTime.utc(2024, 2, 29, 18), 360),
        const LocalDate(2024, 3, 1),
      );
    });

    test('negative offset (UTC-5)', () {
      expect(
        LocalDate.fromUtc(DateTime.utc(2026, 11, 21, 4, 59), -300),
        const LocalDate(2026, 11, 20),
      );
      expect(
        LocalDate.fromUtc(DateTime.utc(2026, 11, 21, 5), -300),
        const LocalDate(2026, 11, 21),
      );
    });

    test('offset zero and pre-1970 instants', () {
      expect(
        LocalDate.fromUtc(DateTime.utc(1969, 12, 31, 23, 59), 0),
        const LocalDate(1969, 12, 31),
      );
      expect(
        LocalDate.fromUtc(DateTime.utc(1969, 12, 31, 18), 360),
        const LocalDate(1970, 1, 1),
      );
    });

    // (minutes, expected UTC)
    final toUtcTable = <(int, DateTime)>[
      (0, DateTime.utc(2026, 11, 20, 18)),
      (60, DateTime.utc(2026, 11, 20, 19)),
      (360, DateTime.utc(2026, 11, 21)),
      (600, DateTime.utc(2026, 11, 21, 4)),
      (990, DateTime.utc(2026, 11, 21, 10, 30)),
      (1439, DateTime.utc(2026, 11, 21, 17, 59)),
      (1440, DateTime.utc(2026, 11, 21, 18)),
    ];
    for (final (minutes, expected) in toUtcTable) {
      test('2026-11-21 + $minutes min at UTC+6 = $expected', () {
        final utc = const LocalDate(2026, 11, 21).toUtc(minutes, 360);
        expect(utc, expected);
        expect(utc.isUtc, isTrue);
      });
    }

    test('toUtc then fromUtc round-trips the date', () {
      for (var e = 20700; e < 20900; e++) {
        final d = LocalDate.fromEpochDay(e);
        for (final minutes in [0, 1, 719, 720, 1439]) {
          expect(LocalDate.fromUtc(d.toUtc(minutes, 360), 360), d);
        }
      }
    });
  });
}
