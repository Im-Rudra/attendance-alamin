import 'dart:math' as math;

import 'package:attendance_alamin/core/time/date_range.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/schedule.dart';
import 'package:attendance_alamin/domain/schedule/occ_id.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';

/// Pure schedule engine (Product 3.9-3.10, Architecture 3.2a + 4A, plan M2-B).
///
/// Works only in center wall-clock terms ([LocalDate] + minutes of day); it
/// never touches `DateTime`, so the fixed UTC+6 offset never enters here.
/// `today` is always a parameter.
///
/// Conventions:
/// * Intervals are half-open `[start, end)`; touching times never clash and
///   different dates never clash (a class cannot cross midnight).
/// * Archived batches yield no occurrences at all ([expand], the `others` of
///   [checkSlotEdit], the `all` of [checkSingle]). The `proposed` batch of
///   [checkSlotEdit] is always expanded as if live, so the same call serves
///   the un-archive check.
/// * A regular occurrence of slot `s` exists on date `d` iff
///   `s.weekday == d.isoWeekday`, `s.activeOn(d)` and `d >= batch.createdOn`.
///   Cancel and reschedule exceptions only apply to an existing regular
///   occurrence; orphaned or malformed exceptions are ignored. When several
///   exceptions target the same occurrence, the last one in the list wins
///   (upstream ids are deterministic, so this only happens transiently).
/// * Extras and rescheduled-in classes are one-offs; they are kept even on
///   dates before `batch.createdOn` (past exceptions record what happened).
abstract final class ScheduleEngine {
  /// Half-open overlap: `a.start < b.end && b.start < a.end`.
  static bool overlaps(int aStart, int aEnd, int bStart, int bEnd) =>
      aStart < bEnd && bStart < aEnd;

  /// Effective occurrences of every live batch for [range] (inclusive).
  ///
  /// * `occurrences`: regular, rescheduled-in (when the NEW date is in range,
  ///   keeping the original `s.<slot>.<date>` identity) and extras, sorted by
  ///   date, start, batchId (then end, occ).
  /// * `cancelled`: cancelled regular occurrences whose date is in range.
  /// * `movedAway`: regular occurrences rescheduled away whose ORIGINAL date
  ///   is in range (also when moved to another time on the same date).
  static ExpandResult expand({
    required DateRange range,
    required List<BatchSchedule> batches,
  }) {
    if (range.isEmpty) return const ExpandResult();
    final dates = _DateSet(range.days);
    final out = _Expansion();
    for (final bs in batches) {
      if (bs.batch.archived) continue;
      _expandBatch(bs, dates, out);
    }
    return out.toResult();
  }

  /// Every pair (candidate, existing) on the same date whose intervals
  /// overlap. An occurrence never clashes with itself (same `occ`), and when
  /// the two lists share occurrences each unordered pair is reported once
  /// (the first orientation met wins). Order: candidates order, then
  /// existing order.
  static List<Clash> findClashes({
    required List<Occurrence> candidates,
    required List<Occurrence> existing,
  }) {
    final byDate = _byDate(existing);
    final seen = <String>{};
    final out = <Clash>[];
    for (final c in candidates) {
      final sameDay = byDate[c.date];
      if (sameDay == null) continue;
      for (final e in sameDay) {
        if (e.occ == c.occ) continue;
        if (!overlaps(c.startMin, c.endMin, e.startMin, e.endMin)) continue;
        if (seen.contains('${e.occ}|${c.occ}')) continue;
        if (!seen.add('${c.occ}|${e.occ}')) continue;
        out.add(Clash(candidate: c, existing: e));
      }
    }
    return out;
  }

