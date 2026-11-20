import 'package:attendance_alamin/domain/sync/sync_models.dart';
import 'package:attendance_alamin/domain/sync/synced_tables.dart';

/// Per-record last-writer-wins merge preview (Product §4, Arch §3.5,
/// plan §1 #17/#18). Pure: never mutates its inputs.
///
/// Row rules, for every incoming row `r` of a table in [kSyncedTables] and the
/// local row `l` with the same id (local rows INCLUDE tombstones):
///
/// | incoming       | local            | result                                   |
/// |----------------|------------------|------------------------------------------|
/// | live           | none             | add                                      |
/// | tombstone      | none             | unknown tombstone: not counted (see 1)   |
/// | none           | any              | untouched (absence never deletes)        |
/// | any            | same content     | nothing (metadata-only differences)      |
/// | wins, deleted  | live             | delete                                   |
/// | wins, live     | deleted          | restore (counted as updated)             |
/// | wins, live     | live             | update                                   |
/// | wins, deleted  | deleted          | update, not counted (see 2)              |
/// | loses          | differs          | keptLocal (both deleted: nothing)        |
///
/// "wins" = [incomingWins]: `(updated_at, device_id, rev)` strictly greater.
///
/// 1. Unknown tombstones are not shown in the summary but ARE returned in
///    [ChangeSummary.winners] (kind [ChangeKind.add]), so live child rows that
///    still reference a deleted parent keep their foreign key on apply.
/// 2. Tombstone-over-tombstone winners converge metadata invisibly.
///
/// Rows are grouped into what the teacher sees (one item per group):
/// batch_fees → their batch, student_photos → their student, enrollment_fees →
/// their enrollment, attendance records → their session (sessions counted, not
/// marks), payment rows → their receipt (`receipt_id`), other_income rows →
/// one item each, settings → one item per key. A group is counted as
/// - added:   not live locally, live after the merge (restored → updated);
/// - deleted: live locally, not live after the merge;
/// - updated: live before and after;
/// - nothing: dead before and after (changes to deleted data are invisible).
/// Liveness of a group is its header row's (batch, student, enrollment,
/// session) when one exists, otherwise "any row live" (payment receipts).
/// keptLocal counts groups with at least one kept-local row.
///
/// Samples: up to 3 per bucket, most recently changed first (max incoming
/// `updated_at` of the group's winning rows desc, then group key asc). A
/// sample is a copy of the group's header row (deleted: the local version;
/// otherwise the merged version) or, without a header, of its first winning
/// row, plus `'_table'` (source table). Payment samples also carry
/// `'_receipt_total'` (sum of the receipt's live `amount`s in that state).
///
/// [ChangeSummary.winners] lists deletions first, then the rest; each part in
/// [kSyncedTables] order, then by id. Apply must run with deferred foreign
/// keys (Arch §3.6). `entities` has an entry for every [SummaryEntity].
abstract final class SyncDiff {
  /// Sync-stamp columns ignored by [contentDiffers] (`deleted_at` is content).
  static const ignoredColumns = <String>{'id', 'created_at', 'updated_at', 'device_id', 'rev'};

  /// Max samples per bucket (plan §1 #17).
  static const maxSamples = 3;

  /// True when [incoming] is strictly newer than [local] by
  /// `(updated_at, device_id, rev)` compared lexicographically (plan §1 #18).
  static bool incomingWins(RowMap incoming, RowMap local) {
    final ua = incoming['updated_at'] as int;
    final ub = local['updated_at'] as int;
    if (ua != ub) return ua > ub;
    final dc = (incoming['device_id'] as String).compareTo(local['device_id'] as String);
    if (dc != 0) return dc > 0;
    return (incoming['rev'] as int) > (local['rev'] as int);
  }

  /// True when any column other than [ignoredColumns] differs. A missing
  /// column equals null. Lists/maps (unexpected, e.g. raw blobs) compare deeply.
  static bool contentDiffers(RowMap a, RowMap b) {
    for (final k in {...a.keys, ...b.keys}) {
      if (ignoredColumns.contains(k)) continue;
      if (!_deepEq(a[k], b[k])) return true;
    }
    return false;
  }

