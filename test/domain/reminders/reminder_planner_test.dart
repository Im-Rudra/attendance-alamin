import 'package:attendance_alamin/core/ids/ids.dart';
import 'package:attendance_alamin/core/time/center_time.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/reminders/reminder_models.dart';
import 'package:attendance_alamin/domain/reminders/reminder_planner.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';
import 'package:flutter_test/flutter_test.dart';

const _center = CenterTime.dhaka; // UTC+6
const _nov20 = LocalDate(2026, 11, 20);

Occurrence _occ(
  String id,
  LocalDate date,
  int startMin, {
  String batch = 'b1',
  OccurrenceKind kind = OccurrenceKind.regular,
}) =>
    Occurrence(
      occ: id,
      batchId: batch,
      date: date,
      startMin: startMin,
      endMin: startMin + 60,
      kind: kind,
    );

/// Dhaka wall time -> UTC.
DateTime _dhaka(LocalDate d, int h, [int m = 0]) => _center.toUtc(d, h * 60 + m);

List<PlannedReminder> _run(
  List<Occurrence> occs, {
  Map<String, int?> leads = const {},
  int def = 15,
  DateTime? now,
  int windowDays = 7,
  int maxCount = 200,
}) =>
    ReminderPlanner.plan(
      occurrences: occs,
      leadByBatch: leads,
      defaultLeadMin: def,
      center: _center,
      nowUtc: now ?? _dhaka(_nov20, 8),
      windowDays: windowDays,
      maxCount: maxCount,
    );

