// In-memory fake of PlacesRepository (schema v2) for widget / controller tests.
// Starts with the default place only, so the app behaves as with one centre.

import 'dart:async';

import 'package:attendance_alamin/data/repositories/places_repository.dart';
import 'package:attendance_alamin/domain/models/place.dart';

class FakePlacesRepository implements PlacesRepository {
  FakePlacesRepository({List<Place>? places, Map<String, String>? batchPlaces})
      : places = places ??
            <Place>[
              const Place(id: kDefaultPlaceId, name: 'আলামিন কোচিং', sortOrder: 0),
            ],
        batchPlaces = batchPlaces ?? <String, String>{};

  final List<Place> places;

  /// Batch id -> place id, for [countBatches].
  final Map<String, String> batchPlaces;

  final StreamController<void> _changes = StreamController<void>.broadcast();
  int _next = 0;

  void notify() => _changes.add(null);

  Stream<T> _watch<T>(T Function() read) async* {
    yield read();
    await for (final _ in _changes.stream) {
      yield read();
    }
  }

  List<Place> _list(bool includeArchived) => <Place>[
        for (final Place p in places)
          if (includeArchived || !p.archived) p,
      ]..sort((Place a, Place b) {
          final int s = a.sortOrder.compareTo(b.sortOrder);
          return s != 0 ? s : a.name.compareTo(b.name);
        });

  Place? _find(String id) {
    for (final Place p in places) {
      if (p.id == id) return p;
    }
    return null;
  }

  void _replace(Place p) {
    final int i = places.indexWhere((Place x) => x.id == p.id);
    if (i >= 0) places[i] = p;
    notify();
  }

  Place _copy(Place p, {String? name, String? phone, String? address, int? sortOrder, bool? archived}) => Place(
        id: p.id,
        name: name ?? p.name,
        phone: phone ?? p.phone,
        address: address ?? p.address,
        sortOrder: sortOrder ?? p.sortOrder,
        archived: archived ?? p.archived,
      );

  @override
  Stream<List<Place>> watchAll({bool includeArchived = false}) => _watch(() => _list(includeArchived));

  @override
  Future<List<Place>> getAll({bool includeArchived = false}) async => _list(includeArchived);

  @override
  Stream<Place?> watchById(String id) => _watch(() => _find(id));

  @override
  Future<Place?> getById(String id) async => _find(id);

  @override
  Future<Place> getDefault() async => _find(kDefaultPlaceId)!;

  @override
  Future<String> create({required String name, String? phone, String? address}) async {
    final String id = 'place-${++_next}';
    places.add(Place(id: id, name: name.trim(), phone: phone, address: address, sortOrder: places.length));
    notify();
    return id;
  }

  @override
  Future<void> update(String id, {required String name, String? phone, String? address}) async {
    final Place? p = _find(id);
    if (p == null) return;
    _replace(Place(
      id: p.id,
      name: name.trim(),
      phone: phone,
      address: address,
      sortOrder: p.sortOrder,
      archived: p.archived,
    ));
  }

  @override
  Future<void> reorder(List<String> orderedIds) async {
    for (var i = 0; i < orderedIds.length; i++) {
      final Place? p = _find(orderedIds[i]);
      if (p != null) _replace(_copy(p, sortOrder: i));
    }
  }

  @override
  Future<void> archive(String id) async {
    if (id == kDefaultPlaceId) throw ArgumentError.value(id, 'id');
    final Place? p = _find(id);
    if (p != null) _replace(_copy(p, archived: true));
  }

  @override
  Future<void> unarchive(String id) async {
    final Place? p = _find(id);
    if (p != null) _replace(_copy(p, archived: false));
  }

  @override
  Future<int> countBatches(String id) async =>
      batchPlaces.values.where((String v) => v == id).length;
}
