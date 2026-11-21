// Interaction tests for Bhor controls: buttons, text field, select,
// segmented, chip, switch, checkbox, radio card, tabs, navigation,
// attendance toggle, escalation bar, money.

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

import 'ds_harness.dart';

void main() {
  group('BhorButton', () {
    for (final (Brightness, Lang) c in kDsCases) {
      testWidgets('press, disabled and loading [${dsCaseLabel(c)}]', (WidgetTester tester) async {
        int taps = 0;
        await pumpDs(
          tester,
          Column(children: <Widget>[
            BhorButton(label: 'সংরক্ষণ', onPressed: () => taps++),
            const BhorButton(label: 'নিষ্ক্রিয়', onPressed: null, disabledReason: 'আগে ব্যাচ বেছে নিন'),
            BhorButton(label: 'চলছে', loading: true, onPressed: () => taps += 100),
          ]),
          brightness: c.$1,
          lang: c.$2,
        );
        await tester.tap(find.text('সংরক্ষণ'));
        await tester.pump(const Duration(milliseconds: 200));
        expect(taps, 1);
        await tester.tap(find.text('নিষ্ক্রিয়'), warnIfMissed: false);
        await tester.tap(find.text('চলছে'), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 200));
        expect(taps, 1);
        expect(find.byType(BhorSpinner), findsOneWidget);
        expectClean(tester);
      });
    }

    testWidgets('keyboard: Tab shows the focus ring, Enter activates', (WidgetTester tester) async {
      int taps = 0;
      await pumpDs(tester, BhorButton(label: 'ঠিক আছে', onPressed: () => taps++));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final BhorFocusRing ring = tester.widget<BhorFocusRing>(
          find.descendant(of: find.byType(BhorButton), matching: find.byType(BhorFocusRing)));
      expect(ring.visible, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 200));
      expect(taps, 1);
    });

    testWidgets('icon button and buttons keep a 44px target', (WidgetTester tester) async {
      await pumpDs(
        tester,
        Row(children: <Widget>[
          BhorIconButton(icon: Icons.search, semanticLabel: 'খুঁজুন', onPressed: () {}),
          BhorButton(label: 'ক', onPressed: () {}),
        ]),
      );
      expect(tester.getSize(find.byType(BhorIconButton)).height, greaterThanOrEqualTo(44));
      expect(tester.getSize(find.byType(BhorButton)).height, greaterThanOrEqualTo(44));
      expect(tester.getSize(find.byType(BhorButton)).width, greaterThanOrEqualTo(44));
    });

    testWidgets('icon button exposes its semantics label', (WidgetTester tester) async {
      final SemanticsHandle h = tester.ensureSemantics();
      await pumpDs(tester, BhorIconButton(icon: Icons.search, semanticLabel: 'খুঁজুন', onPressed: () {}));
      expect(find.bySemanticsLabel('খুঁজুন'), findsWidgets);
      h.dispose();
    });
  });

  group('BhorTextField', () {
    for (final (Brightness, Lang) c in kDsCases) {
      testWidgets('focus, typing Bangla, error [${dsCaseLabel(c)}]', (WidgetTester tester) async {
        final TextEditingController ctrl = TextEditingController();
        addTearDown(ctrl.dispose);
        String? changed;
        await pumpDs(
          tester,
          Column(children: <Widget>[
            BhorTextField(label: 'নাম', hint: 'যেমন: রহিম', controller: ctrl, onChanged: (String v) => changed = v),
            const SizedBox(height: 16),
            const BhorTextField(label: 'ফোন', initialValue: '০১৭', error: 'ভুল নম্বর'),
          ]),
          brightness: c.$1,
          lang: c.$2,
        );
        expect(find.text('যেমন: রহিম'), findsOneWidget);
        await tester.tap(find.byType(EditableText).first);
        await tester.pump();
        final EditableTextState s = tester.state<EditableTextState>(find.byType(EditableText).first);
        expect(s.widget.focusNode.hasFocus, isTrue);
        final BhorFocusRing ring =
            tester.widget<BhorFocusRing>(find.descendant(of: find.byType(BhorTextField).first, matching: find.byType(BhorFocusRing)));
        expect(ring.visible, isTrue);

        await tester.enterText(find.byType(BhorTextField).first, 'রহিম উদ্দিন');
        await tester.pump();
        expect(changed, 'রহিম উদ্দিন');
        expect(ctrl.text, 'রহিম উদ্দিন');
        expect(find.text('যেমন: রহিম'), findsNothing, reason: 'hint hides once there is text');

        expect(find.text('ভুল নম্বর'), findsOneWidget);
        expectClean(tester);
      });
    }

    testWidgets('disabled field does not take focus', (WidgetTester tester) async {
      await pumpDs(tester, const BhorTextField(label: 'নাম', initialValue: 'ক', enabled: false));
      await tester.tap(find.byType(EditableText));
      await tester.pump();
      expect(tester.state<EditableTextState>(find.byType(EditableText)).widget.readOnly, isTrue);
    });
  });

  group('BhorSelect', () {
    for (final (Brightness, Lang) c in kDsCases) {
      testWidgets('opens on the overlay and chooses [${dsCaseLabel(c)}]', (WidgetTester tester) async {
        int? value = 1;
        await pumpDs(
          tester,
          StatefulBuilder(
            builder: (BuildContext context, StateSetter set) => BhorSelect<int>(
              label: 'ব্যাচ',
              value: value,
              options: const <BhorOption<int>>[
                BhorOption<int>(1, 'নবম শ্রেণি'),
                BhorOption<int>(2, 'দশম শ্রেণি'),
                BhorOption<int>(3, 'এসএসসি'),
              ],
              onChanged: (int v) => set(() => value = v),
            ),
          ),
          brightness: c.$1,
          lang: c.$2,
        );
        expect(find.text('দশম শ্রেণি'), findsNothing);
        await tester.tap(find.byType(BhorSelect<int>));
        await tester.pumpAndSettle();
        expect(find.text('দশম শ্রেণি'), findsOneWidget);
        expect(find.text('নবম শ্রেণি'), findsNWidgets(2));
        await tester.tap(find.text('দশম শ্রেণি'));
        await tester.pumpAndSettle();
        expect(value, 2);
        expect(find.text('নবম শ্রেণি'), findsNothing);
        expect(find.text('দশম শ্রেণি'), findsOneWidget);
        expectClean(tester);
      });
    }

    testWidgets('tapping outside closes without a change', (WidgetTester tester) async {
      int changes = 0;
      await pumpDs(
        tester,
        BhorSelect<int>(
          value: 1,
          semanticLabel: 'ব্যাচ',
          options: const <BhorOption<int>>[BhorOption<int>(1, 'এক'), BhorOption<int>(2, 'দুই')],
          onChanged: (_) => changes++,
        ),
      );
      await tester.tap(find.byType(BhorSelect<int>));
      await tester.pumpAndSettle();
      expect(find.text('দুই'), findsOneWidget);
      await tester.tapAt(const Offset(390, 790));
      await tester.pumpAndSettle();
      expect(find.text('দুই'), findsNothing);
      expect(changes, 0);
    });
  });

  testWidgets('BhorSegmented changes value', (WidgetTester tester) async {
    int value = 0;
    await pumpDs(
      tester,
      StatefulBuilder(
        builder: (BuildContext context, StateSetter set) => BhorSegmented<int>(
          segments: const <BhorSegment<int>>[
            BhorSegment<int>(0, 'দিন'),
            BhorSegment<int>(1, 'সপ্তাহ'),
            BhorSegment<int>(2, 'মাস'),
          ],
          value: value,
          onChanged: (int v) => set(() => value = v),
        ),
      ),
    );
    await tester.tap(find.text('মাস'));
    await tester.pumpAndSettle();
    expect(value, 2);
    await tester.tap(find.text('সপ্তাহ'));
    await tester.pumpAndSettle();
    expect(value, 1);
    expectClean(tester);
  });

  testWidgets('BhorChip, BhorSwitch, BhorCheckbox and BhorRadioCard toggle', (WidgetTester tester) async {
    bool chip = false;
    bool sw = false;
    bool box = false;
    int radio = 1;
    await pumpDs(
      tester,
      StatefulBuilder(
        builder: (BuildContext context, StateSetter set) => Column(children: <Widget>[
          BhorChip(label: 'বকেয়া', selected: chip, onSelected: (bool v) => set(() => chip = v)),
          BhorSwitch(value: sw, semanticLabel: 'রিমাইন্ডার', onChanged: (bool v) => set(() => sw = v)),
          BhorCheckbox(value: box, label: 'সবাই', onChanged: (bool v) => set(() => box = v)),
          BhorRadioCard<int>(value: 1, groupValue: radio, title: 'মাসিক', onChanged: (int v) => set(() => radio = v)),
          BhorRadioCard<int>(value: 2, groupValue: radio, title: 'কোর্স', onChanged: (int v) => set(() => radio = v)),
          const BhorSwitch(value: false, onChanged: null, semanticLabel: 'বন্ধ'),
        ]),
      ),
    );
    await tester.tap(find.text('বকেয়া'));
    await tester.tap(find.byType(BhorSwitch).first);
    await tester.tap(find.text('সবাই'));
    await tester.tap(find.text('কোর্স'));
    await tester.pumpAndSettle();
    expect(chip, isTrue);
    expect(sw, isTrue);
    expect(box, isTrue);
    expect(radio, 2);
    await tester.tap(find.byType(BhorSwitch).first);
    await tester.tap(find.text('সবাই'));
    await tester.tap(find.byType(BhorSwitch).last, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(sw, isFalse);
    expect(box, isFalse);
    expectClean(tester);
  });

  testWidgets('BhorTabs, BhorBottomNav and BhorSidebar report taps', (WidgetTester tester) async {
    int tab = 0;
    int nav = 0;
    int side = 0;
    int toggles = 0;
    const List<BhorNavItem> items = <BhorNavItem>[
      BhorNavItem(icon: Icons.today_outlined, label: 'আজ'),
      BhorNavItem(icon: Icons.groups_outlined, label: 'ব্যাচ', badge: '৩'),
    ];
    await pumpDs(
      tester,
      StatefulBuilder(
        builder: (BuildContext context, StateSetter set) => Column(children: <Widget>[
          BhorTabs(tabs: const <String>['এক', 'দুই'], index: tab, onChanged: (int i) => set(() => tab = i)),
          BhorBottomNav(items: items, index: nav, onTap: (int i) => set(() => nav = i)),
          SizedBox(
            height: 300,
            child: Row(children: <Widget>[
              BhorSidebar(
                brand: 'হাজিরা',
                items: items,
                index: side,
                onTap: (int i) => set(() => side = i),
                onToggleCollapsed: () => toggles++,
                toggleLabel: 'ভাঁজ',
              ),
            ]),
          ),
        ]),
      ),
      size: const Size(800, 800),
    );
    await tester.tap(find.text('দুই'));
    await tester.tap(find.descendant(of: find.byType(BhorBottomNav), matching: find.text('ব্যাচ')));
    await tester.tap(find.descendant(of: find.byType(BhorSidebar), matching: find.text('ব্যাচ')));
    await tester.tap(find.byIcon(Icons.keyboard_double_arrow_left_rounded));
    await tester.pumpAndSettle();
    expect(tab, 1);
    expect(nav, 1);
    expect(side, 1);
    expect(toggles, 1);
    expectClean(tester);
  });

  testWidgets('BhorSidebar collapses to 72 wide', (WidgetTester tester) async {
    const List<BhorNavItem> items = <BhorNavItem>[BhorNavItem(icon: Icons.today_outlined, label: 'আজ')];
    await pumpDs(
      tester,
      SizedBox(
        height: 300,
        child: Row(children: <Widget>[
          BhorSidebar(brand: 'হাজিরা', items: items, index: 0, onTap: (_) {}, collapsed: true),
        ]),
      ),
      size: const Size(1280, 800),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(BhorSidebar)).width, BhorSidebar.collapsedWidth);
    expect(find.text('আজ'), findsNothing);
  });

  testWidgets('BhorHeader back button pops the route', (WidgetTester tester) async {
    await pumpDs(
      tester,
      Builder(
        builder: (BuildContext context) => BhorButton(
          label: 'খুলুন',
          onPressed: () => Navigator.of(context).push(PageRouteBuilder<void>(
            pageBuilder: (BuildContext c, Animation<double> a, Animation<double> s) =>
                const BhorScaffold(header: BhorHeader(title: 'দ্বিতীয় পাতা'), body: SizedBox()),
          )),
        ),
      ),
    );
    await tester.tap(find.text('খুলুন'));
    await tester.pumpAndSettle();
    expect(find.text('দ্বিতীয় পাতা'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.text('দ্বিতীয় পাতা'), findsNothing);
  });

  for (final Lang lang in Lang.values) {
    testWidgets('BhorAttendanceToggle switches status [${lang.code}]', (WidgetTester tester) async {
      final AppLocalizations l10n = dsL10n(lang);
      AttendanceKind value = AttendanceKind.present;
      await pumpDs(
        tester,
        StatefulBuilder(
          builder: (BuildContext context, StateSetter set) =>
              BhorAttendanceToggle(value: value, onChanged: (AttendanceKind k) => set(() => value = k)),
        ),
        lang: lang,
        brightness: Brightness.dark,
      );
      expect(find.text(l10n.uiAttPresent), findsOneWidget);
      await tester.tap(find.text(l10n.uiAttLate));
      await tester.pumpAndSettle();
      expect(value, AttendanceKind.late);
      await tester.tap(find.text(l10n.uiAttAbsent));
      await tester.pumpAndSettle();
      expect(value, AttendanceKind.absent);
    });
  }

  testWidgets('BhorEscalationBar announces the day; BhorMoney uses ৳ + thin space', (WidgetTester tester) async {
    final SemanticsHandle h = tester.ensureSemantics();
    final AppLocalizations l10n = dsL10n(Lang.bn);
    await pumpDs(
      tester,
      const Column(children: <Widget>[
        BhorEscalationBar(day: 7),
        BhorEscalationBar(day: 13),
        BhorMoney(150000),
      ]),
    );
    expect(find.bySemanticsLabel(l10n.a11yEscalationDay('৭')), findsOneWidget);
    expect(find.bySemanticsLabel(l10n.uiEscalationBeyond), findsOneWidget);
    expect(find.text('৳ ১,৫০,০০০', findRichText: true), findsOneWidget);
    h.dispose();
  });
}