void main() {
  group('effectiveLead', () {
    final cases = <String, (int?, int, int?)>{
      'null uses default': (null, 15, 15),
      'batch value wins': (30, 15, 30),
      '0 = off': (0, 15, null),
      'null with default 0 = off': (null, 0, null),
      'batch value with default off': (10, 0, 10),
      'negative is off': (-5, 15, null),
    };
    cases.forEach((name, c) {
      test(name, () => expect(ReminderPlanner.effectiveLead(c.$1, c.$2), c.$3));
    });
  });

  group('plan', () {
    test('scenario 22: 15:45 class with default 10 fires 15:35', () {
      final o = _occ('s.a.20261120', _nov20, 15 * 60 + 45);
      final r = _run([o], def: 10);
      expect(r.single.fireAtUtc, _dhaka(_nov20, 15, 35));
      expect(r.single.leadMin, 10);
      expect(r.single.id, Ids.fnv1a31('s.a.20261120'));
      expect(r.single.payload, 'rollcall|s.a.20261120');
      expect(r.single.kind, OccurrenceKind.regular);
      expect(r.single.batchId, 'b1');
      expect(r.single.date, _nov20);
      expect(r.single.startMin, 945);
      expect(r.single.endMin, 1005);
    });

    test('extra class 18:00 with lead 10 fires 17:50', () {
      final o = _occ('x.e1', _nov20, 18 * 60, kind: OccurrenceKind.extra);
      final r = _run([o], leads: {'b1': 10});
      expect(r.single.fireAtUtc, _dhaka(_nov20, 17, 50));
      expect(r.single.kind, OccurrenceKind.extra);
    });

    test('rescheduled keeps its kind and uses the new time', () {
      final o = _occ('s.a.20261119', _nov20, 9 * 60 + 30,
          kind: OccurrenceKind.rescheduled);
      final r = _run([o], def: 10);
      expect(r.single.fireAtUtc, _dhaka(_nov20, 9, 20));
      expect(r.single.kind, OccurrenceKind.rescheduled);
    });

    test('no occurrences (e.g. all cancelled) gives nothing', () {
      expect(_run([]), isEmpty);
    });

    test('fire times are UTC', () {
      final r = _run([_occ('o', _nov20, 9 * 60)], def: 15);
      expect(r.single.fireAtUtc.isUtc, isTrue);
      expect(r.single.fireAtUtc, DateTime.utc(2026, 11, 20, 2, 45));
    });

    group('lead resolution', () {
      test('null batch lead uses default', () {
        final r = _run([_occ('o', _nov20, 600)], leads: {'b1': null}, def: 20);
        expect(r.single.leadMin, 20);
      });
      test('missing batch key uses default', () {
        final r = _run([_occ('o', _nov20, 600)], def: 5);
        expect(r.single.leadMin, 5);
      });
      test('0 turns the batch off, others unaffected', () {
        final r = _run([
          _occ('o1', _nov20, 600, batch: 'off'),
          _occ('o2', _nov20, 660, batch: 'on'),
        ], leads: {'off': 0});
        expect(r.map((e) => e.occ), ['o2']);
      });
      test('default 0 turns off only the null-lead batches', () {
        final r = _run([
          _occ('o1', _nov20, 600, batch: 'dflt'),
          _occ('o2', _nov20, 660, batch: 'own'),
        ], leads: {'own': 10}, def: 0);
        expect(r.map((e) => e.occ), ['o2']);
      });
      test('default change re-times only null-lead batches', () {
        final occs = [
          _occ('o1', _nov20, 600, batch: 'dflt'),
          _occ('o2', _nov20, 600, batch: 'own'),
        ];
        final leads = <String, int?>{'own': 30};
        final a = _run(occs, leads: leads, def: 15);
        final b = _run(occs, leads: leads, def: 60);
        DateTime fire(List<PlannedReminder> r, String o) =>
            r.firstWhere((e) => e.occ == o).fireAtUtc;
        expect(fire(a, 'o1'), _dhaka(_nov20, 9, 45));
        expect(fire(b, 'o1'), _dhaka(_nov20, 9, 0));
        expect(fire(a, 'o2'), fire(b, 'o2'));
        expect(fire(a, 'o2'), _dhaka(_nov20, 9, 30));
      });
    });

    group('past fire times', () {
      test('fire time before now is skipped', () {
        expect(_run([_occ('o', _nov20, 8 * 60 + 10)]), isEmpty);
      });
      test('fire time exactly now is skipped', () {
        expect(_run([_occ('o', _nov20, 8 * 60 + 15)]), isEmpty);
      });
      test('fire time one minute ahead is kept', () {
        expect(_run([_occ('o', _nov20, 8 * 60 + 16)]), hasLength(1));
      });
      test('class already started is skipped', () {
        expect(_run([_occ('o', _nov20, 7 * 60)]), isEmpty);
      });
      test('yesterday is skipped', () {
        expect(_run([_occ('o', _nov20.addDays(-1), 600)]), isEmpty);
      });
    });

    group('window', () {
      test('start exactly at now+7d is included', () {
        final o = _occ('o', _nov20.addDays(7), 8 * 60);
        expect(_run([o]), hasLength(1));
      });
      test('start one minute after the horizon is excluded', () {
        final o = _occ('o', _nov20.addDays(7), 8 * 60 + 1);
        expect(_run([o]), isEmpty);
      });
      test('custom window', () {
        final o = _occ('o', _nov20.addDays(2), 600);
        expect(_run([o], windowDays: 1), isEmpty);
        expect(_run([o], windowDays: 3), hasLength(1));
      });
    });

    group('cap and order', () {
      test('sorted by fire time regardless of input order', () {
        final r = _run([
          _occ('c', _nov20.addDays(2), 600),
          _occ('a', _nov20, 600),
          _occ('b', _nov20.addDays(1), 600),
        ]);
        expect(r.map((e) => e.occ), ['a', 'b', 'c']);
      });

      test('cap at 200 keeps the soonest', () {
        // 250 classes, one minute apart starting 09:00 (all within 7 days).
        final occs = <Occurrence>[
          for (var i = 249; i >= 0; i--) _occ('o$i', _nov20, 9 * 60 + i),
        ];
        final r = _run(occs);
        expect(r, hasLength(200));
        expect(r.first.occ, 'o0');
        expect(r.last.occ, 'o199');
        final kept = r.map((e) => e.occ).toSet();
        for (var i = 200; i < 250; i++) {
          expect(kept.contains('o$i'), isFalse);
        }
      });

      test('custom maxCount and zero', () {
        final occs = [for (var i = 0; i < 5; i++) _occ('o$i', _nov20, 600 + i)];
        expect(_run(occs, maxCount: 3).map((e) => e.occ), ['o0', 'o1', 'o2']);
        expect(_run(occs, maxCount: 0), isEmpty);
      });

      test('cap applies after skipping off and past ones', () {
        final occs = [
          _occ('past', _nov20, 8 * 60 + 5),
          _occ('off', _nov20, 600, batch: 'off'),
          _occ('k1', _nov20, 660),
          _occ('k2', _nov20, 670),
          _occ('k3', _nov20, 680),
        ];
        expect(_run(occs, leads: {'off': 0}, maxCount: 2).map((e) => e.occ),
            ['k1', 'k2']);
      });

      test('equal fire times tie-break by occ id', () {
        final r = _run([
          _occ('s.z', _nov20, 600, batch: 'b1'),
          _occ('s.a', _nov20, 600, batch: 'b2'),
        ]);
        expect(r.map((e) => e.occ), ['s.a', 's.z']);
      });
    });

    test('two classes of the same batch on the same day each get a reminder',
        () {
      final r = _run([
        _occ('s.slot.20261120', _nov20, 9 * 60),
        _occ('x.extra1', _nov20, 17 * 60, kind: OccurrenceKind.extra),
      ]);
      expect(r, hasLength(2));
      expect(r[0].fireAtUtc, _dhaka(_nov20, 8, 45));
      expect(r[1].fireAtUtc, _dhaka(_nov20, 16, 45));
      expect(r[0].id, isNot(r[1].id));
    });

    test('two batches at the same time both fire', () {
      final r = _run([
        _occ('o1', _nov20, 600, batch: 'b1'),
        _occ('o2', _nov20, 600, batch: 'b2'),
      ]);
      expect(r, hasLength(2));
      expect(r[0].fireAtUtc, r[1].fireAtUtc);
    });

    test('duplicate occ ids collapse to one', () {
      final o = _occ('dup', _nov20, 600);
      expect(_run([o, o]), hasLength(1));
    });

    test('center offset shifts the UTC fire time', () {
      final r = ReminderPlanner.plan(
        occurrences: [_occ('o', _nov20, 600)],
        leadByBatch: const {},
        defaultLeadMin: 15,
        center: const CenterTime(0),
        nowUtc: DateTime.utc(2026, 11, 20, 1),
      );
      expect(r.single.fireAtUtc, DateTime.utc(2026, 11, 20, 9, 45));
    });

    test('same input gives equal output', () {
      final occs = [_occ('o', _nov20, 600), _occ('p', _nov20, 700)];
      expect(_run(occs), _run(occs));
    });
  });

  group('payload', () {
    test('round-trips', () {
      for (final o in ['s.abc-1.20261120', 'x.e-2', 's.a.b.20261120']) {
        expect(ReminderPlanner.payloadFor(o), 'rollcall|$o');
        expect(
            ReminderPlanner.occFromPayload(ReminderPlanner.payloadFor(o)), o);
      }
    });
    test('rejects foreign or empty payloads', () {
      expect(ReminderPlanner.occFromPayload(null), isNull);
      expect(ReminderPlanner.occFromPayload(''), isNull);
      expect(ReminderPlanner.occFromPayload('rollcall|'), isNull);
      expect(ReminderPlanner.occFromPayload('other|s.a.20261120'), isNull);
      expect(ReminderPlanner.occFromPayload('s.a.20261120'), isNull);
    });
  });
}
