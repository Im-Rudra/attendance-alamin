import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/domain/models/enums.dart';

/// "Roll call was taken" for one class occurrence ([occ], architecture 3.2a).
class AttendanceSession {
  const AttendanceSession({
    required this.id,
    required this.occ,
    required this.batchId,
    required this.date,
    required this.startMin,
    required this.endMin,
    this.slotId,
    this.originalDate,
    this.exceptionId,
    this.note,
  });

  final String id;
  final String occ;
  final String batchId;
  final String? slotId;
  final LocalDate? originalDate;
  final String? exceptionId;

  /// The date the class actually happened.
  final LocalDate date;
  final int startMin;
  final int endMin;
  final String? note;

  @override
  bool operator ==(Object other) =>
      other is AttendanceSession &&
      other.id == id &&
      other.occ == occ &&
      other.batchId == batchId &&
      other.slotId == slotId &&
      other.originalDate == originalDate &&
      other.exceptionId == exceptionId &&
      other.date == date &&
      other.startMin == startMin &&
      other.endMin == endMin &&
      other.note == note;

  @override
  int get hashCode => Object.hash(id, occ, batchId, slotId, originalDate,
      exceptionId, date, startMin, endMin, note);

  @override
  String toString() => 'AttendanceSession($occ)';
}

class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.sessionId,
    required this.batchId,
    required this.studentId,
    required this.date,
    required this.status,
  });

  final String id;
  final String sessionId;
  final String batchId;
  final String studentId;
  final LocalDate date;
  final AttendanceStatus status;

  @override
  bool operator ==(Object other) =>
      other is AttendanceRecord &&
      other.id == id &&
      other.sessionId == sessionId &&
      other.batchId == batchId &&
      other.studentId == studentId &&
      other.date == date &&
      other.status == status;

  @override
  int get hashCode =>
      Object.hash(id, sessionId, batchId, studentId, date, status);

  @override
  String toString() => 'AttendanceRecord($studentId ${status.code})';
}
