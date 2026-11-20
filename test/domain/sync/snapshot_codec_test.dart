import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/errors/error_codes.dart';
import 'package:attendance_alamin/domain/sync/snapshot_codec.dart';
import 'package:attendance_alamin/domain/sync/sync_diff.dart';
import 'package:attendance_alamin/domain/sync/sync_models.dart';
import 'package:attendance_alamin/domain/sync/synced_tables.dart';
import 'package:flutter_test/flutter_test.dart';

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

Snapshot buildSnap(Map<String, List<RowMap>> tables) => SnapshotCodec.build(
      tables: tables,
      appVersion: '1.0.0+42',
      snapshotId: 'snap-1',
      deviceId: 'dev-P',
      deviceName: 'ফোন',
      createdAtMs: 1795180000000,
    );

Matcher throwsImport(String code) =>
    throwsA(isA<ImportException>().having((e) => e.code, 'code', code));

List<int> gzipText(String text) => GZipEncoder().encodeBytes(utf8.encode(text));

Map<String, dynamic> unwrap(List<int> bytes) =>
    jsonDecode(utf8.decode(GZipDecoder().decodeBytes(bytes))) as Map<String, dynamic>;

Map<String, List<RowMap>> sampleTables() => {
      'subjects': [
        row('s2', data: {'name': 'রসায়ন', 'sort_order': 1, 'archived_at': null, 'notes': null}),
        row('s1', data: {'name': 'Physics "A"\n', 'sort_order': 0, 'archived_at': null, 'notes': 'x\ty'}),
      ],
      'students': [
        row('st-b', data: {'name': 'Tuhin', 'has_photo': 0}, del: 500),
        row('st-a', data: {'name': 'রহিম', 'has_photo': 1}),
      ],
      'student_photos': [
        row('st-a', data: {'jpeg': base64Encode(List<int>.generate(300, (i) => i % 256))}),
      ],
      'settings': [
        row('center_name', data: {'value': jsonEncode('আল-আমিন কোচিং')}),
      ],
    };

