import 'package:attendance_alamin/domain/models/subject.dart';

/// Subjects / classes (Product F1). Writes validate, run in one transaction
/// and stamp sync columns; deletes are soft and cascade to the subject's
/// batches (see `BatchesRepository.softDelete`).
abstract interface class SubjectsRepository {
  /// Live subjects ordered by sort order, then name.
  Stream<List<Subject>> watchAll();

  /// The live subject whose trimmed name equals [name] (case-insensitive), or null.
  Future<Subject?> findByName(String name);

  /// Returns the new id. Throws `ValidationException` for a bad [name].
  Future<String> create({required String name, String? notes});

  /// Throws `ValidationException` (bad name) or `NotFoundException`.
  Future<void> rename(String id, String name);

  /// Tombstones the subject, its batches and everything that belongs to them.
  Future<void> softDelete(String id);
}
