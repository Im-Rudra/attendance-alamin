import 'package:attendance_alamin/core/time/local_date.dart';

/// A calendar month. DB form is INTEGER `yyyymm`.
class YearMonth implements Comparable<YearMonth> {
  const YearMonth(this.year, this.month);

  final int year;
  final int month;

  /// Parses `yyyymm` (e.g. 202611); throws [FormatException] for a month outside 1..12.
  static YearMonth fromInt(int yyyymm) {
    final y = yyyymm ~/ 100;
    final m = yyyymm % 100;
    if (m < 1 || m > 12) {
      throw FormatException('Invalid yyyymm', yyyymm.toString());
    }
    return YearMonth(y, m);
  }

  int toInt() => year * 100 + month;

  /// [n] may be negative.
  YearMonth addMonths(int n) {
    final total = year * 12 + (month - 1) + n;
    final m = total % 12; // Dart `%` is non-negative for a positive divisor.
    return YearMonth((total - m) ~/ 12, m + 1);
  }

  /// Signed number of months from this month to [o] (positive when [o] is later).
  int monthsUntil(YearMonth o) => (o.year - year) * 12 + (o.month - month);

  LocalDate get firstDay => LocalDate(year, month, 1);

  LocalDate get lastDay =>
      LocalDate(year, month, LocalDate.daysInMonth(year, month));

  bool isBefore(YearMonth o) => compareTo(o) < 0;
  bool isAfter(YearMonth o) => compareTo(o) > 0;

  @override
  int compareTo(YearMonth other) => toInt().compareTo(other.toInt());

  @override
  bool operator ==(Object other) =>
      other is YearMonth && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
}
