import 'package:attendance_alamin/domain/models/place.dart';

/// Places / coaching centres (schema v2, feedback item 3).
///
/// The default place ([kDefaultPlaceId]) always exists, cannot be archived and
/// follows the centre settings: reads show the non-blank
/// `centerName` / `centerPhone` / `centerAddress` values in place of its own
/// columns, and [update] of it writes those settings too. So with one place
/// the app behaves exactly as before. Writes validate, run in one transaction
/// and stamp sync columns; places are archived, never deleted.
abstract interface class PlacesRepository {
  /// Places by sort order, then name, then id; archived ones only when asked.
  Stream<List<Place>> watchAll({bool includeArchived = false});
  Future<List<Place>> getAll({bool includeArchived = false});
  Stream<Place?> watchById(String id);

  /// Null for an unknown or deleted id (archived places are returned).
  Future<Place?> getById(String id);

  /// The default place (re-seeded from the centre settings if it is missing).
  Future<Place> getDefault();

  /// Validates (`Validators.name`, `Validators.phone`; blank phone / address
  /// = null) and appends a place at the end of the order. Returns its id.
  Future<String> create({required String name, String? phone, String? address});

  /// Replaces name, phone and address. For the default place the centre
  /// settings are written as well. Throws `ValidationException` /
  /// `NotFoundException`.
  Future<void> update(String id,
      {required String name, String? phone, String? address});

  /// Sets `sort_order` = index in [orderedIds]; ids not listed keep their
  /// place after the listed ones. Unknown ids throw `NotFoundException`.
  Future<void> reorder(List<String> orderedIds);

  /// Hides the place from pickers; its batches and income keep pointing at it.
  /// Throws `ArgumentError` for the default place.
  Future<void> archive(String id);
  Future<void> unarchive(String id);

  /// Live (not deleted) batches of the place, finished ones included.
  Future<int> countBatches(String id);
}