  /// Save-time check for a batch's weekly slots (add / edit / remove / new
  /// batch / un-archive).
  ///
  /// [proposed] = the batch with its slots as they would be after the save
  /// (old versions end-dated, new versions starting at [from]) plus its
  /// exceptions. [others] = every other batch; entries with the proposed
  /// batch's id and archived batches are ignored.
  ///
  /// Checked dates: `[max(from, today), max(from, today) + 7 * horizonWeeks]`
  /// (inclusive) plus the date of every one-off (extra or rescheduled-in, of
  /// any checked batch) on or after `max(from, today)`, however far ahead.
  /// Clash pairs: proposed vs others, and proposed vs proposed (a batch's own
  /// classes must not overlap either). With [onlySlotIds], only pairs where at
  /// least one proposed side is an occurrence of one of those slots count, so
  /// a legacy conflict the edit is not part of never blocks it.
  ///
  /// Groups: an existing REGULAR occurrence groups per (batch, weekday,
  /// start, end) as `everyWeek` (date `null`); one-offs group per
  /// (batch, date, start, end, kind). `count` = distinct existing
  /// occurrences in the group. Groups are ordered by their first clash
  /// (date, then start).
  ///
  /// Suggestion (only when blocked), for the first clashing proposed
  /// occurrence: for a regular one, a start that is free on EVERY checked
  /// date on which that slot has an effective occurrence (its own regular
  /// occurrences are not busy); for a one-off, a start free on its date.
  static SlotCheckResult checkSlotEdit({
    required BatchSchedule proposed,
    required List<BatchSchedule> others,
    required LocalDate from,
    required LocalDate today,
    Set<String>? onlySlotIds,
    int horizonWeeks = 12,
    int dayStartMin = 360,
    int dayEndMin = 1380,
  }) {
    final start = from.isBefore(today) ? today : from;
    final horizonEnd = start.addDays(7 * horizonWeeks);
    final proposedId = proposed.batch.id;
    final live = <BatchSchedule>[
      for (final o in others)
        if (o.batch.id != proposedId && !o.batch.archived) o,
    ];

    final dateList = <LocalDate>[...DateRange(start, horizonEnd).days];
    _addOneOffDates(proposed, start, dateList);
    for (final o in live) {
      _addOneOffDates(o, start, dateList);
    }
    final dates = _DateSet(dateList);

    final propOut = _Expansion();
    _expandBatch(proposed, dates, propOut);
    final prop = propOut.toResult().occurrences;
    final othOut = _Expansion();
    for (final o in live) {
      _expandBatch(o, dates, othOut);
    }
    final oth = othOut.toResult().occurrences;

    final only = onlySlotIds;
    bool focus(Occurrence o) {
      if (only == null) return true;
      final slotId = o.slotId;
      return slotId != null && only.contains(slotId);
    }

    final clashes = <Clash>[];
    final othByDate = _byDate(oth);
    for (final c in prop) {
      if (!focus(c)) continue;
      final sameDay = othByDate[c.date];
      if (sameDay == null) continue;
      for (final e in sameDay) {
        if (e.occ == c.occ) continue;
        if (overlaps(c.startMin, c.endMin, e.startMin, e.endMin)) {
          clashes.add(Clash(candidate: c, existing: e));
        }
      }
    }
    for (final list in _byDate(prop).values) {
      for (var i = 0; i < list.length; i++) {
        for (var j = i + 1; j < list.length; j++) {
          final a = list[i];
          final b = list[j];
          if (a.occ == b.occ) continue;
          if (!overlaps(a.startMin, a.endMin, b.startMin, b.endMin)) continue;
          if (focus(a)) {
            clashes.add(Clash(candidate: a, existing: b));
          } else if (focus(b)) {
            clashes.add(Clash(candidate: b, existing: a));
          }
        }
      }
    }
    if (clashes.isEmpty) return const SlotCheckResult();
    clashes.sort(_compareClash);

    final first = clashes.first.candidate;
    final everything = <Occurrence>[...prop, ...oth];
    final firstSlotId = first.slotId;
    final List<(int, int)> busy;
    if (first.kind == OccurrenceKind.regular && firstSlotId != null) {
      bool ownRegular(Occurrence o) =>
          o.kind == OccurrenceKind.regular && o.slotId == firstSlotId;
      final slotDates = <LocalDate>{
        for (final o in prop)
          if (ownRegular(o)) o.date,
      };
      busy = [
        for (final o in everything)
          if (slotDates.contains(o.date) && !ownRegular(o))
            (o.startMin, o.endMin),
      ];
    } else {
      busy = [
        for (final o in everything)
          if (o.date == first.date && o.occ != first.occ)
            (o.startMin, o.endMin),
      ];
    }
    return SlotCheckResult(
      groups: _group(clashes, weekly: true),
      suggestion: suggestSameDay(
        preferredStartMin: first.startMin,
        durationMin: first.endMin - first.startMin,
        busy: busy,
        dayStartMin: dayStartMin,
        dayEndMin: dayEndMin,
      ),
    );
  }

