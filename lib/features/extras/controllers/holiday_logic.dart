// Live previews for the holiday screen (F28): how many classes a closure would
// cancel, and how many cancelled classes an undo would bring back. Uses the
// same schedule engine as `ScheduleRepository.cancelRange`, so the preview
// number is the number the action returns.

import 'package:attendance_alamin/core/time/date_range.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/schedule/schedule_engine.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';

class HolidayPreview {
  const HolidayPreview({this.classes = 0, this.batches = 0});

  final int classes;
  final int batches;

  bool get isEmpty => classes == 0;
}

/// Regular and moved classes of live batches that fall in [range] (extras are
/// left alone), with the number of batches they belong to.
HolidayPreview previewCancel(List<BatchSchedule> schedules, DateRange range) {
  if (range.isEmpty) return const HolidayPreview();
  final ExpandResult result = ScheduleEngine.expand(range: range, batches: schedules);
  final Set<String> batches = <String>{};
  int classes = 0;
  for (final Occurrence o in result.occurrences) {
    if (o.kind == OccurrenceKind.extra || o.slotId == null) continue;
    classes++;
    batches.add(o.batchId);
  }
  return HolidayPreview(classes: classes, batches: batches.length);
}

/// Cancelled regular classes whose date is in [range].
HolidayPreview previewRestore(List<BatchSchedule> schedules, DateRange range) {
  if (range.isEmpty) return const HolidayPreview();
  final ExpandResult result = ScheduleEngine.expand(range: range, batches: schedules);
  return HolidayPreview(
    classes: result.cancelled.length,
    batches: <String>{for (final CancelledOccurrence c in result.cancelled) c.batchId}.length,
  );
}
