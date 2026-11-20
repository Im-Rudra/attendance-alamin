/// Platform connection of `AppDatabase` (Arch 1.6): `openConnection()`.
///
/// Native (Android, Windows): drift_flutter, file `attendance_alamin.sqlite`
/// in the application-support directory. Web: drift's `WasmDatabase` with
/// `web/sqlite3.wasm` + `web/drift_worker.js`, reporting the chosen storage to
/// `webStorageReport`. `dart:io` may only appear in `*_native.dart`.
library;

export 'package:attendance_alamin/data/db/connection/open_connection_native.dart'
    if (dart.library.js_interop) 'package:attendance_alamin/data/db/connection/open_connection_web.dart';