  /// Merge preview of [incoming] into [local] (`table → all rows incl.
  /// tombstones`). Tables outside [kSyncedTables] are ignored on both sides.
  static ChangeSummary diff({
    required Map<String, List<RowMap>> local,
    required Snapshot incoming,
  }) {
    // Index local rows and their groups.
    final localIdx = <String, Map<String, RowMap>>{};
    final localByGroup = <String, List<_Ref>>{};
    for (final t in kSyncedTables) {
      final idx = <String, RowMap>{};
      for (final r in local[t] ?? const <RowMap>[]) {
        final id = r['id'];
        if (id is String) idx[id] = r;
      }
      localIdx[t] = idx;
      final rule = _rules[t]!;
      for (final e in idx.entries) {
        (localByGroup[rule.groupKey(e.value)] ??= <_Ref>[]).add(_Ref(t, e.key));
      }
    }

    final groups = <String, _Group>{};
    _Group groupFor(String table, RowMap row) {
      final rule = _rules[table]!;
      final key = rule.groupKey(row);
      return groups[key] ??= _Group(key, rule.entity, rule.headerTable, rule.headerId(row));
    }

    final winners = <RowChange>[];
    final winnerIdx = <String, RowChange>{}; // '<table>/<id>'
    for (final t in kSyncedTables) {
      final rows = _dedupe(incoming.tables[t] ?? const <RowMap>[]);
      final lidx = localIdx[t]!;
      for (final r in rows) {
        final id = r['id'] as String;
        final l = lidx[id];
        final ChangeKind kind;
        if (l == null) {
          kind = ChangeKind.add; // includes unknown tombstones (not counted)
        } else if (!contentDiffers(r, l)) {
          continue;
        } else if (incomingWins(r, l)) {
          final rDel = _deleted(r), lDel = _deleted(l);
          kind = rDel && !lDel
              ? ChangeKind.delete
              : (!rDel && lDel ? ChangeKind.restore : ChangeKind.update);
        } else {
          if (!(_deleted(r) && _deleted(l))) groupFor(t, r).kept = true;
          continue;
        }
        final change = RowChange(table: t, id: id, kind: kind, incoming: r, local: l);
        winners.add(change);
        winnerIdx['$t/$id'] = change;
        // Unknown tombstones and tombstone-over-tombstone are applied but
        // never make a group count (they change nothing the teacher can see).
        final invisible = _deleted(r) && (l == null || _deleted(l));
        if (!invisible) groupFor(t, r).winners.add(change);
      }
    }

    // Classify groups.
    final buckets = <SummaryEntity, _Buckets>{
      for (final e in SummaryEntity.values) e: _Buckets(),
    };
    for (final g in groups.values) {
      final b = buckets[g.entity]!;
      if (g.kept) b.keptLocal++;
      if (g.winners.isEmpty) continue;
      RowMap? merged(String table, String id) =>
          winnerIdx['$table/$id']?.incoming ?? localIdx[table]![id];

      final members = <_Ref>{
        ...?localByGroup[g.key],
        for (final w in g.winners) _Ref(w.table, w.id),
      };
      final headerTable = g.headerTable;
      final headerId = g.headerId;
      final localHeader = headerTable == null || headerId == null ? null : localIdx[headerTable]![headerId];
      final mergedHeader = headerTable == null || headerId == null ? null : merged(headerTable, headerId);

      final bool localLive, afterLive, localExists;
      if (mergedHeader != null) {
        localExists = localHeader != null;
        localLive = localHeader != null && !_deleted(localHeader);
        afterLive = !_deleted(mergedHeader);
      } else {
        final localRows = [
          for (final m in members)
            if (localIdx[m.table]![m.id] case final row?) row,
        ];
        localExists = localRows.isNotEmpty;
        localLive = localRows.any((r) => !_deleted(r));
        afterLive = members.any((m) {
          final row = merged(m.table, m.id);
          return row != null && !_deleted(row);
        });
      }

      final _Bucket? bucket;
      if (!localLive && afterLive) {
        bucket = localExists ? b.updated : b.added;
      } else if (localLive && !afterLive) {
        bucket = b.deleted;
      } else if (localLive && afterLive) {
        bucket = b.updated;
      } else {
        bucket = null; // dead before and after: invisible
      }
      if (bucket == null) continue;

      final deleted = identical(bucket, b.deleted);
      final sortedWinners = [...g.winners]..sort(_changeOrder);
      final RowMap rep;
      final String? repTable;
      if (mergedHeader != null) {
        repTable = headerTable;
        rep = deleted ? (localHeader ?? mergedHeader) : mergedHeader;
      } else {
        final first = sortedWinners.first;
        repTable = first.table;
        rep = deleted ? (first.local ?? first.incoming) : first.incoming;
      }
      final sample = <String, Object?>{...rep, '_table': repTable};
      if (repTable == 'payments') {
        var total = 0;
        for (final m in members) {
          if (m.table != 'payments') continue;
          final row = deleted ? localIdx[m.table]![m.id] : merged(m.table, m.id);
          if (row == null || _deleted(row)) continue;
          final amount = row['amount'];
          if (amount is int) total += amount;
        }
        sample['_receipt_total'] = total;
      }
      var recency = 0;
      for (final w in g.winners) {
        final u = w.incoming['updated_at'];
        if (u is int && u > recency) recency = u;
      }
      bucket.items.add(_Item(g.key, recency, Map<String, Object?>.unmodifiable(sample)));
    }

    winners.sort(_winnerOrder);
    return ChangeSummary(
      entities: Map<SummaryEntity, EntityChange>.unmodifiable({
        for (final e in SummaryEntity.values) e: buckets[e]!.toEntityChange(),
      }),
      winners: List<RowChange>.unmodifiable(winners),
    );
  }

