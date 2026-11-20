import 'package:attendance_alamin/core/ids/ids.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final uuidRe = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );

  group('Ids.v4', () {
    test('has v4 shape and is unique', () {
      final seen = <String>{};
      for (var i = 0; i < 200; i++) {
        final id = Ids.v4();
        expect(uuidRe.hasMatch(id), isTrue, reason: id);
        expect(id[14], '4', reason: 'version nibble of $id');
        expect('89ab'.contains(id[19]), isTrue, reason: 'variant nibble of $id');
        expect(seen.add(id), isTrue);
      }
    });
  });

  group('Ids.v5', () {
    test('matches the RFC 4122 / Python DNS test vector', () {
      // uuid.uuid5(uuid.NAMESPACE_DNS, 'python.org')
      expect(
        Ids.v5In('6ba7b810-9dad-11d1-80b4-00c04fd430c8', 'python.org'),
        '886313e1-3b8a-5372-9b90-0c9aee199e5d',
      );
    });

    // Reference values: Python uuid.uuid5(UUID(Ids.namespace), key).
    const table = <(String, String)>[
      ('', 'f2c0a3d6-b58d-51e1-9cca-f1d6b62814e1'),
      ('a', '7a9fba1d-97a4-509f-a93c-2a5a61c9de7a'),
      ('fee:b1:202611', 'cd1b2aa8-0e58-54c1-ab9b-9a823c699365'),
      ('efee:e1:202611', '184de345-7a98-5274-ade8-bd949f3d8047'),
      ('waive:e1:202611', '325e458a-e26d-53e0-989f-6d276f73b108'),
      ('exc:s.abc.20261121', 'b38bd98b-5fd7-5d57-a5c9-592ebd6d337a'),
      ('ses:s.abc.20261121', '3de3cd6a-d2bf-5b91-b3ea-bc3fdb678c08'),
      ('att:s.abc.20261121:stu1', '08f347b6-c45c-51b4-8fd2-72be8ab77595'),
      ('নাম', '6eab3b18-e2c6-5be4-aed2-939254bbeaec'),
    ];
    for (final (key, expected) in table) {
      test('v5("$key") = $expected', () {
        expect(Ids.v5(key), expected);
        expect(Ids.v5(key), Ids.v5(key));
      });
    }

    test('namespace constant', () {
      expect(Ids.namespace, '6f1c2b7e-1d0a-4c55-9b7e-2a4e1f0c9d31');
    });

    test('shape: version 5, RFC variant', () {
      for (final key in ['x', 'y', 'fee:1:2', 'ফি']) {
        final id = Ids.v5(key);
        expect(uuidRe.hasMatch(id), isTrue);
        expect(id[14], '5');
        expect('89ab'.contains(id[19]), isTrue);
      }
    });

    test('different keys give different ids', () {
      expect(Ids.v5('a'), isNot(Ids.v5('b')));
    });

    test('rejects a malformed namespace', () {
      expect(() => Ids.v5In('not-a-uuid', 'x'), throwsFormatException);
    });
  });

  group('Ids natural-key helpers', () {
    const nov = YearMonth(2026, 11);

    test('batchFee / enrollmentFee / waiver use their key formats', () {
      expect(Ids.batchFee('b1', nov), Ids.v5('fee:b1:202611'));
      expect(Ids.enrollmentFee('e1', nov), Ids.v5('efee:e1:202611'));
      expect(Ids.waiver('e1', nov), Ids.v5('waive:e1:202611'));
      expect(Ids.batchFee('b1', nov), 'cd1b2aa8-0e58-54c1-ab9b-9a823c699365');
    });

    test('occurrence-derived ids use their key formats', () {
      expect(Ids.exceptionForOcc('s.abc.20261121'), Ids.v5('exc:s.abc.20261121'));
      expect(Ids.sessionForOcc('s.abc.20261121'), Ids.v5('ses:s.abc.20261121'));
      expect(
        Ids.record('s.abc.20261121', 'stu1'),
        Ids.v5('att:s.abc.20261121:stu1'),
      );
      expect(
        Ids.record('s.abc.20261121', 'stu1'),
        '08f347b6-c45c-51b4-8fd2-72be8ab77595',
      );
    });

    test('same inputs are deterministic, different inputs differ', () {
      expect(Ids.batchFee('b1', nov), Ids.batchFee('b1', nov));
      expect(Ids.batchFee('b1', nov), isNot(Ids.batchFee('b2', nov)));
      expect(
        Ids.batchFee('b1', nov),
        isNot(Ids.batchFee('b1', const YearMonth(2026, 12))),
      );
      expect(Ids.batchFee('x', nov), isNot(Ids.enrollmentFee('x', nov)));
      expect(Ids.enrollmentFee('x', nov), isNot(Ids.waiver('x', nov)));
      expect(Ids.exceptionForOcc('o'), isNot(Ids.sessionForOcc('o')));
      expect(Ids.record('o', 's1'), isNot(Ids.record('o', 's2')));
      expect(Ids.record('o1', 's'), isNot(Ids.record('o2', 's')));
    });
  });

  group('Ids.fnv1a31', () {
    // Reference: 32-bit FNV-1a over UTF-8 bytes, masked with 0x7FFFFFFF
    // (computed with Python big integers).
    const table = <(String, int)>[
      ('', 18652613),
      ('a', 1678518572), // FNV-1a 32 of "a" is 0xE40C292C
      ('foobar', 1067252072), // FNV-1a 32 of "foobar" is 0xBF9CF968
      ('hello', 1335831723),
      ('x.abc', 1895737013),
      ('rollcall|x', 82916038),
      ('পদার্থ', 932511838),
      (
        's.6f1c2b7e-1d0a-4c55-9b7e-2a4e1f0c9d31.20261121',
        1384253824,
      ),
      (
        's.0b1f6b2a-4c3d-4e5f-8a9b-0c1d2e3f4a5b.20261121',
        491939209,
      ),
    ];
    for (final (input, expected) in table) {
      test('fnv1a31("$input") = $expected', () {
        expect(Ids.fnv1a31(input), expected);
      });
    }

    test('always within 0..0x7FFFFFFF', () {
      for (var i = 0; i < 2000; i++) {
        final v = Ids.fnv1a31('s.slot-$i.2026112${i % 10}');
        expect(v, inInclusiveRange(0, 0x7FFFFFFF));
      }
    });

    test('is deterministic and spreads nearby inputs', () {
      expect(Ids.fnv1a31('x.1'), Ids.fnv1a31('x.1'));
      final seen = <int>{};
      for (var i = 0; i < 500; i++) {
        seen.add(Ids.fnv1a31('x.$i'));
      }
      expect(seen.length, 500);
    });
  });
}
