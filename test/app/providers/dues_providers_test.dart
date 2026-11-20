import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/providers/dues_providers.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/pump_app.dart';

// Seed on 2026-11-21: Rahim paid Sep+Oct of Physics A (Nov unpaid, due 1 Nov),
// Nila (FBM Nov) paid nothing, Sara paid Physics A Oct+Nov but not Chem B Oct
// (postpaid, due 1 Nov), Karim's first Chem B month (Nov) is only due 1 Dec.
void main() {
  late SeededFakes f;
  late ProviderContainer c;

  setUp(() {
    f = seedFakes();
    c = makeContainer(overrides: f.overrides);
  });

  test('report lists the three students with an open due month', () async {
    final r = await readData(c, duesReportProvider);
    expect(r.active.map((s) => s.studentId).toSet(),
        {kStuRahim, kStuNila, kStuSara});
    expect(r.active.last.studentId, kStuSara); // 800 sorts after the 1000s
    expect(r.inactive, isEmpty);
    expect(r.totalOutstandingActive, 2800);
    expect(r.studentsWithDues, 3);
    expect(r.overdueStudents, 3);
    expect(r.countByLevel[DueLevel.overdue], 3);
  });

  test('studentDuesProvider: per student, null when nothing is open', () async {
    final rahim = await readData(c, studentDuesProvider(kStuRahim));
    expect(rahim?.totalOutstanding, 1000);
    expect(rahim?.worst, DueLevel.overdue);
    expect(rahim?.oldestOpenDue, const YearMonth(2026, 11));

    final sara = await readData(c, studentDuesProvider(kStuSara));
    expect(sara?.totalOutstanding, 800);
    expect(sara?.openMonths, [const YearMonth(2026, 10)]);

    expect(await readData(c, studentDuesProvider(kStuKarim)), isNull);
  });

  test('enrollmentDuesProvider: all months, even with nothing due', () async {
    final karim = await readData(c, enrollmentDuesProvider(kEnrKarimChem));
    expect(karim, isNotNull);
    expect(karim!.openDue, isEmpty);
    expect(karim.months.first.month, const YearMonth(2026, 11));
    expect(karim.months.first.isDue, isFalse); // postpaid: due 1 Dec
    expect(karim.months.length, 13); // Nov 2026 .. Nov 2027 (12 months ahead)

    final rahim = await readData(c, enrollmentDuesProvider(kEnrRahimPhys));
    expect(rahim!.totalOutstanding, 1000);
    expect(rahim.months.first.state, MonthState.paid);

    expect(await readData(c, enrollmentDuesProvider('nope')), isNull);
  });

  test('batchDuesProvider sums the active students of one batch', () async {
    final phys = await readData(c, batchDuesProvider(kBatPhysA));
    expect((phys.count, phys.total, phys.worst), (2, 2000, DueLevel.overdue));

    final chem = await readData(c, batchDuesProvider(kBatChemB));
    expect((chem.count, chem.total, chem.worst), (1, 800, DueLevel.overdue));

    final none = await readData(c, batchDuesProvider('nope'));
    expect(none, const BatchDuesSummary());
  });

  test('recomputes when a payment fact changes', () async {
    expect((await readData(c, duesReportProvider)).studentsWithDues, 3);

    await f.payments.waive(kEnrRahimPhys, const YearMonth(2026, 11));

    final r = await readData(c, duesReportProvider);
    expect(r.studentsWithDues, 2);
    expect(r.totalOutstandingActive, 1800);
    expect(await readData(c, studentDuesProvider(kStuRahim)), isNull);
  });

  test('dues use todayProvider: before the due date nothing is due', () async {
    final early = makeContainer(
        overrides: f.overrides, nowUtc: at('2026-10-20', '10:00').fixedUtc);
    // On 20 Oct: Rahim's Oct is paid, Nila/Karim not enrolled yet, Sara's
    // Chem B Oct is postpaid (due 1 Nov).
    final r = await readData(early, duesReportProvider);
    expect(r.active, isEmpty);
  });
}
