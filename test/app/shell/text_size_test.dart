// Text size (feedback item 8): four levels stored on this device, applied app
// wide (OS scale x level, clamped), changed from Appearance or with Ctrl + = /
// Ctrl + - / Ctrl + 0, and nothing clips at the biggest level in Bangla.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/providers/app_prefs_providers.dart';
import 'package:attendance_alamin/app/providers/text_size.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/core/settings/setting_keys.dart';
import 'package:attendance_alamin/data/repositories/settings_providers.dart';

import '../../helpers/fakes/fake_settings_repos.dart';
import '../../helpers/fixtures.dart';
import 'shell_harness.dart';

double _scaleOf(WidgetTester tester) {
  final BuildContext ctx = tester.element(find.byType(BhorToastHost).first);
  return MediaQuery.textScalerOf(ctx).scale(100) / 100;
}

void main() {
  group('levels', () {
    test('factors and codes', () {
      expect(TextSizeLevel.values.map((TextSizeLevel l) => l.factor), <double>[0.9, 1.0, 1.15, 1.3]);
      expect(TextSizeLevel.values.map((TextSizeLevel l) => l.code), <String>['small', 'normal', 'large', 'xlarge']);
      for (final TextSizeLevel l in TextSizeLevel.values) {
        expect(TextSizeLevel.fromCode(l.code), l);
      }
      expect(TextSizeLevel.fromCode('???'), TextSizeLevel.normal);
    });

    test('step stays inside the four levels', () {
      expect(TextSizeLevel.normal.step(1), TextSizeLevel.large);
      expect(TextSizeLevel.normal.step(-1), TextSizeLevel.small);
      expect(TextSizeLevel.xlarge.step(1), TextSizeLevel.xlarge);
      expect(TextSizeLevel.small.step(-1), TextSizeLevel.small);
    });

    test('effective scale is OS scale x factor, clamped at 1.5', () {
      expect(effectiveTextScale(1.0, TextSizeLevel.large), closeTo(1.15, 1e-9));
      expect(effectiveTextScale(1.0, TextSizeLevel.small), closeTo(0.9, 1e-9));
      expect(effectiveTextScale(1.2, TextSizeLevel.xlarge), 1.5);
      expect(effectiveTextScale(1.1, TextSizeLevel.xlarge), closeTo(1.43, 1e-9));
      // An OS scale that is already above the clamp is not shrunk by it.
      expect(effectiveTextScale(1.8, TextSizeLevel.normal), 1.8);
    });
  });

  group('stored on this device', () {
    test('loadAppPrefs reads it, unknown values fall back to Normal', () async {
      final FakeSettingsRepository s = FakeSettingsRepository();
      expect((await loadAppPrefs(s, FakeLocalMetaRepository())).textSize, TextSizeLevel.normal);
      await s.set(SettingKeys.textSize, 'large');
      expect((await loadAppPrefs(s, FakeLocalMetaRepository())).textSize, TextSizeLevel.large);
    });

    test('the controller switches at once, then saves', () async {
      final FakeSettingsRepository settings = FakeSettingsRepository();
      final ProviderContainer c = ProviderContainer(
        retry: (int _, Object __) => null,
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settings),
          initialPrefsProvider.overrideWithValue(const AppPrefs(
            lang: Lang.bn,
            themeMode: ThemeMode.light,
            reducedEffects: true,
            onboardingDone: true,
          )),
        ],
      );
      addTearDown(c.dispose);
      expect(c.read(textSizeProvider), TextSizeLevel.normal);
      await c.read(textSizeProvider.notifier).step(1);
      expect(c.read(textSizeProvider), TextSizeLevel.large);
      expect(await settings.get(SettingKeys.textSize), 'large');
      await c.read(textSizeProvider.notifier).step(1);
      await c.read(textSizeProvider.notifier).step(1);
      expect(c.read(textSizeProvider), TextSizeLevel.xlarge);
      await c.read(textSizeProvider.notifier).reset();
      expect(c.read(textSizeProvider), TextSizeLevel.normal);
      expect(await settings.get(SettingKeys.textSize), 'normal');
    });
  });

  group('applied app wide', () {
    testWidgets('the saved level scales the text under the app', (WidgetTester tester) async {
      await pumpShell(tester, size: kDesktop, textSize: TextSizeLevel.large);
      expect(_scaleOf(tester), closeTo(1.15, 1e-9));
    });

    testWidgets('Ctrl + = / Ctrl + - / Ctrl + 0 change it and save it', (WidgetTester tester) async {
      final ShellHarness h = await pumpShell(tester, size: kDesktop);
      Future<void> ctrl(LogicalKeyboardKey key) async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(key);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
      }

      expect(_scaleOf(tester), 1.0);
      await ctrl(LogicalKeyboardKey.equal);
      expect(_scaleOf(tester), closeTo(1.15, 1e-9));
      expect(await h.settings.get(SettingKeys.textSize), 'large');
      await ctrl(LogicalKeyboardKey.equal);
      await ctrl(LogicalKeyboardKey.equal);
      expect(_scaleOf(tester), closeTo(1.3, 1e-9));
      await ctrl(LogicalKeyboardKey.minus);
      expect(_scaleOf(tester), closeTo(1.15, 1e-9));
      await ctrl(LogicalKeyboardKey.digit0);
      expect(_scaleOf(tester), 1.0);
      expect(await h.settings.get(SettingKeys.textSize), 'normal');
      expect(tester.takeException(), isNull);
    });

    testWidgets('Appearance: the choice changes the whole app', (WidgetTester tester) async {
      final ShellHarness h = await pumpShell(tester, location: Routes.more, size: kDesktop);
      final Finder chips = find.byKey(const Key('more-text-size'));
      expect(chips, findsOneWidget);
      final Finder large = find.descendant(of: chips, matching: find.text(l10nOf(Lang.bn).setTextSizeLarge));
      await tester.ensureVisible(large);
      await tester.pumpAndSettle();
      await tester.tap(large);
      await tester.pumpAndSettle();
      expect(_scaleOf(tester), closeTo(1.15, 1e-9));
      expect(await h.settings.get(SettingKeys.textSize), 'large');
      expect(find.byKey(const Key('more-text-size-preview')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('no clipping at Extra large in Bangla', () {
    final Map<String, String> screens = <String, String>{
      'Today': Routes.today,
      'Batches': Routes.batches,
      'Students': Routes.students,
      'Fees': Routes.fees,
      'More (Appearance)': Routes.more,
      'Roll call': Routes.rollCall(physOcc('2026-11-21')),
    };
    for (final double width in <double>[1214, 910]) {
      for (final MapEntry<String, String> s in screens.entries) {
        testWidgets('${s.key} at ${width.toInt()} wide', (WidgetTester tester) async {
          await pumpShell(
            tester,
            location: s.value,
            size: Size(width, 800),
            lang: Lang.bn,
            textSize: TextSizeLevel.xlarge,
          );
          expect(_scaleOf(tester), closeTo(1.3, 1e-9));
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
