// BhorSelect search (W3-Tuition): more than six options put a filter field at
// the top of the list; it narrows by label and searchText (Bangla or ASCII
// digits), Enter picks the first match, and short lists stay as they were.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/core/format/lang.dart';

import 'ds_harness.dart';

const Size _desktop = Size(1280, 800);

const List<BhorOption<int>> _eight = <BhorOption<int>>[
  BhorOption<int>(1, 'রহিম উদ্দিন', searchText: '01711223344'),
  BhorOption<int>(2, 'করিম হোসেন'),
  BhorOption<int>(3, 'সারা আক্তার'),
  BhorOption<int>(4, 'নীলা বেগম'),
  BhorOption<int>(5, 'Rafi Ahmed'),
  BhorOption<int>(6, 'Mitu Das'),
  BhorOption<int>(7, 'Tania Akter'),
  BhorOption<int>(8, 'Joy Saha'),
];

Widget _select(List<BhorOption<int>> options, ValueChanged<int> onChanged, {bool? searchable}) =>
    BhorSelect<int>(
      label: 'শিক্ষার্থী',
      value: null,
      hint: 'বেছে নিন',
      searchable: searchable,
      options: options,
      onChanged: onChanged,
    );

final Finder _search = find.byKey(const ValueKey<String>('bhor-select-search'));

void main() {
  test('bhorSearchNorm folds case, Bangla digits and spaces', () {
    expect(bhorSearchNorm('  Rafi   AHMED '), 'rafi ahmed');
    expect(bhorSearchNorm('০১৭১১'), '01711');
  });

  for (final Lang lang in Lang.values) {
    testWidgets('more than six options: a filter field narrows the popover [${lang.code}]',
        (WidgetTester tester) async {
      int? picked;
      await pumpDs(tester, _select(_eight, (int v) => picked = v), size: _desktop, lang: lang);
      await tester.tap(find.byType(BhorSelect<int>));
      await tester.pumpAndSettle();
      expect(_search, findsOneWidget);
      expect(find.text('Joy Saha'), findsOneWidget);

      await tester.enterText(_search, 'ra');
      await tester.pumpAndSettle();
      expect(find.text('Rafi Ahmed'), findsOneWidget);
      expect(find.text('Joy Saha'), findsNothing);
      expect(find.text('করিম হোসেন'), findsNothing);

      await tester.tap(find.text('Rafi Ahmed'));
      await tester.pumpAndSettle();
      expect(picked, 5);
      expect(_search, findsNothing);
      expectClean(tester);
    });
  }

  testWidgets('searchText matches, Bangla digits too; Enter picks the first match', (WidgetTester tester) async {
    int? picked;
    await pumpDs(tester, _select(_eight, (int v) => picked = v), size: _desktop);
    await tester.tap(find.byType(BhorSelect<int>));
    await tester.pumpAndSettle();
    await tester.enterText(_search, '০১৭১১');
    await tester.pumpAndSettle();
    expect(find.text('রহিম উদ্দিন'), findsOneWidget);
    expect(find.text('Rafi Ahmed'), findsNothing);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(picked, 1);
  });

  testWidgets('no match says so and picks nothing', (WidgetTester tester) async {
    int? picked;
    await pumpDs(tester, _select(_eight, (int v) => picked = v), size: _desktop);
    await tester.tap(find.byType(BhorSelect<int>));
    await tester.pumpAndSettle();
    await tester.enterText(_search, 'zzz');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('bhor-select-no-match')), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(picked, isNull);
  });

  testWidgets('six or fewer options: no filter field (unchanged)', (WidgetTester tester) async {
    await pumpDs(tester, _select(_eight.take(6).toList(), (_) {}), size: _desktop);
    await tester.tap(find.byType(BhorSelect<int>));
    await tester.pumpAndSettle();
    expect(_search, findsNothing);
    expect(find.text('Mitu Das'), findsOneWidget);
  });

  testWidgets('searchable: true forces the field on a short list', (WidgetTester tester) async {
    await pumpDs(tester, _select(_eight.take(2).toList(), (_) {}, searchable: true), size: _desktop);
    await tester.tap(find.byType(BhorSelect<int>));
    await tester.pumpAndSettle();
    expect(_search, findsOneWidget);
  });

  testWidgets('phone: the sheet list gets the same filter field', (WidgetTester tester) async {
    int? picked;
    await pumpDs(tester, _select(_eight, (int v) => picked = v));
    await tester.tap(find.byType(BhorSelect<int>));
    await tester.pumpAndSettle();
    expect(_search, findsOneWidget);
    await tester.enterText(_search, 'tania');
    await tester.pumpAndSettle();
    expect(find.text('Mitu Das'), findsNothing);
    await tester.tap(find.text('Tania Akter'));
    await tester.pumpAndSettle();
    expect(picked, 7);
    expectClean(tester);
  });
}
