import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/domain/attendance_stats/attendance_stats.dart';
import 'package:attendance_alamin/domain/models/attendance.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';

/// Creates an extra-class exception (clash-checked) and returns its occurrence
/// id `x.<id>`. Same shape as `ScheduleRepository.addExtra` (plan M4-A), so a
/// tear-off of it can be passed directly. Must write through the same
/// `AppDatabase` so it joins the caller's transaction.
typedef AddExtraClass = Future<String> Function({
  required String batchId,
  required LocalDate date,
  required int startMin,
  required int endMin,
  String? note,
});

class SessionSummary {
  const SessionSummary({required this.session, required this.tally});

  final AttendanceSession session;
  final AttendanceTally tally;

  @override
  bool operator ==(Object other) =>
      other is SessionSummary && other.session == session && other.tally == tally;

  @override
  int get hashCode => Object.hash(session, tally);

  @override
  String toString() => 'SessionSummary(${session.occ}, $tally)';
}

/// Roll calls per class occurrence (Arch 3.2a, Product 3.6). Session id =
/// `v5("ses:"+occ)`, mark id = `v5("att:"+occ+":"+studentId)`, so re-saving a
/// roll call reuses the same rows.
abstract interface class AttendanceRepository {
  Future<(AttendanceSession, List<AttendanceRecord>)?> getSession(String occ);

  /// Upserts the session and one mark per entry of [statuses] (marks of
  /// students no longer listed are tombstoned) in one transaction.
  /// [removeCancel] also tombstones the occurrence's cancel exception.
  /// Throws `rollCallFutureDate`, `batchArchived`, `slotTimeInvalid`.
  Future<void> saveRollCall({
    required Occurrence occurrence,
    required Map<String, AttendanceStatus> statuses,
    String? note,
    bool removeCancel = false,
  });

  /// Roll call where the batch has no class: creates the extra class through
  /// [AddExtraClass] (clash-checked; a clash throws and nothing is written),
  /// then the session and marks, all in one transaction. Returns the occ.
  Future<String> saveAdHocRollCall({
    required String batchId,
    required LocalDate date,
    required int startMin,
    required int endMin,
    required Map<String, AttendanceStatus> statuses,
  });

  /// "ক্লাস হয়নি": tombstones the session and its marks.
  Future<void> deleteSession(String occ);

  /// Live sessions (filters inclusive) with their tallies, by date then start.
  Stream<List<SessionSummary>> watchSummaries(
      {String? batchId, LocalDate? from, LocalDate? to});

  /// Live marks of live sessions, by session date then start time.
  Stream<List<AttendanceRecord>> watchRecords({String? studentId, String? batchId});
}
