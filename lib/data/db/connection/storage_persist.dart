/// `requestPersistentStorage()`: asks the browser not to evict the web
/// database (`navigator.storage.persist()`, Arch 1.6 step 4). No-op natively.
library;

export 'package:attendance_alamin/data/db/connection/storage_persist_stub.dart'
    if (dart.library.js_interop) 'package:attendance_alamin/data/db/connection/storage_persist_web.dart';
