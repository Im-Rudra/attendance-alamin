import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

/// Database name: `attendance_alamin.sqlite` natively, the IndexedDB / OPFS
/// name on the web. Never change it (existing installs would look empty).
const kDatabaseName = 'attendance_alamin';

/// Opens the on-device database file in the application-support directory
/// (`%APPDATA%` on Windows, not Documents/OneDrive; app files dir on Android).
QueryExecutor openConnection() => driftDatabase(
      name: kDatabaseName,
      native: const DriftNativeOptions(
        databaseDirectory: getApplicationSupportDirectory,
      ),
    );