  // ---------------------------------------------------------------------------

  static bool _deleted(RowMap r) => r['deleted_at'] != null;

  static final Map<String, int> _tableIndex = {
    for (var i = 0; i < kSyncedTables.length; i++) kSyncedTables[i]: i,
  };

  static int _changeOrder(RowChange a, RowChange b) {
    final t = _tableIndex[a.table]!.compareTo(_tableIndex[b.table]!);
    return t != 0 ? t : a.id.compareTo(b.id);
  }

  static int _winnerOrder(RowChange a, RowChange b) {
    final da = a.kind == ChangeKind.delete ? 0 : 1;
    final db = b.kind == ChangeKind.delete ? 0 : 1;
    return da != db ? da.compareTo(db) : _changeOrder(a, b);
  }

  /// One row per id; if a (malformed) input repeats an id, the LWW max wins.
  static List<RowMap> _dedupe(List<RowMap> rows) {
    final byId = <String, RowMap>{};
    for (final r in rows) {
      final id = r['id'];
      if (id is! String) continue;
      final cur = byId[id];
      if (cur == null || incomingWins(r, cur)) byId[id] = r;
    }
    return byId.values.toList();
  }

  static bool _deepEq(Object? a, Object? b) {
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_deepEq(a[i], b[i])) return false;
      }
      return true;
    }
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final k in a.keys) {
        if (!b.containsKey(k) || !_deepEq(a[k], b[k])) return false;
      }
      return true;
    }
    return a == b;
  }

  static String? _str(Object? v) => v is String ? v : null;

  static String _own(String prefix, RowMap r) => '$prefix:${r['id']}';

  static String _parent(String prefix, String column, String table, RowMap r) {
    final p = _str(r[column]);
    return p == null ? '$table#${r['id']}' : '$prefix:$p';
  }

  static final Map<String, _Rule> _rules = {
    'subjects': _Rule(SummaryEntity.subjects, (r) => _own('subject', r), 'subjects', (r) => _str(r['id'])),
    'batches': _Rule(SummaryEntity.batches, (r) => _own('batch', r), 'batches', (r) => _str(r['id'])),
    'batch_fees': _Rule(SummaryEntity.batches, (r) => _parent('batch', 'batch_id', 'batch_fees', r), 'batches',
        (r) => _str(r['batch_id'])),
    'batch_slots': _Rule(SummaryEntity.schedule, (r) => _own('slot', r), 'batch_slots', (r) => _str(r['id'])),
    'schedule_exceptions': _Rule(
        SummaryEntity.schedule, (r) => _own('exception', r), 'schedule_exceptions', (r) => _str(r['id'])),
    'students': _Rule(SummaryEntity.students, (r) => _own('student', r), 'students', (r) => _str(r['id'])),
    // student_photos.id == student_id
    'student_photos': _Rule(SummaryEntity.students, (r) => _own('student', r), 'students', (r) => _str(r['id'])),
    'enrollments': _Rule(SummaryEntity.enrollments, (r) => _own('enrollment', r), 'enrollments', (r) => _str(r['id'])),
    'enrollment_fees': _Rule(SummaryEntity.enrollments,
        (r) => _parent('enrollment', 'enrollment_id', 'enrollment_fees', r), 'enrollments',
        (r) => _str(r['enrollment_id'])),
    'attendance_sessions': _Rule(
        SummaryEntity.attendance, (r) => _own('session', r), 'attendance_sessions', (r) => _str(r['id'])),
    'attendance_records': _Rule(SummaryEntity.attendance,
        (r) => _parent('session', 'session_id', 'attendance_records', r), 'attendance_sessions',
        (r) => _str(r['session_id'])),
    // A receipt has no header row: liveness = any allocation row live.
    'payments': _Rule(
        SummaryEntity.payments, (r) => _parent('receipt', 'receipt_id', 'payments', r), null, (r) => null),
    'other_income': _Rule(SummaryEntity.payments, (r) => _own('income', r), 'other_income', (r) => _str(r['id'])),
    'settings': _Rule(SummaryEntity.settings, (r) => _own('setting', r), 'settings', (r) => _str(r['id'])),
  };
}

