// Screens of Settings & More: the 8-case matrix for every screen plus the
// behaviours that matter (instant save, template preview/reset, custom payment
// methods, reminder switch, diagnostics warning).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/providers/app_prefs_providers.dart';
import 'package:attendance_alamin/app/providers/storage_report.dart';
import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/core/settings/setting_keys.dart';
import 'package:attendance_alamin/core/templates/default_templates.dart';
import 'package:attendance_alamin/features/settings/ui/diagnostics_screen.dart';
import 'package:attendance_alamin/features/settings/ui/help_screen.dart';
import 'package:attendance_alamin/features/settings/ui/more_screen.dart';
import 'package:attendance_alamin/features/settings/ui/payment_methods_screen.dart';
import 'package:attendance_alamin/features/settings/ui/template_editor_screen.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/pump_app.dart';

AppLocalizations get _bn => lookupAppLocalizations(const Locale('bn'));

const AppPrefs _prefs = AppPrefs(
  lang: Lang.bn,
  themeMode: ThemeMode.light,
  reducedEffects: true,
  onboardingDone: true,
);

List<Override> _overrides(SeededFakes fakes) => <Override>[
      ...fakes.overrides,
      initialPrefsProvider.overrideWithValue(_prefs),
    ];

void main() {
  group('matrix', () {
    testScreenMatrix(
      'MoreScreen',
      () => const MoreScreen(),
      overrides: () => _overrides(seedFakes()),
    );
    testScreenMatrix(
      'TemplateEditorScreen reminder',
      () => const TemplateEditorScreen(kind: 'reminder'),
      overrides: () => _overrides(seedFakes()),
    );
    testScreenMatrix(
      'TemplateEditorScreen receipt',
      () => const TemplateEditorScreen(kind: 'receipt'),
      overrides: () => _overrides(seedFakes()),
    );
    testScreenMatrix(
      'PaymentMethodsScreen',
      () => const PaymentMethodsScreen(),
      overrides: () => _overrides(seedFakes(
        encodedSettings: <String, Object?>{
          'payment_methods': '{"hidden":["rocket"],"custom":["Upay"]}',
        },
      )),
    );
    testScreenMatrix(
      'DiagnosticsScreen',
      () => const DiagnosticsScreen(),
      overrides: () => _overrides(seedFakes()),
    );
    testScreenMatrix(
      'HelpScreen',
      () => const HelpScreen(),
      overrides: () => _overrides(seedFakes()),
    );
  });

  group('More', () {
    testWidgets('desktop shows an index next to the first group, and switches groups', (tester) async {
      final SeededFakes fakes = seedFakes();
      await pumpApp(tester, const MoreScreen(),
          viewport: TestViewport.desktop, overrides: _overrides(fakes));
      expect(find.byKey(const Key('more-index-archive')), findsOneWidget);
      expect(find.byKey(const Key('more-index-about')), findsOneWidget);
      // Opens on the first group.
      expect(find.text(_bn.shellTitleArchived), findsOneWidget);
      expect(find.byKey(const Key('more-version')), findsNothing);

      await tester.tap(find.byKey(const Key('more-index-about')));
      await tester.pump();
      expect(find.byKey(const Key('more-version')), findsOneWidget);
      expect(find.text(_bn.shellTitleArchived), findsNothing);
    });

    testWidgets('the reminders switch saves at once', (tester) async {
      final SeededFakes fakes = seedFakes();
      await pumpApp(tester, const MoreScreen(),
          viewport: TestViewport.desktop, overrides: _overrides(fakes));
      await tester.tap(find.byKey(const Key('more-index-reminders')));
      await tester.pump();
      expect(await fakes.settings.get(SettingKeys.remindersEnabled), isTrue);
      await tester.tap(find.byKey(const Key('more-reminders-switch')));
      await tester.pump();
      expect(await fakes.settings.get(SettingKeys.remindersEnabled), isFalse);
      await tester.pump();
      expect(find.text(_bn.setRemindersOffValue), findsOneWidget);
    });

    testWidgets('the cutoff day is picked in a sheet and saved at once', (tester) async {
      final SeededFakes fakes = seedFakes();
      await pumpApp(tester, const MoreScreen(),
          viewport: TestViewport.desktop, overrides: _overrides(fakes));
      await tester.tap(find.byKey(const Key('more-index-fees')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('more-cutoff-day')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppFormat(Lang.bn).digits('20')));
      await tester.pumpAndSettle();
      expect(await fakes.settings.get(SettingKeys.billingCutoffDay), 20);
    });

    testWidgets('reduced effects switch is saved', (tester) async {
      final SeededFakes fakes = seedFakes();
      await pumpApp(tester, const MoreScreen(),
          viewport: TestViewport.desktop, overrides: _overrides(fakes));
      await tester.tap(find.byKey(const Key('more-index-general')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('more-reduced-effects')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(await fakes.settings.get(SettingKeys.reducedEffects), 'on');
    });
  });

  group('template editor', () {
    testWidgets('shows the default text and a live preview', (tester) async {
      final SeededFakes fakes = seedFakes();
      await pumpApp(tester, const TemplateEditorScreen(kind: 'reminder'),
          overrides: _overrides(fakes));
      final TextField field = tester.widget(find.byKey(const Key('template-field')));
      expect(field.controller!.text, DefaultTemplates.reminderBn);
      final Text preview = tester.widget(find.byKey(const Key('template-preview')));
      expect(preview.data, contains('রাহিম'));
      expect(preview.data, isNot(contains('{')));
    });

    testWidgets('a placeholder chip inserts its field, previews and saves', (tester) async {
      final SeededFakes fakes = seedFakes(
        encodedSettings: <String, Object?>{'reminder_template_bn': 'বেতন বাকি'},
      );
      await pumpApp(tester, const TemplateEditorScreen(kind: 'reminder'),
          overrides: _overrides(fakes));
      await tester.ensureVisible(find.byKey(const Key('chip-amount')));
      await tester.tap(find.byKey(const Key('chip-amount')));
      await tester.pump();
      final TextField field = tester.widget(find.byKey(const Key('template-field')));
      expect(field.controller!.text, '{amount}বেতন বাকি');
      final Text preview = tester.widget(find.byKey(const Key('template-preview')));
      expect(preview.data, '২,০০০বেতন বাকি');
      // Saved by itself after a short pause.
      await tester.pump(const Duration(milliseconds: 700));
      expect(await fakes.settings.get(SettingKeys.reminderTemplateBn), '{amount}বেতন বাকি');
    });

    testWidgets('"ডিফল্টে ফেরান" restores the default and clears the stored text', (tester) async {
      final SeededFakes fakes = seedFakes(
        encodedSettings: <String, Object?>{'reminder_template_bn': 'আমার নিজের বার্তা {student}'},
      );
      await pumpApp(tester, const TemplateEditorScreen(kind: 'reminder'),
          overrides: _overrides(fakes));
      TextField field() => tester.widget(find.byKey(const Key('template-field')));
      expect(field().controller!.text, 'আমার নিজের বার্তা {student}');
      expect((tester.widget(find.byKey(const Key('template-preview'))) as Text).data,
          'আমার নিজের বার্তা রাহিম');

      await tester.ensureVisible(find.byKey(const Key('template-reset')));
      await tester.tap(find.byKey(const Key('template-reset')));
      await tester.pump();
      expect(field().controller!.text, DefaultTemplates.reminderBn);
      expect(await fakes.settings.get(SettingKeys.reminderTemplateBn), '');
      expect(find.text(_bn.setTplResetDone), findsOneWidget);
    });

    testWidgets('an unknown field is flagged', (tester) async {
      final SeededFakes fakes = seedFakes(
        encodedSettings: <String, Object?>{'reminder_template_bn': 'হ্যালো {studnet}'},
      );
      await pumpApp(tester, const TemplateEditorScreen(kind: 'reminder'),
          overrides: _overrides(fakes));
      expect(find.text(_bn.setTplUnknown('{studnet}')), findsOneWidget);
    });

    testWidgets('the English message is edited separately', (tester) async {
      final SeededFakes fakes = seedFakes();
      await pumpApp(tester, const TemplateEditorScreen(kind: 'receipt'),
          overrides: _overrides(fakes));
      await tester.tap(find.text(_bn.shellLangEnglish));
      await tester.pump();
      await tester.pump();
      final TextField field = tester.widget(find.byKey(const Key('template-field')));
      expect(field.controller!.text, DefaultTemplates.receiptEn);
      final Text preview = tester.widget(find.byKey(const Key('template-preview')));
      expect(preview.data, contains('Rahim'));
    });
  });

  group('payment methods', () {
    testWidgets('adds a custom method and saves it as custom:<label>', (tester) async {
      final SeededFakes fakes = seedFakes();
      await pumpApp(tester, const PaymentMethodsScreen(), overrides: _overrides(fakes));
      await tester.ensureVisible(find.byKey(const Key('pm-add-field')));
      await tester.enterText(find.byKey(const Key('pm-add-field')), '  Upay ');
      await tester.ensureVisible(find.byKey(const Key('pm-add-button')));
      await tester.tap(find.byKey(const Key('pm-add-button')));
      await tester.pump();
      await tester.pump();
      expect(fakes.settings.encodedValues['payment_methods'], '{"hidden":[],"custom":["Upay"]}');
      expect(find.byKey(const Key('pm-custom-Upay')), findsOneWidget);
    });

    testWidgets('rejects an empty, a too long and a duplicate name', (tester) async {
      final SeededFakes fakes = seedFakes(
        encodedSettings: <String, Object?>{'payment_methods': '{"hidden":[],"custom":["Upay"]}'},
      );
      await pumpApp(tester, const PaymentMethodsScreen(), overrides: _overrides(fakes));
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pump();

      await tester.tap(find.byKey(const Key('pm-add-button')));
      await tester.pump();
      expect(find.text(_bn.setPmErrEmpty), findsOneWidget);

      await tester.enterText(find.byKey(const Key('pm-add-field')), 'a' * 25);
      await tester.ensureVisible(find.byKey(const Key('pm-add-button')));
      await tester.tap(find.byKey(const Key('pm-add-button')));
      await tester.pump();
      expect(find.text(_bn.setPmErrLong('২০')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('pm-add-field')), 'UPAY');
      await tester.ensureVisible(find.byKey(const Key('pm-add-button')));
      await tester.tap(find.byKey(const Key('pm-add-button')));
      await tester.pump();
      expect(find.text(_bn.setPmErrDuplicate), findsOneWidget);

      await tester.enterText(find.byKey(const Key('pm-add-field')), _bn.setPmCash);
      await tester.ensureVisible(find.byKey(const Key('pm-add-button')));
      await tester.tap(find.byKey(const Key('pm-add-button')));
      await tester.pump();
      expect(find.text(_bn.setPmErrDuplicate), findsOneWidget);

      expect(fakes.settings.encodedValues['payment_methods'], '{"hidden":[],"custom":["Upay"]}');
    });

    testWidgets('hiding a built-in saves the hidden list', (tester) async {
      final SeededFakes fakes = seedFakes();
      await pumpApp(tester, const PaymentMethodsScreen(), overrides: _overrides(fakes));
      await tester.ensureVisible(find.byKey(const Key('pm-rocket')));
      await tester.tap(find.byKey(const Key('pm-rocket')));
      await tester.pump();
      await tester.pump();
      expect(fakes.settings.encodedValues['payment_methods'], '{"hidden":["rocket"],"custom":[]}');
    });
  });

  group('diagnostics', () {
    tearDown(() => webStorageReport.value = null);

    testWidgets('shows the uninstall warning and the storage report', (tester) async {
      webStorageReport.value = const WebStorageInfo('inMemory', <String>['sharedWorkers']);
      final SeededFakes fakes = seedFakes();
      await pumpApp(tester, const DiagnosticsScreen(), overrides: _overrides(fakes));
      expect(find.text(_bn.setDiagUninstallBody), findsOneWidget);
      expect(find.text(_bn.setDiagStorageWebMemory), findsOneWidget);
      expect(find.text(_bn.setDiagMissing('sharedWorkers')), findsOneWidget);
      expect(find.text(_bn.setDiagDeviceNameEmpty), findsOneWidget);
    });

    testWidgets('shows the device name from settings', (tester) async {
      final SeededFakes fakes = seedFakes(
        encodedSettings: <String, Object?>{'device_name': 'আমার ফোন'},
      );
      await pumpApp(tester, const DiagnosticsScreen(), overrides: _overrides(fakes));
      expect(find.text('আমার ফোন'), findsOneWidget);
    });
  });
}
