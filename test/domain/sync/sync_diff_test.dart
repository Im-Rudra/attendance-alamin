import 'package:attendance_alamin/domain/sync/snapshot_codec.dart';
import 'package:attendance_alamin/domain/sync/sync_diff.dart';
import 'package:attendance_alamin/domain/sync/sync_models.dart';
import 'package:attendance_alamin/domain/sync/synced_tables.dart';
import 'package:flutter_test/flutter_test.dart';

typedef Tables = Map<String, List<RowMap>>;

RowMap row(String id, {int u = 100, String dev = 'P', int rev = 1, int? del, Map<String, Object?> data = const {}}) =>
    <String, Object?>{
      'id': id,
      'created_at': 1,
      'updated_at': u,
      'deleted_at': del,
      'device_id': dev,
      'rev': rev,
      ...data,
    };

RowMap stu(String id, String name, {int u = 100, String dev = 'P', int rev = 1, int? del, String? phone, String? guardian}) =>
    row(id, u: u, dev: dev, rev: rev, del: del, data: {'name': name, 'phone': phone, 'guardian_name': guardian});

Snapshot snap(Tables t) => SnapshotCodec.build(
    tables: t, appVersion: '1.0.0', snapshotId: 'snap', deviceId: 'P', deviceName: 'Phone', createdAtMs: 0);

ChangeSummary diff(Tables local, Tables incoming) => SyncDiff.diff(local: local, incoming: snap(incoming));

/// What the data layer's apply does: upsert every winner's incoming row.
Tables applyWinners(Tables local, ChangeSummary s) {
  final out = <String, Map<String, RowMap>>{
    for (final e in local.entries) e.key: {for (final r in e.value) r['id'] as String: r},
  };
  for (final w in s.winners) {
    (out[w.table] ??= {})[w.id] = w.incoming;
  }
  return {for (final e in out.entries) e.key: e.value.values.toList()};
}

EntityChange ent(ChangeSummary s, SummaryEntity e) => s.entities[e]!;

void expectCounts(ChangeSummary s, SummaryEntity e, {int added = 0, int updated = 0, int deleted = 0, int kept = 0}) {
  final c = ent(s, e);
  expect([c.added, c.updated, c.deleted, c.keptLocal], [added, updated, deleted, kept], reason: '$e a/u/d/kept');
}

