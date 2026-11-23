// A batch fee of 0 ("fee not decided yet") bills nothing: every month is free,
// nothing is due, and a later fee change bills only from its own month.

import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/domain/dues/dues_engine.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/fee_period.dart';
import 'package:flutter_test/flutter_test.dart';

EnrollmentTerms _terms(List<FeePeriod> fees) => EnrollmentTerms(
      enrollmentId: 'e1',
      studentId: 's1',
      batchId: 'b1',
      studentName: 'Rahim',
      batchName: 'Physics A',
      subjectName: 'Physics',
      billing: BillingType.prepaid,
      start: const YearMonth(2026, 9),
      batchFees: fees,
    );

void main() {
  const LocalDate today = LocalDate(2026, 11, 20);

  test('batch fee 0: every month is free and nothing is due', () {
    final EnrollmentDues dues = DuesEngine.forEnrollment(
      terms: _terms(const <FeePeriod>[FeePeriod(effective: YearMonth(2026, 1), amount: 0)]),
      payments: const <PaymentFact>[],
      today: today,
    );
    expect(dues.months, isNotEmpty);
    expect(dues.months.every((MonthDue m) => m.state == MonthState.free), isTrue);
    expect(dues.openDue, isEmpty);
  });

  test('fee set later: only the months from then on are billed', () {
    final EnrollmentDues dues = DuesEngine.forEnrollment(
      terms: _terms(const <FeePeriod>[
        FeePeriod(effective: YearMonth(2026, 1), amount: 0),
        FeePeriod(effective: YearMonth(2026, 11), amount: 1000),
      ]),
      payments: const <PaymentFact>[],
      today: today,
    );
    MonthDue of(YearMonth m) => dues.months.firstWhere((MonthDue x) => x.month == m);
    expect(of(const YearMonth(2026, 10)).state, MonthState.free);
    expect(of(const YearMonth(2026, 11)).state, MonthState.unpaid);
  });
}
