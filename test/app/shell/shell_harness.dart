// Minimal pump helper for the shell tests (M5-B's pumpApp is built in
// parallel). Real App + router + theme + l10n; fake settings / local meta.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/app.dart';
import 'package:attendance_alamin/app/providers/app_prefs_providers.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

import '../../helpers/fakes/fake_settings_repos.dart';
import '../../helpers/fixtures.dart';

const Size kPhone = Size(360, 640);
const Size kDesktop = Size(1280, 800);

AppLocalizations l10nOf(Lang lang) => lookupAppLocalizations(Locale(lang.code));

class ShellHarness {
  ShellHarness(this.settings, this.meta);

  final FakeSettingsRepository settings;
  final FakeLocalMetaRepository meta;

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(App)));
}

/// Pumps the whole app at [location] in a [size] window and settles.
Future<ShellHarness> pumpShell(
  WidgetTester tester, {
  String location = Routes.today,
  Size size = kPhone,
  Lang lang = Lang.bn,
  ThemeMode themeMode = ThemeMode.light,
  bool reducedEffects = true,
  FakeSettingsRepository? settings,
  FakeLocalMetaRepository? meta,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  // Feature screens read the M4 repositories: back them with the seeded
  // fakes, keeping the caller's settings / local meta.
  final SeededFakes seed0 = seedFakes();
  final ShellHarness h = ShellHarness(settings ?? seed0.settings, meta ?? seed0.localMeta);
  final SeededFakes seed = SeededFakes(
    store: seed0.store,
    subjects: seed0.subjects,
    batches: seed0.batches,
    schedule: seed0.schedule,
    students: seed0.students,
    enrollments: seed0.enrollments,
    payments: seed0.payments,
    attendance: seed0.attendance,
    otherIncome: seed0.otherIncome,
    settings: h.settings,
    localMeta: h.meta,
  );
  await tester.pumpWidget(
    ProviderScope(
      retry: (int _, Object __) => null,
      overrides: [
        ...seed.overrides,
        initialPrefsProvider.overrideWithValue(AppPrefs(
          lang: lang,
          themeMode: themeMode,
          reducedEffects: reducedEffects,
          onboardingDone: true,
        )),
        initialLocationProvider.overrideWithValue(location),
      ],
      child: const App(),
    ),
  );
  await tester.pumpAndSettle();
  return h;
}
