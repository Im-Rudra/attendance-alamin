// Class-time clashes that a backup merge would create (Product 4, "conflict
// detection after merge"): weekly slots of different batches that overlap in
// time once the incoming slots are in. Pure Dart, tested without widgets.

import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/domain/models/schedule.dart';
import 'package:attendance_alamin/domain/schedule/schedule_engine.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';
import 'package:attendance_alamin/domain/sync/sync_models.dart';

/// Two weekly slots of different batches that overlap after the merge.
class MergeClash {
  const MergeClash({
    required this.weekday,
    required this.startMin,
    required this.endMin,
    required this.batchAId,
    required this.batchBId,
  });

  /// ISO weekday (Mon 1 .. Sun 7).
  final int weekday;

  /// The overlapping part of the two slots, minutes from midnight.
  final int startMin;
  final int endMin;
  final String batchAId;
  final String batchBId;

  @override
  bool operator ==(Object other) =>
      other is MergeClash &&
      other.weekday == weekday &&
      other.startMin == startMin &&
      other.endMin == endMin &&
      other.batchAId == batchAId &&
      other.batchBId == batchBId;

  @override
  int get hashCode => Object.hash(weekday, startMin, endMin, batchAId, batchBId);

  @override
  String toString() => 'MergeClash($weekday $startMin-$endMin $batchAId/$batchBId)';
}

class _MergedSlot {
  const _MergedSlot({
    required this.id,
    required this.batchId,
    required this.weekday,
    required this.startMin,
    required this.endMin,
    required this.from,
    required this.to,
    required this.fromMerge,
  });

  final String id;
  final String batchId;
  final int weekday;
  final int startMin;
  final int endMin;
  final LocalDate? from;
  final LocalDate? to;
  final bool fromMerge;
}

/// The clashes the merge of [winners] into [local] would create, sorted by
/// weekday and time. Only pairs where at least one slot comes from the backup
/// count (clashes that already exist are the banner's job). Slots of batches
/// the merge deletes, and slots the merge deletes, are left out.
List<MergeClash> findMergeClashes({
  required List<RowChange> winners,
  required List<BatchSchedule> local,
}) {
  final Set<String> deadBatches = <String>{
    for (final RowChange w in winners)
      if (w.table == 'batches' && w.incoming['deleted_at'] != null) w.id,
  };

  final Map<String, _MergedSlot> slots = <String, _MergedSlot>{
    for (final BatchSchedule bs in local)
      for (final Slot s in bs.slots)
        s.id: _MergedSlot(
          id: s.id,
          batchId: s.batchId,
          weekday: s.weekday,
          startMin: s.startMin,
          endMin: s.endMin,
          from: s.validFrom,
          to: s.validTo,
          fromMerge: false,
        ),
  };

  for (final RowChange w in winners) {
    if (w.table != 'batch_slots') continue;
    if (w.incoming['deleted_at'] != null) {
      slots.remove(w.id);
      continue;
    }
    final Object? batchId = w.incoming['batch_id'];
    final Object? weekday = w.incoming['weekday'];
    final Object? start = w.incoming['start_min'];
    final Object? end = w.incoming['end_min'];
    if (batchId is! String || weekday is! int || start is! int || end is! int) continue;
    final Object? from = w.incoming['valid_from'];
    final Object? to = w.incoming['valid_to'];
    slots[w.id] = _MergedSlot(
      id: w.id,
      batchId: batchId,
      weekday: weekday,
      startMin: start,
      endMin: end,
      from: from is String ? LocalDate.tryParse(from) : null,
      to: to is String ? LocalDate.tryParse(to) : null,
      fromMerge: true,
    );
  }

  final List<_MergedSlot> live = <_MergedSlot>[
    for (final _MergedSlot s in slots.values)
      if (!deadBatches.contains(s.batchId)) s,
  ]..sort((a, b) => a.id.compareTo(b.id));

  final Set<MergeClash> found = <MergeClash>{};
  for (int i = 0; i < live.length; i++) {
    for (int j = i + 1; j < live.length; j++) {
      final _MergedSlot a = live[i];
      final _MergedSlot b = live[j];
      if (!a.fromMerge && !b.fromMerge) continue;
      if (a.batchId == b.batchId || a.weekday != b.weekday) continue;
      if (!ScheduleEngine.overlaps(a.startMin, a.endMin, b.startMin, b.endMin)) continue;
      if (!_windowsOverlap(a, b)) continue;
      final List<String> ids = <String>[a.batchId, b.batchId]..sort();
      found.add(MergeClash(
        weekday: a.weekday,
        startMin: a.startMin > b.startMin ? a.startMin : b.startMin,
        endMin: a.endMin < b.endMin ? a.endMin : b.endMin,
        batchAId: ids[0],
        batchBId: ids[1],
      ));
    }
  }
  return found.toList()
    ..sort((a, b) {
      final int w = a.weekday.compareTo(b.weekday);
      if (w != 0) return w;
      final int s = a.startMin.compareTo(b.startMin);
      if (s != 0) return s;
      return a.batchAId.compareTo(b.batchAId);
    });
}

bool _windowsOverlap(_MergedSlot a, _MergedSlot b) {
  final LocalDate? aFrom = a.from, aTo = a.to, bFrom = b.from, bTo = b.to;
  if (aTo != null && bFrom != null && aTo.isBefore(bFrom)) return false;
  if (bTo != null && aFrom != null && bTo.isBefore(aFrom)) return false;
  return true;
}
