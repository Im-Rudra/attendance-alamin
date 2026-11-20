import 'package:attendance_alamin/data/db/connection/web_storage_report.dart';
import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

/// Database name: `attendance_alamin.sqlite` natively, the IndexedDB / OPFS
/// name on the web. Never change it (existing installs would look empty).
const kDatabaseName = 'attendance_alamin';

/// Opens the browser database through drift's `WasmDatabase`.
///
/// `sqlite3.wasm` and `drift_worker.js` are fetched into `web/` by CI
/// (`tool/fetch_web_assets.sh`, pinned to the drift version). Relative URIs
/// respect `<base href>` (GitHub Pages sub-path). The chosen storage is
/// published to [webStorageReport]; `inMemory` means nothing is saved.
QueryExecutor openConnection() => DatabaseConnection.delayed(Future(() async {
      final result = await WasmDatabase.open(
        databaseName: kDatabaseName,
        sqlite3Uri: Uri.parse('sqlite3.wasm'),
        driftWorkerUri: Uri.parse('drift_worker.js'),
      );
      webStorageReport.value = WebStorageInfo(
        result.chosenImplementation.name,
        [for (final f in result.missingFeatures) f.name]..sort(),
      );
      return result.resolvedExecutor;
    }));
