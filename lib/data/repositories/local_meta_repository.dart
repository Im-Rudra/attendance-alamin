import 'package:attendance_alamin/core/time/local_date.dart';

/// Raw device-only key/value store (`local_meta`, never exported). Build keys
/// with [LocalMetaKeys] only.
abstract interface class LocalMetaRepository {
  Future<String?> getRaw(String key);

  /// Current value (null = absent), re-emitted on change (distinct).
  Stream<String?> watchRaw(String key);

  /// Stores [value]; null removes the key. Throws [ArgumentError] for keys
  /// owned by the infrastructure (`device_id`) or for an empty key.
  Future<void> setRaw(String key, String? value);
}

/// Key formats of the dynamic device keys (plan M4-C).
abstract final class LocalMetaKeys {
  /// Roll-call draft of one occurrence; value = JSON.
  static String rollCallDraft(String occ) => 'rollcall_draft:$occ';

  /// Last payment method used for a student; value = method code.
  static String lastMethod(String studentId) => 'last_method:$studentId';

  /// Students already reminded about dues on [date]; value = JSON list of ids.
  static String reminded(LocalDate date) => 'reminded:${date.toCompact()}';

  /// Absence alert dismissed for an enrollment; value = the session id it was
  /// dismissed at.
  static String absenceDismissed(String enrollmentId) =>
      'absence_dismissed:$enrollmentId';

  /// Width of a resizable pane on [screen]; value = a double as text.
  static String pane(String screen) => 'pane:$screen';

  /// Epoch ms (`createdAt`) of the last snapshot imported from a device
  /// (Arch 3.3, used by future Drive sync). Written by the backup repository.
  static String lastImport(String sourceDeviceId) => 'last_import:$sourceDeviceId';

  /// Keys no feature may write through [LocalMetaRepository.setRaw].
  static const reserved = <String>{'device_id'};
}
