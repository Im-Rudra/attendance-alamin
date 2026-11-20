import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/domain/models/enums.dart';

/// Result of asking the OS for notification permission.
enum ReminderPermission { granted, exactDenied, denied, unsupported }

/// One notification the planner wants scheduled.
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.fireAtUtc,
    required this.occ,
    required this.batchId,
    required this.date,
    required this.startMin,
    required this.endMin,
    required this.kind,
    required this.leadMin,
    required this.payload,
  });

  /// `fnv1a31(occ)`.
  final int id;
  final DateTime fireAtUtc;
  final String occ;
  final String batchId;
  final LocalDate date;
  final int startMin;
  final int endMin;
  final OccurrenceKind kind;
  final int leadMin;

  /// `rollcall|<occ>`.
  final String payload;

  @override
  bool operator ==(Object other) =>
      other is PlannedReminder &&
      other.id == id &&
      other.fireAtUtc == fireAtUtc &&
      other.occ == occ &&
      other.batchId == batchId &&
      other.date == date &&
      other.startMin == startMin &&
      other.endMin == endMin &&
      other.kind == kind &&
      other.leadMin == leadMin &&
      other.payload == payload;

  @override
  int get hashCode => Object.hash(id, fireAtUtc, occ, batchId, date, startMin,
      endMin, kind, leadMin, payload);

  @override
  String toString() => 'PlannedReminder($occ @ $fireAtUtc)';
}
