import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/errors/error_codes.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/schedule.dart';
import 'package:attendance_alamin/domain/models/value_equality.dart';

/// A batch with everything the schedule engine needs.
class BatchSchedule {
  const BatchSchedule({
    required this.batch,
    required this.subjectName,
    this.slots = const [],
    this.exceptions = const [],
  });

  final Batch batch;
  final String subjectName;
  final List<Slot> slots;
  final List<ScheduleException> exceptions;

  @override
  bool operator ==(Object other) =>
      other is BatchSchedule &&
      other.batch == batch &&
      other.subjectName == subjectName &&
      listEq(other.slots, slots) &&
      listEq(other.exceptions, exceptions);

  @override
  int get hashCode => Object.hash(batch, subjectName,
      Object.hashAll(slots), Object.hashAll(exceptions));
}

/// One effective class on [date] (after cancels / reschedules / extras).
class Occurrence {
  const Occurrence({
    required this.occ,
    required this.batchId,
    required this.date,
    required this.startMin,
    required this.endMin,
    required this.kind,
    this.slotId,
    this.exceptionId,
    this.originalDate,
    this.originalStartMin,
    this.originalEndMin,
  });

  final String occ;
  final String batchId;
  final LocalDate date;
  final int startMin;
  final int endMin;
  final OccurrenceKind kind;
  final String? slotId;
  final String? exceptionId;
  final LocalDate? originalDate;
  final int? originalStartMin;
  final int? originalEndMin;

  @override
  bool operator ==(Object other) =>
      other is Occurrence &&
      other.occ == occ &&
      other.batchId == batchId &&
      other.date == date &&
      other.startMin == startMin &&
      other.endMin == endMin &&
      other.kind == kind &&
      other.slotId == slotId &&
      other.exceptionId == exceptionId &&
      other.originalDate == originalDate &&
      other.originalStartMin == originalStartMin &&
      other.originalEndMin == originalEndMin;

  @override
  int get hashCode => Object.hash(occ, batchId, date, startMin, endMin, kind,
      slotId, exceptionId, originalDate, originalStartMin, originalEndMin);

  @override
  String toString() => 'Occurrence($occ, $date $startMin-$endMin)';
}

class CancelledOccurrence {
  const CancelledOccurrence({
    required this.occ,
    required this.batchId,
    required this.date,
    required this.startMin,
    required this.endMin,
    required this.exceptionId,
    this.note,
  });

  final String occ;
  final String batchId;
  final LocalDate date;
  final int startMin;
  final int endMin;
  final String exceptionId;
  final String? note;

  @override
  bool operator ==(Object other) =>
      other is CancelledOccurrence &&
      other.occ == occ &&
      other.batchId == batchId &&
      other.date == date &&
      other.startMin == startMin &&
      other.endMin == endMin &&
      other.exceptionId == exceptionId &&
      other.note == note;

  @override
  int get hashCode =>
      Object.hash(occ, batchId, date, startMin, endMin, exceptionId, note);
}

/// A regular class that was rescheduled away from [originalDate].
class MovedAway {
  const MovedAway({
    required this.occ,
    required this.batchId,
    required this.originalDate,
    required this.originalStartMin,
    required this.newDate,
    required this.newStartMin,
  });

  final String occ;
  final String batchId;
  final LocalDate originalDate;
  final int originalStartMin;
  final LocalDate newDate;
  final int newStartMin;

  @override
  bool operator ==(Object other) =>
      other is MovedAway &&
      other.occ == occ &&
      other.batchId == batchId &&
      other.originalDate == originalDate &&
      other.originalStartMin == originalStartMin &&
      other.newDate == newDate &&
      other.newStartMin == newStartMin;

  @override
  int get hashCode => Object.hash(
      occ, batchId, originalDate, originalStartMin, newDate, newStartMin);
}

class ExpandResult {
  const ExpandResult({
    this.occurrences = const [],
    this.cancelled = const [],
    this.movedAway = const [],
  });

