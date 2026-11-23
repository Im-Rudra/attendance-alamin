import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/errors/error_codes.dart';
import 'package:attendance_alamin/core/ids/ids.dart';
import 'package:attendance_alamin/core/settings/setting_keys.dart';
import 'package:attendance_alamin/core/validation/validators.dart';
import 'package:attendance_alamin/data/db/app_database.dart';
import 'package:attendance_alamin/data/db/mappers.dart';
import 'package:attendance_alamin/data/db/schema_v2.dart';
import 'package:attendance_alamin/data/db/sync_stamper.dart';
import 'package:attendance_alamin/data/repositories/drift/settings_repository_drift.dart';
import 'package:attendance_alamin/data/repositories/places_repository.dart';
import 'package:attendance_alamin/domain/models/place.dart';
import 'package:drift/drift.dart' hide Batch;

/// Throws `NotFoundException` unless [placeId] is a live (not deleted) place.
/// Archived places are accepted (old batches keep them).
Future<void> requirePlace(AppDatabase db, String placeId) async {
  final row = await (db.select(db.places)
        ..where((t) => t.id.equals(placeId) & t.deletedAt.isNull()))
      .getSingleOrNull();
  if (row == null) {
    if (placeId == kDefaultPlaceId) {
      await ensureDefaultPlace(db);
      return;
    }
    throw NotFoundException(ErrorCodes.notFound, detail: 'place $placeId');
  }
}

class DriftPlacesRepository implements PlacesRepository {
  DriftPlacesRepository(this._db, this._stamper);

  final AppDatabase _db;
  final SyncStamper _stamper;

  // ------------------------------------------------------------ reads

  /// The default place shows the centre settings (see [PlacesRepository]).
  Future<Place> _withCenter(Place p) async {
    if (!p.isDefault) return p;
    final center = await readCenterSettings(_db);
    return Place(
      id: p.id,
      name: center.name ?? p.name,
      phone: center.phone,
      address: center.address,
      sortOrder: p.sortOrder,
      archived: false,
    );
  }

