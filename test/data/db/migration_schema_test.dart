// After migrating a real v1 file, the database schema must be exactly what a
// fresh v2 install creates (drift's own schema comparison).

import 'package:attendance_alamin/data/db/app_database.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'migration_test.dart' show openV1File, tempFile, v1Rows;

void main() {
  test('migrated v1 file has the same schema as a fresh v2 database', () async {
    final AppDatabase db = openV1File(await tempFile('validate'), v1Rows());
    addTearDown(db.close);
    await db.validateDatabaseSchema();
  });
}
