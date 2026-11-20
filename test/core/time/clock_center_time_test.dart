import 'package:attendance_alamin/core/time/center_time.dart';
import 'package:attendance_alamin/core/time/clock.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Clock', () {
    test('FixedClock returns its instant as UTC', () {
      final c = FixedClock(DateTime.utc(2026, 11, 21, 10, 30));
      expect(c.nowUtc(), DateTime.utc(2026, 11, 21, 10, 30));
      expect(c.nowUtc().isUtc, isTrue);
      expect(c.nowUtc(), c.nowUtc());
    });

    test('FixedClock converts a non-UTC instant to UTC', () {
      final local = DateTime.fromMillisecondsSinceEpoch(1000);
      expect(FixedClock(local).nowUtc().isUtc, isTrue);
      expect(FixedClock(local).nowUtc().millisecondsSinceEpoch, 1000);
    });

    test('SystemClock returns a UTC instant', () {
      expect(const SystemClock().nowUtc().isUtc, isTrue);
    });
  });

  group('CenterTime.dhaka (UTC+6)', () {
    const dhaka = CenterTime.dhaka;

    test('offset is 360 minutes', () {
      expect(dhaka.offsetMin, 360);
    });

    // (UTC instant, expected center date, expected minutes since midnight)
    final table = <(DateTime, String, int)>[
      (DateTime.utc(2026, 11, 20, 17, 59, 59, 999), '2026-11-20', 1439),
      (DateTime.utc(2026, 11, 20, 18), '2026-11-21', 0),
      (DateTime.utc(2026, 11, 20, 18, 1), '2026-11-21', 1),
      (DateTime.utc(2026, 11, 21, 6, 30), '2026-11-21', 750),
      (DateTime.utc(2026, 11, 21, 9, 59), '2026-11-21', 959),
      (DateTime.utc(2026, 11, 21, 10), '2026-11-21', 960),
      (DateTime.utc(2026, 11, 21, 17, 59), '2026-11-21', 1439),
      (DateTime.utc(2026, 11, 21, 18), '2026-11-22', 0),
      (DateTime.utc(2026, 12, 31, 18), '2027-01-01', 0),
      (DateTime.utc(2024, 2, 28, 23, 0), '2024-02-29', 300),
      (DateTime.utc(1969, 12, 31, 18), '1970-01-01', 0),
    ];
    for (final (utc, date, minutes) in table) {
      test('$utc -> $date, $minutes min', () {
        final clock = FixedClock(utc);
        expect(dhaka.today(clock).toIso(), date);
        expect(dhaka.minutesNow(clock), minutes);
        expect(dhaka.dateOfEpochMs(utc.millisecondsSinceEpoch).toIso(), date);
      });
    }

    test('toUtc maps wall-clock minutes back to UTC', () {
      const date = LocalDate(2026, 11, 21);
      expect(dhaka.toUtc(date, 0), DateTime.utc(2026, 11, 20, 18));
      expect(dhaka.toUtc(date, 960), DateTime.utc(2026, 11, 21, 10));
      expect(dhaka.toUtc(date, 1440), DateTime.utc(2026, 11, 21, 18));
      expect(dhaka.toUtc(date, 960).isUtc, isTrue);
    });

    test('toUtc then today/minutesNow round-trips', () {
      const date = LocalDate(2026, 12, 31);
      for (final minutes in [0, 1, 359, 360, 719, 720, 1000, 1439]) {
        final clock = FixedClock(dhaka.toUtc(date, minutes));
        expect(dhaka.today(clock), date);
        expect(dhaka.minutesNow(clock), minutes);
      }
    });
  });

  group('CenterTime other offsets', () {
    test('UTC+5:30', () {
      const t = CenterTime(330);
      final c = FixedClock(DateTime.utc(2026, 11, 20, 18, 29));
      expect(t.today(c).toIso(), '2026-11-20');
      expect(t.minutesNow(c), 1439);
      final c2 = FixedClock(DateTime.utc(2026, 11, 20, 18, 30));
      expect(t.today(c2).toIso(), '2026-11-21');
      expect(t.minutesNow(c2), 0);
    });

    test('UTC-5 (negative offset)', () {
      const t = CenterTime(-300);
      final c = FixedClock(DateTime.utc(2026, 11, 21, 4, 59));
      expect(t.today(c).toIso(), '2026-11-20');
      expect(t.minutesNow(c), 1439);
      final c2 = FixedClock(DateTime.utc(2026, 11, 21, 5));
      expect(t.today(c2).toIso(), '2026-11-21');
      expect(t.minutesNow(c2), 0);
    });

    test('equality', () {
      expect(const CenterTime(360), CenterTime.dhaka);
      expect(const CenterTime(360).hashCode, CenterTime.dhaka.hashCode);
      expect(const CenterTime(330) == CenterTime.dhaka, isFalse);
    });
  });
}
