// Screens of Settings & More: the 8-case matrix for every screen plus the
// behaviours that matter (instant save, template preview/reset, custom payment
// methods, reminder switch, diagnostics warning).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/providers/app_prefs_providers.dart';
import 'package:attendance_alamin/app/providers/storage_report.dart';
import 'package:attendance_alamin/app/shell/templates/templates.dart';
import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/core/settings/setting_keys.dart';
import 'package:attendance_alamin/core/templates/default_templates.dart';
import 'package:attendance_alamin/features/settings/ui/diagnostics_screen.dart';
import 'package:attendance_alamin/features/settings/ui/help_screen.dart';
import 'package:attendance_alamin/features/settings/ui/more_screen.dart';
import 'package:attendance_alamin/features/settings/ui/payment_methods_screen.dart';
import 'package:attendance_alamin/features/settings/ui/template_editor_screen.dart';
import 'package:attendance_alamin/features/settings/data/template_logic.dart';
import 'package:attendance_alamin/features/settings/widgets/settings_groups.dart';
import 'package:attendance_alamin/features/settings/widgets/setting_widgets.dart';
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

/// The nav entry of [group] in the settings layout.
Finder _nav(SettingsGroup group) => find.descendant(
      of: find.byKey(BhorSettingsPage.navKey),
      matching: find.text(group.title(_bn)),
    );

