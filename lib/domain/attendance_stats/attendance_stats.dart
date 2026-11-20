import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/domain/models/enums.dart';

/// Counts of held sessions by status for one student over some period.
class AttendanceTally {
  const AttendanceTally({
    this.present = 0,
    this.absent = 0,
    this.late = 0,
    this.leave = 0,
  });

  final int present;
  final int absent;
  final int late;
  final int leave;

  /// Sessions held (every status counts).
  int get held => present + absent + late + leave;

  /// (present + late) / (held - leave), whole percent rounded half-up;
  /// `null` when the denominator is 0 (shown as a dash).
  int? get percent {
    final den = held - leave;
    if (den <= 0) return null;
    return (200 * (present + late) + den) ~/ (2 * den);
  }

  AttendanceTally add(AttendanceStatus s) {
    switch (s) {
      case AttendanceStatus.present:
        return AttendanceTally(
            present: present + 1, absent: absent, late: late, leave: leave);
      case AttendanceStatus.absent:
        return AttendanceTally(
            present: present, absent: absent + 1, late: late, leave: leave);
      case AttendanceStatus.late:
        return AttendanceTally(
            present: present, absent: absent, late: late + 1, leave: leave);
      case AttendanceStatus.leave:
        return AttendanceTally(
            present: present, absent: absent, late: late, leave: leave + 1);
    }
  }

  @override
  bool operator ==(Object other) =>
      other is AttendanceTally &&
      other.present == present &&
      other.absent == absent &&
      other.late == late &&
      other.leave == leave;

  @override
  int get hashCode => Object.hash(present, absent, late, leave);

  @override
  String toString() => 'AttendanceTally(P$present A$absent L$late E$leave)';
}

abstract final class AttendanceStats {
  /// Tally of [statuses]; one entry per held session (per occurrence).
  static AttendanceTally tally(Iterable<AttendanceStatus> statuses) {
    var t = const AttendanceTally();
    for (final s in statuses) {
      t = t.add(s);
    }
    return t;
  }

  /// Tally of the sessions dated within an enrollment: [from] (join date) and
  /// [to] (leave/end date) are inclusive and optional. Sessions outside the
  /// range are not "held while enrolled" and never enter the denominator.
  /// (Additive helper, not in the plan's contract.)
  static AttendanceTally tallyWithin(
    Iterable<({LocalDate date, AttendanceStatus status})> sessions, {
    LocalDate? from,
    LocalDate? to,
  }) {
    return tally(sessions
        .where((s) =>
            (from == null || !s.date.isBefore(from)) &&
            (to == null || !s.date.isAfter(to)))
        .map((s) => s.status));
  }

  /// Batch % = mean of the students' non-null percents, rounded half-up;
  /// `null` when no student has a percent.
  static int? meanPercent(Iterable<AttendanceTally> perStudent) {
    var sum = 0;
    var n = 0;
    for (final t in perStudent) {
      final p = t.percent;
      if (p == null) continue;
      sum += p;
      n++;
    }
    if (n == 0) return null;
    return (2 * sum + n) ~/ (2 * n);
  }

  /// True when the last [length] held sessions that are not leave are all
  /// absent. [chronological] is oldest first. Leave is skipped (does not break
  /// the streak, does not count toward it); late or present breaks it.
  static bool absenceStreak(
    List<AttendanceStatus> chronological, {
    int length = 3,
  }) {
    if (length <= 0) return false;
    var seen = 0;
    for (var i = chronological.length - 1; i >= 0 && seen < length; i--) {
      final s = chronological[i];
      if (s == AttendanceStatus.leave) continue;
      if (s != AttendanceStatus.absent) return false;
      seen++;
    }
    return seen == length;
  }
}
