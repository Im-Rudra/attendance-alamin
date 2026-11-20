import 'package:attendance_alamin/core/time/date_range.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/schedule.dart';
import 'package:attendance_alamin/domain/schedule/occ_id.dart';
import 'package:attendance_alamin/domain/schedule/schedule_engine.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fixtures. Product 6 seed: Physics A (pa) Sat/Mon/Wed 16:00-17:00,
// Chem B (cb) Sun/Tue 10:00-11:00. 2026-11-21 is a Saturday; today = Fri 20.
// ---------------------------------------------------------------------------

int t(int h, int m) => h * 60 + m;

LocalDate d(int y, int m, int day) => LocalDate(y, m, day);

const today = LocalDate(2026, 11, 20);
const created = LocalDate(2026, 9, 1);

Batch batch(String id, {LocalDate createdOn = created, LocalDate? archivedOn}) =>
    Batch(
      id: id,
      subjectId: 'subj-$id',
      name: id,
      billingType: BillingType.prepaid,
      createdOn: createdOn,
      sortOrder: 0,
      archivedOn: archivedOn,
    );

Slot slot(String id, String batchId, int weekday, int start, int end,
        {LocalDate? from, LocalDate? to}) =>
    Slot(
      id: id,
      batchId: batchId,
      weekday: weekday,
      startMin: start,
      endMin: end,
      validFrom: from,
      validTo: to,
    );

ScheduleException cancelEx(String id, String batchId, String slotId,
        LocalDate original, {String? note}) =>
    ScheduleException(
      id: id,
      batchId: batchId,
      kind: ExceptionKind.cancel,
      slotId: slotId,
      originalDate: original,
      note: note,
    );

ScheduleException rescheduleEx(String id, String batchId, String slotId,
        LocalDate original, LocalDate newDate, int start, int end) =>
    ScheduleException(
      id: id,
      batchId: batchId,
      kind: ExceptionKind.reschedule,
      slotId: slotId,
      originalDate: original,
      newDate: newDate,
      newStartMin: start,
      newEndMin: end,
    );

ScheduleException extraEx(
        String id, String batchId, LocalDate date, int start, int end) =>
    ScheduleException(
      id: id,
      batchId: batchId,
      kind: ExceptionKind.extra,
      newDate: date,
      newStartMin: start,
      newEndMin: end,
    );

BatchSchedule sched(Batch b,
        {List<Slot> slots = const [],
        List<ScheduleException> exceptions = const []}) =>
    BatchSchedule(
        batch: b, subjectName: 'S-${b.id}', slots: slots, exceptions: exceptions);

final paSat = slot('pa-sat', 'pa', 6, t(16, 0), t(17, 0));
final paMon = slot('pa-mon', 'pa', 1, t(16, 0), t(17, 0));
final paWed = slot('pa-wed', 'pa', 3, t(16, 0), t(17, 0));
final cbSun = slot('cb-sun', 'cb', 7, t(10, 0), t(11, 0));
final cbTue = slot('cb-tue', 'cb', 2, t(10, 0), t(11, 0));

BatchSchedule physicsA({List<ScheduleException> ex = const []}) =>
    sched(batch('pa'), slots: [paSat, paMon, paWed], exceptions: ex);

BatchSchedule chemB({List<ScheduleException> ex = const []}) =>
    sched(batch('cb'), slots: [cbSun, cbTue], exceptions: ex);

BatchSchedule mathC(
        {List<Slot> slots = const [],
        List<ScheduleException> ex = const []}) =>
    sched(batch('mc', createdOn: today), slots: slots, exceptions: ex);

Occurrence oneOff(String occ, String batchId, LocalDate date, int start,
        int end,
        {OccurrenceKind kind = OccurrenceKind.extra}) =>
    Occurrence(
      occ: occ,
      batchId: batchId,
      date: date,
      startMin: start,
      endMin: end,
      kind: kind,
    );

Occurrence reg(String slotId, String batchId, LocalDate date, int start,
        int end) =>
    Occurrence(
      occ: OccId.regular(slotId, date),
      batchId: batchId,
      date: date,
      startMin: start,
      endMin: end,
      kind: OccurrenceKind.regular,
      slotId: slotId,
    );

List<Occurrence> occsOn(List<BatchSchedule> all, LocalDate date) =>
    ScheduleEngine.expand(range: DateRange(date, date), batches: all)
        .occurrences;