  /// Save-time check for one occurrence (extra class, reschedule, cancel
  /// removal, ad-hoc roll call): [candidate] vs every effective occurrence of
  /// [all] (live batches, including the candidate's own batch) on
  /// `candidate.date`, minus the candidate itself (same `occ`) and
  /// [excludeOcc] (the occurrence being moved / replaced).
  /// Groups are per existing occurrence (`everyWeek` false, `date` set),
  /// ordered by start then batch. Suggestion only when blocked.
  static SlotCheckResult checkSingle({
    required Occurrence candidate,
    required List<BatchSchedule> all,
    String? excludeOcc,
    int dayStartMin = 360,
    int dayEndMin = 1380,
  }) {
    final day = expand(
      range: DateRange(candidate.date, candidate.date),
      batches: all,
    ).occurrences;
    final busy = <Occurrence>[
      for (final o in day)
        if (o.occ != candidate.occ && o.occ != excludeOcc) o,
    ];
    final clashes = <Clash>[
      for (final e in busy)
        if (overlaps(candidate.startMin, candidate.endMin, e.startMin, e.endMin))
          Clash(candidate: candidate, existing: e),
    ];
    if (clashes.isEmpty) return const SlotCheckResult();
    clashes.sort(_compareClash);
    return SlotCheckResult(
      groups: _group(clashes, weekly: false),
      suggestion: suggestSameDay(
        preferredStartMin: candidate.startMin,
        durationMin: candidate.endMin - candidate.startMin,
        busy: [for (final o in busy) (o.startMin, o.endMin)],
        dayStartMin: dayStartMin,
        dayEndMin: dayEndMin,
      ),
    );
  }

  /// Nearest free starts on one day (Product 3.10): candidates are multiples
  /// of [stepMin] within `[dayStartMin, dayEndMin - durationMin]`; a start is
  /// free when `[s, s + durationMin)` overlaps no [busy] interval (touching is
  /// fine). `earlierStartMin` = greatest free start `< preferredStartMin`,
  /// `laterStartMin` = smallest free start `> preferredStartMin`; either is
  /// `null` when none exists ("no free time" = both `null`).
  static FreeSuggestion suggestSameDay({
    required int preferredStartMin,
    required int durationMin,
    required List<(int, int)> busy,
    int dayStartMin = 360,
    int dayEndMin = 1380,
    int stepMin = 5,
  }) {
    if (stepMin <= 0) {
      throw ArgumentError.value(stepMin, 'stepMin', 'must be positive');
    }
    int? earlier;
    int? later;
    if (durationMin > 0) {
      final lo = _ceilTo(dayStartMin, stepMin);
      final hi = _floorTo(dayEndMin - durationMin, stepMin);
      bool free(int s) {
        for (final b in busy) {
          if (overlaps(s, s + durationMin, b.$1, b.$2)) return false;
        }
        return true;
      }

      for (var s = math.min(hi, _floorTo(preferredStartMin - 1, stepMin));
          s >= lo;
          s -= stepMin) {
        if (free(s)) {
          earlier = s;
          break;
        }
      }
      for (var s = math.max(lo, _ceilTo(preferredStartMin + 1, stepMin));
          s <= hi;
          s += stepMin) {
        if (free(s)) {
          later = s;
          break;
        }
      }
    }
    return FreeSuggestion(
      durationMin: durationMin,
      earlierStartMin: earlier,
      laterStartMin: later,
      preferredStartMin: preferredStartMin,
    );
  }

  // ---------------------------------------------------------------------------

  static int _floorTo(int x, int step) => x - (x % step);

  static int _ceilTo(int x, int step) => -_floorTo(-x, step);

  static bool _hasNewTime(ScheduleException ex) =>
      ex.newDate != null && ex.newStartMin != null && ex.newEndMin != null;

  static bool _regularExists(Slot s, LocalDate d, Batch b) =>
      s.weekday == d.isoWeekday && s.activeOn(d) && !d.isBefore(b.createdOn);

  static void _addOneOffDates(
      BatchSchedule bs, LocalDate start, List<LocalDate> into) {
    for (final ex in bs.exceptions) {
      if (ex.kind == ExceptionKind.cancel) continue;
      final nd = ex.newDate;
      if (nd != null && !nd.isBefore(start)) into.add(nd);
    }
  }

