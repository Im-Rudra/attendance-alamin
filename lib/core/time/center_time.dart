import 'package:attendance_alamin/core/time/clock.dart';
import 'package:attendance_alamin/core/time/local_date.dart';

/// The center's wall clock: a fixed offset from UTC (no DST). Bangladesh is UTC+6.
class CenterTime {
  const CenterTime(this.offsetMin);

  static const dhaka = CenterTime(360);

  final int offsetMin;

  static const int _msPerDay = 86400000;
  static const int _msPerMinute = 60000;

  /// The center's current date.
  LocalDate today(Clock clock) => LocalDate.fromUtc(clock.nowUtc(), offsetMin);

  /// Minutes since local midnight (0..1439).
  int minutesNow(Clock clock) {
    final ms = clock.nowUtc().millisecondsSinceEpoch + offsetMin * _msPerMinute;
    return (ms % _msPerDay) ~/ _msPerMinute;
  }

  /// The UTC instant of [minutes] past midnight on [date] at the center.
  DateTime toUtc(LocalDate date, int minutes) => date.toUtc(minutes, offsetMin);

  /// The center date containing the UTC epoch instant [epochMs].
  LocalDate dateOfEpochMs(int epochMs) => LocalDate.fromUtc(
        DateTime.fromMillisecondsSinceEpoch(epochMs, isUtc: true),
        offsetMin,
      );

  @override
  bool operator ==(Object other) =>
      other is CenterTime && other.offsetMin == offsetMin;

  @override
  int get hashCode => offsetMin.hashCode;

  @override
  String toString() => 'CenterTime($offsetMin min)';
}
