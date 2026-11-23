import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/enums.dart';

/// The comparison key of a batch / private-tuition name: trimmed, inner
/// whitespace collapsed to one space, lower-case. "  Physics   A " and
/// "physics a" are the same name.
String batchNameKey(String name) =>
    name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

/// Whether [name] is already used by another batch of the same [kind] in
/// [batches] (pass the live, not deleted batches; finished ones count).
/// [excludeId] skips the batch being renamed. A blank name is never taken.
bool isBatchNameTaken(
  Iterable<Batch> batches,
  String name, {
  required BatchKind kind,
  String? excludeId,
}) {
  final String key = batchNameKey(name);
  if (key.isEmpty) return false;
  for (final Batch b in batches) {
    if (b.id == excludeId || b.kind != kind) continue;
    if (batchNameKey(b.name) == key) return true;
  }
  return false;
}
