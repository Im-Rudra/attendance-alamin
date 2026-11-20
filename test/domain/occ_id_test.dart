import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/domain/schedule/occ_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const uuid = '6f1c2b7e-1d0a-4c55-9b7e-2a4e1f0c9d31';

  test('regular format', () {
    expect(OccId.regular('abc', const LocalDate(2026, 11, 21)), 's.abc.20261121');
  });

  test('extra format', () {
    expect(OccId.extra('abc'), 'x.abc');
  });

  test('regular round-trips a UUID with dashes', () {
    final occ = OccId.regular(uuid, const LocalDate(2026, 2, 3));
    expect(occ, 's.$uuid.20260203');
    final ref = OccId.parse(occ);
    expect(ref, isA<RegularOccRef>());
    final r = ref as RegularOccRef;
    expect(r.slotId, uuid);
    expect(r.originalDate, const LocalDate(2026, 2, 3));
    expect(r, const RegularOccRef(uuid, LocalDate(2026, 2, 3)));
  });

  test('extra round-trips a UUID with dashes', () {
    final ref = OccId.parse(OccId.extra(uuid));
    expect(ref, isA<ExtraOccRef>());
    expect((ref as ExtraOccRef).exceptionId, uuid);
    expect(ref, const ExtraOccRef(uuid));
  });

  test('sealed switch is exhaustive', () {
    String f(OccRef r) => switch (r) {
          RegularOccRef() => 'r',
          ExtraOccRef() => 'x',
        };
    expect(f(OccId.parse('x.q')), 'x');
    expect(f(OccId.parse('s.q.20260101')), 'r');
  });

  for (final bad in [
    '',
    'x.',
    'x',
    's.',
    's..20260101',
    's.abc',
    's.abc.',
    's.abc.2026',
    's.abc.20261301',
    's.abc.20260230',
    's.abc.2026110a',
    'q.abc.20260101',
    'abc',
    'S.abc.20260101',
  ]) {
    test('malformed "$bad" throws FormatException', () {
      expect(() => OccId.parse(bad), throwsFormatException);
    });
  }
}
