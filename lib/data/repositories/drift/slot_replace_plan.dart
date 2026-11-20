import 'package:attendance_alamin/core/ids/ids.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/domain/models/drafts.dart';
import 'package:attendance_alamin/domain/models/schedule.dart';
import 'package:attendance_alamin/domain/schedule/occ_id.dart';

/// One database step of a slot replacement.
sealed class SlotOp {
  const SlotOp();
}

final class InsertSlotOp extends SlotOp {
  const InsertSlotOp(this.slot);
  final Slot slot;
}

/// In-place edit (the slot has no history at or after the edit date).
final class UpdateSlotOp extends SlotOp {
  const UpdateSlotOp(this.slot);
  final Slot slot;
}

/// End-dates a slot (`valid_to = from - 1`).
final class CloseSlotOp extends SlotOp {
  const CloseSlotOp(this.slotId, this.validTo);
  final String slotId;
  final LocalDate validTo;
}

final class TombstoneSlotOp extends SlotOp {
  const TombstoneSlotOp(this.slotId);
  final String slotId;
}

/// Inserts or overwrites an exception row (id is already final).
final class PutExceptionOp extends SlotOp {
  const PutExceptionOp(this.exception);
  final ScheduleException exception;
}

final class TombstoneExceptionOp extends SlotOp {
  const TombstoneExceptionOp(this.exceptionId);
  final String exceptionId;
}

/// The outcome of [planSlotReplace]: the steps to apply plus the resulting
/// schedule (for the clash check).
class SlotPlan {
  const SlotPlan({
    required this.ops,
    required this.slotsAfter,
    required this.exceptionsAfter,
    required this.focusSlotIds,
  });

  final List<SlotOp> ops;
  final List<Slot> slotsAfter;
  final List<ScheduleException> exceptionsAfter;

  /// Slots created or changed by the edit; only these are blamed for clashes.
  final Set<String> focusSlotIds;
}

/// Pure planner for "make [drafts] this batch's weekly schedule from [from]"
/// (Arch 3.2): an unchanged slot is kept; a slot that starts on/after [from]
/// is edited or removed in place; any other slot is end-dated at `from - 1`
/// and, when edited, replaced by a new row valid from [from] to which its
/// exceptions with `original_date >= from` are moved (their ids derive from
/// the slot, so each is tombstoned and re-created). Slots already ended before
/// [from] are history and never touched. Drafts are assumed validated.
SlotPlan planSlotReplace({
  required String batchId,
  required List<Slot> currentSlots,
  required List<ScheduleException> currentExceptions,
  required List<SlotDraft> drafts,
  required LocalDate from,
  required String Function() newSlotId,
}) {
  final ops = <SlotOp>[];
  final slotsAfter = <Slot>[];
  final focus = <String>{};
  final used = <String>{};
  var exceptions = List<ScheduleException>.of(currentExceptions);
  final byId = {for (final s in currentSlots) s.id: s};

  bool isHistory(Slot s) {
    final to = s.validTo;
    return to != null && to.isBefore(from);
  }

  bool startsOnOrAfter(Slot s) {
    final f = s.validFrom;
    return f != null && !f.isBefore(from);
  }

  Slot closed(Slot s) => Slot(
        id: s.id,
        batchId: s.batchId,
        weekday: s.weekday,
        startMin: s.startMin,
        endMin: s.endMin,
        validFrom: s.validFrom,
        validTo: from.addDays(-1),
      );

  for (final s in currentSlots) {
    if (isHistory(s)) slotsAfter.add(s);
  }

  for (final d in drafts) {
    final oldId = d.id;
    final old = oldId == null ? null : byId[oldId];
    if (old == null || isHistory(old) || !used.add(old.id)) {
      final fresh = Slot(
        id: newSlotId(),
        batchId: batchId,
        weekday: d.weekday,
        startMin: d.startMin,
        endMin: d.endMin,
        validFrom: from,
      );
      ops.add(InsertSlotOp(fresh));
      slotsAfter.add(fresh);
      focus.add(fresh.id);
      continue;
    }
    final unchanged = old.weekday == d.weekday &&
        old.startMin == d.startMin &&
        old.endMin == d.endMin;
    if (unchanged) {
      slotsAfter.add(old);
      continue;
    }
    if (startsOnOrAfter(old)) {
      final edited = Slot(
        id: old.id,
        batchId: old.batchId,
        weekday: d.weekday,
        startMin: d.startMin,
        endMin: d.endMin,
        validFrom: old.validFrom,
        validTo: old.validTo,
      );
      ops.add(UpdateSlotOp(edited));
      slotsAfter.add(edited);
      focus.add(old.id);
      continue;
    }
    final end = closed(old);
    final fresh = Slot(
      id: newSlotId(),
      batchId: old.batchId,
      weekday: d.weekday,
      startMin: d.startMin,
      endMin: d.endMin,
      validFrom: from,
      validTo: old.validTo,
    );
    ops
      ..add(CloseSlotOp(old.id, end.validTo!))
      ..add(InsertSlotOp(fresh));
    slotsAfter
      ..add(end)
      ..add(fresh);
    focus.add(fresh.id);
    final next = <ScheduleException>[];
    for (final e in exceptions) {
      final od = e.originalDate;
      if (e.slotId == old.id && od != null && !od.isBefore(from)) {
        final moved = ScheduleException(
          id: Ids.exceptionForOcc(OccId.regular(fresh.id, od)),
          batchId: e.batchId,
          kind: e.kind,
          slotId: fresh.id,
          originalDate: od,
          newDate: e.newDate,
          newStartMin: e.newStartMin,
          newEndMin: e.newEndMin,
          note: e.note,
        );
        ops
          ..add(TombstoneExceptionOp(e.id))
          ..add(PutExceptionOp(moved));
        next.add(moved);
      } else {
        next.add(e);
      }
    }
    exceptions = next;
  }

  for (final old in currentSlots) {
    if (isHistory(old) || used.contains(old.id)) continue;
    if (startsOnOrAfter(old)) {
      ops.add(TombstoneSlotOp(old.id));
      final next = <ScheduleException>[];
      for (final e in exceptions) {
        if (e.slotId == old.id) {
          ops.add(TombstoneExceptionOp(e.id));
        } else {
          next.add(e);
        }
      }
      exceptions = next;
    } else {
      final end = closed(old);
      ops.add(CloseSlotOp(old.id, end.validTo!));
      slotsAfter.add(end);
      final next = <ScheduleException>[];
      for (final e in exceptions) {
        final od = e.originalDate;
        if (e.slotId == old.id && od != null && !od.isBefore(from)) {
          ops.add(TombstoneExceptionOp(e.id));
        } else {
          next.add(e);
        }
      }
      exceptions = next;
    }
  }

  return SlotPlan(
    ops: ops,
    slotsAfter: slotsAfter,
    exceptionsAfter: exceptions,
    focusSlotIds: focus,
  );
}
