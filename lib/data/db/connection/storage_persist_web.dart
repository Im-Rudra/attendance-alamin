import 'dart:js_interop';

/// `navigator.storage` (absent in some browsers and insecure contexts).
@JS('navigator.storage')
external _StorageManager? get _storageManager;

extension type _StorageManager._(JSObject raw) implements JSObject {
  external JSPromise<JSBoolean> persisted();
  external JSPromise<JSBoolean> persist();
}

/// Calls `navigator.storage.persist()` unless storage is already persistent.
/// Never throws: a refusal only means the browser may evict data under
/// pressure, which the backup nudge covers.
Future<void> requestPersistentStorage() async {
  try {
    final storage = _storageManager;
    if (storage == null) return;
    final already = (await storage.persisted().toDart).toDart;
    if (already) return;
    await storage.persist().toDart;
  } catch (_) {
    // Unsupported or blocked: keep going without persistence.
  }
}