  Future<List<Place>> _load(bool includeArchived) async {
    final rows = await (_db.select(_db.places)
          ..where((t) => includeArchived
              ? t.deletedAt.isNull()
              : t.deletedAt.isNull() & t.archivedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.name),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .get();
    return [for (final r in rows) await _withCenter(placeFromRow(r))];
  }

  @override
  Stream<List<Place>> watchAll({bool includeArchived = false}) =>
      _db.watchComposite({_db.places, _db.syncedSettings},
          () => _load(includeArchived));

  @override
  Future<List<Place>> getAll({bool includeArchived = false}) =>
      _load(includeArchived);

  @override
  Stream<Place?> watchById(String id) =>
      _db.watchComposite({_db.places, _db.syncedSettings}, () => getById(id));

  @override
  Future<Place?> getById(String id) async {
    final row = await (_db.select(_db.places)
          ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
        .getSingleOrNull();
    if (row == null) return null;
    return _withCenter(placeFromRow(row));
  }

  @override
  Future<Place> getDefault() async {
    final found = await getById(kDefaultPlaceId);
    if (found != null) return found;
    await _db.transaction(() => ensureDefaultPlace(_db));
    _db.notifyUpdates({TableUpdate.onTable(_db.places, kind: UpdateKind.insert)});
    return (await getById(kDefaultPlaceId))!;
  }

  @override
  Future<int> countBatches(String id) async {
    final count = _db.batches.id.count();
    final row = await (_db.selectOnly(_db.batches)
          ..addColumns([count])
          ..where(_db.batches.placeId.equals(id) &
              _db.batches.deletedAt.isNull()))
        .getSingle();
    return row.read(count) ?? 0;
  }

  // ------------------------------------------------------------ writes

  static ({String name, String? phone, String? address}) _clean(
      String name, String? phone, String? address) {
    final String? a = address?.trim();
    return (
      name: Validators.name(name),
      phone: Validators.phone(phone),
      address: (a == null || a.isEmpty) ? null : a,
    );
  }

  Future<PlaceRow> _live(String id) async {
    final row = await (_db.select(_db.places)
          ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
        .getSingleOrNull();
    if (row == null) {
      throw NotFoundException(ErrorCodes.notFound, detail: 'place $id');
    }
    return row;
  }

  Future<void> _write(PlaceRow old, PlacesCompanion changes) =>
      (_db.update(_db.places)..where((t) => t.id.equals(old.id))).write(
        changes.copyWith(
          updatedAt: Value(_stamper.nextUpdatedAt(old.updatedAt)),
          rev: Value(_stamper.nextRev(old.rev)),
          deviceId: Value(_stamper.deviceId),
        ),
      );

  @override
  Future<String> create(
      {required String name, String? phone, String? address}) async {
    final c = _clean(name, phone, address);
    return _db.transaction(() async {
      final maxRow = await (_db.select(_db.places)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.desc(t.sortOrder)])
            ..limit(1))
          .getSingleOrNull();
      final id = Ids.v4();
      final now = _stamper.nowMs();
      await _db.into(_db.places).insert(PlacesCompanion(
            id: Value(id),
            name: Value(c.name),
            phone: Value(c.phone),
            address: Value(c.address),
            sortOrder: Value(maxRow == null ? 0 : maxRow.sortOrder + 1),
            createdAt: Value(now),
            updatedAt: Value(now),
            deviceId: Value(_stamper.deviceId),
            rev: const Value(1),
          ));
      return id;
    });
  }

  @override
  Future<void> update(String id,
      {required String name, String? phone, String? address}) async {
    final c = _clean(name, phone, address);
    await _db.transaction(() async {
      if (id == kDefaultPlaceId) await ensureDefaultPlace(_db);
      final old = await _live(id);
      if (old.name != c.name || old.phone != c.phone || old.address != c.address) {
        await _write(
            old,
            PlacesCompanion(
              name: Value(c.name),
              phone: Value(c.phone),
              address: Value(c.address),
            ));
      }
      if (id == kDefaultPlaceId) {
        final settings = DriftSettingsRepository(_db, _stamper);
        await settings.set(SettingKeys.centerName, c.name);
        await settings.set(SettingKeys.centerPhone, c.phone ?? '');
        await settings.set(SettingKeys.centerAddress, c.address ?? '');
      }
    });
  }

  @override
  Future<void> reorder(List<String> orderedIds) async {
    await _db.transaction(() async {
      final rows = await (_db.select(_db.places)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([
              (t) => OrderingTerm.asc(t.sortOrder),
              (t) => OrderingTerm.asc(t.name),
              (t) => OrderingTerm.asc(t.id),
            ]))
          .get();
      final byId = {for (final r in rows) r.id: r};
      for (final id in orderedIds) {
        if (!byId.containsKey(id)) {
          throw NotFoundException(ErrorCodes.notFound, detail: 'place $id');
        }
      }
      final order = <String>[
        ...orderedIds,
        for (final r in rows)
          if (!orderedIds.contains(r.id)) r.id,
      ];
      for (var i = 0; i < order.length; i++) {
        final old = byId[order[i]]!;
        if (old.sortOrder == i) continue;
        await _write(old, PlacesCompanion(sortOrder: Value(i)));
      }
    });
  }

  @override
  Future<void> archive(String id) async {
    if (id == kDefaultPlaceId) {
      throw ArgumentError.value(id, 'id', 'The default place cannot be archived');
    }
    await _db.transaction(() async {
      final old = await _live(id);
      if (old.archivedAt != null) return;
      await _write(old, PlacesCompanion(archivedAt: Value(_stamper.nowMs())));
    });
  }

  @override
  Future<void> unarchive(String id) async {
    await _db.transaction(() async {
      final old = await _live(id);
      if (old.archivedAt == null) return;
      await _write(old, const PlacesCompanion(archivedAt: Value(null)));
    });
  }
}
