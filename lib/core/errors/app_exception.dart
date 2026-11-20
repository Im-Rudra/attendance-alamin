/// Base class of every expected failure. Repositories throw subclasses;
/// the UI maps [code] to a localised message (`errorText`). Never shown raw.
///
/// Deliberately not sealed: subclasses live in other libraries.
abstract class AppException implements Exception {
  const AppException(this.code, {this.detail});

  /// One of the `ErrorCodes` constants.
  final String code;

  /// Optional technical detail for logs / diagnostics (not user-facing).
  final String? detail;

  @override
  String toString() =>
      '$runtimeType($code${detail == null ? '' : ': $detail'})';
}

/// User input failed validation. [field] names the offending form field.
final class ValidationException extends AppException {
  const ValidationException(super.code, {this.field, super.detail});

  final String? field;
}

final class NotFoundException extends AppException {
  const NotFoundException(super.code, {super.detail});
}

final class ImportException extends AppException {
  const ImportException(super.code, {super.detail});
}

final class StorageException extends AppException {
  const StorageException(super.code, {super.detail});
}
