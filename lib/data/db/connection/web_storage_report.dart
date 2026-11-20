import 'package:flutter/foundation.dart';

/// Which storage the web database ended up on (Arch 1.6 step 3).
///
/// [implementation] is drift's `WasmStorageImplementation.name`
/// (`opfsShared`, `opfsLocks`, `sharedIndexedDb`, `unsafeIndexedDb` or
/// `inMemory`); [missingFeatures] are `MissingBrowserFeature.name`s.
class WebStorageInfo {
  const WebStorageInfo(this.implementation, this.missingFeatures);

  final String implementation;
  final List<String> missingFeatures;

  /// `false` when drift fell back to memory: data will NOT survive a reload
  /// (the app shows a permanent red banner).
  bool get persistent => implementation != 'inMemory';

  @override
  bool operator ==(Object other) =>
      other is WebStorageInfo &&
      other.implementation == implementation &&
      listEquals(other.missingFeatures, missingFeatures);

  @override
  int get hashCode =>
      Object.hash(implementation, Object.hashAll(missingFeatures));

  @override
  String toString() =>
      'WebStorageInfo($implementation, missing: $missingFeatures)';
}

/// Set once by the web connection when the database opens; stays `null` on
/// Android / Windows (native files are always persistent).
final webStorageReport = ValueNotifier<WebStorageInfo?>(null);
