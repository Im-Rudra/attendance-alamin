import 'package:attendance_alamin/core/time/local_date.dart';

/// An inclusive range of dates. Empty when [end] is before [start].
class DateRange {
  const DateRange(this.start, this.end);

  final LocalDate start;
  final LocalDate end;

  bool get isEmpty => end.isBefore(start);

  /// Number of days in the range (0 when empty).
  int get length => isEmpty ? 0 : start.daysUntil(end) + 1;

  /// Every date from [start] to [end] inclusive, in order.
  Iterable<LocalDate> get days sync* {
    final first = start.epochDay;
    final last = end.epochDay;
    for (var e = first; e <= last; e++) {
      yield LocalDate.fromEpochDay(e);
    }
  }

  bool contains(LocalDate d) => !d.isBefore(start) && !d.isAfter(end);

  @override
  bool operator ==(Object other) =>
      other is DateRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => '$start..$end';
}
