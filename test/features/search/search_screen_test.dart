// SearchScreen in the 8-case screen matrix (light/dark x bn/en x phone/desktop).

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/features/search/controllers/search_providers.dart';
import 'package:attendance_alamin/features/search/ui/search_screen.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/pump_app.dart';

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(
      find.byKey(const ValueKey<String>('search-field')), text);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testScreenMatrix(
    'search: start (no recent searches)',
    () => const SearchScreen(),
    overrides: () => seedFakes().overrides,
    verify: (WidgetTester tester) async {
      expect(find.byKey(const ValueKey<String>('search-field')), findsOneWidget);
    },
  );

  testScreenMatrix(
    'search: recent searches',
    () => const SearchScreen(),
    overrides: () {
      final SeededFakes f = seedFakes();
      unawaited(f.localMeta
          .setRaw(kSearchRecentKey, jsonEncode(<String>['রহিম', '০১৭১'])));
      return f.overrides;
    },
    verify: (WidgetTester tester) async {
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const ValueKey<String>('search-recent-রহিম')),
          findsOneWidget);
      expect(find.byKey(const ValueKey<String>('search-clear-recent')),
          findsOneWidget);
    },
  );

  testScreenMatrix(
    'search: Bangla digits find a student by phone',
    () => const SearchScreen(),
    overrides: () => seedFakes().overrides,
    verify: (WidgetTester tester) async {
      await _type(tester, '০১৭১');
      expect(find.byKey(const ValueKey<String>('search-student-$kStuRahim')),
          findsOneWidget);
      expect(find.byKey(const ValueKey<String>('search-student-$kStuKarim')),
          findsNothing);
    },
  );

  testScreenMatrix(
    'search: ASCII and Bangla digits give the same student',
    () => const SearchScreen(),
    overrides: () => seedFakes().overrides,
    verify: (WidgetTester tester) async {
      await _type(tester, '01733');
      expect(find.byKey(const ValueKey<String>('search-student-$kStuSara')),
          findsOneWidget);
      await _type(tester, '০১৭৩৩');
      expect(find.byKey(const ValueKey<String>('search-student-$kStuSara')),
          findsOneWidget);
    },
  );

  testScreenMatrix(
    'search: batch result',
    () => const SearchScreen(),
    overrides: () => seedFakes().overrides,
    verify: (WidgetTester tester) async {
      await _type(tester, 'ফিজিক্স');
      expect(find.byKey(const ValueKey<String>('search-batch-$kBatPhysA')),
          findsOneWidget);
    },
  );

  testScreenMatrix(
    'search: nothing found',
    () => const SearchScreen(),
    overrides: () => seedFakes().overrides,
    verify: (WidgetTester tester) async {
      await _type(tester, 'zzzzqq');
      expect(find.byType(BhorButton), findsOneWidget);
    },
  );

  testWidgets('Esc with text clears the query (W1-A, G2)',
      (WidgetTester tester) async {
    final SeededFakes f = seedFakes();
    await pumpApp(tester, const SearchScreen(), overrides: f.overrides);
    await _type(tester, 'করিম');
    final Finder editable = find.descendant(
        of: find.byKey(const ValueKey<String>('search-field')),
        matching: find.byType(EditableText));
    expect(tester.widget<EditableText>(editable).controller.text, 'করিম');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(tester.widget<EditableText>(editable).controller.text, isEmpty);
    // Esc away from the field (focus elsewhere) still reaches search.
    await _type(tester, 'রহিম');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(tester.widget<EditableText>(editable).controller.text, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a submitted search is saved in the recent list',
      (WidgetTester tester) async {
    final SeededFakes f = seedFakes();
    await pumpApp(tester, const SearchScreen(), overrides: f.overrides);
    await _type(tester, 'করিম');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(jsonDecode(f.localMeta.values[kSearchRecentKey]!), <String>['করিম']);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
