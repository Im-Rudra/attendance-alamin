import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/errors/error_codes.dart';
import 'package:flutter_test/flutter_test.dart';

import 'structure_fixtures.dart';

Matcher validation(String code) => throwsA(
    isA<ValidationException>().having((e) => e.code, 'code', code));

void main() {
  late Harness h;

  setUp(() => h = Harness());

  group('create', () {
    test('trims, stamps and orders', () async {
      final a = await h.subjects.create(name: '  Physics ', notes: ' n ');
      final b = await h.subjects.create(name: 'Chemistry');
      final ra = await h.subjectRow(a);
      expect(ra.name, 'Physics');
      expect(ra.notes, 'n');
      expect(ra.sortOrder, 0);
      expectInserted(
        createdAt: ra.createdAt,
        updatedAt: ra.updatedAt,
        rev: ra.rev,
        deviceId: ra.deviceId,
        deletedAt: ra.deletedAt,
      );
      expect((await h.subjectRow(b)).sortOrder, 1);
    });

    test('validates the name', () async {
      await expectLater(
          h.subjects.create(name: '   '), validation(ErrorCodes.nameRequired));
      await expectLater(h.subjects.create(name: 'x' * 81),
          validation(ErrorCodes.nameTooLong));
      expect(await h.subjects.watchAll().first, isEmpty);
    });
  });

  group('reads', () {
    test('watchAll lists live subjects in order', () async {
      await h.subjects.create(name: 'Physics');
      final c = await h.subjects.create(name: 'Chemistry');
      await h.subjects.softDelete(c);
      final list = await h.subjects.watchAll().first;
      expect([for (final s in list) s.name], ['Physics']);
    });

    test('findByName ignores case and padding, skips tombstones', () async {
      final id = await h.subjects.create(name: 'Physics');
      expect((await h.subjects.findByName('  pHysics '))?.id, id);
      expect(await h.subjects.findByName('Math'), isNull);
      expect(await h.subjects.findByName('  '), isNull);
      await h.subjects.softDelete(id);
      expect(await h.subjects.findByName('Physics'), isNull);
    });
  });

  group('rename', () {
    test('stamps updatedAt (monotonic) and rev', () async {
      final id = await h.subjects.create(name: 'Physcis');
      h.setNow(DateTime.fromMillisecondsSinceEpoch(t0 + 5000, isUtc: true));
      await h.subjects.rename(id, 'Physics');
      var r = await h.subjectRow(id);
      expect(r.name, 'Physics');
      expect(r.createdAt, t0);
      expect(r.updatedAt, t0 + 5000);
      expect(r.rev, 2);
      expect(r.deviceId, dev);

      // Same clock reading: updatedAt still moves forward by one.
      await h.subjects.rename(id, 'Physics 2');
      r = await h.subjectRow(id);
      expect(r.updatedAt, t0 + 5001);
      expect(r.rev, 3);
    });

    test('validates and requires a live subject', () async {
      final id = await h.subjects.create(name: 'Physics');
      await expectLater(
          h.subjects.rename(id, ''), validation(ErrorCodes.nameRequired));
      await expectLater(
          h.subjects.rename('nope', 'X'),
          throwsA(isA<NotFoundException>()
              .having((e) => e.code, 'code', ErrorCodes.notFound)));
      await h.subjects.softDelete(id);
      await expectLater(
          h.subjects.rename(id, 'X'), throwsA(isA<NotFoundException>()));
    });
  });

  group('softDelete', () {
    test('tombstones the subject, never hard deletes', () async {
      final id = await h.subjects.create(name: 'Physics');
      h.setNow(DateTime.fromMillisecondsSinceEpoch(t0 + 1000, isUtc: true));
      await h.subjects.softDelete(id);
      final r = await h.subjectRow(id);
      expect(r.deletedAt, t0 + 1000);
      expect(r.updatedAt, t0 + 1000);
      expect(r.rev, 2);
      expect(await h.subjects.watchAll().first, isEmpty);
      await expectLater(
          h.subjects.softDelete(id), throwsA(isA<NotFoundException>()));
    });

    test('cascades to batches, slots, exceptions and fees', () async {
      final physics = await h.physicsA();
      final subjectId = (await h.batchRow(physics)).subjectId;
      final occ = 's.${await h.slotId(physics, sat)}.20261121';
      await h.schedule.cancel(occ);

      h.setNow(DateTime.fromMillisecondsSinceEpoch(t0 + 9000, isUtc: true));
      await h.subjects.softDelete(subjectId);

      final b = await h.batchRow(physics);
      expect(b.deletedAt, t0 + 9000);
      expect(b.rev, 2);
      for (final s in await h.slotRows(physics)) {
        expect(s.deletedAt, t0 + 9000);
        expect(s.rev, 2);
      }
      for (final e in await h.exceptionRows(physics)) {
        expect(e.deletedAt, t0 + 9000);
      }
      final fees = await (h.db.select(h.db.batchFees)).get();
      expect(fees.every((f) => f.deletedAt != null), isTrue);
      expect(await h.batches.getById(physics), isNull);
      expect(await h.loaded(), isEmpty);
    });
  });
}
