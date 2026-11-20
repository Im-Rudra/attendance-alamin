import 'package:attendance_alamin/core/time/year_month.dart';

/// A calendar date on the center's wall clock (no time zone, no time of day).
///
/// Pure value type. DB form is TEXT `'YYYY-MM-DD'`.
class LocalDate implements Comparable<LocalDate> {
  const LocalDate(this.year, this.month, this.day);

  final int year;
  final int month;
  final int day;

  static const int _msPerDay = 86400000;
  static final RegExp _isoRe = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
  static final RegExp _compactRe = RegExp(r'^(\d{4})(\d{2})(\d{2})$');

  static bool isLeapYear(int year) =>
      (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;

  /// Number of days in [month] (1..12) of [year].
  static int daysInMonth(int year, int month) {
    switch (month) {
      case 2:
        return isLeapYear(year) ? 29 : 28;
      case 4:
      case 6:
      case 9:
      case 11:
        return 30;
      default:
        return 31;
    }
  }

  /// Parses `'YYYY-MM-DD'`; throws [FormatException] otherwise (including
  /// impossible dates such as 2026-02-30).
  static LocalDate parse(String iso) {
    final m = _isoRe.firstMatch(iso);
    if (m == null) {
      throw FormatException('Invalid ISO date', iso);
    }
    return _validated(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
      iso,
    );
  }

  static LocalDate? tryParse(String? iso) {
    if (iso == null) return null;
    try {
      return parse(iso);
    } on FormatException {
      return null;
    }
  }

  /// Parses `'YYYYMMDD'`; throws [FormatException] otherwise.
  static LocalDate parseCompact(String yyyymmdd) {
    final m = _compactRe.firstMatch(yyyymmdd);
    if (m == null) {
      throw FormatException('Invalid compact date', yyyymmdd);
    }
    return _validated(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
      yyyymmdd,
    );
  }

  static LocalDate _validated(int y, int mo, int d, String source) {
    if (mo < 1 || mo > 12 || d < 1 || d > daysInMonth(y, mo)) {
      throw FormatException('Impossible date', source);
    }
    return LocalDate(y, mo, d);
  }

  /// Inverse of [epochDay] (days since 1970-01-01, may be negative).
  static LocalDate fromEpochDay(int epochDay) {
    // Howard Hinnant's civil_from_days.
    final z = epochDay + 719468;
    final era = (z >= 0 ? z : z - 146096) ~/ 146097;
    final doe = z - era * 146097; // [0, 146096]
    final yoe = (doe - doe ~/ 1460 + doe ~/ 36524 - doe ~/ 146096) ~/ 365;
    final doy = doe - (365 * yoe + yoe ~/ 4 - yoe ~/ 100); // [0, 365]
    final mp = (5 * doy + 2) ~/ 153; // [0, 11]
    final d = doy - (153 * mp + 2) ~/ 5 + 1;
    final m = mp < 10 ? mp + 3 : mp - 9;
    final y = yoe + era * 400 + (m <= 2 ? 1 : 0);
    return LocalDate(y, m, d);
  }

  /// The wall-clock date at UTC instant [utc] for a fixed [offsetMin].
  static LocalDate fromUtc(DateTime utc, int offsetMin) {
    final ms = utc.millisecondsSinceEpoch + offsetMin * 60000;
    // Dart `%` is non-negative for a positive divisor, so this is a floor division.
    return fromEpochDay((ms - (ms % _msPerDay)) ~/ _msPerDay);
  }

  /// Days since 1970-01-01.
  int get epochDay {
    // Howard Hinnant's days_from_civil.
    final y = month <= 2 ? year - 1 : year;
    final era = (y >= 0 ? y : y - 399) ~/ 400;
    final yoe = y - era * 400; // [0, 399]
    final mp = month > 2 ? month - 3 : month + 9; // March = 0
    final doy = (153 * mp + 2) ~/ 5 + day - 1; // [0, 365]
    final doe = yoe * 365 + yoe ~/ 4 - yoe ~/ 100 + doy; // [0, 146096]
    return era * 146097 + doe - 719468;
  }

  /// Monday = 1 ... Saturday = 6, Sunday = 7.
  int get isoWeekday => ((epochDay + 3) % 7) + 1;

  YearMonth get yearMonth => YearMonth(year, month);

  LocalDate addDays(int n) => fromEpochDay(epochDay + n);

  /// Signed number of days from this date to [other] (positive when [other] is later).
  int daysUntil(LocalDate other) => other.epochDay - epochDay;

  bool isBefore(LocalDate o) => compareTo(o) < 0;
  bool isAfter(LocalDate o) => compareTo(o) > 0;

  String toIso() => '${_pad(year, 4)}-${_pad(month, 2)}-${_pad(day, 2)}';

  String toCompact() => '${_pad(year, 4)}${_pad(month, 2)}${_pad(day, 2)}';

  /// The UTC instant at which the wall clock of this date reads [minutes]
  /// minutes past midnight, for a fixed [offsetMin]. [minutes] may be 1440.
  DateTime toUtc(int minutes, int offsetMin) =>
      DateTime.fromMillisecondsSinceEpoch(
        epochDay * _msPerDay + (minutes - offsetMin) * 60000,
        isUtc: true,
      );

  static String _pad(int v, int width) => v.toString().padLeft(width, '0');

  @override
  int compareTo(LocalDate other) {
    if (year != other.year) return year < other.year ? -1 : 1;
    if (month != other.month) return month < other.month ? -1 : 1;
    if (day != other.day) return day < other.day ? -1 : 1;
    return 0;
  }

  @override
  bool operator ==(Object other) =>
      other is LocalDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toIso();
}
