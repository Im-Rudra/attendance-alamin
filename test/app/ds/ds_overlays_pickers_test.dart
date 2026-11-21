// Sheet / dialog / toast behaviour and the date + time pickers (week start
// Saturday, Bangla digits, period-first time entry).

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

import 'ds_harness.dart';

/// A button that runs [onPressed] with a context under the navigator.
Widget _opener(String label, Future<void> Function(BuildContext context) onPressed) => Builder(
      builder: (BuildContext context) => BhorButton(label: label, onPressed: () => onPressed(context)),
    );

void main() {
  group('BhorSheet', () {
    for (final (Brightness, Lang) c in kDsCases) {
      testWidgets('opens, returns a value, closes [${dsCaseLabel(c)}]', (WidgetTester tester) async {
        String? result = 'unset';
        await pumpDs(
          tester,
          _opener('খুলুন', (BuildContext context) async {
            result = await showBhorSheet<String>(
              context,
              title: 'অন্যান্য আয়',
              builder: (BuildContext ctx) => BhorButton(label: 'বেছে নিন', onPressed: () => Navigator.of(ctx).pop('x')),
            );
          }),
          brightness: c.$1,
          lang: c.$2,
        );
        await tester.tap(find.text('খুলুন'));
        await tester.pumpAndSettle();
        expect(find.text('অন্যান্য আয়'), findsOneWidget);
        expect(materialWidgetsIn(tester), isEmpty);
        await tester.tap(find.text('বেছে নিন'));
        await tester.pumpAndSettle();
        expect(result, 'x');
        expect(find.text('অন্যান্য আয়'), findsNothing);

        await tester.tap(find.text('খুলুন'));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(BhorIcons.close));
        await tester.pumpAndSettle();
        expect(find.text('অন্যান্য আয়'), findsNothing);
        expect(result, isNull);
        expectClean(tester);
      });
    }

    testWidgets('drag down on the handle dismisses', (WidgetTester tester) async {
      await pumpDs(
        tester,
        _opener('খুলুন', (BuildContext context) async {
          await showBhorSheet<void>(context, title: 'শিট', builder: (_) => const SizedBox(height: 200));
        }),
      );
      await tester.tap(find.text('খুলুন'));
      await tester.pumpAndSettle();
      await tester.drag(find.byKey(const ValueKey<String>('bhor-sheet-handle')), const Offset(0, 200));
      await tester.pumpAndSettle();
      expect(find.text('শিট'), findsNothing);
    });
  });

  group('BhorDialog', () {
    testWidgets('confirm returns true, cancel returns false', (WidgetTester tester) async {
      final AppLocalizations l10n = dsL10n(Lang.bn);
      final List<bool> results = <bool>[];
      await pumpDs(
        tester,
        _opener('মুছুন?', (BuildContext context) async {
          results.add(await showBhorConfirm(
            context,
            title: 'ব্যাচ মুছবেন?',
            message: 'ফেরানো যাবে না',
            confirmLabel: 'মুছুন',
            destructive: true,
          ));
        }),
        brightness: Brightness.dark,
      );
      await tester.tap(find.text('মুছুন?'));
      await tester.pumpAndSettle();
      expect(find.text('ব্যাচ মুছবেন?'), findsOneWidget);
      await tester.tap(find.text('মুছুন'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('মুছুন?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.commonCancel));
      await tester.pumpAndSettle();
      expect(results, <bool>[true, false]);
      expectClean(tester);
    });
  });

  group('BhorToast', () {
    for (final (Brightness, Lang) c in kDsCases) {
      testWidgets('auto-dismisses after its duration [${dsCaseLabel(c)}]', (WidgetTester tester) async {
        await pumpDs(
          tester,
          _opener('দেখান', (BuildContext context) async {
            BhorToast.show(context, message: 'সংরক্ষিত হয়েছে', tone: BhorTone.ok, icon: Icons.check);
          }),
          brightness: c.$1,
          lang: c.$2,
        );
        await tester.tap(find.text('দেখান'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        expect(find.text('সংরক্ষিত হয়েছে'), findsOneWidget);
        await tester.pump(const Duration(seconds: 3));
        expect(find.text('সংরক্ষিত হয়েছে'), findsOneWidget);
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();
        expect(find.text('সংরক্ষিত হয়েছে'), findsNothing);
        expectClean(tester);
      });
    }

    testWidgets('action runs and closes; a new toast replaces the old one', (WidgetTester tester) async {
      int undone = 0;
      await pumpDs(
        tester,
        Column(children: <Widget>[
          _opener('এক', (BuildContext context) async {
            BhorToast.show(context, message: 'প্রথম', actionLabel: 'ফেরান', onAction: () => undone++);
          }),
          _opener('দুই', (BuildContext context) async {
            BhorToast.show(context, message: 'দ্বিতীয়', top: true);
          }),
        ]),
      );
      await tester.tap(find.text('এক'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ফেরান'));
      await tester.pumpAndSettle();
      expect(undone, 1);
      expect(find.text('প্রথম'), findsNothing);

      await tester.tap(find.text('এক'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('দুই'));
      await tester.pumpAndSettle();
      expect(find.text('প্রথম'), findsNothing);
      expect(find.text('দ্বিতীয়'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('দ্বিতীয়'), findsNothing);
    });
  });

  group('BhorDatePicker', () {
    Future<DateTime?> pumpPicker(WidgetTester tester, {int weekStart = DateTime.saturday, Lang lang = Lang.bn}) async {
      DateTime? picked;
      await pumpDs(
        tester,
        StatefulBuilder(
          builder: (BuildContext context, StateSetter set) => BhorDatePicker(
            selected: picked ?? DateTime(2026, 11, 21),
            today: DateTime(2026, 11, 21),
            firstDate: DateTime(2026),
            lastDate: DateTime(2026, 12, 31),
            weekStart: weekStart,
            onChanged: (DateTime d) => set(() => picked = d),
          ),
        ),
        lang: lang,
      );
      return picked;
    }

    testWidgets('week starts on Saturday by default, Bangla digits', (WidgetTester tester) async {
      await pumpPicker(tester);
      Text weekday(int i) => tester.widget<Text>(find.byKey(ValueKey<String>('bhor-weekday-$i')));
      expect(weekday(0).data, 'শনি');
      expect(weekday(1).data, 'রবি');
      expect(weekday(6).data, 'শুক্র');
      expect(find.text('নভেম্বর ২০২৬'), findsOneWidget);
      expect(find.text('২১'), findsOneWidget);
      expect(find.text('21'), findsNothing);
      // 1 Nov 2026 is a Sunday: it sits in the second column under রবি.
      expect(tester.getCenter(find.text('১')).dx,
          moreOrLessEquals(tester.getCenter(find.byKey(const ValueKey<String>('bhor-weekday-1'))).dx, epsilon: 1));
      expectClean(tester);
    });

    testWidgets('Sunday start and English digits', (WidgetTester tester) async {
      await pumpPicker(tester, weekStart: DateTime.sunday, lang: Lang.en);
      expect(tester.widget<Text>(find.byKey(const ValueKey<String>('bhor-weekday-0'))).data, 'Sun');
      expect(find.text('21'), findsOneWidget);
      expect(tester.getCenter(find.text('1')).dx,
          moreOrLessEquals(tester.getCenter(find.byKey(const ValueKey<String>('bhor-weekday-0'))).dx, epsilon: 1));
    });

    testWidgets('picking a day and moving months', (WidgetTester tester) async {
      DateTime? picked;
      await pumpDs(
        tester,
        BhorDatePicker(
          selected: DateTime(2026, 11, 21),
          firstDate: DateTime(2026, 11, 5),
          lastDate: DateTime(2026, 12, 31),
          onChanged: (DateTime d) => picked = d,
        ),
      );
      await tester.tap(find.text('২৫'));
      await tester.pump();
      expect(picked, DateTime(2026, 11, 25));
      picked = null;
      await tester.tap(find.text('৪'), warnIfMissed: false);
      await tester.pump();
      expect(picked, isNull, reason: 'before firstDate');
      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      await tester.pumpAndSettle();
      expect(find.text('ডিসেম্বর ২০২৬'), findsOneWidget);
    });

    testWidgets('showBhorDatePicker resolves with the tapped date', (WidgetTester tester) async {
      DateTime? result;
      await pumpDs(
        tester,
        _opener('তারিখ', (BuildContext context) async {
          result = await showBhorDatePicker(
            context,
            initialDate: DateTime(2026, 11, 21),
            firstDate: DateTime(2026),
            lastDate: DateTime(2026, 12, 31),
          );
        }),
        size: const Size(400, 900),
      );
      await tester.tap(find.text('তারিখ'));
      await tester.pumpAndSettle();
      expect(find.text(dsL10n(Lang.bn).dsPickDate), findsOneWidget);
      await tester.tap(find.text('১৮'));
      await tester.pumpAndSettle();
      expect(result, DateTime(2026, 11, 18));
    });
  });

  group('BhorTimePicker', () {
    for (final Lang lang in Lang.values) {
      testWidgets('period first, then hour, then 5-minute step [${lang.code}]', (WidgetTester tester) async {
        final AppLocalizations l10n = dsL10n(lang);
        int? value;
        await pumpDs(
          tester,
          StatefulBuilder(
            builder: (BuildContext context, StateSetter set) =>
                BhorTimePicker(value: value, onChanged: (int v) => set(() => value = v)),
          ),
          lang: lang,
        );
        for (final String p in <String>[
          l10n.dsPeriodDawn,
          l10n.dsPeriodMorning,
          l10n.dsPeriodNoon,
          l10n.dsPeriodAfternoon,
          l10n.dsPeriodEvening,
          l10n.dsPeriodNight,
        ]) {
          expect(find.text(p), findsOneWidget);
        }
        expect(find.byKey(const ValueKey<String>('bhor-hour-16')), findsNothing, reason: 'hours wait for a period');

        await tester.tap(find.text(l10n.dsPeriodAfternoon));
        await tester.pumpAndSettle();
        expect(value, 15 * 60);
        expect(find.byKey(const ValueKey<String>('bhor-hour-12')), findsNothing);
        expect(tester.getCenter(find.text(l10n.dsPeriodAfternoon)).dy,
            lessThan(tester.getCenter(find.byKey(const ValueKey<String>('bhor-hour-16'))).dy));

        await tester.tap(find.byKey(const ValueKey<String>('bhor-hour-16')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey<String>('bhor-minute-30')));
        await tester.pumpAndSettle();
        expect(value, 16 * 60 + 30);
        expect(find.text(lang == Lang.bn ? 'বিকাল ৪:৩০' : '4:30 PM'), findsOneWidget);
        expect(
          find.descendant(of: find.byKey(const ValueKey<String>('bhor-hour-16')), matching: find.text(lang == Lang.bn ? '৪' : '4')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: find.byKey(const ValueKey<String>('bhor-minute-30')), matching: find.text(lang == Lang.bn ? '৩০' : '30')),
          findsOneWidget,
        );

        await tester.tap(find.text(l10n.dsPeriodNight));
        await tester.pumpAndSettle();
        expect(value, 20 * 60 + 30, reason: 'night starts at 8, minutes kept');
        expect(find.byKey(const ValueKey<String>('bhor-hour-0')), findsOneWidget);
        expectClean(tester);
      });
    }

    testWidgets('showBhorTimePicker returns the chosen minutes on Done', (WidgetTester tester) async {
      int? result;
      await pumpDs(
        tester,
        _opener('সময়', (BuildContext context) async {
          result = await showBhorTimePicker(context, initial: 10 * 60);
        }),
        size: const Size(400, 900),
      );
      await tester.tap(find.text('সময়'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('bhor-minute-15')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(dsL10n(Lang.bn).commonDone));
      await tester.pumpAndSettle();
      expect(result, 10 * 60 + 15);
    });
  });
}
