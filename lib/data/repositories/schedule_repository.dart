import 'package:attendance_alamin/core/time/date_range.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/drafts.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';

/// Resolution of an occurrence id (Arch 3.2a).
class OccurrenceInfo {
  const OccurrenceInfo({
    required this.batch,
    required this.subjectName,
    this.occurrence,
    this.cancelled = false,
  });

  final Batch batch;
  final String subjectName;

  /// Where / when the class actually is. For a cancelled class this is the
  /// class as it was scheduled; `null` when the id no longer matches a class
  /// (e.g. its slot ended before that date).
  final Occurrence? occurrence;
  final bool cancelled;
}

/// Weekly slots and one-off exceptions. Every write that can create an
/// overlap runs the schedule engine inside the repository and throws
/// `ScheduleClashException` (clash groups + free suggestions) instead of saving.
abstract interface class ScheduleRepository {
  Stream<List<BatchSchedule>> watchAllSchedules();

  /// Live check for the slot editor; [batchId] null = a batch not yet saved.
  /// Never throws for clashes.
  Future<SlotCheckResult> checkSlots(String? batchId, List<SlotDraft> slots,
      {required LocalDate from});

  /// Makes [slots] the batch's schedule from [from] on (Arch 3.2 split rules:
  /// the old version is end-dated at `from - 1`, past occurrences stay).
  Future<void> replaceSlots(String batchId, List<SlotDraft> slots,
      {required LocalDate from});

  Future<SlotCheckResult> checkSingle({
    required String batchId,
    required LocalDate date,
    required int startMin,
    required int endMin,
    String? replacingOcc,
  });

  /// Returns the new occurrence id `x.<id>`.
  Future<String> addExtra({
    required String batchId,
    required LocalDate date,
    required int startMin,
    required int endMin,
    String? note,
  });

  Future<void> reschedule(String occ,
      {required LocalDate newDate, required int startMin, required int endMin});

  /// Cancelling an extra class removes it.
  Future<void> cancel(String occ, {String? note});

  /// Un-cancel / un-move (clash-checked); also revives a removed extra.
  Future<void> restore(String occ);
  Future<void> deleteExtra(String occ);
  Future<OccurrenceInfo?> resolve(String occ);

  /// Cancels every regular / moved class of every live batch in [range];
  /// extras are left alone. Returns the number of cancelled classes.
  Future<int> cancelRange(DateRange range, {String? note});

  /// Restores every cancelled regular class whose original date is in [range]
  /// (clash-checked). Returns the number restored.
  Future<int> undoCancelRange(DateRange range);
}