class _Rule {
  const _Rule(this.entity, this.groupKey, this.headerTable, this.headerId);
  final SummaryEntity entity;
  final String Function(RowMap row) groupKey;
  final String? headerTable;
  final String? Function(RowMap row) headerId;
}

class _Ref {
  const _Ref(this.table, this.id);
  final String table;
  final String id;

  @override
  bool operator ==(Object other) => other is _Ref && other.table == table && other.id == id;

  @override
  int get hashCode => Object.hash(table, id);
}

class _Group {
  _Group(this.key, this.entity, this.headerTable, this.headerId);
  final String key;
  final SummaryEntity entity;
  final String? headerTable;
  final String? headerId;
  final List<RowChange> winners = [];
  bool kept = false;
}

class _Item {
  const _Item(this.key, this.recency, this.sample);
  final String key;
  final int recency;
  final RowMap sample;
}

class _Bucket {
  final List<_Item> items = [];

  List<RowMap> samples() {
    final sorted = [...items]
      ..sort((a, b) {
        final r = b.recency.compareTo(a.recency);
        return r != 0 ? r : a.key.compareTo(b.key);
      });
    return List<RowMap>.unmodifiable(sorted.take(SyncDiff.maxSamples).map((i) => i.sample));
  }
}

class _Buckets {
  final _Bucket added = _Bucket();
  final _Bucket updated = _Bucket();
  final _Bucket deleted = _Bucket();
  int keptLocal = 0;

  EntityChange toEntityChange() => EntityChange(
        added: added.items.length,
        updated: updated.items.length,
        deleted: deleted.items.length,
        keptLocal: keptLocal,
        addedSamples: added.samples(),
        updatedSamples: updated.samples(),
        deletedSamples: deleted.samples(),
      );
}
