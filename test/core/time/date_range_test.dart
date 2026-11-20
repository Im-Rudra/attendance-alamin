import 'package:attendance_alamin/core/time/date_range.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DateRange', () {
    test('inclusive days within a month', () {
      final r = DateRange(LocalDate.parse('2026-11-19'), LocalDate.parse('2026-11-23'));
      expect(r.days.map((d) => d.toIso()).toList(), [
        '2026-11-19',
        '2026-11-20',
        '2026-11-21',
        '2026-11-22',
        '2026-11-23',
      ]);
      expect(r.length, 5);
      expect(r.isEmpty, isFalse);
    });

    test('single day', () {
      const d = LocalDate(2026, 11, 21);
      const r = DateRange(d, d);
      expect(r.days.toList(), [d]);
      expect(r.length, 1);
      expect(r.contains(d), isTrue);
    });

    test('reversed range is empty', () {
      final r = DateRange(LocalDate.parse('2026-11-22'), LocalDate.parse('2026-11-21'));
      expect(r.days, isEmpty);
      expect(r.length, 0);
      expect(r.isEmpty, isTrue);
      expect(r.contains(LocalDate.parse('2026-11-21')), isFalse);
    });

    test('rolls over month and year boundaries', () {
      final r = DateRange(LocalDate.parse('2026-12-30'), LocalDate.parse('2027-01-02'));
      expect(r.days.map((d) => d.toIso()).toList(), [
        '2026-12-30',
        '2026-12-31',
        '2027-01-01',
        '2027-01-02',
      ]);
    });

    test('includes leap day', () {
      final r = DateRange(LocalDate.parse('2024-02-27'), LocalDate.parse('2024-03-01'));
      expect(r.days.map((d) => d.toIso()).toList(), [
        '2024-02-27',
        '2024-02-28',
        '2024-02-29',
        '2024-03-01',
      ]);
      expect(
        DateRange(LocalDate.parse('2026-02-27'), LocalDate.parse('2026-03-01')).length,
        3,
      );
    });

    test('a full non-leap year has 365 days', () {
      final r = DateRange(LocalDate.parse('2026-01-01'), LocalDate.parse('2026-12-31'));
      expect(r.length, 365);
      expect(r.days.length, 365);
    });

    test('contains is inclusive at both ends', () {
      final r = DateRange(LocalDate.parse('2026-11-10'), LocalDate.parse('2026-11-20'));
      expect(r.contains(LocalDate.parse('2026-11-09')), isFalse);
      expect(r.contains(LocalDate.parse('2026-11-10')), isTrue);
      expect(r.contains(LocalDate.parse('2026-11-15')), isTrue);
      expect(r.contains(LocalDate.parse('2026-11-20')), isTrue);
      expect(r.contains(LocalDate.parse('2026-11-21')), isFalse);
    });

    test('equality and toString', () {
      const a = DateRange(LocalDate(2026, 11, 1), LocalDate(2026, 11, 5));
      const b = DateRange(LocalDate(2026, 11, 1), LocalDate(2026, 11, 5));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == const DateRange(LocalDate(2026, 11, 1), LocalDate(2026, 11, 6)), isFalse);
      expect(a.toString(), '2026-11-01..2026-11-05');
    });
  });
}
