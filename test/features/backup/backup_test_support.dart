// Shared helpers of the backup tests: snapshot rows, a repository that really
// merges (SyncDiff over in-memory tables), a router host, and a rich change
// summary for the screen matrix.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/data/backup/backup_providers.dart';
import 'package:attendance_alamin/data/backup/backup_repository.dart';
import 'package:attendance_alamin/domain/sync/snapshot_codec.dart';
import 'package:attendance_alamin/domain/sync/sync_diff.dart';
import 'package:attendance_alamin/domain/sync/sync_models.dart';
import 'package:attendance_alamin/features/backup/backup_entry.dart';
import 'package:attendance_alamin/features/backup/controllers/backup_state.dart';
import 'package:attendance_alamin/features/backup/controllers/merge_clashes.dart';
import 'package:attendance_alamin/features/backup/controllers/backup_text.dart';
import 'package:attendance_alamin/features/backup/ui/backup_review_screen.dart';

import '../../helpers/fakes/fake_settings_repos.dart';
import '../../helpers/fixtures.dart';

typedef Tables = Map<String, List<RowMap>>;

RowMap row(
  String id, {
  int u = 100,
  String dev = 'P',
  int rev = 1,
  int? del,
  Map<String, Object?> data = const <String, Object?>{},
}) =>
    <String, Object?>{
      'id': id,
      'created_at': 1,
      'updated_at': u,
      'deleted_at': del,
      'device_id': dev,
      'rev': rev,
      ...data,
    };

RowMap stu(String id, String name,
        {int u = 100, String dev = 'P', int rev = 1, int? del, String? phone, String? guardian}) =>
    row(id, u: u, dev: dev, rev: rev, del: del, data: <String, Object?>{
      'name': name,
      'phone': phone,
      'guardian_name': guardian,
    });

Snapshot snap(Tables t, {int createdAtMs = 0, String device = 'Phone'}) => SnapshotCodec.build(
      tables: t,
      appVersion: '1.0.0+7',
      snapshotId: 'snap',
      deviceId: 'P',
      deviceName: device,
      createdAtMs: createdAtMs,
    );

Uint8List encoded(Snapshot s) => Uint8List.fromList(SnapshotCodec.encode(s));

/// The backup repository over in-memory tables: a real preview/apply (the
/// SyncDiff the data layer uses), safety copies and restore.
class MergingBackupRepository implements BackupRepository {
  MergingBackupRepository(this.tables);

  Tables tables;
  final Map<String, Tables> _copies = <String, Tables>{};
  List<SafetyCopyInfo> _list = const <SafetyCopyInfo>[];
  final StreamController<List<SafetyCopyInfo>> _changes =
      StreamController<List<SafetyCopyInfo>>.broadcast();
  int _n = 0;
  int overfilled = 0;

  Tables _clone(Tables t) => <String, List<RowMap>>{
        for (final MapEntry<String, List<RowMap>> e in t.entries) e.key: <RowMap>[...e.value],
      };

  String _keep(String reason) {
    final String id = 'copy-${++_n}';
    _copies[id] = _clone(tables);
    _list = <SafetyCopyInfo>[
      SafetyCopyInfo(id: id, createdAtMs: 1000 * _n, reason: reason),
      ..._list,
    ].take(kSafetyCopiesKept).toList();
    _changes.add(_list);
    return id;
  }

  @override
  Future<Snapshot> buildSnapshot({required String appVersion}) async => snap(tables);

  @override
  Future<ChangeSummary> preview(Snapshot incoming) async =>
      SyncDiff.diff(local: tables, incoming: incoming);

  @override
  Future<ApplyOutcome> apply(Snapshot incoming, ChangeSummary summary) async {
    if (summary.isEmpty) return const ApplyOutcome(applied: 0, safetyCopyId: '');
    final ChangeSummary diff = SyncDiff.diff(local: tables, incoming: incoming);
    if (diff.isEmpty) return const ApplyOutcome(applied: 0, safetyCopyId: '');
    final String id = _keep(SafetyCopyReason.beforeImport);
    final Map<String, Map<String, RowMap>> out = <String, Map<String, RowMap>>{
      for (final MapEntry<String, List<RowMap>> e in tables.entries)
        e.key: <String, RowMap>{for (final RowMap r in e.value) r['id']! as String: r},
    };
    for (final RowChange w in diff.winners) {
      (out[w.table] ??= <String, RowMap>{})[w.id] = w.incoming;
    }
    tables = <String, List<RowMap>>{
      for (final MapEntry<String, Map<String, RowMap>> e in out.entries) e.key: e.value.values.toList(),
    };
    return ApplyOutcome(applied: diff.winners.length, safetyCopyId: id);
  }

  @override
  Stream<List<SafetyCopyInfo>> watchSafetyCopies() async* {
    yield _list;
    yield* _changes.stream;
  }

  @override
  Future<void> restoreSafetyCopy(String id) async {
    final Tables? copy = _copies[id];
    if (copy == null) throw StateError('unknown safety copy $id');
    _keep(SafetyCopyReason.beforeRestore);
    tables = _clone(copy);
  }

  @override
  Future<int> countOverfilledMonths() async => overfilled;

  RowMap? byId(String table, String id) {
    for (final RowMap r in tables[table] ?? const <RowMap>[]) {
      if (r['id'] == id) return r;
    }
    return null;
  }
}

