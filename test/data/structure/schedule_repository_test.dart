import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/errors/error_codes.dart';
import 'package:attendance_alamin/core/ids/ids.dart';
import 'package:attendance_alamin/core/time/date_range.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/data/db/app_database.dart';
import 'package:attendance_alamin/data/db/mappers.dart';
import 'package:attendance_alamin/domain/models/attendance.dart';
import 'package:attendance_alamin/domain/models/drafts.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/schedule/occ_id.dart';
import 'package:attendance_alamin/domain/schedule/schedule_engine.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';
import 'package:drift/drift.dart' hide Batch, isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';

import 'structure_fixtures.dart';

Matcher validation(String code) => throwsA(
    isA<ValidationException>().having((e) => e.code, 'code', code));

Matcher notFound() => throwsA(isA<NotFoundException>());

void main() {
  late Harness h;

  setUp(() => h = Harness());

  Future<String> mathC({List<SlotDraft>? slots}) async => h.batch(
      await h.subject('Math'), 'Math C',
      slots: slots ?? [slot(thu, 840, 900)]);

  group('Product 17: overlap blocked with suggestions', () {
    test('extra class refused, suggestion saves', () async {
      final chem = await h.chemB();
      final physics = await h.physicsA();
      final math = await mathC();

      // Physics A extra Sun 11:00-12:00 touches Chem B's 10:00-11:00.
      final physicsExtra = await h.schedule.addExtra(
          batchId: physics, date: d(2026, 11, 22), startMin: 660, endMin: 720);
      expect(physicsExtra, startsWith('x.'));

      final e = await expectClash(() async {
        await h.schedule.addExtra(
            batchId: math, date: d(2026, 11, 22), startMin: 630, endMin: 690);
      });
      expect(e.code, ErrorCodes.scheduleClash);
      expect(e.result.groups, [
        ClashGroup(
            batchId: chem,
            startMin: 600,
            endMin: 660,
            everyWeek: false,
            weekday: 7,
            date: d(2026, 11, 22),
            existingKind: OccurrenceKind.regular,
            count: 1),
        ClashGroup(
            batchId: physics,
            startMin: 660,
            endMin: 720,
            everyWeek: false,
            weekday: 7,
            date: d(2026, 11, 22),
            existingKind: OccurrenceKind.extra,
            count: 1),
      ]);
      final s = e.result.suggestion;
      expect(s?.durationMin, 60);
      expect(s?.earlierStartMin, 540);
      expect(s?.laterStartMin, 720);
      expect(await h.exceptionRows(math), isEmpty);

      // Tapping the earlier suggestion and saving succeeds.
      final occ = await h.schedule.addExtra(
          batchId: math, date: d(2026, 11, 22), startMin: 540, endMin: 600);
      expect(occ, startsWith('x.'));
      expect(await h.exceptionRows(math), hasLength(1));
    });

    test('an extra overlapping its own batch is refused, a free one saves',
        () async {
      final chem = await h.chemB();
      final e = await expectClash(() async {
        await h.schedule.addExtra(
            batchId: chem, date: d(2026, 11, 22), startMin: 630, endMin: 690);
      });
      expect(e.result.groups.single.batchId, chem);
      expect(e.result.groups.single.startMin, 600);
      final occ = await h.schedule.addExtra(
          batchId: chem, date: d(2026, 11, 22), startMin: 1020, endMin: 1080);
      expect(occ, startsWith('x.'));
    });

    test('suggestions respect the day window setting', () async {
      await h.chemB();
      final math = await mathC();
      await h.db.into(h.db.syncedSettings).insert(stamped(
          SyncedSettingsCompanion(
            id: const Value('day_window_start_min'),
            value: const Value('600'),
          ).copyWith));
      final e = await expectClash(() async {
        await h.schedule.addExtra(
            batchId: math, date: d(2026, 11, 22), startMin: 630, endMin: 690);
      });
      expect(e.result.suggestion?.earlierStartMin, isNull);
      expect(e.result.suggestion?.laterStartMin, 660);
    });
  });

  group('Product 18: touching times', () {
    test('touching saves, a 5 minute overlap is refused every Sunday',
        () async {
      final chem = await h.chemB();
      final math = await mathC(slots: [slot(sun, 660, 720)]);
      final mathSlot = await h.slotId(math, sun);
      final edit = [
        SlotDraft(id: mathSlot, weekday: sun, startMin: 655, endMin: 715),
      ];

      final preview = await h.schedule.checkSlots(math, edit, from: today);
      expect(preview.ok, isFalse);

      final e = await expectClash(
          () => h.schedule.replaceSlots(math, edit, from: today));
      final g = e.result.groups.single;
      expect(g.batchId, chem);
      expect(g.everyWeek, isTrue);
      expect(g.weekday, sun);
      expect(g.startMin, 600);
      expect(g.endMin, 660);
      expect(g.date, isNull);
      expect((await h.slotRow(mathSlot)).startMin, 660);

      // A free time saves in place (the slot starts today: no history).
      await h.schedule.replaceSlots(
          math,
          [SlotDraft(id: mathSlot, weekday: sun, startMin: 720, endMin: 780)],
          from: today);
      final r = await h.slotRow(mathSlot);
      expect(r.startMin, 720);
      expect(r.endMin, 780);
      expect(r.rev, 2);
      expect(r.validFrom, '2026-11-20');
    });

    test('checkSlots for a batch not saved yet', () async {
      final chem = await h.chemB();
      final ok = await h.schedule
          .checkSlots(null, [slot(sun, 660, 720)], from: today);
      expect(ok.ok, isTrue);
      final bad = await h.schedule
          .checkSlots(null, [slot(sun, 655, 715)], from: today);
      expect(bad.groups.single.batchId, chem);
    });
  });

  group('Product 19: reschedule', () {
    test('clash refused, free time saves and shows in the expansion',
        () async {
      final chem = await h.chemB();
      final physics = await h.physicsA();
      final monSlot = await h.slotId(physics, mon);
      final occ = OccId.regular(monSlot, d(2026, 11, 23));

      final e = await expectClash(() => h.schedule.reschedule(occ,
          newDate: d(2026, 11, 24), startMin: 630, endMin: 690));
      final g = e.result.groups.single;
      expect(g.batchId, chem);
      expect(g.date, d(2026, 11, 24));
      expect(g.startMin, 600);
      expect(e.result.suggestion?.earlierStartMin, 540);
      expect(e.result.suggestion?.laterStartMin, 660);
      expect(await h.exceptionRows(physics), isEmpty);

      await h.schedule.reschedule(occ,
          newDate: d(2026, 11, 24), startMin: 660, endMin: 720);

      final row = await h.exceptionRow(Ids.exceptionForOcc(occ));
      expect(row.kind, 'reschedule');
      expect(row.slotId, monSlot);
      expect(row.originalDate, '2026-11-23');
      expect(row.newDate, '2026-11-24');
      expect(row.newStartMin, 660);
      expect(row.newEndMin, 720);
      expectInserted(
          createdAt: row.createdAt,
          updatedAt: row.updatedAt,
          rev: row.rev,
          deviceId: row.deviceId,
          deletedAt: row.deletedAt);

      final info = await h.schedule.resolve(occ);
      expect(info?.subjectName, 'Physics');
      expect(info?.batch.id, physics);
      expect(info?.cancelled, isFalse);
      final o = info?.occurrence;
      expect(o?.kind, OccurrenceKind.rescheduled);
      expect(o?.date, d(2026, 11, 24));
      expect(o?.startMin, 660);
      expect(o?.originalDate, d(2026, 11, 23));
      expect(o?.originalStartMin, 960);

      final res = ScheduleEngine.expand(
          range: DateRange(d(2026, 11, 23), d(2026, 11, 24)),
          batches: await h.loaded());
      expect(res.movedAway.single.occ, occ);
      final moved = res.occurrences.singleWhere((x) => x.batchId == physics);
      expect(moved.date, d(2026, 11, 24));
      expect(moved.startMin, 660);
      expect(moved.occ, occ);
    });

    test('moving back to the original time removes the exception', () async {
      await h.chemB();
      final physics = await h.physicsA();
      final occ =
          OccId.regular(await h.slotId(physics, mon), d(2026, 11, 23));
      await h.schedule.reschedule(occ,
          newDate: d(2026, 11, 24), startMin: 660, endMin: 720);
      await h.schedule.reschedule(occ,
          newDate: d(2026, 11, 23), startMin: 960, endMin: 1020);
      final row = await h.exceptionRow(Ids.exceptionForOcc(occ));
      expect(row.deletedAt, isNotNull);
      expect((await h.schedule.resolve(occ))?.occurrence?.kind,
          OccurrenceKind.regular);
    });

    test('moving within the same day does not clash with itself', () async {
      final physics = await h.physicsA();
      final occ =
          OccId.regular(await h.slotId(physics, mon), d(2026, 11, 23));
      final ok = await h.schedule.checkSingle(
          batchId: physics,
          date: d(2026, 11, 23),
          startMin: 990,
          endMin: 1050,
          replacingOcc: occ);
      expect(ok.ok, isTrue);
      // As a brand new class the same time clashes with the regular one.
      final bad = await h.schedule.checkSingle(
          batchId: physics,
          date: d(2026, 11, 23),
          startMin: 990,
          endMin: 1050);
      expect(bad.ok, isFalse);
      expect(bad.groups.single.batchId, physics);

      await h.schedule.reschedule(occ,
          newDate: d(2026, 11, 23), startMin: 990, endMin: 1050);
      expect((await h.schedule.resolve(occ))?.occurrence?.startMin, 990);
    });

    test('a second reschedule updates the same row', () async {
      final physics = await h.physicsA();
      final occ =
          OccId.regular(await h.slotId(physics, mon), d(2026, 11, 23));
      await h.schedule.reschedule(occ,
          newDate: d(2026, 11, 24), startMin: 660, endMin: 720);
      await h.schedule.reschedule(occ,
          newDate: d(2026, 11, 25), startMin: 600, endMin: 660);
      final rows = await h.exceptionRows(physics);
      expect(rows, hasLength(1));
      expect(rows.single.rev, 2);
      expect(rows.single.updatedAt, t0 + 1);
      expect(rows.single.newDate, '2026-11-25');
    });

    test('a class that does not exist cannot be moved', () async {
      final physics = await h.physicsA();
      // Slot is Monday; 2026-11-24 is a Tuesday.
      final bad = OccId.regular(await h.slotId(physics, mon), d(2026, 11, 24));
      await expectLater(
          h.schedule.reschedule(bad,
              newDate: d(2026, 11, 25), startMin: 600, endMin: 660),
          notFound());
    });
  });

  group('Product 20: slot vs future one-off, edits keep history', () {
    test('a weekly slot is refused by another batch\'s future extra',
        () async {
      final chem = await h.chemB();
      final physics = await h.physicsA();
      final extra = await h.schedule.addExtra(
          batchId: chem, date: d(2026, 11, 26), startMin: 990, endMin: 1050);
      final drafts = [...await h.draftsOf(physics), slot(thu, 960, 1020)];

      final e = await expectClash(
          () => h.schedule.replaceSlots(physics, drafts, from: today));
      final g = e.result.groups.single;
      expect(g.batchId, chem);
      expect(g.everyWeek, isFalse);
      expect(g.date, d(2026, 11, 26));
      expect(g.existingKind, OccurrenceKind.extra);
      expect(await h.slotRows(physics), hasLength(3));

      // Move the extra to 17:00-18:00: the slot saves.
      await h.schedule.reschedule(extra,
          newDate: d(2026, 11, 26), startMin: 1020, endMin: 1080);
      await h.schedule.replaceSlots(physics, drafts, from: today);
      expect(await h.slotRows(physics), hasLength(4));
    });

    test('editing from a later date end-dates the old slot and moves its '
        'future exceptions', () async {
      final physics = await h.physicsA();
      final satSlot = await h.slotId(physics, sat);
      final pastOcc = OccId.regular(satSlot, d(2026, 11, 28));
      final futureOcc = OccId.regular(satSlot, d(2026, 12, 5));
      await h.schedule.cancel(pastOcc);
      await h.schedule.cancel(futureOcc, note: 'exam');
      await h.db.into(h.db.attendanceSessions).insert(stamped(
          sessionToCompanion(AttendanceSession(
            id: 'ses-1',
            occ: OccId.regular(satSlot, d(2026, 11, 21)),
            batchId: physics,
            slotId: satSlot,
            originalDate: d(2026, 11, 21),
            date: d(2026, 11, 21),
            startMin: 960,
            endMin: 1020,
          )).copyWith));

      h.setNow(DateTime.utc(2026, 11, 30, 6));
      final drafts = [
        for (final x in await h.draftsOf(physics))
          x.id == satSlot
              ? SlotDraft(id: satSlot, weekday: sat, startMin: 1020, endMin: 1080)
              : x,
      ];
      await h.schedule.replaceSlots(physics, drafts, from: d(2026, 11, 30));

      // Old version ended the day before; new version starts on the date.
      final old = await h.slotRow(satSlot);
      expect(old.validFrom, '2026-11-20');
      expect(old.validTo, '2026-11-29');
      expect(old.deletedAt, isNull);
      expect(old.startMin, 960);
      expect(old.rev, 2);
      final fresh = (await h.slotRows(physics))
          .singleWhere((s) => s.weekday == sat && s.id != satSlot);
      expect(fresh.validFrom, '2026-11-30');
      expect(fresh.validTo, isNull);
      expect(fresh.startMin, 1020);
      expect(fresh.endMin, 1080);
      expect(fresh.rev, 1);
      expect(fresh.deviceId, dev);

      // The past exception stays; the future one moved to the new slot.
      final past = await h.exceptionRow(Ids.exceptionForOcc(pastOcc));
      expect(past.deletedAt, isNull);
      expect(past.slotId, satSlot);
      final movedOcc = OccId.regular(fresh.id, d(2026, 12, 5));
      final moved = await h.exceptionRow(Ids.exceptionForOcc(movedOcc));
      expect(moved.deletedAt, isNull);
      expect(moved.slotId, fresh.id);
      expect(moved.kind, 'cancel');
      expect(moved.originalDate, '2026-12-05');
      expect(moved.note, 'exam');
      expect(
          (await h.exceptionRow(Ids.exceptionForOcc(futureOcc))).deletedAt,
          isNotNull);

      // Past session untouched.
      final session = await h.db.select(h.db.attendanceSessions).getSingle();
      expect(session.deletedAt, isNull);
      expect(session.rev, 1);

      // The calendar: old time before, new time after, cancels follow.
      final res = ScheduleEngine.expand(
          range: DateRange(d(2026, 11, 21), d(2026, 12, 12)),
          batches: await h.loaded());
      expect([
        for (final o in res.occurrences)
          if (o.date.isoWeekday == sat) '${o.date} ${o.startMin}',
      ], ['2026-11-21 960', '2026-12-12 1020']);
      expect([for (final c in res.cancelled) c.occ], [pastOcc, movedOcc]);
    });

    test('removing a slot: tombstone when it has no history, else end-date',
        () async {
      final math = await mathC(slots: [slot(sun, 660, 720), slot(thu, 840, 900)]);
      final sunSlot = await h.slotId(math, sun);
      final thuSlot = await h.slotId(math, thu);

      await h.schedule.replaceSlots(math,
          [SlotDraft(id: sunSlot, weekday: sun, startMin: 660, endMin: 720)],
          from: today);
      final gone = await h.slotRow(thuSlot);
      expect(gone.deletedAt, isNotNull);
      expect(gone.rev, 2);
      expect((await h.slotRow(sunSlot)).rev, 1); // unchanged slot untouched

      await h.schedule.replaceSlots(math, [slot(thu, 840, 900)],
          from: d(2026, 12, 1));
      final ended = await h.slotRow(sunSlot);
      expect(ended.deletedAt, isNull);
      expect(ended.validTo, '2026-11-30');
      final live = (await h.scheduleOf(math)).slots;
      expect(live, hasLength(2));
      expect(live.any((s) => s.weekday == thu && s.validFrom == d(2026, 12, 1)),
          isTrue);

      await expectLater(h.schedule.replaceSlots(math, [], from: today),
          validation(ErrorCodes.slotsEmpty));
    });

    test('an unchanged list changes nothing; validation and archived batch',
        () async {
      final physics = await h.physicsA();
      await h.schedule
          .replaceSlots(physics, await h.draftsOf(physics), from: today);
      for (final s in await h.slotRows(physics)) {
        expect(s.rev, 1);
      }
      await expectLater(
          h.schedule.replaceSlots(physics, [slot(sat, 1020, 960)], from: today),
          validation(ErrorCodes.slotTimeInvalid));
      await expectLater(
          h.schedule.replaceSlots('nope', [slot(sat, 960, 1020)], from: today),
          notFound());
      await h.batches.archive(physics,
          on: today, lastBillableMonth: const YearMonth(2026, 11));
      await expectLater(
          h.schedule.replaceSlots(physics, [slot(sat, 960, 1020)], from: today),
          validation(ErrorCodes.batchArchived));
    });
  });

  group('Product 25: two classes of one batch in a day', () {
    test('weekly slots Fri 08:00 and Fri 17:00 coexist', () async {
      final phys = await h.batch(await h.subject('Physics'), 'Physics A',
          slots: [slot(fri, 480, 540), slot(fri, 1020, 1080)]);
      final res = ScheduleEngine.expand(
          range: DateRange(d(2026, 12, 11), d(2026, 12, 11)),
          batches: await h.loaded());
      final todays = res.occurrences.where((o) => o.batchId == phys).toList();
      expect(todays, hasLength(2));
      expect(todays[0].occ, isNot(todays[1].occ));
    });

    test('an extra 17:00 saves, an extra overlapping the 08:00 class is '
        'refused', () async {
      final phys = await h.batch(await h.subject('Physics'), 'Physics A',
          slots: [slot(sat, 480, 540)]);
      final extra = await h.schedule.addExtra(
          batchId: phys, date: d(2026, 12, 12), startMin: 1020, endMin: 1080);
      expect(extra, startsWith('x.'));

      final e = await expectClash(() async {
        await h.schedule.addExtra(
            batchId: phys, date: d(2026, 12, 12), startMin: 510, endMin: 570);
      });
      final g = e.result.groups.single;
      expect(g.batchId, phys);
      expect(g.startMin, 480);
      expect(g.endMin, 540);
      expect(g.date, d(2026, 12, 12));
      expect(g.existingKind, OccurrenceKind.regular);

      final res = ScheduleEngine.expand(
          range: DateRange(d(2026, 12, 12), d(2026, 12, 12)),
          batches: await h.loaded());
      expect(res.occurrences.map((o) => o.startMin), [480, 1020]);
      expect(res.occurrences.last.occ, extra);
    });

    test('a batch\'s own weekly slots may not overlap', () async {
      final phys = await h.batch(await h.subject('Physics'), 'Physics A',
          slots: [slot(fri, 480, 540)]);
      final drafts = [...await h.draftsOf(phys), slot(fri, 500, 560)];
      await expectClash(
          () => h.schedule.replaceSlots(phys, drafts, from: today));
    });
  });

  group('extras', () {
    test('add, move, cancel, restore and delete an extra', () async {
      final physics = await h.physicsA();
      final occ = await h.schedule.addExtra(
          batchId: physics,
          date: d(2026, 11, 26),
          startMin: 1080,
          endMin: 1140,
          note: ' n ');
      final id = occ.substring(2);

      var row = await h.exceptionRow(id);
      expect(row.kind, 'extra');
      expect(row.slotId, isNull);
      expect(row.originalDate, isNull);
      expect(row.newDate, '2026-11-26');
      expect(row.note, 'n');
      expectInserted(
          createdAt: row.createdAt,
          updatedAt: row.updatedAt,
          rev: row.rev,
          deviceId: row.deviceId,
          deletedAt: row.deletedAt);

      final info = await h.schedule.resolve(occ);
      expect(info?.occurrence?.kind, OccurrenceKind.extra);
      expect(info?.occurrence?.exceptionId, id);
      expect(info?.occurrence?.startMin, 1080);

      await h.schedule.reschedule(occ,
          newDate: d(2026, 11, 27), startMin: 1080, endMin: 1140);
      row = await h.exceptionRow(id);
      expect(row.newDate, '2026-11-27');
      expect(row.note, 'n');
      expect(row.rev, 2);

      // Cancelling an extra removes it; restore brings it back.
      await h.schedule.cancel(occ);
      expect((await h.exceptionRow(id)).deletedAt, isNotNull);
      expect(await h.schedule.resolve(occ), isNull);
      expect((await h.scheduleOf(physics)).exceptions, isEmpty);
      await h.schedule.restore(occ);
      row = await h.exceptionRow(id);
      expect(row.deletedAt, isNull);
      expect(row.rev, 4);
      expect((await h.schedule.resolve(occ))?.occurrence?.date,
          d(2026, 11, 27));

      await h.schedule.deleteExtra(occ);
      expect((await h.exceptionRow(id)).deletedAt, isNotNull);
      await expectLater(h.schedule.deleteExtra(occ), notFound());
    });

    test('deleteExtra refuses a regular class', () async {
      final physics = await h.physicsA();
      final occ = OccId.regular(await h.slotId(physics, sat), d(2026, 11, 21));
      await expectLater(h.schedule.deleteExtra(occ), notFound());
      await expectLater(h.schedule.deleteExtra('garbage'), notFound());
    });

    test('a removed extra cannot come back onto a taken time', () async {
      final physics = await h.physicsA();
      final occ = await h.schedule.addExtra(
          batchId: physics, date: d(2026, 11, 26), startMin: 840, endMin: 900);
      await h.schedule.deleteExtra(occ);
      // Thursday 14:00-15:00 becomes Math C's weekly class meanwhile.
      final math = await mathC();
      await expectClash(() => h.schedule.restore(occ));
      expect(await h.batches.getById(math), isNotNull);
    });

    test('validation and unknown batches', () async {
      final physics = await h.physicsA();
      await expectLater(
          h.schedule.addExtra(
              batchId: physics, date: today, startMin: 600, endMin: 600),
          validation(ErrorCodes.slotTimeInvalid));
      await expectLater(
          h.schedule.addExtra(
              batchId: 'nope', date: today, startMin: 600, endMin: 660),
          notFound());
      await h.batches.archive(physics,
          on: today, lastBillableMonth: const YearMonth(2026, 11));
      await expectLater(
          h.schedule.addExtra(
              batchId: physics, date: today, startMin: 600, endMin: 660),
          validation(ErrorCodes.batchArchived));
    });
  });

  group('cancel and restore', () {
    test('cancel writes a deterministic stamped exception; restore '
        'tombstones it', () async {
      final physics = await h.physicsA();
      final monSlot = await h.slotId(physics, mon);
      final occ = OccId.regular(monSlot, d(2026, 11, 23));
      final id = Ids.exceptionForOcc(occ);

      await h.schedule.cancel(occ, note: ' Eid ');
      var row = await h.exceptionRow(id);
      expect(row.kind, 'cancel');
      expect(row.batchId, physics);
      expect(row.slotId, monSlot);
      expect(row.originalDate, '2026-11-23');
      expect(row.newDate, isNull);
      expect(row.note, 'Eid');
      expectInserted(
          createdAt: row.createdAt,
          updatedAt: row.updatedAt,
          rev: row.rev,
          deviceId: row.deviceId,
          deletedAt: row.deletedAt);

      final info = await h.schedule.resolve(occ);
      expect(info?.cancelled, isTrue);
      expect(info?.occurrence?.startMin, 960);
      final cancelled = ScheduleEngine.expand(
              range: DateRange(d(2026, 11, 23), d(2026, 11, 23)),
              batches: await h.loaded())
          .cancelled;
      expect(cancelled.single.occ, occ);

      // Cancelling again with the same data writes nothing.
      await h.schedule.cancel(occ, note: 'Eid');
      expect((await h.exceptionRow(id)).rev, 1);

      // A new note updates the same row.
      h.setNow(DateTime.fromMillisecondsSinceEpoch(t0 + 500, isUtc: true));
      await h.schedule.cancel(occ, note: 'Holiday');
      row = await h.exceptionRow(id);
      expect(row.rev, 2);
      expect(row.updatedAt, t0 + 500);
      expect(row.note, 'Holiday');

      await h.schedule.restore(occ);
      row = await h.exceptionRow(id);
      expect(row.deletedAt, isNotNull);
      expect(row.rev, 3);
      expect((await h.schedule.resolve(occ))?.cancelled, isFalse);
      expect((await h.scheduleOf(physics)).exceptions, isEmpty);
      // Restoring something not cancelled is a no-op.
      await h.schedule.restore(occ);
      expect((await h.exceptionRow(id)).rev, 3);

      // Cancelling again revives the same row.
      await h.schedule.cancel(occ);
      row = await h.exceptionRow(id);
      expect(row.deletedAt, isNull);
      expect(row.rev, 4);
      expect(row.note, isNull);
      expect(await h.exceptionRows(physics), hasLength(1));
    });

    test('a cancelled class frees its time; restoring is clash-checked',
        () async {
      final physics = await h.physicsA();
      final math = await mathC();
      final occ = OccId.regular(await h.slotId(physics, mon), d(2026, 11, 23));
      await h.schedule.cancel(occ);

      // Math C takes the freed Monday 16:00-17:00.
      final extra = await h.schedule.addExtra(
          batchId: math, date: d(2026, 11, 23), startMin: 960, endMin: 1020);

      final e = await expectClash(() => h.schedule.restore(occ));
      final g = e.result.groups.single;
      expect(g.batchId, math);
      expect(g.existingKind, OccurrenceKind.extra);
      expect((await h.schedule.resolve(occ))?.cancelled, isTrue);

      await h.schedule.deleteExtra(extra);
      await h.schedule.restore(occ);
      expect((await h.schedule.resolve(occ))?.cancelled, isFalse);
    });

    test('un-moving a class is clash-checked too', () async {
      final physics = await h.physicsA();
      final math = await mathC();
      final occ = OccId.regular(await h.slotId(physics, mon), d(2026, 11, 23));
      await h.schedule.reschedule(occ,
          newDate: d(2026, 11, 24), startMin: 660, endMin: 720);
      await h.schedule.addExtra(
          batchId: math, date: d(2026, 11, 23), startMin: 960, endMin: 1020);
      await expectClash(() => h.schedule.restore(occ));
    });

    test('unknown or impossible occurrences', () async {
      final physics = await h.physicsA();
      await expectLater(h.schedule.cancel('garbage'), notFound());
      await expectLater(
          h.schedule.cancel('s.missing-slot.20261123'), notFound());
      // Saturday slot on a Monday.
      final wrong = OccId.regular(await h.slotId(physics, sat), d(2026, 11, 23));
      await expectLater(h.schedule.cancel(wrong), notFound());
      await expectLater(h.schedule.restore('x.missing'), notFound());
      expect(await h.schedule.resolve('garbage'), isNull);
      expect(await h.schedule.resolve('s.missing-slot.20261123'), isNull);
    });

    test('a slot that ended resolves to no class', () async {
      final physics = await h.physicsA();
      final satSlot = await h.slotId(physics, sat);
      h.setNow(DateTime.utc(2026, 11, 30, 6));
      await h.schedule.replaceSlots(
          physics,
          [
            for (final x in await h.draftsOf(physics))
              if (x.id != satSlot) x,
          ],
          from: d(2026, 11, 30));
      final info =
          await h.schedule.resolve(OccId.regular(satSlot, d(2026, 12, 5)));
      expect(info?.batch.id, physics);
      expect(info?.occurrence, isNull);
      // Past occurrences of the ended slot still resolve (roll call history).
      final past =
          await h.schedule.resolve(OccId.regular(satSlot, d(2026, 11, 21)));
      expect(past?.occurrence?.startMin, 960);
    });
  });

  group('holiday range', () {
    test('cancelRange cancels every regular class, undo restores them',
        () async {
      final chem = await h.chemB();
      final physics = await h.physicsA();
      final extra = await h.schedule.addExtra(
          batchId: physics, date: d(2026, 11, 26), startMin: 1080, endMin: 1140);
      final range = DateRange(d(2026, 11, 21), d(2026, 11, 27));

      // Sat 21, Sun 22, Mon 23, Tue 24, Wed 25 (the Thursday extra stays).
      expect(await h.schedule.cancelRange(range, note: 'Hartal'), 5);
      expect(await h.schedule.cancelRange(range, note: 'Hartal'), 0);
      final cancels = [
        ...await h.exceptionRows(physics),
        ...await h.exceptionRows(chem),
      ].where((e) => e.kind == 'cancel');
      expect(cancels, hasLength(5));
      expect(cancels.every((e) => e.note == 'Hartal'), isTrue);

      final during = ScheduleEngine.expand(
          range: range, batches: await h.loaded());
      expect([for (final o in during.occurrences) o.occ], [extra]);
      expect(during.cancelled, hasLength(5));

      expect(await h.schedule.undoCancelRange(range), 5);
      final after = ScheduleEngine.expand(
          range: range, batches: await h.loaded());
      expect(after.occurrences, hasLength(6));
      expect(after.cancelled, isEmpty);
      expect(await h.schedule.undoCancelRange(range), 0);
    });

    test('cancelRange also cancels a class moved into the range', () async {
      final physics = await h.physicsA();
      final occ = OccId.regular(await h.slotId(physics, mon), d(2026, 11, 23));
      await h.schedule.reschedule(occ,
          newDate: d(2026, 11, 26), startMin: 660, endMin: 720);
      final n = await h.schedule
          .cancelRange(DateRange(d(2026, 11, 26), d(2026, 11, 26)));
      expect(n, 1);
      final row = await h.exceptionRow(Ids.exceptionForOcc(occ));
      expect(row.kind, 'cancel');
      expect(row.originalDate, '2026-11-23');
      expect(row.newDate, isNull);
    });
  });

  group('reads', () {
    test('watchAllSchedules shows live data only', () async {
      final physics = await h.physicsA();
      await h.chemB();
      final occ = OccId.regular(await h.slotId(physics, mon), d(2026, 11, 23));
      await h.schedule.cancel(occ);
      await h.schedule.restore(occ);

      var list = await h.schedule.watchAllSchedules().first;
      expect(list, hasLength(2));
      final p = list.firstWhere((b) => b.batch.id == physics);
      expect(p.subjectName, 'Physics');
      expect(p.slots, hasLength(3));
      expect(p.exceptions, isEmpty);

      await h.batches.softDelete(physics);
      list = await h.schedule.watchAllSchedules().first;
      expect([for (final b in list) b.batch.name], ['Chem B']);
    });
  });
}
