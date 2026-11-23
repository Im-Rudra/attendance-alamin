import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/errors/error_codes.dart';
import 'package:attendance_alamin/core/ids/ids.dart';
import 'package:attendance_alamin/core/time/center_time.dart';
import 'package:attendance_alamin/core/validation/validators.dart';
import 'package:attendance_alamin/data/db/app_database.dart';
import 'package:attendance_alamin/data/db/mappers.dart';
import 'package:attendance_alamin/data/db/sync_stamper.dart';
import 'package:attendance_alamin/data/repositories/drift/batches_repository_drift.dart';
import 'package:attendance_alamin/data/repositories/drift/structure_store.dart';
import 'package:attendance_alamin/data/repositories/subjects_repository.dart';
import 'package:attendance_alamin/domain/models/subject.dart';
import 'package:drift/drift.dart' hide Batch;

/// Writes the hidden "no subject" row ([kNoSubjectId], name `''`) used by
/// private tuitions without a subject, or revives it. Call inside a
/// transaction. Never listed by [DriftSubjectsRepository].
Future<void> ensureNoSubjectRow(AppDatabase db, SyncStamper stamper) async {
  final old = await (db.select(db.subjects)
        ..where((t) => t.id.equals(kNoSubjectId)))
      .getSingleOrNull();
  if (old == null) {
    final now = stamper.nowMs();
    await db.into(db.subjects).insert(SubjectsCompanion(
          id: const Value(kNoSubjectId),
          name: const Value(''),
          sortOrder: const Value(1 << 30),
          createdAt: Value(now),
          updatedAt: Value(now),
          deviceId: Value(stamper.deviceId),
          rev: const Value(1),
        ));
    return;
  }
  if (old.deletedAt == null) return;
  await (db.update(db.subjects)..where((t) => t.id.equals(kNoSubjectId))).write(
    SubjectsCompanion(
      deletedAt: const Value(null),
      updatedAt: Value(stamper.nextUpdatedAt(old.updatedAt)),
      rev: Value(stamper.nextRev(old.rev)),
      deviceId: Value(stamper.deviceId),
    ),
  );
}

class DriftSubjectsRepository implements SubjectsRepository {
  DriftSubjectsRepository(
    this._db,
    this._stamper, {
    CenterTime center = CenterTime.dhaka,
  }) : _store = StructureStore(_db, _stamper, center);

  final AppDatabase _db;
  final SyncStamper _stamper;
  final StructureStore _store;

  @override
  Stream<List<Subject>> watchAll() {
    final q = _db.select(_db.subjects)
      ..where((t) => t.deletedAt.isNull() & t.id.equals(kNoSubjectId).not())
      ..orderBy([
        (t) => OrderingTerm.asc(t.sortOrder),
        (t) => OrderingTerm.asc(t.name),
        (t) => OrderingTerm.asc(t.id),
      ]);
    return q.watch().map((rows) => [for (final r in rows) subjectFromRow(r)]);
  }

  @override
  Future<Subject?> findByName(String name) async {
    final wanted = name.trim().toLowerCase();
    if (wanted.isEmpty) return null;
    final rows = await (_db.select(_db.subjects)
          ..where((t) => t.deletedAt.isNull() & t.id.equals(kNoSubjectId).not())
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .get();
    for (final r in rows) {
      if (r.name.trim().toLowerCase() == wanted) return subjectFromRow(r);
    }
    return null;
  }

  @override
  Future<String> create({required String name, String? notes}) async {
    final clean = Validators.name(name);
    final note = StructureStore.cleanNote(notes);
    return _db.transaction(() async {
      final maxRow = await (_db.select(_db.subjects)
            ..where((t) => t.deletedAt.isNull() & t.id.equals(kNoSubjectId).not())
            ..orderBy([(t) => OrderingTerm.desc(t.sortOrder)])
            ..limit(1))
          .getSingleOrNull();
      final id = Ids.v4();
      final now = _stamper.nowMs();
      await _db.into(_db.subjects).insert(SubjectsCompanion(
            id: Value(id),
            name: Value(clean),
            sortOrder: Value(maxRow == null ? 0 : maxRow.sortOrder + 1),
            notes: Value(note),
            createdAt: Value(now),
            updatedAt: Value(now),
            deviceId: Value(_stamper.deviceId),
            rev: const Value(1),
          ));
      return id;
    });
  }

  @override
  Future<void> rename(String id, String name) async {
    final clean = Validators.name(name);
    return _db.transaction(() async {
      final old = await _live(id);
      await (_db.update(_db.subjects)..where((t) => t.id.equals(id))).write(
        SubjectsCompanion(
          name: Value(clean),
          updatedAt: Value(_stamper.nextUpdatedAt(old.updatedAt)),
          rev: Value(_stamper.nextRev(old.rev)),
          deviceId: Value(_stamper.deviceId),
        ),
      );
    });
  }

  @override
  Future<void> softDelete(String id) async {
    return _db.transaction(() async {
      final old = await _live(id);
      final batches = await (_db.select(_db.batches)
            ..where((t) => t.subjectId.equals(id) & t.deletedAt.isNull()))
          .get();
      for (final b in batches) {
        await cascadeDeleteBatch(_store, b.id);
      }
      final ts = _stamper.nextUpdatedAt(old.updatedAt);
      await (_db.update(_db.subjects)..where((t) => t.id.equals(id))).write(
        SubjectsCompanion(
          deletedAt: Value(ts),
          updatedAt: Value(ts),
          rev: Value(_stamper.nextRev(old.rev)),
          deviceId: Value(_stamper.deviceId),
        ),
      );
    });
  }

  Future<SubjectRow> _live(String id) async {
    if (id == kNoSubjectId) {
      throw NotFoundException(ErrorCodes.notFound, detail: 'subject $id');
    }
    final row = await (_db.select(_db.subjects)
          ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
        .getSingleOrNull();
    if (row == null) {
      throw NotFoundException(ErrorCodes.notFound, detail: 'subject $id');
    }
    return row;
  }
}