  /// Expands one batch over [dates] into [out], ignoring its archived flag.
  static void _expandBatch(BatchSchedule bs, _DateSet dates, _Expansion out) {
    final batch = bs.batch;
    final slotsById = <String, Slot>{for (final s in bs.slots) s.id: s};
    final slotsByWeekday = <int, List<Slot>>{};
    for (final s in slotsById.values) {
      (slotsByWeekday[s.weekday] ??= <Slot>[]).add(s);
    }

    // occ -> cancel / reschedule (last wins); extras by id (last wins).
    final byOcc = <String, ScheduleException>{};
    final extras = <String, ScheduleException>{};
    for (final ex in bs.exceptions) {
      if (ex.kind == ExceptionKind.extra) {
        if (_hasNewTime(ex)) extras[ex.id] = ex;
        continue;
      }
      final slotId = ex.slotId;
      final od = ex.originalDate;
      if (slotId == null || od == null) continue;
      if (ex.kind == ExceptionKind.reschedule && !_hasNewTime(ex)) continue;
      byOcc[OccId.regular(slotId, od)] = ex;
    }

    // Regular occurrences (and their cancel / moved-away markers).
    for (final d in dates.days) {
      final daySlots = slotsByWeekday[d.isoWeekday];
      if (daySlots == null) continue;
      for (final s in daySlots) {
        if (!_regularExists(s, d, batch)) continue;
        final occ = OccId.regular(s.id, d);
        final ex = byOcc[occ];
        if (ex == null) {
          out.occurrences.add(Occurrence(
            occ: occ,
            batchId: batch.id,
            date: d,
            startMin: s.startMin,
            endMin: s.endMin,
            kind: OccurrenceKind.regular,
            slotId: s.id,
          ));
        } else if (ex.kind == ExceptionKind.cancel) {
          out.cancelled.add(CancelledOccurrence(
            occ: occ,
            batchId: batch.id,
            date: d,
            startMin: s.startMin,
            endMin: s.endMin,
            exceptionId: ex.id,
            note: ex.note,
          ));
        } else {
          final nd = ex.newDate;
          final ns = ex.newStartMin;
          if (nd != null && ns != null) {
            out.movedAway.add(MovedAway(
              occ: occ,
              batchId: batch.id,
              originalDate: d,
              originalStartMin: s.startMin,
              newDate: nd,
              newStartMin: ns,
            ));
          }
        }
      }
    }

    // Rescheduled-in: included when the NEW date is checked, even if the
    // original date is not. Keeps the original occurrence identity.
    for (final entry in byOcc.entries) {
      final ex = entry.value;
      if (ex.kind != ExceptionKind.reschedule) continue;
      final slot = slotsById[ex.slotId];
      final od = ex.originalDate;
      final nd = ex.newDate;
      final ns = ex.newStartMin;
      final ne = ex.newEndMin;
      if (slot == null || od == null || nd == null || ns == null || ne == null) {
        continue;
      }
      if (!_regularExists(slot, od, batch)) continue;
      if (!dates.contains(nd)) continue;
      out.occurrences.add(Occurrence(
        occ: entry.key,
        batchId: batch.id,
        date: nd,
        startMin: ns,
        endMin: ne,
        kind: OccurrenceKind.rescheduled,
        slotId: slot.id,
        exceptionId: ex.id,
        originalDate: od,
        originalStartMin: slot.startMin,
        originalEndMin: slot.endMin,
      ));
    }

    // Extras.
    for (final ex in extras.values) {
      final nd = ex.newDate;
      final ns = ex.newStartMin;
      final ne = ex.newEndMin;
      if (nd == null || ns == null || ne == null) continue;
      if (!dates.contains(nd)) continue;
      out.occurrences.add(Occurrence(
        occ: OccId.extra(ex.id),
        batchId: batch.id,
        date: nd,
        startMin: ns,
        endMin: ne,
        kind: OccurrenceKind.extra,
        exceptionId: ex.id,
      ));
    }
  }

  static Map<LocalDate, List<Occurrence>> _byDate(List<Occurrence> list) {
    final map = <LocalDate, List<Occurrence>>{};
    for (final o in list) {
      (map[o.date] ??= <Occurrence>[]).add(o);
    }
    return map;
  }

