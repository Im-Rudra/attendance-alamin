// Shared widget-test harness (plan 2.11): pumps a widget under the real theme,
// real localisation, a fixed clock and a ProviderScope with the given
// overrides, and runs the 8-case screen matrix.
//
// It builds its own MaterialApp (no router, no app.dart), so it works for any
// screen or widget. Use the fake repositories from test/helpers/fakes/ (see
// `seedFakes` in fixtures.dart) instead of drift.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/theme/app_theme.dart';
import 'package:attendance_alamin/app/widgets/effects_mode.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/core/time/center_time.dart';
import 'package:attendance_alamin/core/time/clock.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/data/infra_providers.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

/// The two window sizes every screen is checked at (logical px, ratio 1).
enum TestViewport {
  phone(Size(360, 640)),
  desktop(Size(1280, 800));

  const TestViewport(this.size);

  final Size size;
}

/// 2026-11-21 (a Saturday) 10:00 at the center (UTC+6).
final DateTime kTestNowUtc = DateTime.utc(2026, 11, 21, 4);

/// 10:00 center time on [date].
DateTime testNowUtcOn(LocalDate date) => CenterTime.dhaka.toUtc(date, 600);

/// A [FixedClock] at center time [hhmm] ("16:30") on [date] ("2026-11-05").
FixedClock at(String date, String hhmm) {
  final parts = hhmm.split(':');
  final minutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);
  return FixedClock(CenterTime.dhaka.toUtc(LocalDate.parse(date), minutes));
}

/// Overrides every test needs: a fixed clock, and a minute tick that emits once
/// and never schedules a timer (no pending timers at the end of a test).
List<Override> _baseOverrides(DateTime nowUtc) => <Override>[
      clockProvider.overrideWithValue(FixedClock(nowUtc)),
      minuteTickProvider.overrideWith((ref) => Stream<int>.value(
          ref.watch(centerTimeProvider).minutesNow(ref.watch(clockProvider)))),
    ];

/// Pumps [child] inside a ProviderScope and a MaterialApp with the app theme
/// (light and dark both registered, [themeMode] picks), [lang] locale and
/// delegates, a [viewport] sized window and [EffectsMode]. [today] fixes the
/// clock at 10:00 on that date (default 2026-11-21). [overrides] come last
/// and win over the harness's own.
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  ThemeMode themeMode = ThemeMode.light,
  Lang lang = Lang.bn,
  TestViewport viewport = TestViewport.phone,
  List<Override> overrides = const [],
  bool reducedEffects = true,
  LocalDate? today,
}) async {
  tester.view.physicalSize = viewport.size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final nowUtc = today == null ? kTestNowUtc : testNowUtcOn(today);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, __) => null,
      overrides: <Override>[..._baseOverrides(nowUtc), ...overrides],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: themeMode,
        locale: Locale(lang.code),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (BuildContext context, Widget? home) =>
            EffectsMode(reduced: reducedEffects, child: home!),
        home: Builder(
          builder: (BuildContext context) => Material(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: child,
          ),
        ),
      ),
    ),
  );
  // Let fake-repository streams deliver and first frames settle, without
  // waiting for endless animations.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

/// The ProviderContainer of the app pumped by [pumpApp].
ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

/// One cell of the matrix.
class MatrixCase {
  const MatrixCase(this.themeMode, this.lang, this.viewport);

  final ThemeMode themeMode;
  final Lang lang;
  final TestViewport viewport;

  String get label => '${themeMode.name} ${lang.code} ${viewport.name}';
}

/// {light, dark} x {bn, en} x {phone, desktop} (phone only when [phoneOnly]).
List<MatrixCase> matrixCases({bool phoneOnly = false}) => <MatrixCase>[
      for (final v in TestViewport.values)
        if (!phoneOnly || v == TestViewport.phone)
          for (final l in Lang.values)
            for (final m in const [ThemeMode.light, ThemeMode.dark])
              MatrixCase(m, l, v),
    ];

/// Fails when the framework recorded an exception (RenderFlex overflow,
/// build error, failed assertion...) since the last check.
void expectNoException(WidgetTester tester, String when) {
  final Object? e = tester.takeException();
  if (e != null) fail('Exception $when: $e');
}

/// Runs one matrix case: pump, check, [verify], unmount, check. Used by
/// [testScreenMatrix]; exposed for the harness self-test.
Future<void> runMatrixCase(
  WidgetTester tester,
  MatrixCase c,
  Widget Function() build, {
  List<Override> Function()? overrides,
  Future<void> Function(WidgetTester tester)? verify,
}) async {
  await pumpApp(
    tester,
    build(),
    themeMode: c.themeMode,
    lang: c.lang,
    viewport: c.viewport,
    overrides: overrides?.call() ?? const <Override>[],
  );
  expectNoException(tester, 'while pumping (${c.label})');
  if (verify != null) {
    await verify(tester);
    expectNoException(tester, 'in verify (${c.label})');
  }
  // Unmount so providers dispose and no timer outlives the test.
  await tester.pumpWidget(const SizedBox.shrink());
  expectNoException(tester, 'while unmounting (${c.label})');
}

/// Registers 8 widget tests (4 with [phoneOnly]) named "[name] [<case>]":
/// {light, dark} x {bn, en} x {phone 360x640, desktop 1280x800}. Each fails
/// on any exception, including a RenderFlex overflow. [build] and [overrides]
/// are called once per case (fresh fakes every time).
void testScreenMatrix(
  String name,
  Widget Function() build, {
  List<Override> Function()? overrides,
  Future<void> Function(WidgetTester tester)? verify,
  bool phoneOnly = false,
}) {
  for (final c in matrixCases(phoneOnly: phoneOnly)) {
    testWidgets('$name [${c.label}]', (WidgetTester tester) async {
      await runMatrixCase(tester, c, build,
          overrides: overrides, verify: verify);
    });
  }
}

/// A container with a fixed clock (default 2026-11-21 10:00 center time) and
/// the same minute-tick override as [pumpApp]; disposed at test teardown.
/// Use it with `container.listen` / `readData` for provider tests.
ProviderContainer makeContainer({
  List<Override> overrides = const [],
  DateTime? nowUtc,
}) {
  final container = ProviderContainer(
    retry: (_, __) => null,
    overrides: <Override>[..._baseOverrides(nowUtc ?? kTestNowUtc), ...overrides],
  );
  addTearDown(container.dispose);
  return container;
}

/// Lets pending stream events of the (fake) repositories arrive.
Future<void> settle([int turns = 5]) async {
  for (var i = 0; i < turns; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// The current value of an async provider after pending events were delivered;
/// waits (a few turns) while it still loads and rethrows its error. The
/// provider stays listened to until the container is disposed.
Future<T> readData<T>(
  ProviderContainer container,
  ProviderListenable<AsyncValue<T>> provider,
) async {
  final sub = container.listen<AsyncValue<T>>(provider, (_, __) {});
  await settle();
  for (var i = 0; i < 50; i++) {
    final v = sub.read();
    if (v.hasError) {
      Error.throwWithStackTrace(
          v.error!, v.stackTrace ?? StackTrace.current);
    }
    if (v.hasValue) return v.requireValue;
    await Future<void>.delayed(Duration.zero);
  }
  throw StateError('$provider still loading after 50 turns');
}
