import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/errors/error_codes.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/other_income.dart';
import 'package:flutter_test/flutter_test.dart';

import 'people_harness.dart';

OtherIncome income(String label, int amount, LocalDate paidOn,
        {String? studentId, PaymentMethod method = PaymentMethod.cash}) =>
    OtherIncome(
      id: 'ignored',
      label: label,
      amount: amount,
      paidOn: paidOn,
      method: method,
      studentId: studentId,
      note: ' ',
    );

void main() {
  test('add validates, stamps and watchBetween is inclusive', () async {
    final h = PeopleHarness();
    final s = await h.addStudent('Rahim');
    final id = await h.otherIncome.add(
        income(' Exam fee ', 200, d('2026-11-01'), studentId: s, method: PaymentMethod.custom('Upay')));
    await h.otherIncome.add(income('Book', 150, d('2026-11-30')));
    await h.otherIncome.add(income('Old', 50, d('2026-10-31')));

    expect(id, isNot('ignored'));
    final nov = await h.otherIncome.watchBetween(d('2026-11-01'), d('2026-11-30')).first;
    expect([for (final i in nov) (i.label, i.amount)], [('Exam fee', 200), ('Book', 150)]);
    expect((nov.first.studentId, nov.first.method.code, nov.first.note),
        (s, 'custom:Upay', null));
    final row = (await h.db.select(h.db.otherIncome).get()).first;
    final now = h.stamper.nowMs();
    expect((row.createdAt, row.updatedAt, row.rev, row.deviceId), (now, now, 1, dev));

    await expectLater(h.otherIncome.add(income(' ', 10, d('2026-11-02'))),
        throwsA(isA<ValidationException>().having((e) => e.field, 'field', 'label')));
    await expectLater(h.otherIncome.add(income('X', 0, d('2026-11-02'))),
        throwsCode(ErrorCodes.amountInvalid));
    await expectLater(h.otherIncome.add(income('X', 1000001, d('2026-11-02'))),
        throwsCode(ErrorCodes.amountTooLarge));
    await expectLater(
        h.otherIncome.add(income('X', 10, d('2026-11-02'), studentId: 'ghost')),
        throwsA(isA<NotFoundException>()));
    expect(await h.db.select(h.db.otherIncome).get(), hasLength(3));
  });

  test('softDelete tombstones and hides the row', () async {
    final h = PeopleHarness();
    final id = await h.otherIncome.add(income('Book', 150, d('2026-11-10')));
    h.clock.tick();
    await h.otherIncome.softDelete(id);
    expect(await h.otherIncome.watchBetween(d('2026-11-01'), d('2026-11-30')).first,
        isEmpty);
    final row = await h.db.select(h.db.otherIncome).getSingle();
    expect((row.deletedAt, row.rev, row.updatedAt), (h.stamper.nowMs(), 2, h.stamper.nowMs()));
    await expectLater(h.otherIncome.softDelete(id), throwsA(isA<NotFoundException>()));
  });
}
