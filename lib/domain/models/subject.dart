/// Hidden subject of a private tuition that has no subject (schema v2).
///
/// `batches.subject_id` stays NOT NULL with its foreign key (making it
/// nullable would mean rebuilding the batches table and changing every
/// `Batch.subjectId` reader), so a subject-less tuition points at this one
/// fixed row instead. `BatchesRepository.create` writes the row on first use;
/// `SubjectsRepository` and the shared loaders never list it (its subject name
/// reads as `''`). Pass it as `BatchDraft.subjectId` for "no subject".
const String kNoSubjectId = '00000000-0000-4000-8000-00000000500b';

class Subject {
  const Subject({
    required this.id,
    required this.name,
    required this.sortOrder,
    this.notes,
    this.archived = false,
  });

  final String id;
  final String name;
  final int sortOrder;
  final String? notes;
  final bool archived;

  @override
  bool operator ==(Object other) =>
      other is Subject &&
      other.id == id &&
      other.name == name &&
      other.sortOrder == sortOrder &&
      other.notes == notes &&
      other.archived == archived;

  @override
  int get hashCode => Object.hash(id, name, sortOrder, notes, archived);

  @override
  String toString() => 'Subject($id, $name)';
}
