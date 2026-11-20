import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/domain/models/enums.dart';

/// A recurring weekly slot of a batch. [weekday] is ISO (Mon=1..Sun=7);
/// times are minutes from midnight on the center's wall clock.
class Slot {
  const Slot({
    required this.id,
    required this.batchId,
    required this.weekday,
    required this.startMin,
    required this.endMin,
    this.validFrom,
    this.validTo,
  });

  final String id;
  final String batchId;
  final int weekday;
  final int startMin;
  final int endMin;

  /// Inclusive; `null` = unbounded.
  final LocalDate? validFrom;

  /// Inclusive; `null` = unbounded.
  final LocalDate? validTo;

  /// Whether [d] lies within the validity window. Does NOT check the weekday
  /// (the schedule engine iterates matching weekdays itself).
  bool activeOn(LocalDate d) {
    final from = validFrom;
    final to = validTo;
    if (from != null && d.isBefore(from)) return false;
    if (to != null && d.isAfter(to)) return false;
    return true;
  }

  int get durationMin => endMin - startMin;

  @override
  bool operator ==(Object other) =>
      other is Slot &&
      other.id == id &&
      other.batchId == batchId &&
      other.weekday == weekday &&
      other.startMin == startMin &&
      other.endMin == endMin &&
      other.validFrom == validFrom &&
      other.validTo == validTo;

  @override
  int get hashCode =>
      Object.hash(id, batchId, weekday, startMin, endMin, validFrom, validTo);

  @override
  String toString() => 'Slot($id, $weekday $startMin-$endMin)';
}

/// A per-date change to the recurring schedule.
/// cancel: slotId + originalDate. reschedule: slotId + originalDate + new*.
/// extra: new* only.
class ScheduleException {
  const ScheduleException({
    required this.id,
    required this.batchId,
    required this.kind,
    this.slotId,
    this.originalDate,
    this.newDate,
    this.newStartMin,
    this.newEndMin,
    this.note,
  });

  final String id;
  final String batchId;
  final ExceptionKind kind;
  final String? slotId;
  final LocalDate? originalDate;
  final LocalDate? newDate;
  final int? newStartMin;
  final int? newEndMin;
  final String? note;

  @override
  bool operator ==(Object other) =>
      other is ScheduleException &&
      other.id == id &&
      other.batchId == batchId &&
      other.kind == kind &&
      other.slotId == slotId &&
      other.originalDate == originalDate &&
      other.newDate == newDate &&
      other.newStartMin == newStartMin &&
      other.newEndMin == newEndMin &&
      other.note == note;

  @override
  int get hashCode => Object.hash(id, batchId, kind, slotId, originalDate,
      newDate, newStartMin, newEndMin, note);

  @override
  String toString() => 'ScheduleException($id, ${kind.name})';
}