  final List<Occurrence> occurrences;
  final List<CancelledOccurrence> cancelled;
  final List<MovedAway> movedAway;

  @override
  bool operator ==(Object other) =>
      other is ExpandResult &&
      listEq(other.occurrences, occurrences) &&
      listEq(other.cancelled, cancelled) &&
      listEq(other.movedAway, movedAway);

  @override
  int get hashCode => Object.hash(Object.hashAll(occurrences),
      Object.hashAll(cancelled), Object.hashAll(movedAway));
}

class Clash {
  const Clash({required this.candidate, required this.existing});

  final Occurrence candidate;
  final Occurrence existing;

  @override
  bool operator ==(Object other) =>
      other is Clash &&
      other.candidate == candidate &&
      other.existing == existing;

  @override
  int get hashCode => Object.hash(candidate, existing);
}

/// Clashes grouped for display. [everyWeek] -> "প্রতি রবিবার" (uses [weekday]);
/// otherwise [date] -> "২৬ নভে".
class ClashGroup {
  const ClashGroup({
    required this.batchId,
    required this.startMin,
    required this.endMin,
    required this.everyWeek,
    required this.weekday,
    required this.existingKind,
    required this.count,
    this.date,
  });

  final String batchId;
  final int startMin;
  final int endMin;
  final bool everyWeek;
  final int weekday;
  final LocalDate? date;
  final OccurrenceKind existingKind;
  final int count;

  @override
  bool operator ==(Object other) =>
      other is ClashGroup &&
      other.batchId == batchId &&
      other.startMin == startMin &&
      other.endMin == endMin &&
      other.everyWeek == everyWeek &&
      other.weekday == weekday &&
      other.date == date &&
      other.existingKind == existingKind &&
      other.count == count;

  @override
  int get hashCode => Object.hash(batchId, startMin, endMin, everyWeek,
      weekday, date, existingKind, count);
}

/// Nearest free start times for a class of [durationMin].
class FreeSuggestion {
  const FreeSuggestion({
    required this.durationMin,
    this.earlierStartMin,
    this.laterStartMin,
    this.preferredStartMin,
  });

  final int durationMin;
  final int? earlierStartMin;
  final int? laterStartMin;

  /// The start the user asked for; lets [primaryStartMin] measure the shift.
  /// (Added to the plan's contract; optional.) When `null`, later wins.
  final int? preferredStartMin;

  /// The suggestion with the smaller |shift| from the preferred start;
  /// a tie (or unknown preferred start) picks the later one.
  int? get primaryStartMin {
    final e = earlierStartMin;
    final l = laterStartMin;
    if (e == null) return l;
    if (l == null) return e;
    final p = preferredStartMin;
    if (p == null) return l;
    return (p - e).abs() < (l - p).abs() ? e : l;
  }

  @override
  bool operator ==(Object other) =>
      other is FreeSuggestion &&
      other.durationMin == durationMin &&
      other.earlierStartMin == earlierStartMin &&
      other.laterStartMin == laterStartMin &&
      other.preferredStartMin == preferredStartMin;

  @override
  int get hashCode => Object.hash(
      durationMin, earlierStartMin, laterStartMin, preferredStartMin);
}

class SlotCheckResult {
  const SlotCheckResult({this.groups = const [], this.suggestion});

  final List<ClashGroup> groups;
  final FreeSuggestion? suggestion;

  bool get ok => groups.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is SlotCheckResult &&
      listEq(other.groups, groups) &&
      other.suggestion == suggestion;

  @override
  int get hashCode => Object.hash(Object.hashAll(groups), suggestion);
}

/// Thrown by repositories when a slot / one-off change would clash.
final class ScheduleClashException extends AppException {
  const ScheduleClashException(this.result) : super(ErrorCodes.scheduleClash);

  final SlotCheckResult result;
}