void main() {
  // -------------------------------------------------------------------------
  group('overlaps (half-open [start, end))', () {
    final cases = <(int, int, int, int, bool, String)>[
      (t(10, 0), t(11, 0), t(11, 0), t(12, 0), false, 'touching after'),
      (t(11, 0), t(12, 0), t(10, 0), t(11, 0), false, 'touching before'),
      (t(10, 0), t(11, 1), t(11, 0), t(12, 0), true, '1-minute overlap'),
      (t(10, 0), t(11, 0), t(10, 30), t(11, 30), true, 'partial overlap'),
      (t(10, 0), t(11, 0), t(10, 0), t(11, 0), true, 'identical'),
      (t(9, 0), t(12, 0), t(10, 0), t(11, 0), true, 'containment'),
      (t(10, 0), t(11, 0), t(9, 0), t(12, 0), true, 'contained'),
      (t(8, 0), t(9, 0), t(17, 0), t(18, 0), false, 'disjoint'),
      (0, 60, 30, 90, true, 'start at 00:00 overlap'),
      (0, 60, 60, 120, false, 'start at 00:00 touching'),
      (t(23, 0), 1440, t(23, 59), 1440, true, 'end at 24:00 overlap'),
      (t(23, 0), t(23, 59), t(23, 59), 1440, false, '23:59 touching'),
    ];
    for (final c in cases) {
      test(c.$6, () {
        expect(ScheduleEngine.overlaps(c.$1, c.$2, c.$3, c.$4), c.$5);
      });
    }
  });

  // -------------------------------------------------------------------------
  group('expand', () {
    test('seed week: exact occurrences, ids and order', () {
      final r = ScheduleEngine.expand(
        range: DateRange(d(2026, 11, 21), d(2026, 11, 27)),
        batches: [chemB(), physicsA()],
      );
      expect(r.occurrences, [
        reg('pa-sat', 'pa', d(2026, 11, 21), t(16, 0), t(17, 0)),
        reg('cb-sun', 'cb', d(2026, 11, 22), t(10, 0), t(11, 0)),
        reg('pa-mon', 'pa', d(2026, 11, 23), t(16, 0), t(17, 0)),
        reg('cb-tue', 'cb', d(2026, 11, 24), t(10, 0), t(11, 0)),
        reg('pa-wed', 'pa', d(2026, 11, 25), t(16, 0), t(17, 0)),
      ]);
      expect(r.occurrences.first.occ, 's.pa-sat.20261121');
      expect(r.cancelled, isEmpty);
      expect(r.movedAway, isEmpty);
    });

    test('weekday mapping: Sat = 6, Fri = 5 (ISO)', () {
      expect(d(2026, 11, 21).isoWeekday, 6);
      expect(d(2026, 11, 27).isoWeekday, 5);
      final fri = slot('x-fri', 'x', 5, t(8, 0), t(9, 0));
      final sat = slot('x-sat', 'x', 6, t(8, 0), t(9, 0));
      final r = ScheduleEngine.expand(
        range: DateRange(d(2026, 11, 21), d(2026, 11, 27)),
        batches: [sched(batch('x'), slots: [fri, sat])],
      );
      expect(r.occurrences.map((o) => o.date), [d(2026, 11, 21), d(2026, 11, 27)]);
      expect(r.occurrences.map((o) => o.slotId), ['x-sat', 'x-fri']);
    });

    test('two slots of one batch on one weekday -> two distinct occs', () {
      final a = slot('x-fri-am', 'x', 5, t(8, 0), t(9, 0));
      final b = slot('x-fri-pm', 'x', 5, t(17, 0), t(18, 0));
      final r = ScheduleEngine.expand(
        range: DateRange(d(2026, 11, 27), d(2026, 11, 27)),
        batches: [sched(batch('x'), slots: [b, a])],
      );
      expect(r.occurrences.map((o) => o.occ),
          ['s.x-fri-am.20261127', 's.x-fri-pm.20261127']);
    });

    test('archived batch yields nothing (slots and extras)', () {
      final bio = sched(
        batch('bio', archivedOn: d(2026, 10, 1)),
        slots: [slot('bio-sat', 'bio', 6, t(16, 0), t(17, 0))],
        exceptions: [extraEx('e1', 'bio', d(2026, 11, 22), t(9, 0), t(10, 0))],
      );
      final r = ScheduleEngine.expand(
          range: DateRange(d(2026, 11, 21), d(2026, 11, 22)), batches: [bio]);
      expect(r, const ExpandResult());
    });

    test('no regular occurrence before batch.createdOn; extras still kept', () {
      final b = sched(
        batch('n', createdOn: d(2026, 11, 25)),
        slots: [slot('n-mon', 'n', 1, t(9, 0), t(10, 0))],
        exceptions: [extraEx('past', 'n', d(2026, 11, 20), t(9, 0), t(10, 0))],
      );
      final r = ScheduleEngine.expand(
          range: DateRange(d(2026, 11, 16), d(2026, 12, 1)), batches: [b]);
      expect(r.occurrences.map((o) => o.occ), ['x.past', 's.n-mon.20261130']);
    });

    test('createdOn day itself is included', () {
      final b = sched(batch('n', createdOn: d(2026, 11, 23)),
          slots: [slot('n-mon', 'n', 1, t(9, 0), t(10, 0))]);
      final r = ScheduleEngine.expand(
          range: DateRange(d(2026, 11, 23), d(2026, 11, 23)), batches: [b]);
      expect(r.occurrences.single.occ, 's.n-mon.20261123');
    });

    test('validity window starting and ending mid-week (inclusive bounds)', () {
      // Monday slot valid Wed 2026-11-25 .. Wed 2026-12-09.
      final s = slot('m', 'x', 1, t(9, 0), t(10, 0),
          from: d(2026, 11, 25), to: d(2026, 12, 9));
      final r = ScheduleEngine.expand(
        range: DateRange(d(2026, 11, 16), d(2026, 12, 20)),
        batches: [sched(batch('x'), slots: [s])],
      );
      expect(r.occurrences.map((o) => o.date),
          [d(2026, 11, 30), d(2026, 12, 7)]);
    });

    test('validFrom == validTo on the weekday -> exactly one occurrence', () {
      final s = slot('m', 'x', 1, t(9, 0), t(10, 0),
          from: d(2026, 11, 30), to: d(2026, 11, 30));
      final r = ScheduleEngine.expand(
        range: DateRange(d(2026, 11, 1), d(2026, 12, 31)),
        batches: [sched(batch('x'), slots: [s])],
      );
      expect(r.occurrences.single.date, d(2026, 11, 30));
    });

    test('slot edit "from date" split keeps past occurrence ids', () {
      // Physics A Sat 16:00-17:00 moved to 17:00-18:00 from Sat 2026-11-28.
      final old = slot('pa-sat', 'pa', 6, t(16, 0), t(17, 0),
          to: d(2026, 11, 27));
      final neu = slot('pa-sat2', 'pa', 6, t(17, 0), t(18, 0),
          from: d(2026, 11, 28));
      final r = ScheduleEngine.expand(
        range: DateRange(d(2026, 11, 14), d(2026, 12, 5)),
        batches: [sched(batch('pa'), slots: [old, neu])],
      );
      expect(r.occurrences, [
        reg('pa-sat', 'pa', d(2026, 11, 14), t(16, 0), t(17, 0)),
        reg('pa-sat', 'pa', d(2026, 11, 21), t(16, 0), t(17, 0)),
        reg('pa-sat2', 'pa', d(2026, 11, 28), t(17, 0), t(18, 0)),
        reg('pa-sat2', 'pa', d(2026, 12, 5), t(17, 0), t(18, 0)),
      ]);
    });

    test('cancel drops only that class and lists it in cancelled', () {
      final b = sched(
        batch('x'),
        slots: [
          slot('am', 'x', 6, t(8, 0), t(9, 0)),
          slot('pm', 'x', 6, t(16, 0), t(17, 0)),
        ],
        exceptions: [cancelEx('c1', 'x', 'am', d(2026, 11, 21), note: 'Eid')],
      );
      final r = ScheduleEngine.expand(
          range: DateRange(d(2026, 11, 21), d(2026, 11, 21)), batches: [b]);
      expect(r.occurrences.map((o) => o.occ), ['s.pm.20261121']);
      expect(r.cancelled, const [
        CancelledOccurrence(
          occ: 's.am.20261121',
          batchId: 'x',
          date: LocalDate(2026, 11, 21),
          startMin: 480,
          endMin: 540,
          exceptionId: 'c1',
          note: 'Eid',
        ),
      ]);
    });

    test('reschedule to another date keeps occ; moved-away on original date',
        () {
      // Scenario 19 (saved form): Physics A 11-23 -> 11-24 11:00-12:00.
      final pa = physicsA(ex: [
        rescheduleEx('r1', 'pa', 'pa-mon', d(2026, 11, 23), d(2026, 11, 24),
            t(11, 0), t(12, 0)),
      ]);
      final r = ScheduleEngine.expand(
          range: DateRange(d(2026, 11, 23), d(2026, 11, 24)),
          batches: [pa, chemB()]);
      expect(r.occurrences, [
        reg('cb-tue', 'cb', d(2026, 11, 24), t(10, 0), t(11, 0)),
        const Occurrence(
          occ: 's.pa-mon.20261123',
          batchId: 'pa',
          date: LocalDate(2026, 11, 24),
          startMin: 660,
          endMin: 720,
          kind: OccurrenceKind.rescheduled,
          slotId: 'pa-mon',
          exceptionId: 'r1',
          originalDate: LocalDate(2026, 11, 23),
          originalStartMin: 960,
          originalEndMin: 1020,
        ),
      ]);
      expect(r.movedAway, const [
        MovedAway(
          occ: 's.pa-mon.20261123',
          batchId: 'pa',
          originalDate: LocalDate(2026, 11, 23),
          originalStartMin: 960,
          newDate: LocalDate(2026, 11, 24),
          newStartMin: 660,
        ),
      ]);
      expect(r.cancelled, isEmpty);
    });

    test('reschedule across range edges: only new date / only original date',
        () {
      final pa = physicsA(ex: [
        rescheduleEx('r1', 'pa', 'pa-mon', d(2026, 11, 23), d(2026, 11, 24),
            t(11, 0), t(12, 0)),
      ]);
      final onlyNew = ScheduleEngine.expand(
          range: DateRange(d(2026, 11, 24), d(2026, 11, 24)), batches: [pa]);
      expect(onlyNew.occurrences.single.occ, 's.pa-mon.20261123');
      expect(onlyNew.occurrences.single.kind, OccurrenceKind.rescheduled);
      expect(onlyNew.movedAway, isEmpty);

      final onlyOld = ScheduleEngine.expand(
          range: DateRange(d(2026, 11, 23), d(2026, 11, 23)), batches: [pa]);
      expect(onlyOld.occurrences, isEmpty);
      expect(onlyOld.movedAway.single.newDate, d(2026, 11, 24));
    });

    test('reschedule within the same date (time change only)', () {
      final pa = physicsA(ex: [
        rescheduleEx('r1', 'pa', 'pa-mon', d(2026, 11, 23), d(2026, 11, 23),
            t(16, 30), t(17, 30)),
      ]);
      final r = ScheduleEngine.expand(
          range: DateRange(d(2026, 11, 23), d(2026, 11, 23)), batches: [pa]);
      expect(r.occurrences.single.startMin, t(16, 30));
      expect(r.occurrences.single.occ, 's.pa-mon.20261123');
      expect(r.movedAway.single.newStartMin, t(16, 30));
    });

    test('extra class (ad-hoc roll call) gets an x.<exceptionId> occ', () {
      final pa = physicsA(
          ex: [extraEx('adhoc-1', 'pa', d(2026, 11, 26), t(18, 0), t(19, 0))]);
      final r = ScheduleEngine.expand(
          range: DateRange(d(2026, 11, 26), d(2026, 11, 26)), batches: [pa]);
      final o = r.occurrences.single;
      expect(o.occ, 'x.adhoc-1');
      expect(o.kind, OccurrenceKind.extra);
      expect(o.exceptionId, 'adhoc-1');
      expect(o.slotId, isNull);
      expect(OccId.parse(o.occ), const ExtraOccRef('adhoc-1'));
    });

    test('occ round-trips for regular and rescheduled occurrences', () {
      final r = ScheduleEngine.expand(
          range: DateRange(d(2026, 11, 21), d(2026, 11, 21)),
          batches: [physicsA()]);
      expect(OccId.parse(r.occurrences.single.occ),
          RegularOccRef('pa-sat', d(2026, 11, 21)));
    });

    test('two exceptions for one occurrence: last in the list wins', () {
      final cancelThenMove = physicsA(ex: [
        cancelEx('a', 'pa', 'pa-sat', d(2026, 11, 21)),
        rescheduleEx('b', 'pa', 'pa-sat', d(2026, 11, 21), d(2026, 11, 21),
            t(18, 0), t(19, 0)),
      ]);
      final r1 = ScheduleEngine.expand(
          range: DateRange(d(2026, 11, 21), d(2026, 11, 21)),
          batches: [cancelThenMove]);
      expect(r1.cancelled, isEmpty);
      expect(r1.occurrences.single.startMin, t(18, 0));

      final moveThenCancel = physicsA(ex: [
        rescheduleEx('b', 'pa', 'pa-sat', d(2026, 11, 21), d(2026, 11, 21),
            t(18, 0), t(19, 0)),
        cancelEx('a', 'pa', 'pa-sat', d(2026, 11, 21)),
      ]);
      final r2 = ScheduleEngine.expand(
          range: DateRange(d(2026, 11, 21), d(2026, 11, 21)),
          batches: [moveThenCancel]);
      expect(r2.occurrences, isEmpty);
      expect(r2.cancelled.single.exceptionId, 'a');
    });

    test('orphaned reschedule (slot not valid on original date) is ignored',
        () {
      final s = slot('pa-sat', 'pa', 6, t(16, 0), t(17, 0),
          to: d(2026, 11, 20));
      final b = sched(batch('pa'), slots: [s], exceptions: [
        rescheduleEx('r', 'pa', 'pa-sat', d(2026, 11, 21), d(2026, 11, 22),
            t(9, 0), t(10, 0)),
      ]);
      final r = ScheduleEngine.expand(
          range: DateRange(d(2026, 11, 21), d(2026, 11, 22)), batches: [b]);
      expect(r, const ExpandResult());
    });

    test('malformed reschedule (no new date) is ignored; class stays', () {
      final b = physicsA(ex: [
        ScheduleException(
            id: 'bad',
            batchId: 'pa',
            kind: ExceptionKind.reschedule,
            slotId: 'pa-sat',
            originalDate: d(2026, 11, 21)),
      ]);
      final r = ScheduleEngine.expand(
          range: DateRange(d(2026, 11, 21), d(2026, 11, 21)), batches: [b]);
      expect(r.occurrences.single.kind, OccurrenceKind.regular);
    });

    test('month boundary range', () {
      final r = ScheduleEngine.expand(
        range: DateRange(d(2026, 11, 29), d(2026, 12, 2)),
        batches: [physicsA(), chemB()],
      );
      expect(r.occurrences.map((o) => o.occ), [
        's.cb-sun.20261129',
        's.pa-mon.20261130',
        's.cb-tue.20261201',
        's.pa-wed.20261202',
      ]);
    });

    test('year boundary range', () {
      final r = ScheduleEngine.expand(
        range: DateRange(d(2026, 12, 28), d(2027, 1, 5)),
        batches: [chemB()],
      );
      expect(r.occurrences.map((o) => o.date),
          [d(2026, 12, 29), d(2027, 1, 3), d(2027, 1, 5)]);
    });

    test('empty range -> empty result', () {
      final r = ScheduleEngine.expand(
          range: DateRange(d(2026, 11, 22), d(2026, 11, 21)),
          batches: [physicsA()]);
      expect(r, const ExpandResult());
    });

    test('sorted by date, start, then batchId', () {
      final a = sched(batch('b2'), slots: [slot('s2', 'b2', 6, 600, 660)]);
      final b = sched(batch('b1'), slots: [slot('s1', 'b1', 6, 600, 660)]);
      final c = sched(batch('b0'), slots: [slot('s0', 'b0', 6, 540, 600)]);
      final r = ScheduleEngine.expand(
          range: DateRange(d(2026, 11, 21), d(2026, 11, 21)),
          batches: [a, b, c]);
      expect(r.occurrences.map((o) => o.batchId), ['b0', 'b1', 'b2']);
    });

    test('scenario 25: two Physics A rows on 12 Dec, distinct occs', () {
      final pa = sched(batch('pa'),
          slots: [slot('pa-sat-am', 'pa', 6, t(8, 0), t(9, 0))],
          exceptions: [
            extraEx('e17', 'pa', d(2026, 12, 12), t(17, 0), t(18, 0)),
          ]);
      final occs = occsOn([pa], d(2026, 12, 12));
      expect(occs.map((o) => (o.occ, o.startMin, o.endMin)), [
        ('s.pa-sat-am.20261212', 480, 540),
        ('x.e17', 1020, 1080),
      ]);
    });
  });

  // -------------------------------------------------------------------------
  group('findClashes', () {
    final day = d(2026, 11, 22);
    test('reports overlaps only; touching and other dates never clash', () {
      final cand = oneOff('x.a', 'mc', day, t(10, 30), t(11, 30));
      final existing = [
        reg('cb-sun', 'cb', day, t(10, 0), t(11, 0)),
        oneOff('x.b', 'pa', day, t(11, 30), t(12, 30)), // touching
        oneOff('x.c', 'pa', d(2026, 11, 23), t(10, 30), t(11, 30)),
      ];
      final r = ScheduleEngine.findClashes(
          candidates: [cand], existing: existing);
      expect(r, [Clash(candidate: cand, existing: existing.first)]);
    });

    test('an occurrence never clashes with itself (same occ)', () {
      final o = reg('cb-sun', 'cb', day, t(10, 0), t(11, 0));
      final moved = Occurrence(
          occ: o.occ,
          batchId: 'cb',
          date: day,
          startMin: t(10, 30),
          endMin: t(11, 30),
          kind: OccurrenceKind.rescheduled);
      expect(ScheduleEngine.findClashes(candidates: [moved], existing: [o]),
          isEmpty);
    });

    test('same list on both sides: each pair once', () {
      final a = oneOff('x.a', 'p', day, 600, 660);
      final b = oneOff('x.b', 'q', day, 630, 690);
      final c = oneOff('x.c', 'r', day, 690, 750);
      final all = [a, b, c];
      final r = ScheduleEngine.findClashes(candidates: all, existing: all);
      expect(r, [Clash(candidate: a, existing: b)]);
    });

    test('24:00 end vs next day 00:00 start never clash', () {
      final late = oneOff('x.l', 'p', d(2026, 11, 21), t(23, 0), 1440);
      final early = oneOff('x.e', 'q', d(2026, 11, 22), 0, 60);
      expect(
          ScheduleEngine.findClashes(candidates: [late], existing: [early]),
          isEmpty);
    });

    test('legacy conflict from expansion (archived batch ignored)', () {
      final bio = sched(batch('bio', archivedOn: d(2026, 10, 1)),
          slots: [slot('bio-sat', 'bio', 6, t(16, 0), t(17, 0))]);
      final occs = occsOn([physicsA(), bio], d(2026, 11, 21));
      expect(ScheduleEngine.findClashes(candidates: occs, existing: occs),
          isEmpty);
      final unarchived =
          sched(batch('bio'), slots: [slot('bio-sat', 'bio', 6, 960, 1020)]);
      final occs2 = occsOn([physicsA(), unarchived], d(2026, 11, 21));
      expect(ScheduleEngine.findClashes(candidates: occs2, existing: occs2),
          hasLength(1));
    });
  });

  // -------------------------------------------------------------------------
  group('checkSingle', () {
    final sun = d(2026, 11, 22);
    // Scenario 17 world: Chem B Sun 10-11 + Physics A extra Sun 11-12.
    List<BatchSchedule> s17() => [
          chemB(),
          physicsA(ex: [extraEx('pe', 'pa', sun, t(11, 0), t(12, 0))]),
          mathC(),
        ];

    test('scenario 17: Math C extra 10:30-11:30 refused, both cited', () {
      final r = ScheduleEngine.checkSingle(
        candidate: oneOff('x.new', 'mc', sun, t(10, 30), t(11, 30)),
        all: s17(),
      );
      expect(r.ok, isFalse);
      expect(r.groups, [
        ClashGroup(
          batchId: 'cb',
          startMin: 600,
          endMin: 660,
          everyWeek: false,
          weekday: 7,
          date: sun,
          existingKind: OccurrenceKind.regular,
          count: 1,
        ),
        ClashGroup(
          batchId: 'pa',
          startMin: 660,
          endMin: 720,
          everyWeek: false,
          weekday: 7,
          date: sun,
          existingKind: OccurrenceKind.extra,
          count: 1,
        ),
      ]);
      expect(
          r.suggestion,
          const FreeSuggestion(
              durationMin: 60,
              earlierStartMin: 540, // 09:00-10:00
              laterStartMin: 720, // 12:00-13:00
              preferredStartMin: 630));
      // Equal shift (90 min) -> later wins.
      expect(r.suggestion?.primaryStartMin, 720);
    });

    test('scenario 17: tapping either suggestion then saving succeeds', () {
      for (final s in [540, 720]) {
        final r = ScheduleEngine.checkSingle(
          candidate: oneOff('x.new', 'mc', sun, s, s + 60),
          all: s17(),
        );
        expect(r, const SlotCheckResult(), reason: 'start $s');
      }
    });

    test('scenario 17: Chem B extra 10:30-11:30 refused by its own class', () {
      final r = ScheduleEngine.checkSingle(
        candidate: oneOff('x.cbx', 'cb', sun, t(10, 30), t(11, 30)),
        all: s17(),
      );
      expect(r.groups.map((g) => (g.batchId, g.startMin)),
          [('cb', 600), ('pa', 660)]);
    });

    test('scenario 17: Chem B extra 17:00-18:00 saves', () {
      final r = ScheduleEngine.checkSingle(
        candidate: oneOff('x.cbx', 'cb', sun, t(17, 0), t(18, 0)),
        all: s17(),
      );
      expect(r.ok, isTrue);
      expect(r.suggestion, isNull);
    });

    test('scenario 19: reschedule into Chem B 10:00-11:00 refused', () {
      final occ = OccId.regular('pa-mon', d(2026, 11, 23));
      final r = ScheduleEngine.checkSingle(
        candidate: Occurrence(
            occ: occ,
            batchId: 'pa',
            date: d(2026, 11, 24),
            startMin: t(10, 30),
            endMin: t(11, 30),
            kind: OccurrenceKind.rescheduled,
            slotId: 'pa-mon'),
        all: [physicsA(), chemB()],
        excludeOcc: occ,
      );
      expect(r.groups, [
        ClashGroup(
          batchId: 'cb',
          startMin: 600,
          endMin: 660,
          everyWeek: false,
          weekday: 2,
          date: d(2026, 11, 24),
          existingKind: OccurrenceKind.regular,
          count: 1,
        ),
      ]);
      expect(r.suggestion?.earlierStartMin, 540);
      expect(r.suggestion?.laterStartMin, 660);
    });

    test('scenario 19: reschedule to 11:00-12:00 saves', () {
      final occ = OccId.regular('pa-mon', d(2026, 11, 23));
      final r = ScheduleEngine.checkSingle(
        candidate: Occurrence(
            occ: occ,
            batchId: 'pa',
            date: d(2026, 11, 24),
            startMin: t(11, 0),
            endMin: t(12, 0),
            kind: OccurrenceKind.rescheduled,
            slotId: 'pa-mon'),
        all: [physicsA(), chemB()],
        excludeOcc: occ,
      );
      expect(r.ok, isTrue);
    });

    test('reschedule into its own original slot / overlapping itself is fine',
        () {
      final occ = OccId.regular('pa-mon', d(2026, 11, 23));
      for (final start in [t(16, 0), t(16, 30), t(15, 30)]) {
        final r = ScheduleEngine.checkSingle(
          candidate: Occurrence(
              occ: occ,
              batchId: 'pa',
              date: d(2026, 11, 23),
              startMin: start,
              endMin: start + 60,
              kind: OccurrenceKind.rescheduled,
              slotId: 'pa-mon'),
          all: [physicsA(), chemB()],
          excludeOcc: occ,
        );
        expect(r.ok, isTrue, reason: 'start $start');
      }
    });

    test('re-rescheduling an already moved class ignores its moved copy', () {
      final occ = OccId.regular('pa-mon', d(2026, 11, 23));
      final pa = physicsA(ex: [
        rescheduleEx('r1', 'pa', 'pa-mon', d(2026, 11, 23), d(2026, 11, 24),
            t(11, 0), t(12, 0)),
      ]);
      final r = ScheduleEngine.checkSingle(
        candidate: Occurrence(
            occ: occ,
            batchId: 'pa',
            date: d(2026, 11, 24),
            startMin: t(11, 30),
            endMin: t(12, 30),
            kind: OccurrenceKind.rescheduled,
            slotId: 'pa-mon'),
        all: [pa, chemB()],
        excludeOcc: occ,
      );
      expect(r.ok, isTrue);
    });

    test('rescheduling one of two same-day classes onto the other clashes',
        () {
      final pa = sched(batch('pa'), slots: [
        slot('am', 'pa', 6, t(8, 0), t(9, 0)),
        slot('pm', 'pa', 6, t(16, 0), t(17, 0)),
      ]);
      final occ = OccId.regular('pm', d(2026, 11, 21));
      final r = ScheduleEngine.checkSingle(
        candidate: Occurrence(
            occ: occ,
            batchId: 'pa',
            date: d(2026, 11, 21),
            startMin: t(8, 30),
            endMin: t(9, 30),
            kind: OccurrenceKind.rescheduled,
            slotId: 'pm'),
        all: [pa],
        excludeOcc: occ,
      );
      expect(r.groups.single.batchId, 'pa');
      expect(r.groups.single.startMin, t(8, 0));
      // Busy 08:00-09:00 only (16:00 is the class being moved).
      expect(r.suggestion?.earlierStartMin, t(7, 0));
      expect(r.suggestion?.laterStartMin, t(9, 0));
    });

    test('cancel then add an extra at the same time: allowed', () {
      final cb = chemB(ex: [cancelEx('c', 'cb', 'cb-sun', sun)]);
      final r = ScheduleEngine.checkSingle(
        candidate: oneOff('x.m', 'mc', sun, t(10, 0), t(11, 0)),
        all: [cb, mathC()],
      );
      expect(r.ok, isTrue);
      // The cancelled batch itself may also use the freed time.
      final r2 = ScheduleEngine.checkSingle(
        candidate: oneOff('x.c2', 'cb', sun, t(10, 0), t(11, 0)),
        all: [cb],
      );
      expect(r2.ok, isTrue);
    });

    test('cancel removal ("restore") is checked against what took the time',
        () {
      final cb = chemB(ex: [cancelEx('c', 'cb', 'cb-sun', sun)]);
      final mc = mathC(ex: [extraEx('m', 'mc', sun, t(10, 0), t(11, 0))]);
      final r = ScheduleEngine.checkSingle(
        candidate: reg('cb-sun', 'cb', sun, t(10, 0), t(11, 0)),
        all: [cb, mc],
      );
      expect(r.groups.single.batchId, 'mc');
      expect(r.groups.single.existingKind, OccurrenceKind.extra);
    });

    test('scenario 21: archived batch never blocks a one-off', () {
      final bio = sched(batch('bio', archivedOn: d(2026, 10, 1)),
          slots: [slot('bio-sat', 'bio', 6, t(16, 0), t(17, 0))]);
      final r = ScheduleEngine.checkSingle(
        candidate: oneOff('x.p', 'pa', d(2026, 11, 21), t(16, 0), t(17, 0)),
        all: [bio],
      );
      expect(r.ok, isTrue);
    });

    test('scenario 25: second Physics A class allowed, 08:30-09:30 refused',
        () {
      final pa = sched(batch('pa'),
          slots: [slot('pa-sat-am', 'pa', 6, t(8, 0), t(9, 0))]);
      final dec12 = d(2026, 12, 12);
      expect(
          ScheduleEngine.checkSingle(
                  candidate: oneOff('x.e17', 'pa', dec12, t(17, 0), t(18, 0)),
                  all: [pa])
              .ok,
          isTrue);

      final withExtra = sched(batch('pa'),
          slots: [slot('pa-sat-am', 'pa', 6, t(8, 0), t(9, 0))],
          exceptions: [extraEx('e17', 'pa', dec12, t(17, 0), t(18, 0))]);
      final r = ScheduleEngine.checkSingle(
        candidate: oneOff('x.e8', 'pa', dec12, t(8, 30), t(9, 30)),
        all: [withExtra],
      );
      expect(r.groups, [
        ClashGroup(
          batchId: 'pa',
          startMin: 480,
          endMin: 540,
          everyWeek: false,
          weekday: 6,
          date: dec12,
          existingKind: OccurrenceKind.regular,
          count: 1,
        ),
      ]);
      expect(
          r.suggestion,
          const FreeSuggestion(
              durationMin: 60,
              earlierStartMin: 420,
              laterStartMin: 540,
              preferredStartMin: 510));
    });

    test('excludeOcc removes the extra being edited', () {
      final mc = mathC(ex: [extraEx('m', 'mc', sun, t(12, 0), t(13, 0))]);
      final r = ScheduleEngine.checkSingle(
        candidate: oneOff('x.edit', 'mc', sun, t(12, 30), t(13, 30)),
        all: [mc],
        excludeOcc: 'x.m',
      );
      expect(r.ok, isTrue);
    });

    test('23:00-23:59 one-off: no later suggestion inside the day window',
        () {
      final cb = chemB(ex: [extraEx('n', 'cb', sun, t(23, 0), t(23, 59))]);
      final r = ScheduleEngine.checkSingle(
        candidate: oneOff('x.z', 'mc', sun, t(23, 0), t(23, 59)),
        all: [cb],
      );
      expect(r.groups.single.startMin, t(23, 0));
      expect(r.suggestion?.laterStartMin, isNull);
      // Latest start whose 59-min class ends by 23:00 on a 5-min step.
      expect(r.suggestion?.earlierStartMin, t(22, 0));
    });

    test('00:00 one-off: no earlier suggestion inside the day window', () {
      final cb = chemB(ex: [extraEx('n', 'cb', sun, 0, 60)]);
      final r = ScheduleEngine.checkSingle(
        candidate: oneOff('x.z', 'mc', sun, 0, 60),
        all: [cb],
      );
      expect(r.groups.single.startMin, 0);
      expect(r.suggestion?.earlierStartMin, isNull);
      expect(r.suggestion?.laterStartMin, 360);
    });
  });

  // -------------------------------------------------------------------------
  group('checkSlotEdit', () {
    test('scenario 18: touching Sun 11:00-12:00 saves', () {
      final r = ScheduleEngine.checkSlotEdit(
        proposed: mathC(slots: [slot('mc-sun', 'mc', 7, t(11, 0), t(12, 0))]),
        others: [physicsA(), chemB()],
        from: today,
        today: today,
      );
      expect(r, const SlotCheckResult());
    });

    test('scenario 18: edited to 10:55-11:55 refused, every Sunday', () {
      final r = ScheduleEngine.checkSlotEdit(
        proposed:
            mathC(slots: [slot('mc-sun', 'mc', 7, t(10, 55), t(11, 55))]),
        others: [physicsA(), chemB()],
        from: today,
        today: today,
      );
      expect(r.groups, const [
        ClashGroup(
          batchId: 'cb',
          startMin: 600,
          endMin: 660,
          everyWeek: true,
          weekday: 7,
          existingKind: OccurrenceKind.regular,
          count: 12, // Sundays 2026-11-22 .. 2027-02-07
        ),
      ]);
      expect(
          r.suggestion,
          const FreeSuggestion(
              durationMin: 60,
              earlierStartMin: 540,
              laterStartMin: 660,
              preferredStartMin: 655));
      expect(r.suggestion?.primaryStartMin, 660);
    });

    test('scenario 20: Thu slot refused naming Chem B extra on 26 Nov only',
        () {
      final cb =
          chemB(ex: [extraEx('cx', 'cb', d(2026, 11, 26), t(16, 30), t(17, 30))]);
      final pa = sched(batch('pa'), slots: [
        paSat,
        paMon,
        paWed,
        slot('pa-thu', 'pa', 4, t(16, 0), t(17, 0), from: today),
      ]);
      final r = ScheduleEngine.checkSlotEdit(
        proposed: pa,
        others: [cb],
        from: today,
        today: today,
        onlySlotIds: {'pa-thu'},
      );
      expect(r.groups, [
        ClashGroup(
          batchId: 'cb',
          startMin: 990,
          endMin: 1050,
          everyWeek: false,
          weekday: 4,
          date: d(2026, 11, 26),
          existingKind: OccurrenceKind.extra,
          count: 1,
        ),
      ]);
      expect(
          r.suggestion,
          const FreeSuggestion(
              durationMin: 60,
              earlierStartMin: 930, // 15:30
              laterStartMin: 1050, // 17:30
              preferredStartMin: 960));

      // After the extra is moved to 17:00-18:00 the slot saves (touching).
      final cbMoved =
          chemB(ex: [extraEx('cx', 'cb', d(2026, 11, 26), t(17, 0), t(18, 0))]);
      final ok = ScheduleEngine.checkSlotEdit(
        proposed: pa,
        others: [cbMoved],
        from: today,
        today: today,
        onlySlotIds: {'pa-thu'},
      );
      expect(ok.ok, isTrue);
    });

    test('scenario 20: past Physics A occurrences unaffected by the new slot',
        () {
      final before = ScheduleEngine.expand(
          range: DateRange(d(2026, 11, 1), d(2026, 11, 19)),
          batches: [physicsA()]);
      final pa = sched(batch('pa'), slots: [
        paSat,
        paMon,
        paWed,
        slot('pa-thu', 'pa', 4, t(16, 0), t(17, 0), from: today),
      ]);
      final after = ScheduleEngine.expand(
          range: DateRange(d(2026, 11, 1), d(2026, 11, 19)), batches: [pa]);
      expect(after, before);
    });

    test('scenario 21: archived Old Bio does not conflict with Physics A', () {
      final bio = sched(batch('bio', archivedOn: d(2026, 11, 1)),
          slots: [slot('bio-sat', 'bio', 6, t(16, 0), t(17, 0))]);
      final r = ScheduleEngine.checkSlotEdit(
        proposed: physicsA(),
        others: [bio, chemB()],
        from: today,
        today: today,
      );
      expect(r.ok, isTrue);
    });

    test('scenario 21: un-archive check lists the Physics A clash', () {
      final bio = sched(batch('bio', archivedOn: d(2026, 11, 1)),
          slots: [slot('bio-sat', 'bio', 6, t(16, 0), t(17, 0))]);
      final r = ScheduleEngine.checkSlotEdit(
        proposed: bio,
        others: [physicsA(), chemB()],
        from: today,
        today: today,
      );
      expect(r.groups, const [
        ClashGroup(
          batchId: 'pa',
          startMin: 960,
          endMin: 1020,
          everyWeek: true,
          weekday: 6,
          existingKind: OccurrenceKind.regular,
          count: 12,
        ),
      ]);
      expect(r.suggestion?.earlierStartMin, t(15, 0));
      expect(r.suggestion?.laterStartMin, t(17, 0));
    });

    test('scenario 25: Fri 08:00-09:00 and Fri 17:00-18:00 coexist', () {
      final r = ScheduleEngine.checkSlotEdit(
        proposed: sched(batch('pa'), slots: [
          slot('f1', 'pa', 5, t(8, 0), t(9, 0)),
          slot('f2', 'pa', 5, t(17, 0), t(18, 0)),
        ]),
        others: [chemB()],
        from: today,
        today: today,
      );
      expect(r.ok, isTrue);
    });

    test('two overlapping slots of the same batch on one weekday: blocked',
        () {
      final r = ScheduleEngine.checkSlotEdit(
        proposed: sched(batch('pa'), slots: [
          slot('f1', 'pa', 5, t(8, 0), t(9, 0)),
          slot('f2', 'pa', 5, t(8, 30), t(9, 30)),
        ]),
        others: const [],
        from: today,
        today: today,
      );
      expect(r.groups, const [
        ClashGroup(
          batchId: 'pa',
          startMin: 510,
          endMin: 570,
          everyWeek: true,
          weekday: 5,
          existingKind: OccurrenceKind.regular,
          count: 13, // Fridays 2026-11-20 .. 2027-02-12 inclusive
        ),
      ]);
      // Suggestion for f1 (first clash): busy 08:30-09:30 every Friday.
      expect(r.suggestion?.earlierStartMin, t(7, 30));
      expect(r.suggestion?.laterStartMin, t(9, 30));
    });

    test('identical slots of two batches clash', () {
      final r = ScheduleEngine.checkSlotEdit(
        proposed: sched(batch('z'), slots: [slot('z1', 'z', 2, 600, 660)]),
        others: [chemB()],
        from: today,
        today: today,
      );
      expect(r.groups.single.batchId, 'cb');
      expect(r.groups.single.weekday, 2);
    });

    test('containment (slot inside another) clashes', () {
      final r = ScheduleEngine.checkSlotEdit(
        proposed: sched(batch('z'), slots: [slot('z1', 'z', 2, 615, 645)]),
        others: [chemB()],
        from: today,
        today: today,
      );
      expect(r.ok, isFalse);
    });

    test('other batch of the same subject is still checked', () {
      final cb2 = BatchSchedule(
        batch: Batch(
            id: 'cb2',
            subjectId: 'subj-cb',
            name: 'Chem B2',
            billingType: BillingType.postpaid,
            createdOn: created,
            sortOrder: 1),
        subjectName: 'Chemistry',
        slots: [slot('cb2-sun', 'cb2', 7, t(10, 30), t(11, 30))],
      );
      final r = ScheduleEngine.checkSlotEdit(
          proposed: cb2, others: [chemB()], from: today, today: today);
      expect(r.groups.single.batchId, 'cb');
    });

    test('old version of the proposed batch in others is ignored', () {
      final r = ScheduleEngine.checkSlotEdit(
        proposed: sched(batch('cb'),
            slots: [slot('cb-sun', 'cb', 7, t(10, 30), t(11, 30))]),
        others: [chemB()],
        from: today,
        today: today,
      );
      expect(r.ok, isTrue);
    });

    test('proposed slot vs the same batch own future extra: blocked', () {
      final pa = sched(batch('pa'),
          slots: [slot('pa-thu', 'pa', 4, t(16, 0), t(17, 0))],
          exceptions: [
            extraEx('own', 'pa', d(2026, 12, 3), t(16, 30), t(17, 30)),
          ]);
      final r = ScheduleEngine.checkSlotEdit(
          proposed: pa, others: const [], from: today, today: today);
      expect(r.groups.single.date, d(2026, 12, 3));
      expect(r.groups.single.existingKind, OccurrenceKind.extra);
      expect(r.groups.single.batchId, 'pa');
    });

    test('rescheduled-in class of another batch is a one-off clash', () {
      final cb = chemB(ex: [
        rescheduleEx('r', 'cb', 'cb-tue', d(2026, 12, 1), d(2026, 12, 3),
            t(16, 30), t(17, 30)),
      ]);
      final r = ScheduleEngine.checkSlotEdit(
        proposed: sched(batch('pa'),
            slots: [slot('pa-thu', 'pa', 4, t(16, 0), t(17, 0))]),
        others: [cb],
        from: today,
        today: today,
      );
      expect(r.groups, [
        ClashGroup(
          batchId: 'cb',
          startMin: 990,
          endMin: 1050,
          everyWeek: false,
          weekday: 4,
          date: d(2026, 12, 3),
          existingKind: OccurrenceKind.rescheduled,
          count: 1,
        ),
      ]);
    });

    test('future one-off beyond the 12-week horizon is still checked', () {
      final cb = chemB(
          ex: [extraEx('far', 'cb', d(2027, 6, 10), t(16, 30), t(17, 30))]);
      final r = ScheduleEngine.checkSlotEdit(
        proposed: sched(batch('pa'),
            slots: [slot('pa-thu', 'pa', 4, t(16, 0), t(17, 0))]),
        others: [cb],
        from: today,
        today: today,
      );
      expect(r.groups.single.date, d(2027, 6, 10));
    });

    test('past one-off (before today) is not checked', () {
      final cb = chemB(
          ex: [extraEx('old', 'cb', d(2026, 11, 19), t(16, 30), t(17, 30))]);
      final r = ScheduleEngine.checkSlotEdit(
        proposed: sched(batch('pa'),
            slots: [slot('pa-thu', 'pa', 4, t(16, 0), t(17, 0))]),
        others: [cb],
        from: d(2026, 11, 1),
        today: today,
      );
      expect(r.ok, isTrue);
    });

    test('one-off before the "from" date is not checked', () {
      final cb = chemB(
          ex: [extraEx('cx', 'cb', d(2026, 11, 26), t(16, 30), t(17, 30))]);
      final r = ScheduleEngine.checkSlotEdit(
        proposed: sched(batch('pa'), slots: [
          slot('pa-thu', 'pa', 4, t(16, 0), t(17, 0), from: d(2026, 11, 27)),
        ]),
        others: [cb],
        from: d(2026, 11, 27),
        today: today,
      );
      expect(r.ok, isTrue);
    });

    test('"from date" split: only the new version is checked from that date',
        () {
      // Math C Sun 11:00-12:00 until 12-05, then 10:30-11:30 from Sun 12-06.
      final mc = sched(batch('mc', createdOn: today), slots: [
        slot('mc-sun', 'mc', 7, t(11, 0), t(12, 0), to: d(2026, 12, 5)),
        slot('mc-sun-b', 'mc', 7, t(10, 30), t(11, 30), from: d(2026, 12, 6)),
      ]);
      final r = ScheduleEngine.checkSlotEdit(
        proposed: mc,
        others: [chemB()],
        from: d(2026, 12, 6),
        today: today,
        onlySlotIds: {'mc-sun-b'},
      );
      expect(r.groups, const [
        ClashGroup(
          batchId: 'cb',
          startMin: 600,
          endMin: 660,
          everyWeek: true,
          weekday: 7,
          existingKind: OccurrenceKind.regular,
          count: 13, // Sundays 2026-12-06 .. 2027-02-28 inclusive
        ),
      ]);
      expect(r.suggestion?.preferredStartMin, t(10, 30));
      expect(r.suggestion?.laterStartMin, t(11, 0));
      expect(r.suggestion?.earlierStartMin, t(9, 0));
    });

    test('onlySlotIds: an unrelated legacy conflict does not block', () {
      // Legacy: pa-sat clashes with live Old Bio Sat 16:00-17:00.
      final bio = sched(batch('bio'),
          slots: [slot('bio-sat', 'bio', 6, t(16, 0), t(17, 0))]);
      final pa = sched(batch('pa'), slots: [
        paSat,
        slot('pa-mon', 'pa', 1, t(18, 0), t(19, 0)),
        paWed,
      ]);
      final focused = ScheduleEngine.checkSlotEdit(
        proposed: pa,
        others: [bio, chemB()],
        from: today,
        today: today,
        onlySlotIds: {'pa-mon'},
      );
      expect(focused.ok, isTrue);

      final full = ScheduleEngine.checkSlotEdit(
          proposed: pa, others: [bio, chemB()], from: today, today: today);
      expect(full.groups.single.batchId, 'bio');
      expect(full.groups.single.weekday, 6);
    });

    test('onlySlotIds: legacy conflict party being edited must end clean', () {
      final bio = sched(batch('bio'),
          slots: [slot('bio-sat', 'bio', 6, t(16, 0), t(17, 0))]);
      final pa = sched(batch('pa'), slots: [
        slot('pa-sat', 'pa', 6, t(16, 30), t(17, 30)),
        paMon,
        paWed,
      ]);
      final r = ScheduleEngine.checkSlotEdit(
        proposed: pa,
        others: [bio],
        from: today,
        today: today,
        onlySlotIds: {'pa-sat'},
      );
      expect(r.groups.single.batchId, 'bio');
    });

    test('own cancelled date frees the time for the new slot', () {
      final pa = sched(batch('pa'), slots: [
        slot('pa-thu', 'pa', 4, t(16, 0), t(17, 0)),
      ], exceptions: [
        cancelEx('c', 'pa', 'pa-thu', d(2026, 11, 26)),
      ]);
      final cb =
          chemB(ex: [extraEx('cx', 'cb', d(2026, 11, 26), t(16, 30), t(17, 30))]);
      final r = ScheduleEngine.checkSlotEdit(
          proposed: pa, others: [cb], from: today, today: today);
      expect(r.ok, isTrue);
    });

    test('other batch slot ending mid-horizon: count only its live weeks', () {
      final cb = sched(batch('cb'),
          slots: [slot('cb-sun', 'cb', 7, 600, 660, to: d(2026, 11, 30))]);
      final r = ScheduleEngine.checkSlotEdit(
        proposed: mathC(slots: [slot('mc-sun', 'mc', 7, 630, 690)]),
        others: [cb],
        from: today,
        today: today,
      );
      expect(r.groups.single.count, 2); // 11-22 and 11-29
    });

    test('other batch slot starting in the future: count from its start', () {
      final cb = sched(batch('cb'),
          slots: [slot('cb-sun', 'cb', 7, 600, 660, from: d(2027, 1, 1))]);
      final r = ScheduleEngine.checkSlotEdit(
        proposed: mathC(slots: [slot('mc-sun', 'mc', 7, 630, 690)]),
        others: [cb],
        from: today,
        today: today,
      );
      expect(r.groups.single.count, 6); // 2027-01-03 .. 2027-02-07
    });

    test('two proposed slots hitting one existing slot -> one group', () {
      final r = ScheduleEngine.checkSlotEdit(
        proposed: mathC(slots: [
          slot('a', 'mc', 7, 600, 630),
          slot('b', 'mc', 7, 630, 660),
        ]),
        others: [chemB()],
        from: today,
        today: today,
      );
      expect(r.groups.single.everyWeek, isTrue);
      expect(r.groups.single.count, 12);
    });

    test('no free time of that length -> both suggestions null', () {
      final r = ScheduleEngine.checkSlotEdit(
        proposed:
            mathC(slots: [slot('long', 'mc', 7, t(6, 0), t(23, 0))]),
        others: [chemB()],
        from: today,
        today: today,
      );
      expect(r.ok, isFalse);
      expect(r.suggestion?.earlierStartMin, isNull);
      expect(r.suggestion?.laterStartMin, isNull);
      expect(r.suggestion?.primaryStartMin, isNull);
    });

    test('suggestion must be free on every checked date of the weekday', () {
      // Sun 2026-11-29 has an extra 09:00-10:00 so 09:00 is not free weekly.
      final cb = chemB(
          ex: [extraEx('e', 'cb', d(2026, 11, 29), t(9, 0), t(10, 0))]);
      final r = ScheduleEngine.checkSlotEdit(
        proposed:
            mathC(slots: [slot('mc-sun', 'mc', 7, t(10, 30), t(11, 30))]),
        others: [cb],
        from: today,
        today: today,
      );
      expect(r.suggestion?.earlierStartMin, t(8, 0));
      expect(r.suggestion?.laterStartMin, t(11, 0));
    });

    test('24:00 slot vs next-day 00:00 slot: no clash', () {
      final r = ScheduleEngine.checkSlotEdit(
        proposed: sched(batch('z'), slots: [slot('z', 'z', 6, t(23, 0), 1440)]),
        others: [
          sched(batch('y'), slots: [slot('y', 'y', 7, 0, 60)]),
        ],
        from: today,
        today: today,
      );
      expect(r.ok, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  group('suggestSameDay', () {
    test('nothing busy: nearest 5-minute steps either side', () {
      final s = ScheduleEngine.suggestSameDay(
          preferredStartMin: 600, durationMin: 60, busy: const []);
      expect(s.earlierStartMin, 595);
      expect(s.laterStartMin, 605);
      expect(s.primaryStartMin, 605); // tie -> later
    });

    test('earlier wins when it is the smaller shift', () {
      final s = ScheduleEngine.suggestSameDay(
          preferredStartMin: 610,
          durationMin: 60,
          busy: const [(620, 700)]);
      expect(s.earlierStartMin, 560);
      expect(s.laterStartMin, 700);
      expect(s.primaryStartMin, 560);
    });

    test('window start edge: no earlier than 06:00', () {
      final s = ScheduleEngine.suggestSameDay(
          preferredStartMin: 360, durationMin: 60, busy: const [(360, 420)]);
      expect(s.earlierStartMin, isNull);
      expect(s.laterStartMin, 420);
    });

    test('window end edge: must end by 23:00', () {
      final s = ScheduleEngine.suggestSameDay(
          preferredStartMin: 1320, durationMin: 60, busy: const [(1320, 1380)]);
      expect(s.laterStartMin, isNull);
      expect(s.earlierStartMin, 1260);
    });

    test('off-grid preferred start snaps to 5-minute clock steps', () {
      final s = ScheduleEngine.suggestSameDay(
          preferredStartMin: 602, durationMin: 60, busy: const [(602, 662)]);
      expect(s.earlierStartMin, 540);
      expect(s.laterStartMin, 665);
    });

    test('off-grid window start rounds up', () {
      final s = ScheduleEngine.suggestSameDay(
          preferredStartMin: 300,
          durationMin: 30,
          busy: const [],
          dayStartMin: 362);
      expect(s.earlierStartMin, isNull);
      expect(s.laterStartMin, 365);
    });

    test('preferred outside the window (05:00) -> later from 06:00', () {
      final s = ScheduleEngine.suggestSameDay(
          preferredStartMin: 300, durationMin: 60, busy: const [(360, 400)]);
      expect(s.earlierStartMin, isNull);
      expect(s.laterStartMin, 400);
    });

    test('duration longer than every gap -> none', () {
      final s = ScheduleEngine.suggestSameDay(
        preferredStartMin: 600,
        durationMin: 120,
        busy: const [(400, 500), (590, 700), (790, 900), (990, 1300)],
      );
      expect(s.earlierStartMin, isNull);
      expect(s.laterStartMin, isNull);
      expect(s.durationMin, 120);
    });

    test('duration longer than the day window -> none', () {
      final s = ScheduleEngine.suggestSameDay(
          preferredStartMin: 360, durationMin: 1100, busy: const []);
      expect(s.earlierStartMin, isNull);
      expect(s.laterStartMin, isNull);
    });

    test('whole window busy -> none ("no free time")', () {
      final s = ScheduleEngine.suggestSameDay(
          preferredStartMin: 700, durationMin: 30, busy: const [(0, 1440)]);
      expect(s,
          const FreeSuggestion(durationMin: 30, preferredStartMin: 700));
    });

    test('touching busy intervals are fine', () {
      final s = ScheduleEngine.suggestSameDay(
          preferredStartMin: 630,
          durationMin: 60,
          busy: const [(600, 660), (720, 780)]);
      expect(s.earlierStartMin, 540);
      expect(s.laterStartMin, 660);
    });

    test('custom step', () {
      final s = ScheduleEngine.suggestSameDay(
          preferredStartMin: 600,
          durationMin: 60,
          busy: const [(600, 660)],
          stepMin: 15);
      expect(s.earlierStartMin, 540);
      expect(s.laterStartMin, 660);
    });

    test('non-positive step is rejected', () {
      expect(
          () => ScheduleEngine.suggestSameDay(
              preferredStartMin: 600,
              durationMin: 60,
              busy: const [],
              stepMin: 0),
          throwsArgumentError);
    });
  });
}
