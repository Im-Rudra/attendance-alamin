// Self-test of the shared harness (pump_app.dart / fixtures.dart).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/providers/dues_providers.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

import 'fixtures.dart';
import 'pump_app.dart';

/// Reads what the harness provides, so the matrix test can assert on it.
class _Probe extends ConsumerWidget {
  const _Probe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    return Center(
      child: Text(
        '${AppLocalizations.of(context).commonSave} ${today.toIso()} '
        'রহিম উদ্দিন Rahim',
      ),
    );
  }
}

/// A Row wider than its 100 px box: a RenderFlex overflow.
class _Overflowing extends StatelessWidget {
  const _Overflowing();

  @override
  Widget build(BuildContext context) => const Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 100,
          child: Row(children: [SizedBox(width: 300, height: 20)]),
        ),
      );
}

void main() {
  group('trivial widget', () {
    testScreenMatrix('probe', () => const _Probe(), verify: (tester) async {
      expect(find.textContaining('2026-11-21'), findsOneWidget);
      expect(find.textContaining('রহিম উদ্দিন'), findsOneWidget);
    });
  });

  group('phoneOnly', () {
    test('matrix has 8 cases, or 4 on the phone only', () {
      expect(matrixCases(), hasLength(8));
      expect(matrixCases(phoneOnly: true), hasLength(4));
      expect(matrixCases().map((c) => c.label).toSet(), hasLength(8));
    });
  });

  testWidgets('an overflowing widget fails a matrix case', (tester) async {
    await expectLater(
      runMatrixCase(
        tester,
        const MatrixCase(ThemeMode.light, Lang.en, TestViewport.phone),
        () => const _Overflowing(),
      ),
      throwsA(isA<TestFailure>()),
    );
  });

  testWidgets('pumpApp applies theme, locale, viewport and clock', (tester) async {
    late BuildContext captured;
    await pumpApp(
      tester,
      Builder(builder: (context) {
        captured = context;
        return const SizedBox.expand();
      }),
      themeMode: ThemeMode.dark,
      lang: Lang.en,
      viewport: TestViewport.desktop,
      today: const LocalDate(2026, 12, 5),
    );
    expect(Theme.of(captured).brightness, Brightness.dark);
    expect(Localizations.localeOf(captured).languageCode, 'en');
    expect(MediaQuery.sizeOf(captured), TestViewport.desktop.size);
    final container = ProviderScope.containerOf(captured);
    expect(container.read(todayProvider), const LocalDate(2026, 12, 5));
    expectNoException(tester, 'after pumpApp');
  });

  testWidgets('pumpApp wires the seeded fakes through overrides', (tester) async {
    final f = seedFakes();
    await pumpApp(
      tester,
      Consumer(builder: (context, ref, _) {
        final dues = ref.watch(duesReportProvider).value;
        return Text('students with dues: ${dues?.studentsWithDues}');
      }),
      overrides: f.overrides,
    );
    expect(find.text('students with dues: 3'), findsOneWidget);
  });

  test('makeContainer overrides win and provide the fixed clock', () {
    final c = makeContainer(nowUtc: at('2026-11-05', '16:00').fixedUtc);
    expect(c.read(todayProvider), const LocalDate(2026, 11, 5));
    expect(c.read(nowMinutesProvider), 960);
  });

  test('fixtures: seed is consistent', () {
    final f = seedFakes();
    expect(f.store.batches.map((b) => b.id), [kBatPhysA, kBatChemB]);
    expect(f.store.schedules().expand((s) => s.slots), hasLength(5));
    expect(f.enrollments.terms, hasLength(5));
    expect(f.attendance.sessions, hasLength(6));
    expect(f.attendance.records, hasLength(6 + 6 + 4));
    expect(at('2026-11-05', '10:00').fixedUtc, DateTime.utc(2026, 11, 5, 4));
  });
}