/// What the editor shows for stored [text]: variables as readable pills.
String _shown(String text) => toDisplayText(text, <String, String>{
      'student': _bn.setPhStudent,
      'batch': _bn.setPhBatch,
      'months': _bn.setPhMonths,
      'amount': _bn.setPhAmount,
      'center': _bn.setPhCenter,
      'teacher_phone': _bn.setPhTeacherPhone,
      'id': _bn.setPhId,
      'method': _bn.setPhMethod,
      'date': _bn.setPhDate,
      'remaining_line': _bn.setPhRemainingLine,
    });

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
    testWidgets('desktop shows a section nav next to the first section, and switches sections', (tester) async {
      final SeededFakes fakes = seedFakes();
      await pumpApp(tester, const MoreScreen(),
          viewport: TestViewport.desktop, overrides: _overrides(fakes));
      expect(find.byKey(BhorSettingsPage.navKey), findsOneWidget);
      expect(_nav(SettingsGroup.archive), findsOneWidget);
      expect(_nav(SettingsGroup.holidays), findsOneWidget);
      // Opens on the first section (Appearance); no search button of its own (G4).
      expect(find.byKey(const Key('more-language')), findsOneWidget);
      expect(find.byKey(const Key('more-version')), findsNothing);
      expect(find.byIcon(BhorIcons.search), findsNothing);

      await tester.tap(_nav(SettingsGroup.about));
      await tester.pumpAndSettle(); // the pane cross-fades to the next section
      expect(find.byKey(const Key('more-version')), findsOneWidget);
      expect(find.byKey(const Key('more-language')), findsNothing);
    });

    testWidgets('Holidays is its own section; Archive holds archived batches and left students', (tester) async {
      final SeededFakes fakes = seedFakes();
      await pumpApp(tester, const MoreScreen(),
          viewport: TestViewport.desktop, overrides: _overrides(fakes));
      await tester.tap(_nav(SettingsGroup.holidays));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('holiday-run')), findsOneWidget);
      expect(find.byKey(const Key('more-archived')), findsNothing);

      await tester.tap(_nav(SettingsGroup.archive));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('more-archived')), findsOneWidget);
      expect(find.byKey(const Key('more-left')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('holiday-run')), findsNothing);
    });

    testWidgets('a sub-page shows a crumb back to its section, in the same column', (tester) async {
      final SeededFakes fakes = seedFakes();
      await pumpApp(tester, const MoreScreen(),
          viewport: TestViewport.desktop, overrides: _overrides(fakes));
      await tester.tap(_nav(SettingsGroup.archive));
      await tester.pumpAndSettle();
      final Rect section = tester.getRect(find.byKey(BhorSettingsPage.contentKey));
      await tester.tap(find.byKey(const Key('more-archived')));
      await tester.pumpAndSettle();
      expect(find.byKey(BhorSettingsPage.crumbKey), findsOneWidget);
      expect(find.text(_bn.shellTitleArchived), findsWidgets);
      expect(tester.getRect(find.byKey(BhorSettingsPage.contentKey)), section);
      // The nav still highlights Archive: it matches the content.
      expect(_nav(SettingsGroup.archive), findsOneWidget);

      await tester.tap(find.byKey(BhorSettingsPage.crumbKey));
      await tester.pumpAndSettle();
      expect(find.byKey(BhorSettingsPage.crumbKey), findsNothing);
      expect(find.byKey(const Key('more-archived')), findsOneWidget);
    });

    testWidgets('Backup is one UI in the settings column: a primary card, then the rows', (tester) async {
      final SeededFakes fakes = seedFakes();
      await pumpApp(tester, const MoreScreen(),
          viewport: TestViewport.desktop, overrides: _overrides(fakes));
      await tester.tap(_nav(SettingsGroup.backup));
      await tester.pumpAndSettle();
      final Rect card = tester.getRect(find.byKey(const Key('backup-last-card')));
      final Rect button = tester.getRect(find.byKey(const Key('backup-export-button')));
      final Rect restore = tester.getRect(find.byKey(const Key('more-restore')));
      expect(button.top, greaterThanOrEqualTo(card.top));
      expect(button.bottom, lessThanOrEqualTo(card.bottom));
      expect(restore.top, greaterThan(card.bottom));
      expect(find.byKey(const Key('more-safety-copy')), findsOneWidget);
      expect(find.byKey(const Key('more-csv-export')), findsOneWidget);
      expect(find.byKey(const Key('more-backup-reminder')), findsOneWidget);
      expect(find.byKey(const Key('more-device-name')), findsOneWidget);
    });

    testWidgets('Coaching center fields have no hairlines between them (M6)', (tester) async {
      final SeededFakes fakes = seedFakes();
      await pumpApp(tester, const MoreScreen(),
          viewport: TestViewport.desktop, overrides: _overrides(fakes));
      await tester.tap(_nav(SettingsGroup.center));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('more-center-name')), findsOneWidget);
      final SettingsCard card = tester.widget(find.ancestor(
        of: find.byKey(const Key('more-center-name')),
        matching: find.byType(SettingsCard),
      ));
      expect(card.dividers, isFalse);
    });

    testWidgets('the fonts credit expands in place, no dialog (M5)', (tester) async {
      final SeededFakes fakes = seedFakes();
      await pumpApp(tester, const MoreScreen(),
          viewport: TestViewport.desktop, overrides: _overrides(fakes));
      await tester.tap(_nav(SettingsGroup.about));
      await tester.pumpAndSettle();
      expect(find.text(_bn.setFontCreditBody), findsNothing);
      await tester.tap(find.byKey(const Key('more-font-credit')));
      await tester.pumpAndSettle();
      expect(find.text(_bn.setFontCreditBody), findsOneWidget);
      expect(find.byType(BhorDialog), findsNothing);
    });

    testWidgets('the reminders switch saves at once', (tester) async {
      final SeededFakes fakes = seedFakes();
      await pumpApp(tester, const MoreScreen(),
          viewport: TestViewport.desktop, overrides: _overrides(fakes));
      await tester.tap(_nav(SettingsGroup.reminders));
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
      await tester.tap(_nav(SettingsGroup.fees));
      await tester.pump();
      await tester.tap(find.byKey(const Key('more-cutoff-day')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppFormat(Lang.bn).digits('20')));
      await tester.pumpAndSettle();
      expect(await fakes.settings.get(SettingKeys.billingCutoffDay), 20);
    });

    testWidgets('tapping a theme preview tile selects that theme', (tester) async {
      final SeededFakes fakes = seedFakes();
      await pumpApp(tester, const MoreScreen(),
          viewport: TestViewport.desktop, overrides: _overrides(fakes));
      await tester.tap(_nav(SettingsGroup.general));
      await tester.pump();
      final ProviderContainer container = ProviderScope.containerOf(tester.element(find.byType(MoreScreen)));
      await tester.tap(find.byKey(const ValueKey<String>('theme-swatch-dark')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(container.read(themeModeProvider), ThemeMode.dark);
    });

    testWidgets('desktop opens help and templates over the settings layout, not as routes', (tester) async {
      final SeededFakes fakes = seedFakes();
      await pumpApp(tester, const MoreScreen(),
          viewport: TestViewport.desktop, overrides: _overrides(fakes));
      await tester.tap(_nav(SettingsGroup.about));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('more-help')));
      await tester.pumpAndSettle();
      expect(find.byType(HelpScreen), findsOneWidget);
      expect(find.byType(MoreScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(HelpScreen))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(HelpScreen), findsNothing);

      await tester.tap(_nav(SettingsGroup.fees));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('more-template-reminder')));
      await tester.pumpAndSettle();
      expect(find.byType(TemplateEditorScreen), findsOneWidget);
      expect(find.byKey(const Key('template-field')), findsOneWidget);
    });

    testWidgets('reduced effects switch is saved', (tester) async {
      final SeededFakes fakes = seedFakes();
      await pumpApp(tester, const MoreScreen(),
          viewport: TestViewport.desktop, overrides: _overrides(fakes));
      await tester.tap(_nav(SettingsGroup.general));
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
      final BhorTextField field = tester.widget(find.byKey(const Key('template-field')));
      // Variables show as readable pills, never as raw braces (M4).
      expect(field.controller!.text, _shown(DefaultTemplates.reminderBn));
      expect(field.controller!.text, isNot(contains('{')));
      expect(field.controller!.text, contains('[${_bn.setPhStudent}]'));
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
      final BhorTextField field = tester.widget(find.byKey(const Key('template-field')));
      expect(field.controller!.text, '[${_bn.setPhAmount}]বেতন বাকি');
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
      BhorTextField field() => tester.widget(find.byKey(const Key('template-field')));
      expect(field().controller!.text, 'আমার নিজের বার্তা [${_bn.setPhStudent}]');
      expect((tester.widget(find.byKey(const Key('template-preview'))) as Text).data,
          'আমার নিজের বার্তা রাহিম');

      await tester.ensureVisible(find.byKey(const Key('template-reset')));
      await tester.tap(find.byKey(const Key('template-reset')));
      await tester.pump();
      expect(field().controller!.text, _shown(DefaultTemplates.reminderBn));
      expect(await fakes.settings.get(SettingKeys.reminderTemplateBn), '');
      expect(find.text(_bn.setTplResetDone), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
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
      final BhorTextField field = tester.widget(find.byKey(const Key('template-field')));
      expect(field.controller!.text, _shown(DefaultTemplates.receiptEn));
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
      await tester.pumpAndSettle(const Duration(seconds: 5));
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