void main() {
  group('incomingWins: (updated_at, device_id, rev) strictly greater', () {
    test('newer updated_at wins regardless of device and rev', () {
      expect(SyncDiff.incomingWins(row('a', u: 101, dev: 'A', rev: 1), row('a', u: 100, dev: 'Z', rev: 9)), isTrue);
      expect(SyncDiff.incomingWins(row('a', u: 99, dev: 'Z', rev: 9), row('a', u: 100, dev: 'A', rev: 1)), isFalse);
    });
    test('tie on updated_at → higher device_id wins, even with lower rev', () {
      expect(SyncDiff.incomingWins(row('a', dev: 'W', rev: 1), row('a', dev: 'P', rev: 9)), isTrue);
      expect(SyncDiff.incomingWins(row('a', dev: 'A', rev: 9), row('a', dev: 'P', rev: 1)), isFalse);
      // lexicographic, not numeric
      expect(SyncDiff.incomingWins(row('a', dev: 'P9'), row('a', dev: 'P10')), isTrue);
    });
    test('tie on updated_at and device_id → higher rev wins', () {
      expect(SyncDiff.incomingWins(row('a', rev: 3), row('a', rev: 2)), isTrue);
      expect(SyncDiff.incomingWins(row('a', rev: 2), row('a', rev: 3)), isFalse);
    });
    test('full tie → not a win', () {
      expect(SyncDiff.incomingWins(row('a'), row('a')), isFalse);
    });
  });

  group('contentDiffers', () {
    test('ignores id/created_at/updated_at/device_id/rev', () {
      final a = row('a', u: 1, dev: 'P', rev: 1, data: {'name': 'x'});
      final b = Map<String, Object?>.of(row('a', u: 9, dev: 'W', rev: 7, data: {'name': 'x'}))..['created_at'] = 55;
      expect(SyncDiff.contentDiffers(a, b), isFalse);
    });
    test('deleted_at and data columns count', () {
      expect(SyncDiff.contentDiffers(row('a'), row('a', del: 5)), isTrue);
      expect(SyncDiff.contentDiffers(row('a', data: {'n': 1}), row('a', data: {'n': 2})), isTrue);
    });
    test('missing column equals null; extra non-null column differs', () {
      expect(SyncDiff.contentDiffers(row('a', data: {'notes': null}), row('a')), isFalse);
      expect(SyncDiff.contentDiffers(row('a', data: {'notes': 'x'}), row('a')), isTrue);
    });
    test('lists compare deeply', () {
      expect(SyncDiff.contentDiffers(row('a', data: {'b': [1, 2]}), row('a', data: {'b': [1, 2]})), isFalse);
      expect(SyncDiff.contentDiffers(row('a', data: {'b': [1, 2]}), row('a', data: {'b': [1, 3]})), isTrue);
    });
  });

  group('merge table (Product §4)', () {
    test('backup has record, device has nothing → Add', () {
      final s = diff({}, {'students': [stu('n', 'Nila')]});
      expectCounts(s, SummaryEntity.students, added: 1);
      expect(s.winners.single.kind, ChangeKind.add);
      expect(s.winners.single.local, isNull);
      expect(ent(s, SummaryEntity.students).addedSamples.single['name'], 'Nila');
      expect(ent(s, SummaryEntity.students).addedSamples.single['_table'], 'students');
    });

    test('backup has nothing, device has record → Keep (absence never deletes)', () {
      final local = {'students': [stu('r', 'Rahim')], 'payments': [row('p1', data: {'receipt_id': 'rc', 'amount': 5})]};
      final s = diff(local, {'students': [], 'payments': []});
      expect(s.isEmpty, isTrue);
      expect(s.winners, isEmpty);
      expectCounts(s, SummaryEntity.students);
      expect(applyWinners(local, s)['students']!.single['name'], 'Rahim');
    });

    test('both have it, backup newer and different → Update (whole record)', () {
      final local = {'students': [stu('r', 'Rahim', phone: '1', guardian: 'G')]};
      final s = diff(local, {'students': [stu('r', 'Rahim', u: 200, rev: 2, phone: '2')]});
      expectCounts(s, SummaryEntity.students, updated: 1);
      expect(s.winners.single.kind, ChangeKind.update);
      final after = applyWinners(local, s)['students']!.single;
      expect(after['phone'], '2');
      expect(after['guardian_name'], isNull); // no field-level merge
    });

    test('both have it, backup newer but same content → nothing', () {
      final s = diff({'students': [stu('r', 'Rahim')]}, {'students': [stu('r', 'Rahim', u: 500, dev: 'W', rev: 4)]});
      expect(s.isEmpty, isTrue);
      expect(s.winners, isEmpty);
      expectCounts(s, SummaryEntity.students);
    });

    test('both have it, device newer and different → keptLocal', () {
      final local = {'students': [stu('r', 'Rahim', u: 300, dev: 'W', guardian: 'G2')]};
      final s = diff(local, {'students': [stu('r', 'Rahim', u: 200, phone: '9')]});
      expectCounts(s, SummaryEntity.students, kept: 1);
      expect(s.winners, isEmpty);
      expect(s.isEmpty, isTrue);
    });

    test('tombstone newer than live device record → Delete (sample = device version)', () {
      final local = {'students': [stu('t', 'Tuhin', phone: 'old')]};
      final s = diff(local, {'students': [stu('t', 'Tuhin', u: 200, del: 200, phone: 'new')]});
      expectCounts(s, SummaryEntity.students, deleted: 1);
      expect(s.winners.single.kind, ChangeKind.delete);
      final sample = ent(s, SummaryEntity.students).deletedSamples.single;
      expect(sample['phone'], 'old');
      expect(sample['deleted_at'], isNull);
      expect(applyWinners(local, s)['students']!.single['deleted_at'], 200);
    });

    test('tombstone older than a local edit → device record kept', () {
      final local = {'students': [stu('t', 'Tuhin', u: 300, phone: 'edited')]};
      final s = diff(local, {'students': [stu('t', 'Tuhin', u: 200, del: 200)]});
      expectCounts(s, SummaryEntity.students, kept: 1);
      expect(s.winners, isEmpty);
      expect(applyWinners(local, s)['students']!.single['deleted_at'], isNull);
    });

    test('live record newer than device tombstone → Restore (counted as updated)', () {
      final local = {'students': [stu('t', 'Tuhin', u: 200, del: 200)]};
      final s = diff(local, {'students': [stu('t', 'Tuhin', u: 300, dev: 'W', phone: '5')]});
      expectCounts(s, SummaryEntity.students, updated: 1);
      expect(s.winners.single.kind, ChangeKind.restore);
      expect(ent(s, SummaryEntity.students).updatedSamples.single['name'], 'Tuhin');
    });

    test('live record older than device tombstone → stays deleted', () {
      final local = {'students': [stu('t', 'Tuhin', u: 300, del: 300)]};
      final s = diff(local, {'students': [stu('t', 'Tuhin', u: 200, phone: '5')]});
      expect(s.winners, isEmpty);
      expect(s.isEmpty, isTrue);
      expectCounts(s, SummaryEntity.students, kept: 1);
    });

    test('unknown tombstone: not counted, but returned as a winner (keeps FK targets)', () {
      final s = diff({}, {'students': [stu('x', 'Ghost', del: 50)]});
      expect(s.isEmpty, isTrue);
      expectCounts(s, SummaryEntity.students);
      expect(s.winners.single.kind, ChangeKind.add);
      expect(s.winners.single.incoming['deleted_at'], 50);
    });

    test('tombstone over tombstone: newer one converges silently; older is ignored', () {
      final local = {'students': [stu('t', 'Tuhin', u: 200, del: 200)]};
      final s = diff(local, {'students': [stu('t', 'Tuhin', u: 300, dev: 'W', del: 300)]});
      expect(s.isEmpty, isTrue);
      expect(s.winners.single.kind, ChangeKind.update);
      final s2 = diff({'students': [stu('t', 'Tuhin', u: 300, del: 300)]},
          {'students': [stu('t', 'Tuhin', u: 200, del: 200)]});
      expect(s2.winners, isEmpty);
      expectCounts(s2, SummaryEntity.students); // not "kept": nothing to keep
    });
  });

  group('tie-break levels inside diff', () {
    Tables local() => {'subjects': [row('s', u: 100, dev: 'P', rev: 2, data: {'name': 'Local'})]};
    ChangeSummary inc({required int u, required String dev, required int rev}) =>
        diff(local(), {'subjects': [row('s', u: u, dev: dev, rev: rev, data: {'name': 'Incoming'})]});

    test('updated_at decides first', () {
      expectCounts(inc(u: 101, dev: 'A', rev: 1), SummaryEntity.subjects, updated: 1);
      expectCounts(inc(u: 99, dev: 'Z', rev: 9), SummaryEntity.subjects, kept: 1);
    });
    test('then device_id', () {
      expectCounts(inc(u: 100, dev: 'W', rev: 1), SummaryEntity.subjects, updated: 1);
      expectCounts(inc(u: 100, dev: 'A', rev: 9), SummaryEntity.subjects, kept: 1);
    });
    test('then rev', () {
      expectCounts(inc(u: 100, dev: 'P', rev: 3), SummaryEntity.subjects, updated: 1);
      expectCounts(inc(u: 100, dev: 'P', rev: 1), SummaryEntity.subjects, kept: 1);
    });
    test('identical stamps with different content → local kept (deterministic)', () {
      expectCounts(inc(u: 100, dev: 'P', rev: 2), SummaryEntity.subjects, kept: 1);
    });
  });

  group('entity grouping', () {
    final batch = row('b1', data: {'name': 'Physics A', 'subject_id': 's1'});
    RowMap fee(String id, int month, int amount, {int u = 100, int? del}) =>
        row(id, u: u, del: del, data: {'batch_id': 'b1', 'effective_month': month, 'amount': amount});

    test('new batch with its fee row → Batches added 1', () {
      final s = diff({}, {'batches': [batch], 'batch_fees': [fee('f1', 202611, 1000)]});
      expectCounts(s, SummaryEntity.batches, added: 1);
      expect(s.winners.length, 2);
      expect(ent(s, SummaryEntity.batches).addedSamples.single['name'], 'Physics A');
    });

    test('fee change on an existing batch → Batches updated 1, sample is the batch', () {
      final local = {'batches': [batch], 'batch_fees': [fee('f1', 202611, 1000)]};
      final s = diff(local, {'batches': [batch], 'batch_fees': [fee('f1', 202611, 1000), fee('f2', 202612, 1200, u: 300)]});
      expectCounts(s, SummaryEntity.batches, updated: 1);
      final sample = ent(s, SummaryEntity.batches).updatedSamples.single;
      expect(sample['name'], 'Physics A');
      expect(sample['_table'], 'batches');
    });

    test('slots and exceptions are separate schedule items', () {
      final s = diff({}, {
        'batch_slots': [row('sl1', data: {'batch_id': 'b1', 'weekday': 6, 'start_min': 960, 'end_min': 1020})],
        'schedule_exceptions': [row('ex1', data: {'batch_id': 'b1', 'kind': 'extra', 'new_date': '2026-11-26'})],
      });
      expectCounts(s, SummaryEntity.schedule, added: 2);
      expect(ent(s, SummaryEntity.schedule).addedSamples.map((r) => r['_table']).toSet(),
          {'batch_slots', 'schedule_exceptions'});
    });

    test('photo for an existing student → Students updated 1; new student with photo → added 1', () {
      final s = diff({'students': [stu('r', 'Rahim')]}, {
        'students': [stu('r', 'Rahim'), stu('n', 'Nila')],
        'student_photos': [row('r', data: {'jpeg': 'AAAA'}), row('n', data: {'jpeg': 'BBBB'})],
      });
      expectCounts(s, SummaryEntity.students, added: 1, updated: 1);
      expect(ent(s, SummaryEntity.students).updatedSamples.single['name'], 'Rahim');
      expect(ent(s, SummaryEntity.students).addedSamples.single['name'], 'Nila');
    });

    test('enrollment fee override → Enrollments updated 1', () {
      final enr = row('e1', data: {'student_id': 'r', 'batch_id': 'b1', 'start_month': 202611});
      final s = diff({'enrollments': [enr]}, {
        'enrollments': [enr],
        'enrollment_fees': [row('ef1', data: {'enrollment_id': 'e1', 'effective_month': 202612, 'amount': 800})],
      });
      expectCounts(s, SummaryEntity.enrollments, updated: 1);
    });

    group('attendance counts sessions, not marks', () {
      final session = row('se1', data: {'batch_id': 'b1', 'date': '2026-11-21', 'occ': 's.x.20261121'});
      RowMap rec(String id, String status, {int u = 100, String sid = 'se1', int? del}) =>
          row(id, u: u, del: del, data: {'session_id': sid, 'student_id': 'st$id', 'status': status});

      test('new session with 3 marks → added 1', () {
        final s = diff({}, {'attendance_sessions': [session], 'attendance_records': [rec('1', 'P'), rec('2', 'A'), rec('3', 'P')]});
        expectCounts(s, SummaryEntity.attendance, added: 1);
        expect(s.winners.length, 4);
        expect(ent(s, SummaryEntity.attendance).addedSamples.single['date'], '2026-11-21');
      });

      test('two marks changed in one session → updated 1, sample is the session', () {
        final local = {'attendance_sessions': [session], 'attendance_records': [rec('1', 'P'), rec('2', 'P')]};
        final s = diff(local, {
          'attendance_sessions': [session],
          'attendance_records': [rec('1', 'A', u: 200), rec('2', 'L', u: 200)],
        });
        expectCounts(s, SummaryEntity.attendance, updated: 1);
        expect(ent(s, SummaryEntity.attendance).updatedSamples.single['_table'], 'attendance_sessions');
      });

      test('session deleted with its marks → deleted 1', () {
        final local = {'attendance_sessions': [session], 'attendance_records': [rec('1', 'P')]};
        final s = diff(local, {
          'attendance_sessions': [row('se1', u: 200, del: 200, data: {'batch_id': 'b1', 'date': '2026-11-21', 'occ': 's.x.20261121'})],
          'attendance_records': [rec('1', 'P', u: 200, del: 200)],
        });
        expectCounts(s, SummaryEntity.attendance, deleted: 1);
      });

      test('kept marks counted once per session', () {
        final local = {'attendance_sessions': [session], 'attendance_records': [rec('1', 'A', u: 300), rec('2', 'A', u: 300)]};
        final s = diff(local, {'attendance_sessions': [session], 'attendance_records': [rec('1', 'P'), rec('2', 'P')]});
        expectCounts(s, SummaryEntity.attendance, kept: 1);
      });
    });

    group('payments count receipts (+ other income rows)', () {
      RowMap pay(String id, String receipt, int month, int amount, {int u = 100, int? del}) => row(id,
          u: u,
          del: del,
          data: {'receipt_id': receipt, 'student_id': 'sara', 'billing_month': month, 'amount': amount, 'paid_on': '2026-11-05'});

      test('new receipt with 2 allocations + 1 other income → added 2; receipt total in the sample', () {
        final s = diff({}, {
          'payments': [pay('p1', 'rc1', 202610, 500), pay('p2', 'rc1', 202611, 500)],
          'other_income': [row('oi1', data: {'label': 'Book', 'amount': 150})],
        });
        expectCounts(s, SummaryEntity.payments, added: 2);
        final samples = ent(s, SummaryEntity.payments).addedSamples;
        final receipt = samples.firstWhere((r) => r['_table'] == 'payments');
        expect(receipt['_receipt_total'], 1000);
        expect(samples.firstWhere((r) => r['_table'] == 'other_income')['label'], 'Book');
      });

      test('reallocated receipt (one row tombstoned, one added) → updated 1, not deleted', () {
        final local = {'payments': [pay('p1', 'rc1', 202610, 600), pay('p2', 'rc1', 202611, 400)]};
        final s = diff(local, {
          'payments': [pay('p1', 'rc1', 202610, 600), pay('p2', 'rc1', 202611, 400, u: 200, del: 200), pay('p3', 'rc1', 202612, 400, u: 200)],
        });
        expectCounts(s, SummaryEntity.payments, updated: 1);
        expect(ent(s, SummaryEntity.payments).updatedSamples.single['_receipt_total'], 1000);
      });

      test('receipt deleted (all rows tombstoned) → deleted 1 with the device total', () {
        final local = {'payments': [pay('p1', 'rc1', 202610, 600), pay('p2', 'rc1', 202611, 400)]};
        final s = diff(local, {
          'payments': [pay('p1', 'rc1', 202610, 600, u: 200, del: 200), pay('p2', 'rc1', 202611, 400, u: 200, del: 200)],
        });
        expectCounts(s, SummaryEntity.payments, deleted: 1);
        expect(ent(s, SummaryEntity.payments).deletedSamples.single['_receipt_total'], 1000);
        expect(s.winners.every((w) => w.kind == ChangeKind.delete), isTrue);
      });
    });

    test('settings by key', () {
      final local = {'settings': [row('center_name', data: {'value': '"A"'})]};
      final s = diff(local, {
        'settings': [row('center_name', u: 200, data: {'value': '"B"'}), row('week_start', data: {'value': '7'})],
      });
      expectCounts(s, SummaryEntity.settings, added: 1, updated: 1);
      expect(ent(s, SummaryEntity.settings).addedSamples.single['id'], 'week_start');
    });

    test('children of an unknown deleted parent are applied but invisible', () {
      final s = diff({}, {
        'batches': [row('b9', u: 200, del: 200, data: {'name': 'Gone'})],
        'batch_fees': [row('f9', data: {'batch_id': 'b9', 'effective_month': 202611, 'amount': 500})],
      });
      expect(s.isEmpty, isTrue);
      expect(s.winners.map((w) => w.table).toSet(), {'batches', 'batch_fees'});
    });

    test('unknown child tombstone under a live batch does not count as a batch update', () {
      final s = diff({'batches': [batch]}, {'batches': [batch], 'batch_fees': [fee('f7', 202611, 1, del: 9)]});
      expect(s.isEmpty, isTrue);
      expectCounts(s, SummaryEntity.batches);
    });

    test('child added under a batch that stays deleted locally is invisible', () {
      final local = {'batches': [row('b1', u: 500, del: 500, data: {'name': 'Physics A', 'subject_id': 's1'})]};
      final s = diff(local, {'batches': [batch], 'batch_fees': [fee('f3', 202611, 900)]});
      expect(s.isEmpty, isTrue);
      expectCounts(s, SummaryEntity.batches, kept: 1);
    });

    test('tables outside kSyncedTables are ignored', () {
      final s = diff({}, {'local_meta': [row('device_id', data: {'value': 'x'})]});
      expect(s.isEmpty, isTrue);
      expect(s.winners, isEmpty);
    });
  });

  group('summary shape', () {
    test('every SummaryEntity has an entry, in declaration order', () {
      final s = diff({}, {});
      expect(s.entities.keys.toList(), SummaryEntity.values);
      expect(s.isEmpty, isTrue);
      expect(s.totalChanges, 0);
    });

    test('at most 3 samples, most recent first, ties by id', () {
      final s = diff({}, {
        'students': [
          stu('a', 'A', u: 100),
          stu('b', 'B', u: 500),
          stu('c', 'C', u: 300),
          stu('d', 'D', u: 300),
          stu('e', 'E', u: 200),
        ],
      });
      final c = ent(s, SummaryEntity.students);
      expect(c.added, 5);
      expect(c.addedSamples.map((r) => r['name']), ['B', 'C', 'D']);
    });

    test('samples are unmodifiable copies', () {
      final s = diff({}, {'students': [stu('a', 'A')]});
      expect(() => ent(s, SummaryEntity.students).addedSamples.single['name'] = 'x', throwsUnsupportedError);
    });

    test('per-entity counts and totals', () {
      final local = {
        'subjects': [row('s1', data: {'name': 'Physics'}), row('s2', data: {'name': 'Chem'})],
        'students': [stu('r', 'Rahim'), stu('t', 'Tuhin')],
      };
      final s = diff(local, {
        'subjects': [row('s1', u: 200, del: 200, data: {'name': 'Physics'}), row('s3', data: {'name': 'Math'})],
        'students': [stu('r', 'Rahim', u: 200, phone: '1'), stu('n', 'Nila')],
        'settings': [row('center_name', data: {'value': '"X"'})],
      });
      expectCounts(s, SummaryEntity.subjects, added: 1, deleted: 1);
      expectCounts(s, SummaryEntity.students, added: 1, updated: 1);
      expectCounts(s, SummaryEntity.settings, added: 1);
      expectCounts(s, SummaryEntity.batches);
      expect(s.totalChanges, 5);
    });

    test('winners: deletions first, then kSyncedTables order, then id', () {
      final local = {
        'subjects': [row('s1', data: {'name': 'Physics'})],
        'batches': [row('b1', data: {'name': 'A'})],
        'students': [stu('t', 'Tuhin')],
      };
      final s = diff(local, {
        'students': [stu('t', 'Tuhin', u: 200, del: 200), stu('n', 'Nila')],
        'batches': [row('b1', u: 200, data: {'name': 'B'})],
        'subjects': [row('s1', u: 200, del: 200, data: {'name': 'Physics'})],
      });
      expect(s.winners.map((w) => '${w.kind.name}:${w.table}/${w.id}'),
          ['delete:subjects/s1', 'delete:students/t', 'update:batches/b1', 'add:students/n']);
    });

    test('diff never mutates its inputs', () {
      final local = {'students': [stu('r', 'Rahim')]};
      final before = local['students']!.single.toString();
      diff(local, {'students': [stu('r', 'Rahim', u: 200, phone: '1')]});
      expect(local['students']!.single.toString(), before);
    });
  });

  group('idempotence & restore', () {
    test('into an empty device = full restore of live rows', () {
      final backup = {
        'subjects': [row('s1', data: {'name': 'Physics'})],
        'students': [stu('r', 'Rahim'), stu('t', 'Tuhin', del: 50)],
      };
      final s = diff({}, backup);
      expectCounts(s, SummaryEntity.subjects, added: 1);
      expectCounts(s, SummaryEntity.students, added: 1);
      final after = applyWinners({}, s);
      expect(diff(after, backup).isEmpty, isTrue);
      expect(diff(after, backup).winners, isEmpty);
    });

    test('importing the same file twice → second time no changes', () {
      final local = {
        'students': [stu('r', 'Rahim', u: 300, guardian: 'G'), stu('t', 'Tuhin'), stu('old', 'Old', u: 300, del: 300)],
        'payments': [row('p1', data: {'receipt_id': 'rc', 'amount': 5})],
      };
      final backup = {
        'students': [
          stu('r', 'Rahim', u: 200, phone: '1'),
          stu('t', 'Tuhin', u: 200, del: 200),
          stu('n', 'Nila'),
          stu('x', 'Ghost', del: 10),
          stu('old', 'Old', u: 100),
        ],
        'attendance_sessions': [row('se', data: {'batch_id': 'b'})],
        'attendance_records': [row('r1', data: {'session_id': 'se', 'status': 'P'})],
      };
      final first = diff(local, backup);
      expect(first.isEmpty, isFalse);
      final after = applyWinners(local, first);
      final second = diff(after, backup);
      expect(second.isEmpty, isTrue);
      expect(second.winners, isEmpty);
      expectCounts(second, SummaryEntity.students, kept: 2); // newer device edits still reported, not applied
      // and a third time, through the real codec
      final third = SyncDiff.diff(local: after, incoming: SnapshotCodec.decode(SnapshotCodec.encode(snap(backup))));
      expect(third.isEmpty, isTrue);
      expect(third.winners, isEmpty);
    });
  });

  test('Scenario 15: phone P backup merged into PC W', () {
    // Shared base (written by P at t=100); Rahim's base had phone 01711000000, guardian Karim.
    final tuhinBase = stu('tuhin', 'Tuhin');
    final saraBase = stu('sara', 'Sara');
    // W: adds a payment for Sara (t=230), later edits Rahim's guardian (t=300, after P's edit).
    final saraPay = row('pay1', u: 230, dev: 'W',
        data: {'receipt_id': 'rcpt1', 'student_id': 'sara', 'billing_month': 202611, 'amount': 1000, 'paid_on': '2026-11-05'});
    final rahimW = stu('rahim', 'Rahim', u: 300, dev: 'W', rev: 2, phone: '01711000000', guardian: 'Abdul Karim');
    final w = <String, List<RowMap>>{
      'students': [rahimW, tuhinBase, saraBase],
      'payments': [saraPay],
    };
    // P: adds Nila, edits Rahim's phone, deletes Tuhin; then exports.
    final pBackup = snap({
      'students': [
        stu('nila', 'Nila', u: 200),
        stu('rahim', 'Rahim', u: 210, rev: 2, phone: '01811000000', guardian: 'Karim'),
        stu('tuhin', 'Tuhin', u: 220, rev: 2, del: 220),
        saraBase,
      ],
      'payments': [],
    });

    final imported = SnapshotCodec.decode(SnapshotCodec.encode(pBackup));
    final s = SyncDiff.diff(local: w, incoming: imported);

    final students = ent(s, SummaryEntity.students);
    expect([students.added, students.updated, students.deleted, students.keptLocal], [1, 0, 1, 1]);
    expect(students.addedSamples.single['name'], 'Nila');
    expect(students.deletedSamples.single['name'], 'Tuhin');
    expectCounts(s, SummaryEntity.payments);
    expect(s.totalChanges, 2);
    expect(s.winners.first.kind, ChangeKind.delete); // deletions listed first
    expect(s.winners.map((c) => c.id), ['tuhin', 'nila']);
    expect(w['students']!.length, 3, reason: 'nothing changes before apply');

    final after = applyWinners(w, s);
    final byId = {for (final r in after['students']!) r['id']: r};
    expect(byId['nila']!['deleted_at'], isNull);
    expect(byId['tuhin']!['deleted_at'], 220);
    expect(byId['rahim'], rahimW); // W's newer whole record wins
    expect(after['payments'], [saraPay]); // Sara's payment intact

    final again = SyncDiff.diff(local: after, incoming: imported);
    expect(again.isEmpty, isTrue);
    expect(again.winners, isEmpty);
  });

  test('kSyncedTables are all mapped to an entity', () {
    for (final t in kSyncedTables) {
      expect(() => diff({}, {t: [row('id-$t', data: {'name': t})]}), returnsNormally, reason: t);
    }
  });
}