/// A host page with two buttons and the review route, driven by a real
/// GoRouter (the entry functions use `context.push`).
GoRouter hostRouter() => GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) => Scaffold(
            body: Builder(
              builder: (BuildContext context) => Column(
                children: <Widget>[
                  TextButton(
                    key: const Key('host-import'),
                    onPressed: () => runImportBackup(context),
                    child: const Text('import'),
                  ),
                  TextButton(
                    key: const Key('host-export'),
                    onPressed: () => runExportBackup(context),
                    child: const Text('export'),
                  ),
                ],
              ),
            ),
          ),
        ),
        GoRoute(
          path: Routes.moreBackupReview,
          builder: (BuildContext context, GoRouterState state) => const BackupReviewScreen(),
        ),
      ],
    );

/// A review screen state fixed by the test.
class FixedImportController extends ImportController {
  FixedImportController(this._state);

  final ImportState _state;

  @override
  ImportState build() => _state;
}

Override fixedImport(ImportState state) =>
    importControllerProvider.overrideWith(() => FixedImportController(state));

EntityChange _ec({
  int added = 0,
  int updated = 0,
  int deleted = 0,
  int kept = 0,
  List<RowMap> addedS = const <RowMap>[],
  List<RowMap> updatedS = const <RowMap>[],
  List<RowMap> deletedS = const <RowMap>[],
}) =>
    EntityChange(
      added: added,
      updated: updated,
      deleted: deleted,
      keptLocal: kept,
      addedSamples: addedS,
      updatedSamples: updatedS,
      deletedSamples: deletedS,
    );

/// Every kind of line the review shows: new / changed / removed rows over
/// several entities, more rows than samples, a payment, a slot.
ChangeSummary richSummary() => ChangeSummary(
      entities: <SummaryEntity, EntityChange>{
        for (final SummaryEntity e in SummaryEntity.values) e: const EntityChange(),
        SummaryEntity.batches: _ec(
          updated: 1,
          updatedS: <RowMap>[
            <String, Object?>{'id': kBatPhysA, 'name': 'ফিজিক্স এ', '_table': 'batches'},
          ],
        ),
        SummaryEntity.students: _ec(
          added: 5,
          deleted: 4,
          kept: 2,
          addedS: <RowMap>[
            <String, Object?>{'id': 'n1', 'name': 'তানভীর হাসান', '_table': 'students'},
            <String, Object?>{'id': 'n2', 'name': 'মীম আক্তার', '_table': 'students'},
            <String, Object?>{'id': 'n3', 'name': 'সুমন দাস', '_table': 'students'},
          ],
          deletedS: <RowMap>[
            <String, Object?>{'id': 'd1', 'name': 'তানিয়া আক্তার', '_table': 'students'},
            <String, Object?>{'id': 'd2', 'name': 'রাকিব হোসেন', '_table': 'students'},
            <String, Object?>{'id': 'd3', 'name': 'নাঈম উদ্দিন', '_table': 'students'},
          ],
        ),
        SummaryEntity.attendance: _ec(
          added: 38,
          addedS: <RowMap>[
            <String, Object?>{
              'id': 's1',
              'batch_id': kBatPhysA,
              'date': '2026-11-16',
              '_table': 'attendance_sessions',
            },
          ],
        ),
        SummaryEntity.payments: _ec(
          added: 2,
          addedS: <RowMap>[
            <String, Object?>{
              'id': 'p1',
              'student_id': kStuRahim,
              'amount': 1000,
              'paid_on': '2026-11-05',
              '_receipt_total': 1000,
              '_table': 'payments',
            },
          ],
        ),
        SummaryEntity.schedule: _ec(
          added: 1,
          addedS: <RowMap>[
            <String, Object?>{
              'id': 'slot-new',
              'batch_id': kBatChemB,
              'weekday': 6,
              'start_min': 960,
              'end_min': 1020,
              '_table': 'batch_slots',
            },
          ],
        ),
      },
    );

ImportState richState({bool older = true, bool clashes = true, String? errorCode}) => ImportState(
      phase: ImportPhase.ready,
      snapshot: snap(
        <String, List<RowMap>>{
          'students': <RowMap>[stu(kStuRahim, 'রহিম উদ্দিন')],
          'batches': <RowMap>[row(kBatPhysA, data: <String, Object?>{'name': 'ফিজিক্স এ'})],
        },
        createdAtMs: DateTime.utc(2026, 11, 18, 15, 15).millisecondsSinceEpoch,
        device: 'Windows PC',
      ),
      summary: richSummary(),
      names: const SnapshotNames(
        students: <String, String>{kStuRahim: 'রহিম উদ্দিন'},
        batches: <String, String>{kBatPhysA: 'ফিজিক্স এ', kBatChemB: 'কেমিস্ট্রি বি'},
      ),
      clashes: clashes
          ? const <MergeClash>[
              MergeClash(weekday: 6, startMin: 960, endMin: 1020, batchAId: kBatChemB, batchBId: kBatPhysA),
            ]
          : const <MergeClash>[],
      older: older,
      errorCode: errorCode,
    );

/// Backup repository + files fakes wired as provider overrides.
List<Override> backupOverrides({
  required BackupRepository repo,
  required FakeBackupFiles files,
}) =>
    <Override>[
      backupRepositoryProvider.overrideWithValue(repo),
      backupFilesProvider.overrideWithValue(files),
    ];
