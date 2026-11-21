// Naive-tester round 3 (library level): the first tap after typing fires the
// tapped button, popovers fit a 450 px window with Done visible, the time
// picker applies live, toasts never sit over an opening sheet, share
// feedback, and button labels (no double "+", never truncated).

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/services/share_service.dart';
import 'package:attendance_alamin/core/format/lang.dart';

import 'ds_harness.dart';

Widget _opener(String label, void Function(BuildContext context) onPressed) => Builder(
      builder: (BuildContext context) => BhorButton(label: label, onPressed: () => onPressed(context)),
    );

void main() {
  group('first tap is not swallowed by a focused field', () {
    testWidgets('one tap on a button unfocuses the field and fires the action', (WidgetTester tester) async {
      final FocusNode node = FocusNode();
      addTearDown(node.dispose);
      int taps = 0;
      await pumpDs(
        tester,
        Column(
          children: <Widget>[
            BhorTextField(label: 'নাম', focusNode: node),
            BhorButton(label: 'সেভ', onPressed: () => taps++),
          ],
        ),
        scroll: false,
      );
      await tester.tap(find.byType(BhorTextField));
      await tester.pump();
      expect(node.hasFocus, isTrue);
      await tester.tap(find.text('সেভ'));
      await tester.pump();
      expect(taps, 1, reason: 'the same tap that unfocuses also fires');
      expect(node.hasFocus, isFalse);
    });

    testWidgets('a tap on empty space still unfocuses', (WidgetTester tester) async {
      final FocusNode node = FocusNode();
      addTearDown(node.dispose);
      await pumpDs(
        tester,
        Align(alignment: Alignment.topCenter, child: BhorTextField(label: 'নাম', focusNode: node)),
        scroll: false,
      );
      await tester.tap(find.byType(BhorTextField));
      await tester.pump();
      expect(node.hasFocus, isTrue);
      await tester.tapAt(const Offset(200, 600));
      await tester.pump();
      expect(node.hasFocus, isFalse);
    });
  });

  group('popovers fit a 450 px tall window', () {
    const Size small = Size(1280, 450);

    testWidgets('time picker: Done visible, live apply, Esc keeps the pick', (WidgetTester tester) async {
      int? result;
      final List<int> live = <int>[];
      await pumpDs(
        tester,
        Align(
          alignment: Alignment.centerLeft,
          child: _opener('সময়', (BuildContext c) async {
            result = await showBhorTimePicker(c, initial: 10 * 60, onChanged: live.add);
          }),
        ),
        size: small,
        scroll: false,
      );
      await tester.tap(find.text('সময়'));
      await tester.pumpAndSettle();
      final Finder done = find.text(dsL10n(Lang.bn).commonDone);
      expect(done, findsOneWidget);
      expect(tester.getRect(done).bottom, lessThanOrEqualTo(small.height));
      final Rect pop = tester.getRect(find.byKey(const ValueKey<String>('bhor-popover')));
      expect(pop.top, greaterThanOrEqualTo(0));
      expect(pop.bottom, lessThanOrEqualTo(small.height));
      await tester.tap(find.byKey(const ValueKey<String>('bhor-minute-15')));
      await tester.pumpAndSettle();
      expect(live, <int>[10 * 60 + 15]);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(result, 10 * 60 + 15, reason: 'Esc keeps the current selection');
    });

    testWidgets('date picker: popover stays inside the window', (WidgetTester tester) async {
      await pumpDs(
        tester,
        Align(
          alignment: Alignment.bottomLeft,
          child: _opener('তারিখ', (BuildContext c) {
            showBhorDatePicker(
              c,
              initialDate: DateTime(2026, 11, 21),
              firstDate: DateTime(2026, 1, 1),
              lastDate: DateTime(2027, 1, 1),
            );
          }),
        ),
        size: small,
        scroll: false,
      );
      await tester.tap(find.text('তারিখ'));
      await tester.pumpAndSettle();
      final Rect pop = tester.getRect(find.byKey(const ValueKey<String>('bhor-popover')));
      expect(pop.top, greaterThanOrEqualTo(0));
      expect(pop.bottom, lessThanOrEqualTo(small.height));
    });
  });

  testWidgets('opening a sheet dismisses a visible toast', (WidgetTester tester) async {
    await pumpDs(
      tester,
      _opener('শীট', (BuildContext c) {
        BhorToast.show(c, message: 'সেভ হয়েছে');
        showBhorSheet<void>(c, title: 'ফর্ম', builder: (BuildContext c) => const Text('ভিতরে'));
      }),
    );
    await tester.tap(find.text('শীট'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('সেভ হয়েছে'), findsNothing);
    expect(find.text('ভিতরে'), findsOneWidget);
  });

  group('ShareService reminder feedback', () {
    testWidgets('no phone: says so first, then the copy hint (windows)', (WidgetTester tester) async {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) async => null);
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await pumpDs(
        tester,
        _opener('পাঠান', (BuildContext c) => ShareService.shareText(c, 'hello', hasPhone: false)),
      );
      await tester.tap(find.text('পাঠান'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('এই শিক্ষার্থীর ফোন নম্বর নেই'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text(dsL10n(Lang.bn).shellTextCopied), findsOneWidget);
      expect(dsL10n(Lang.bn).shellTextCopied, contains('WhatsApp'));
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    });
  });

  group('button labels', () {
    testWidgets('a leading "+ " is dropped when an icon is present', (WidgetTester tester) async {
      await pumpDs(
        tester,
        BhorButton(label: '+ নতুন ব্যাচ', icon: BhorIcons.add, onPressed: () {}),
      );
      expect(find.text('নতুন ব্যাচ'), findsOneWidget);
      expect(find.text('+ নতুন ব্যাচ'), findsNothing);
    });

    testWidgets('a long label wraps instead of truncating', (WidgetTester tester) async {
      await pumpDs(
        tester,
        const SizedBox(
          width: 120,
          child: BhorButton(label: 'হাজিরা নিন এখনই শুরু করুন', onPressed: null, expand: true),
        ),
      );
      final Text t = tester.widget<Text>(find.text('হাজিরা নিন এখনই শুরু করুন'));
      expect(t.overflow, isNot(TextOverflow.ellipsis));
      expect(t.maxLines, 2);
    });
  });
}