void main() {
  group('canonicalJson', () {
    test('sorted keys, no whitespace, minimal escapes; equals Python reference', () {
      final tables = {
        'subjects': [
          {'sort_order': 1, 'name': 'পদার্থ "x"\n', 'id': 'a', 'deleted_at': null, 'archived': true},
        ],
        'batches': <Object?>[],
      };
      // python: json.dumps(t, ensure_ascii=False, separators=(',',':'), sort_keys=True)
      expect(SnapshotCodec.canonicalJson(tables),
          r'{"batches":[],"subjects":[{"archived":true,"deleted_at":null,"id":"a","name":"পদার্থ \"x\"\n","sort_order":1}]}');
      expect(SnapshotCodec.tablesSha256({
        'subjects': [
          {'sort_order': 1, 'name': 'পদার্থ "x"\n', 'id': 'a', 'deleted_at': null, 'archived': true},
        ],
        'batches': [],
      }), 'b5a13852d8a3d65dd41ccd60811e1b765919cec0860ac423eaa8720415be286d');
    });

    test('control characters, backslash, nested lists', () {
      expect(SnapshotCodec.canonicalJson('a\u0001b\\c\r\b\f'), r'"a\u0001b\\c\r\b\f"');
      expect(SnapshotCodec.canonicalJson([1, 'x', null, [false], {'b': 1, 'a': 2}]), '[1,"x",null,[false],{"a":2,"b":1}]');
    });

    test('integral doubles print as ints (VM and web agree); fractions keep their digits', () {
      expect(SnapshotCodec.canonicalJson(2.0), '2');
      expect(SnapshotCodec.canonicalJson(-0.0), '0');
      expect(SnapshotCodec.canonicalJson(2.5), '2.5');
      expect(SnapshotCodec.canonicalJson(1795180000000), '1795180000000');
    });

    test('rejects non-JSON values', () {
      expect(() => SnapshotCodec.canonicalJson({1: 'x'}), throwsArgumentError);
      expect(() => SnapshotCodec.canonicalJson(double.nan), throwsArgumentError);
      expect(() => SnapshotCodec.canonicalJson(double.infinity), throwsArgumentError);
      expect(() => SnapshotCodec.canonicalJson(DateTime.utc(2026)), throwsArgumentError);
    });
  });

  group('tablesSha256', () {
    test('independent of row order and column order; 64 lowercase hex', () {
      final a = SnapshotCodec.tablesSha256({
        'subjects': [
          {'id': 'b', 'name': 'B'},
          {'id': 'a', 'name': 'A'},
        ],
      });
      final b = SnapshotCodec.tablesSha256({
        'subjects': [
          {'name': 'A', 'id': 'a'},
          {'name': 'B', 'id': 'b'},
        ],
      });
      expect(a, b);
      expect(a, matches(RegExp(r'^[0-9a-f]{64}$')));
    });

    test('any value change changes the hash', () {
      final a = SnapshotCodec.tablesSha256({'subjects': [row('a', data: {'name': 'A'})]});
      final b = SnapshotCodec.tablesSha256({'subjects': [row('a', data: {'name': 'a'})]});
      final c = SnapshotCodec.tablesSha256({'subjects': [row('a', data: {'name': 'A'}, rev: 2)]});
      expect(a, isNot(b));
      expect(a, isNot(c));
    });
  });

  group('build', () {
    test('header fields, rows sorted by id, live counts, checksum', () {
      final s = buildSnap(sampleTables());
      expect(s.formatVersion, SnapshotCodec.formatVersion);
      expect(s.schemaVersion, kCurrentSchemaVersion);
      expect(s.appVersion, '1.0.0+42');
      expect(s.deviceName, 'ফোন');
      expect(s.createdAtMs, 1795180000000);
      expect(s.tables['subjects']!.map((r) => r['id']), ['s1', 's2']);
      expect(s.tables['students']!.map((r) => r['id']), ['st-a', 'st-b']);
      expect(s.counts, {'subjects': 2, 'students': 1, 'student_photos': 1, 'settings': 1});
      expect(s.sha256, SnapshotCodec.tablesSha256(sampleTables()));
      expect(s.tables.keys.toList(), ['subjects', 'students', 'student_photos', 'settings']);
    });

    test('snapshot rows are copies and unmodifiable', () {
      final tables = sampleTables();
      final s = buildSnap(tables);
      tables['subjects']![0]['name'] = 'changed';
      expect(s.tables['subjects']!.any((r) => r['name'] == 'changed'), isFalse);
      expect(() => s.tables['subjects']![0]['name'] = 'x', throwsUnsupportedError);
      expect(() => s.tables['subjects']!.add(row('z')), throwsUnsupportedError);
    });

    test('rejects rows without id and duplicate ids', () {
      expect(() => buildSnap({'subjects': [{'name': 'x'}]}), throwsArgumentError);
      expect(() => buildSnap({'subjects': [row('')]}), throwsArgumentError);
      expect(() => buildSnap({'subjects': [row('a'), row('a', u: 5)]}), throwsArgumentError);
    });
  });

  group('encode/decode round trip', () {
    test('decode(encode(s)) == s, including Bangla text, tombstones and base64 blobs', () {
      final s = buildSnap(sampleTables());
      final bytes = SnapshotCodec.encode(s);
      expect(bytes.take(2), [0x1f, 0x8b]);
      final back = SnapshotCodec.decode(bytes);
      expect(back, s);
      expect(back.sha256, s.sha256);
      expect(back.counts, s.counts);
      expect(back.tables['students']!.last['deleted_at'], 500);
      expect(back.tables['subjects']!.first['name'], 'Physics "A"\n');
      expect(SnapshotCodec.decode(SnapshotCodec.encode(back)), s);
    });

    test('envelope follows Arch §3.4 and is canonical JSON', () {
      final s = buildSnap(sampleTables());
      final text = utf8.decode(GZipDecoder().decodeBytes(SnapshotCodec.encode(s)));
      final env = jsonDecode(text) as Map<String, dynamic>;
      expect(env.keys.toSet(), {
        'format', 'formatVersion', 'schemaVersion', 'appVersion', 'snapshotId', 'deviceId',
        'deviceName', 'createdAt', 'counts', 'sha256', 'tables',
      });
      expect(env['format'], 'attendance-alamin-backup');
      expect(env['createdAt'], 1795180000000);
      expect(text, SnapshotCodec.canonicalJson(env));
    });

    test('empty snapshot round-trips', () {
      final s = buildSnap({for (final t in kSyncedTables) t: <RowMap>[]});
      expect(SnapshotCodec.decode(SnapshotCodec.encode(s)), s);
      expect(s.counts.values.every((c) => c == 0), isTrue);
    });

    test('decoded rows are unmodifiable', () {
      final back = SnapshotCodec.decode(SnapshotCodec.encode(buildSnap(sampleTables())));
      expect(() => back.tables['subjects']![0]['name'] = 'x', throwsUnsupportedError);
    });

    test('decode re-sorts rows and recomputes counts from the verified tables', () {
      final s = buildSnap(sampleTables());
      final env = unwrap(SnapshotCodec.encode(s));
      (env['tables']['subjects'] as List).insert(0, (env['tables']['subjects'] as List).removeLast());
      env['counts'] = {'subjects': 99};
      final back = SnapshotCodec.decode(gzipText(jsonEncode(env)));
      expect(back.tables['subjects']!.map((r) => r['id']), ['s1', 's2']);
      expect(back.counts, s.counts);
    });

    test('uppercase sha256 in the file is accepted', () {
      final env = unwrap(SnapshotCodec.encode(buildSnap(sampleTables())));
      env['sha256'] = (env['sha256'] as String).toUpperCase();
      expect(() => SnapshotCodec.decode(gzipText(jsonEncode(env))), returnsNormally);
    });
  });

  group('decode rejects', () {
    late List<int> good;
    setUp(() => good = SnapshotCodec.encode(buildSnap(sampleTables())));

    test('not gzip → importNotBackup', () {
      expect(() => SnapshotCodec.decode(<int>[]), throwsImport(ErrorCodes.importNotBackup));
      expect(() => SnapshotCodec.decode([0x1f]), throwsImport(ErrorCodes.importNotBackup));
      expect(() => SnapshotCodec.decode(utf8.encode('{"format":"attendance-alamin-backup"}')),
          throwsImport(ErrorCodes.importNotBackup));
      // zlib (no gzip header) must not be accepted through archive's fallback
      // zlib stream of '{}' (header 78 9c): no gzip magic, so never decoded
      expect(() => SnapshotCodec.decode([0x78, 0x9c, 0xab, 0xae, 0x05, 0x00, 0x01, 0x75, 0x00, 0xf9]),
          throwsImport(ErrorCodes.importNotBackup));
    });

    test('valid gzip that is not our backup → importNotBackup', () {
      expect(() => SnapshotCodec.decode(gzipText('hello world')), throwsImport(ErrorCodes.importNotBackup));
      expect(() => SnapshotCodec.decode(gzipText('[]')), throwsImport(ErrorCodes.importNotBackup));
      expect(() => SnapshotCodec.decode(gzipText('{"format":"other"}')), throwsImport(ErrorCodes.importNotBackup));
      expect(() => SnapshotCodec.decode(GZipEncoder().encodeBytes([0xff, 0xfe, 0xfd])),
          throwsImport(ErrorCodes.importNotBackup));
    });

    test('truncated gzip → importCorrupt', () {
      for (final cut in [1, 4, 8, 9, good.length ~/ 2, good.length - 12]) {
        expect(() => SnapshotCodec.decode(good.sublist(0, good.length - cut)), throwsImport(ErrorCodes.importCorrupt),
            reason: 'cut $cut');
      }
      expect(() => SnapshotCodec.decode(good.sublist(0, 12)), throwsImport(ErrorCodes.importCorrupt));
    });

    test('damaged gzip body or trailer → importCorrupt', () {
      for (final at in [good.length ~/ 2, good.length - 6, good.length - 2]) {
        final bad = List<int>.of(good);
        bad[at] ^= 0x5a;
        expect(() => SnapshotCodec.decode(bad), throwsImport(ErrorCodes.importCorrupt), reason: 'byte $at');
      }
      expect(() => SnapshotCodec.decode([...good, 0, 0, 0, 0]), throwsImport(ErrorCodes.importCorrupt));
    });

    test('tampered table content (valid gzip, stale sha256) → importChecksum', () {
      final env = unwrap(good);
      (env['tables']['students'] as List).first['name'] = 'Hacker';
      expect(() => SnapshotCodec.decode(gzipText(jsonEncode(env))), throwsImport(ErrorCodes.importChecksum));

      final env2 = unwrap(good);
      (env2['tables']['subjects'] as List).removeLast();
      expect(() => SnapshotCodec.decode(gzipText(jsonEncode(env2))), throwsImport(ErrorCodes.importChecksum));

      final env3 = unwrap(good);
      (env3['tables'] as Map<String, dynamic>)['payments'] = <Object?>[];
      expect(() => SnapshotCodec.decode(gzipText(jsonEncode(env3))), throwsImport(ErrorCodes.importChecksum));
    });

    test('snapshot with a wrong sha256 field → importChecksum', () {
      final s = buildSnap(sampleTables());
      final forged = Snapshot(
        formatVersion: s.formatVersion,
        schemaVersion: s.schemaVersion,
        appVersion: s.appVersion,
        snapshotId: s.snapshotId,
        deviceId: s.deviceId,
        deviceName: s.deviceName,
        createdAtMs: s.createdAtMs,
        counts: s.counts,
        sha256: '0' * 64,
        tables: s.tables,
      );
      expect(() => SnapshotCodec.decode(SnapshotCodec.encode(forged)), throwsImport(ErrorCodes.importChecksum));
    });

    test('newer schemaVersion or formatVersion → importNewerSchema (before checksum)', () {
      for (final f in [
        (Map<String, dynamic> e) => e['schemaVersion'] = kCurrentSchemaVersion + 1,
        (Map<String, dynamic> e) => e['formatVersion'] = SnapshotCodec.formatVersion + 1,
      ]) {
        final env = unwrap(good);
        f(env);
        expect(() => SnapshotCodec.decode(gzipText(jsonEncode(env))), throwsImport(ErrorCodes.importNewerSchema));
        env['sha256'] = 'bad';
        env['tables'] = {'brand_new_table': 42};
        expect(() => SnapshotCodec.decode(gzipText(jsonEncode(env))), throwsImport(ErrorCodes.importNewerSchema));
      }
    });

    test('missing or mistyped envelope fields → importCorrupt', () {
      for (final key in ['formatVersion', 'schemaVersion', 'appVersion', 'snapshotId', 'deviceId', 'deviceName',
          'createdAt', 'sha256', 'tables']) {
        final env = unwrap(good)..remove(key);
        expect(() => SnapshotCodec.decode(gzipText(jsonEncode(env))), throwsImport(ErrorCodes.importCorrupt),
            reason: key);
      }
      final env = unwrap(good)..['createdAt'] = '2026';
      expect(() => SnapshotCodec.decode(gzipText(jsonEncode(env))), throwsImport(ErrorCodes.importCorrupt));
      final env0 = unwrap(good)..['schemaVersion'] = 0;
      expect(() => SnapshotCodec.decode(gzipText(jsonEncode(env0))), throwsImport(ErrorCodes.importCorrupt));
    });

    List<int> withTables(Map<String, List<Map<String, Object?>>> tables) {
      final env = unwrap(good)
        ..['tables'] = tables
        ..['sha256'] = SnapshotCodec.tablesSha256(tables);
      return gzipText(jsonEncode(env));
    }

    test('bad table shape → importCorrupt', () {
      final env = unwrap(good)..['tables'] = {'subjects': 'nope'};
      expect(() => SnapshotCodec.decode(gzipText(jsonEncode(env))), throwsImport(ErrorCodes.importCorrupt));
      final env2 = unwrap(good)..['tables'] = {'subjects': [1, 2]};
      expect(() => SnapshotCodec.decode(gzipText(jsonEncode(env2))), throwsImport(ErrorCodes.importCorrupt));
      final env3 = unwrap(good)..['tables'] = {
        'subjects': [
          {'name': 'no id'},
        ],
      };
      expect(() => SnapshotCodec.decode(gzipText(jsonEncode(env3))), throwsImport(ErrorCodes.importCorrupt));
    });

    test('duplicate ids → importCorrupt', () {
      expect(() => SnapshotCodec.decode(withTables({'subjects': [row('a'), row('a', u: 7)]})),
          throwsImport(ErrorCodes.importCorrupt));
    });

    test('missing or mistyped sync columns → importCorrupt', () {
      for (final mutate in <void Function(Map<String, Object?>)>[
        (r) => r.remove('updated_at'),
        (r) => r['updated_at'] = '100',
        (r) => r['rev'] = null,
        (r) => r['device_id'] = 3,
        (r) => r['deleted_at'] = 'yes',
        (r) => r.remove('deleted_at'),
        (r) => r.remove('created_at'),
      ]) {
        final r = Map<String, Object?>.of(row('a', data: {'name': 'x'}));
        mutate(r);
        expect(() => SnapshotCodec.decode(withTables({'subjects': [r]})), throwsImport(ErrorCodes.importCorrupt));
      }
      expect(() => SnapshotCodec.decode(withTables({'subjects': [row('a', del: 9)]})), returnsNormally);
    });
  });

  test('5k-row snapshot: build + encode + decode + diff complete quickly', () {
    final sw = Stopwatch()..start();
    final students = [for (var i = 0; i < 1000; i++) row('st$i', data: {'name': 'Student $i', 'phone': '017$i'})];
    final sessions = [for (var i = 0; i < 100; i++) row('se$i', data: {'batch_id': 'b1', 'date': '2026-11-01'})];
    final records = [
      for (var i = 0; i < 3900; i++)
        row('r$i', data: {'session_id': 'se${i % 100}', 'student_id': 'st${i % 1000}', 'status': 'P'}),
    ];
    final local = {'students': students, 'attendance_sessions': sessions, 'attendance_records': records};
    final incomingTables = {
      'students': [
        for (final s in students) s['id'] == 'st0' ? row('st0', u: 200, data: {'name': 'Renamed', 'phone': '0170'}) : s,
        row('new', u: 300, data: {'name': 'Nila', 'phone': null}),
      ],
      'attendance_sessions': sessions,
      'attendance_records': [
        for (final r in records)
          r['id'] == 'r5' ? row('r5', u: 200, data: {'session_id': 'se5', 'student_id': 'st5', 'status': 'A'}) : r,
      ],
    };
    final snap = buildSnap(incomingTables);
    final bytes = SnapshotCodec.encode(snap);
    final back = SnapshotCodec.decode(bytes);
    final summary = SyncDiff.diff(local: local, incoming: back);
    sw.stop();
    expect(back.counts['attendance_records'], 3900);
    expect(summary.entities[SummaryEntity.students]!.added, 1);
    expect(summary.entities[SummaryEntity.students]!.updated, 1);
    expect(summary.entities[SummaryEntity.attendance]!.updated, 1);
    expect(summary.winners.length, 3);
    expect(sw.elapsedMilliseconds, lessThan(10000));
  });
}
