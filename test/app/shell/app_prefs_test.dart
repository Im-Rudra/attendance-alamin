// Scenarios 16 / 24 (behaviour): language and theme switch instantly without
// a restart and are saved on this device; reduced-effects rules; preload.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/providers/app_prefs_providers.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/core/settings/setting_keys.dart';
import 'package:attendance_alamin/data/repositories/settings_providers.dart';
import 'package:attendance_alamin/features/home/ui/today_screen.dart';

import '../../helpers/fakes/fake_settings_repos.dart';
import 'shell_harness.dart';

void main() {
  group('loadAppPrefs', () {
    test('defaults: Bangla, system theme, effects on, onboarding pending', () async {
      final AppPrefs p = await loadAppPrefs(FakeSettingsRepository(), FakeLocalMetaRepository());
      expect(p.lang, Lang.bn);
      expect(p.themeMode, ThemeMode.system);
      expect(p.reducedEffects, isFalse);
      expect(p.onboardingDone, isFalse);
    });

    test('reads the saved device values', () async {
      final FakeSettingsRepository s = FakeSettingsRepository();
      await s.set(SettingKeys.locale, 'en');
      await s.set(SettingKeys.themeMode, 'dark');
      await s.set(SettingKeys.reducedEffects, 'on');
      await s.set(SettingKeys.onboardingDone, true);
      final AppPrefs p = await loadAppPrefs(s, FakeLocalMetaRepository());
      expect(p.lang, Lang.en);
      expect(p.themeMode, ThemeMode.dark);
      expect(p.reducedEffects, isTrue);
      expect(p.onboardingDone, isTrue);
    });

    test('a remembered slow raster check reduces effects', () async {
      final AppPrefs p = await loadAppPrefs(
        FakeSettingsRepository(),
        FakeLocalMetaRepository(<String, String>{kEffectsRasterMetaKey: 'slow'}),
      );
      expect(p.reducedEffects, isTrue);
    });

    test('theme codes round-trip', () {
      for (final ThemeMode m in ThemeMode.values) {
        expect(themeModeFromCode(themeModeCode(m)), m);
      }
      expect(themeModeFromCode('nonsense'), ThemeMode.system);
    });
  });

  group('reduced effects controller', () {
    late FakeSettingsRepository settings;
    late FakeLocalMetaRepository meta;
    late ProviderContainer c;

    setUp(() {
      settings = FakeSettingsRepository();
      meta = FakeLocalMetaRepository();
      c = ProviderContainer(
        retry: (int _, Object __) => null,
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settings),
          localMetaRepositoryProvider.overrideWithValue(meta),
          initialPrefsProvider.overrideWithValue(const AppPrefs(
            lang: Lang.bn,
            themeMode: ThemeMode.system,
            reducedEffects: false,
            onboardingDone: true,
          )),
        ],
      );
    });
    tearDown(() => c.dispose());

    test('toggle on / auto is saved', () async {
      expect(c.read(reducedEffectsProvider), isFalse);
      await c.read(reducedEffectsProvider.notifier).set(true);
      expect(c.read(reducedEffectsProvider), isTrue);
      expect(await settings.get(SettingKeys.reducedEffects), 'on');
      await c.read(reducedEffectsProvider.notifier).set(false);
      expect(c.read(reducedEffectsProvider), isFalse);
      expect(await settings.get(SettingKeys.reducedEffects), 'auto');
    });

    test('a slow raster check keeps effects reduced in auto mode', () async {
      await c.read(reducedEffectsProvider.notifier).reportRasterCheck(slow: true);
      expect(c.read(reducedEffectsProvider), isTrue);
      expect(meta.values[kEffectsRasterMetaKey], 'slow');
      await c.read(reducedEffectsProvider.notifier).set(false);
      expect(c.read(reducedEffectsProvider), isTrue);
    });

    test('a fast raster check is remembered and changes nothing', () async {
      await c.read(reducedEffectsProvider.notifier).reportRasterCheck(slow: false);
      expect(c.read(reducedEffectsProvider), isFalse);
      expect(meta.values[kEffectsRasterMetaKey], 'ok');
    });
  });

  testWidgets('language switches instantly and is saved', (WidgetTester tester) async {
    final ShellHarness h = await pumpShell(tester);
    expect(find.text(l10nOf(Lang.bn).navToday), findsWidgets);

    await h.container(tester).read(langProvider.notifier).set(Lang.en);
    await tester.pumpAndSettle();
    expect(find.text(l10nOf(Lang.en).navToday), findsWidgets);
    expect(find.text(l10nOf(Lang.bn).navBatches), findsNothing);
    expect(await h.settings.get(SettingKeys.locale), 'en');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the language chip on Today toggles bn <-> en', (WidgetTester tester) async {
    final ShellHarness h = await pumpShell(tester);
    await tester.tap(find.byKey(const Key('language-chip')));
    await tester.pumpAndSettle();
    expect(find.text(l10nOf(Lang.en).navStudents), findsOneWidget);
    await tester.tap(find.byKey(const Key('language-chip')));
    await tester.pumpAndSettle();
    expect(find.text(l10nOf(Lang.bn).navStudents), findsOneWidget);
    expect(await h.settings.get(SettingKeys.locale), 'bn');
  });

  testWidgets('theme switches instantly from the More tab and is saved', (WidgetTester tester) async {
    final ShellHarness h = await pumpShell(tester, location: Routes.more);
    Brightness brightness() => Theme.of(tester.element(find.byType(BhorSegmented<ThemeMode>))).brightness;
    expect(brightness(), Brightness.light);

    await tester.ensureVisible(find.text(l10nOf(Lang.bn).shellThemeDark));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10nOf(Lang.bn).shellThemeDark));
    await tester.pumpAndSettle();
    expect(brightness(), Brightness.dark);
    expect(await h.settings.get(SettingKeys.themeMode), 'dark');

    await tester.ensureVisible(find.text(l10nOf(Lang.bn).shellLangEnglish));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10nOf(Lang.bn).shellLangEnglish));
    await tester.pumpAndSettle();
    expect(find.text(l10nOf(Lang.en).shellAppearance), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('theme and language changes keep the current route', (WidgetTester tester) async {
    final ShellHarness h = await pumpShell(tester, location: Routes.today, size: kDesktop);
    await h.container(tester).read(themeModeProvider.notifier).set(ThemeMode.dark);
    await h.container(tester).read(langProvider.notifier).set(Lang.en);
    await tester.pumpAndSettle();
    expect(find.byType(TodayScreen), findsOneWidget);
    expect(Theme.of(tester.element(find.byType(TodayScreen))).brightness, Brightness.dark);
  });

  testWidgets('reduced effects reaches EffectsMode', (WidgetTester tester) async {
    await pumpShell(tester, reducedEffects: true);
    expect(EffectsMode.reducedOf(tester.element(find.byType(TodayScreen))), isTrue);
  });
}
