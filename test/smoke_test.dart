import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/app_info.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';
import 'package:attendance_alamin/main.dart';

void main() {
  testWidgets('hello app renders in Bangla', (tester) async {
    await tester.pumpWidget(const HelloApp());
    await tester.pumpAndSettle();

    expect(find.text(kAppDisplayNameBn), findsOneWidget);
    expect(find.text('$kAppDisplayNameBn-এ স্বাগতম'), findsOneWidget);
    expect(find.text(kFontSample), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hello app renders in English', (tester) async {
    await tester.pumpWidget(const HelloApp(initialLocale: Locale('en')));
    await tester.pumpAndSettle();

    expect(find.text(kAppDisplayNameLatin), findsOneWidget);
    expect(find.text('Welcome to $kAppDisplayNameLatin'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('language toggle switches bn -> en -> bn', (tester) async {
    await tester.pumpWidget(const HelloApp());
    await tester.pumpAndSettle();
    expect(find.text(kAppDisplayNameBn), findsOneWidget);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text(kAppDisplayNameLatin), findsOneWidget);
    expect(find.text(kAppDisplayNameBn), findsNothing);

    await tester.tap(find.text('বাংলা'));
    await tester.pumpAndSettle();
    expect(find.text(kAppDisplayNameBn), findsOneWidget);
  });

  test('commonAppTitle matches app_info display names', () {
    expect(lookupAppLocalizations(const Locale('bn')).commonAppTitle, kAppDisplayNameBn);
    expect(lookupAppLocalizations(const Locale('en')).commonAppTitle, kAppDisplayNameLatin);
  });
}
