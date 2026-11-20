import 'dart:io';

import 'package:attendance_alamin/data/db/app_database.dart';
import 'package:attendance_alamin/data/db/mappers.dart';
import 'package:attendance_alamin/domain/sync/synced_tables.dart';
import 'package:drift/drift.dart' hide Batch;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'db_fixtures.dart';

void main() {
  test('closing and reopening a v1 file database keeps every row', () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final dir = await Directory.systemTemp.createTemp('m3a_reopen_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/attendance_alamin.sqlite');

    final first = AppDatabase(NativeDatabase(file));
    await seedBasics(first);
    await first.into(first.payments).insert(stamp(paymentToCompanion(paymentFor('pay-1')).copyWith));
    final version = await first.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.first, kCurrentSchemaVersion);
    await first.close();

    final second = AppDatabase(NativeDatabase(file));
    addTearDown(second.close);
    expect(subjectFromRow(await second.select(second.subjects).getSingle()), subjectA);
    expect(batchFromRow(await second.select(second.batches).getSingle(), center), batchA);
    expect(slotFromRow(await second.select(second.batchSlots).getSingle()), slotA);
    expect(studentFromRow(await second.select(second.students).getSingle()), studentA);
    expect(enrollmentFromRow(await second.select(second.enrollments).getSingle()), enrollmentA);
    expect(paymentFromRow(await second.select(second.payments).getSingle()), paymentFor('pay-1'));
    // beforeOpen ran again on the new connection.
    final fk = await second.customSelect('PRAGMA foreign_keys').getSingle();
    expect(fk.data.values.first, 1);
  });
}
