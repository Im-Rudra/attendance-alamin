// Smoke test. M0-A's hello app was replaced by the real shell in M5-A
// (lib/main.dart -> bootstrap()); this keeps the toolchain checks: gen-l10n in
// both languages, app_info display names, and the app booting to Today.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/app_info.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/features/home/ui/today_screen.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

import 'app/shell/shell_harness.dart';

void main() {
  test('commonAppTitle matches app_info display names', () {
    expect(lookupAppLocalizations(const Locale('bn')).commonAppTitle, kAppDisplayNameBn);
    expect(lookupAppLocalizations(const Locale('en')).commonAppTitle, kAppDisplayNameLatin);
  });

  testWidgets('the app boots to Today in Bangla', (WidgetTester tester) async {
    await pumpShell(tester);
    expect(find.byType(TodayScreen), findsOneWidget);
    expect(find.text(l10nOf(Lang.bn).navToday), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the app boots to Today in English', (WidgetTester tester) async {
    await pumpShell(tester, lang: Lang.en);
    expect(find.text('Today'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