  static List<ClashGroup> _group(List<Clash> clashes, {required bool weekly}) {
    final order = <String>[];
    final firstOf = <String, Occurrence>{};
    final occsOf = <String, Set<String>>{};
    for (final c in clashes) {
      final e = c.existing;
      final every = weekly && e.kind == OccurrenceKind.regular;
      final key = every
          ? 'w|${e.batchId}|${e.date.isoWeekday}|${e.startMin}|${e.endMin}'
          : 'd|${e.batchId}|${e.date.toIso()}|${e.startMin}|${e.endMin}|'
              '${e.kind.name}';
      if (!firstOf.containsKey(key)) {
        order.add(key);
        firstOf[key] = e;
        occsOf[key] = <String>{};
      }
      occsOf[key]?.add(e.occ);
    }
    return [
      for (final key in order)
        if (firstOf[key] case final e?)
          ClashGroup(
            batchId: e.batchId,
            startMin: e.startMin,
            endMin: e.endMin,
            everyWeek: key.startsWith('w|'),
            weekday: e.date.isoWeekday,
            date: key.startsWith('w|') ? null : e.date,
            existingKind: e.kind,
            count: occsOf[key]?.length ?? 0,
          ),
    ];
  }

  static int _compareClash(Clash a, Clash b) {
    var c = a.candidate.date.compareTo(b.candidate.date);
    if (c != 0) return c;
    c = a.existing.startMin.compareTo(b.existing.startMin);
    if (c != 0) return c;
    c = a.candidate.startMin.compareTo(b.candidate.startMin);
    if (c != 0) return c;
    c = a.existing.batchId.compareTo(b.existing.batchId);
    if (c != 0) return c;
    c = a.existing.occ.compareTo(b.existing.occ);
    if (c != 0) return c;
    return a.candidate.occ.compareTo(b.candidate.occ);
  }

  static int _compareOcc(Occurrence a, Occurrence b) {
    var c = a.date.compareTo(b.date);
    if (c != 0) return c;
    c = a.startMin.compareTo(b.startMin);
    if (c != 0) return c;
    c = a.batchId.compareTo(b.batchId);
    if (c != 0) return c;
    c = a.endMin.compareTo(b.endMin);
    if (c != 0) return c;
    return a.occ.compareTo(b.occ);
  }

  static int _compareCancelled(CancelledOccurrence a, CancelledOccurrence b) {
    var c = a.date.compareTo(b.date);
    if (c != 0) return c;
    c = a.startMin.compareTo(b.startMin);
    if (c != 0) return c;
    c = a.batchId.compareTo(b.batchId);
    if (c != 0) return c;
    return a.occ.compareTo(b.occ);
  }

  static int _compareMoved(MovedAway a, MovedAway b) {
    var c = a.originalDate.compareTo(b.originalDate);
    if (c != 0) return c;
    c = a.originalStartMin.compareTo(b.originalStartMin);
    if (c != 0) return c;
    c = a.batchId.compareTo(b.batchId);
    if (c != 0) return c;
    return a.occ.compareTo(b.occ);
  }
}

/// A sorted, de-duplicated set of dates with O(1) membership.
final class _DateSet {
  factory _DateSet(Iterable<LocalDate> dates) {
    final set = dates.toSet();
    final sorted = set.toList()..sort();
    return _DateSet._(sorted, set);
  }

  const _DateSet._(this.days, this._set);

  final List<LocalDate> days;
  final Set<LocalDate> _set;

  bool contains(LocalDate d) => _set.contains(d);
}

/// Mutable accumulator for one expansion.
final class _Expansion {
  final List<Occurrence> occurrences = <Occurrence>[];
  final List<CancelledOccurrence> cancelled = <CancelledOccurrence>[];
  final List<MovedAway> movedAway = <MovedAway>[];

  ExpandResult toResult() {
    occurrences.sort(ScheduleEngine._compareOcc);
    cancelled.sort(ScheduleEngine._compareCancelled);
    movedAway.sort(ScheduleEngine._compareMoved);
    return ExpandResult(
      occurrences: List<Occurrence>.unmodifiable(occurrences),
      cancelled: List<CancelledOccurrence>.unmodifiable(cancelled),
      movedAway: List<MovedAway>.unmodifiable(movedAway),
    );
  }
}
