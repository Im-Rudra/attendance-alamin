import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';

class Enrollment {
  const Enrollment({
    required this.id,
    required this.studentId,
    required this.batchId,
    required this.joinDate,
    required this.startMonth,
    this.endMonth,
    this.endDate,
    this.notes,
  });

  final String id;
  final String studentId;
  final String batchId;

  /// Drives roll-call listing.
  final LocalDate joinDate;

  /// First billable month.
  final YearMonth startMonth;

  /// Last billable month; `null` = open.
  final YearMonth? endMonth;

  /// Leave / end date (inclusive); `null` = still enrolled.
  final LocalDate? endDate;
  final String? notes;

  /// `joinDate <= d` and `d <= endDate` (when set), both inclusive.
  bool coversDate(LocalDate d) {
    if (d.isBefore(joinDate)) return false;
    final end = endDate;
    if (end != null && d.isAfter(end)) return false;
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is Enrollment &&
      other.id == id &&
      other.studentId == studentId &&
      other.batchId == batchId &&
      other.joinDate == joinDate &&
      other.startMonth == startMonth &&
      other.endMonth == endMonth &&
      other.endDate == endDate &&
      other.notes == notes;

  @override
  int get hashCode => Object.hash(
      id, studentId, batchId, joinDate, startMonth, endMonth, endDate, notes);

  @override
  String toString() => 'Enrollment($id, $studentId in $batchId)';
}
