import 'package:attendance_alamin/data/infra_providers.dart';
import 'package:attendance_alamin/data/repositories/drift/places_repository_drift.dart';
import 'package:attendance_alamin/data/repositories/places_repository.dart';
import 'package:attendance_alamin/domain/models/place.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final placesRepositoryProvider = Provider<PlacesRepository>((ref) =>
    DriftPlacesRepository(
        ref.watch(appDatabaseProvider), ref.watch(syncStamperProvider)));

/// Places that are not archived, in the teacher's order (pickers, filters).
final placesProvider = StreamProvider<List<Place>>(
    (ref) => ref.watch(placesRepositoryProvider).watchAll());

/// Every place, archived ones included (Settings › Places, old batches).
final allPlacesProvider = StreamProvider<List<Place>>((ref) =>
    ref.watch(placesRepositoryProvider).watchAll(includeArchived: true));

/// The default place (follows the centre settings); null while loading.
final defaultPlaceProvider = Provider<Place?>((ref) {
  final List<Place> all = ref.watch(allPlacesProvider).value ?? const <Place>[];
  for (final Place p in all) {
    if (p.isDefault) return p;
  }
  return null;
});

/// Any place by id, archived ones included; null when unknown or loading.
final placeByIdProvider = Provider.family<Place?, String>((ref, id) {
  final List<Place> all = ref.watch(allPlacesProvider).value ?? const <Place>[];
  for (final Place p in all) {
    if (p.id == id) return p;
  }
  return null;
});

/// True when the teacher has 2+ places that are not archived: only then do
/// place filters, per-place totals and place pickers show (one place = the
/// app looks exactly as before).
final hasManyPlacesProvider = Provider<bool>(
    (ref) => (ref.watch(placesProvider).value?.length ?? 0) > 1);
