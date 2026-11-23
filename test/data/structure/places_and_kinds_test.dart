// Schema v2: places (feedback item 3), batch kind / private tuition without a
// subject and the per-kind name check (item 1).

import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/settings/setting_keys.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/data/db/db_queries.dart';
import 'package:attendance_alamin/data/db/schema_v2.dart';
import 'package:attendance_alamin/data/repositories/drift/places_repository_drift.dart';
import 'package:attendance_alamin/data/repositories/drift/settings_repository_drift.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/batch_names.dart';
import 'package:attendance_alamin/domain/models/drafts.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/place.dart';
import 'package:attendance_alamin/domain/models/subject.dart';
import 'package:flutter_test/flutter_test.dart';

import 'structure_fixtures.dart';

BatchDraft _draft(String subjectId, String name,
        {BatchKind kind = BatchKind.batch, String? placeId, List<SlotDraft>? slots}) =>
    BatchDraft(
      subjectId: subjectId,
      name: name,
      billingType: BillingType.prepaid,
      monthlyFee: 1500,
      feeFrom: const YearMonth(2026, 11),
      slots: slots ?? <SlotDraft>[slot(fri, 900, 960)],
      slotsFrom: today,
      kind: kind,
      placeId: placeId,
    );

void main() {
  group('places', () {
    test('a fresh database has only the default place, following the centre settings', () async {
      final h = Harness();
      final places = DriftPlacesRepository(h.db, h.stamper);
      final settings = DriftSettingsRepository(h.db, h.stamper);

      final Place first = await places.getDefault();
      expect(first.id, kDefaultPlaceId);
      expect(first.name, kDefaultPlaceNameBn);
      expect(first.isDefault, isTrue);

      await settings.set(SettingKeys.centerName, 'আলামিন কোচিং');
      await settings.set(SettingKeys.centerPhone, '01712345678');
      final List<Place> all = await places.getAll();
      expect(all.single.name, 'আলামিন কোচিং');
      expect(all.single.phone, '01712345678');
      expect(all.single.address, isNull);
    });

    test('updating the default place writes the centre settings too', () async {
      final h = Harness();
      final places = DriftPlacesRepository(h.db, h.stamper);
      final settings = DriftSettingsRepository(h.db, h.stamper);

      await places.update(kDefaultPlaceId, name: '  Main centre ', phone: '01812345678', address: 'Mirpur');
      expect(await settings.get(SettingKeys.centerName), 'Main centre');
      expect(await settings.get(SettingKeys.centerPhone), '01812345678');
      expect(await settings.get(SettingKeys.centerAddress), 'Mirpur');
      expect((await places.getDefault()).name, 'Main centre');
    });

    test('create, update, reorder, archive and unarchive', () async {
      final h = Harness();
      final places = DriftPlacesRepository(h.db, h.stamper);

      final String home = await places.create(name: "Student's home", address: '  ');
      final String second = await places.create(name: 'Second centre', phone: '০১৭১২৩৪৫৬৭৮');
      expect((await places.getById(second))!.phone, '01712345678');
      expect((await places.getById(home))!.address, isNull);
      expect([for (final Place p in await places.getAll()) p.id], <String>[kDefaultPlaceId, home, second]);

      await places.update(home, name: 'Home', address: 'Road 3');
      expect((await places.getById(home))!.name, 'Home');

      await places.reorder(<String>[second, kDefaultPlaceId]);
      expect([for (final Place p in await places.getAll()) p.id], <String>[second, kDefaultPlaceId, home]);

      await places.archive(home);
      expect([for (final Place p in await places.getAll()) p.id], <String>[second, kDefaultPlaceId]);
      expect(await places.getAll(includeArchived: true), hasLength(3));
      expect((await places.getById(home))!.archived, isTrue);
      await places.unarchive(home);
      expect(await places.getAll(), hasLength(3));

      await expectLater(places.archive(kDefaultPlaceId), throwsArgumentError);
      await expectLater(places.create(name: '  '), throwsA(isA<ValidationException>()));
      await expectLater(places.create(name: 'X', phone: '123'), throwsA(isA<ValidationException>()));
      await expectLater(places.reorder(<String>['nope']), throwsA(isA<NotFoundException>()));
    });

    test('watchAll emits again when a place or the centre settings change', () async {
      final h = Harness();
      final places = DriftPlacesRepository(h.db, h.stamper);
      final settings = DriftSettingsRepository(h.db, h.stamper);
      final List<List<String>> seen = <List<String>>[];
      final sub = places.watchAll().listen((List<Place> l) => seen.add([for (final Place p in l) p.name]));
      addTearDown(sub.cancel);
      await pumpEventQueue();
      await places.create(name: 'Second');
      await pumpEventQueue();
      await settings.set(SettingKeys.centerName, 'Renamed');
      await pumpEventQueue();
      expect(seen.last, <String>['Renamed', 'Second']);
    });
  });

  group('batches: kind and place', () {
    test('a batch goes to the default place unless another is picked', () async {
      final h = Harness();
      final places = DriftPlacesRepository(h.db, h.stamper);
      final String sub = await h.subject('Physics');
      final String a = await h.batches.create(_draft(sub, 'Physics A'));
      final String other = await places.create(name: 'Second centre');
      final String b = await h.batches.create(_draft(sub, 'Physics B',
          placeId: other, slots: <SlotDraft>[slot(sat, 600, 660)]));

      expect((await h.batches.getById(a))!.placeId, kDefaultPlaceId);
      expect((await h.batches.getById(a))!.kind, BatchKind.batch);
      expect((await h.batches.getById(b))!.placeId, other);
      expect(await places.countBatches(other), 1);

      await h.batches.setPlace(a, other);
      expect((await h.batches.getById(a))!.placeId, other);
      await expectLater(h.batches.setPlace(a, 'nope'), throwsA(isA<NotFoundException>()));
      await expectLater(h.batches.create(_draft(sub, 'Physics C', placeId: 'nope', slots: <SlotDraft>[slot(sun, 600, 660)])),
          throwsA(isA<NotFoundException>()));
    });

    test('a private tuition may have no subject; the hidden subject is never listed', () async {
      final h = Harness();
      final String id = await h.batches.create(_draft(kNoSubjectId, 'Rafi (home)', kind: BatchKind.tuition));
      final Batch t = (await h.batches.getById(id))!;
      expect(t.kind, BatchKind.tuition);
      expect(t.isTuition, isTrue);
      expect(t.hasSubject, isFalse);

      expect(await h.subjects.watchAll().first, isEmpty);
      expect(await h.subjects.findByName(''), isNull);
      final schedules = await loadAllSchedules(h.db, center);
      expect(schedules.single.subjectName, '');

      // A second subject-less tuition reuses the same hidden row.
      await h.batches.create(_draft(kNoSubjectId, 'Mitu', kind: BatchKind.tuition,
          slots: <SlotDraft>[slot(sat, 600, 660)]));
      final rows = await h.db.select(h.db.subjects).get();
      expect(rows.single.id, kNoSubjectId);
      await expectLater(h.subjects.rename(kNoSubjectId, 'X'), throwsA(isA<NotFoundException>()));
    });

    test('enrollment terms carry the batch place', () async {
      final h = Harness();
      final places = DriftPlacesRepository(h.db, h.stamper);
      final String other = await places.create(name: 'Second centre');
      final String sub = await h.subject('Physics');
      await h.batches.create(_draft(sub, 'Physics A', placeId: other));
      // No enrollments yet: the loader still works and returns nothing.
      expect(await loadEnrollmentTerms(h.db, center), isEmpty);
    });
  });

  group('name check', () {
    test('batchNameKey ignores case and extra spaces', () {
      expect(batchNameKey('  Physics   A '), 'physics a');
      expect(batchNameKey('PHYSICS a'), 'physics a');
    });

    test('isNameTaken is per kind, among live batches, finished ones included', () async {
      final h = Harness();
      final String sub = await h.subject('Physics');
      final String a = await h.batches.create(_draft(sub, 'Physics A'));
      await h.batches.create(_draft(kNoSubjectId, 'Rafi', kind: BatchKind.tuition,
          slots: <SlotDraft>[slot(sat, 600, 660)]));

      expect(await h.batches.isNameTaken('  physics   a', kind: BatchKind.batch), isTrue);
      expect(await h.batches.isNameTaken('Physics A', kind: BatchKind.tuition), isFalse);
      expect(await h.batches.isNameTaken('RAFI', kind: BatchKind.tuition), isTrue);
      expect(await h.batches.isNameTaken('Physics A', kind: BatchKind.batch, excludeId: a), isFalse);
      expect(await h.batches.isNameTaken('   ', kind: BatchKind.batch), isFalse);

      await h.batches.archive(a, on: today, lastBillableMonth: const YearMonth(2026, 11));
      expect(await h.batches.isNameTaken('Physics A', kind: BatchKind.batch), isTrue, reason: 'finished counts');

      await h.batches.softDelete(a);
      expect(await h.batches.isNameTaken('Physics A', kind: BatchKind.batch), isFalse, reason: 'deleted does not');
    });
  });

  group('ensureDefaultPlace', () {
    test('revives a tombstoned or archived default place', () async {
      final h = Harness();
      await h.db.customStatement('UPDATE places SET deleted_at = 5, archived_at = 5');
      await ensureDefaultPlace(h.db);
      final row = await h.db.select(h.db.places).getSingle();
      expect((row.deletedAt, row.archivedAt), (null, null));
    });
  });
}
