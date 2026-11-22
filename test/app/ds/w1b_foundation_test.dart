// W1-B (docs/council/16-windows-rebuild-plan.md): desktop type step at 1200,
// BhorDigits round trip and the digit display in fields, filled (ring-free)
// selected states, one field style, BhorTabs, BhorEmptyState sizes,
// BhorMasonry, the selection style and BhorPickerField.

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/app.dart';
import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/core/format/lang.dart';

import 'ds_harness.dart';

/// The decoration of the first DecoratedBox / Container under [of] whose
/// colour is [color] (null when none).
BoxDecoration? _decoWithColor(WidgetTester tester, Finder of, Color color) {
  for (final Element e in find.descendant(of: of, matching: find.byWidgetPredicate((Widget w) => true)).evaluate()) {
    final Widget w = e.widget;
    Decoration? d;
    if (w is DecoratedBox) d = w.decoration;
    if (w is Container) d = w.decoration;
    if (w is AnimatedContainer) d = w.decoration;
    if (d is BoxDecoration && d.color == color) return d;
  }
  return null;
}

void main() {
  group('desktop type step', () {
    test('BhorType: phone scale below 1200, desktop step from 1200', () {
      final BhorType phone = BhorThemeData.forWidth(Brightness.light, 1199).type;
      final BhorType desk = BhorThemeData.forWidth(Brightness.light, 1200).type;
      expect(phone.desktop, isFalse);
      expect(phone.display.fontSize, 26);
      expect(phone.title.fontSize, 19);
      expect(phone.heading.fontSize, 16);
      expect(phone.body.fontSize, 14.5);
      expect(phone.stat.fontSize, 24);
      expect(desk.desktop, isTrue);
      expect(desk.display.fontSize, 28);
      expect(desk.title.fontSize, 22);
      expect(desk.heading.fontSize, 18);
      expect(desk.body.fontSize, 15);
      expect(desk.stat.fontSize, 30);
      // Never below the Bangla floor.
      expect(desk.meta.fontSize, greaterThanOrEqualTo(12.5));
      // Same colours, cached instances.
      expect(BhorThemeData.of(Brightness.dark, desktop: true).colors, same(BhorThemeData.dark().colors));
      expect(BhorThemeData.forWidth(Brightness.dark, 1600), same(BhorThemeData.of(Brightness.dark, desktop: true)));
      expect(BhorThemeData.light().desktop, isFalse);
    });

    for (final (double width, bool desktop) in <(double, bool)>[(1199, false), (1200, true), (390, false)]) {
      testWidgets('BhorAppRoot picks the step from the window width ($width)', (WidgetTester tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        late BhorThemeData seen;
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(size: Size(width, 800)),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: BhorAppRoot(
                themeMode: ThemeMode.light,
                child: Builder(builder: (BuildContext context) {
                  seen = context.bhor;
                  return const SizedBox.shrink();
                }),
              ),
            ),
          ),
        );
        expect(seen.desktop, desktop);
        expect(seen.type.title.fontSize, desktop ? 22 : 19);
      });
    }
  });

  group('BhorDigits', () {
    test('round trip: ASCII <-> Bangla, lengths kept', () {
      const String ascii = '01712-345678';
      final String bn = BhorDigits.toBangla(ascii);
      expect(bn, '০১৭১২-৩৪৫৬৭৮');
      expect(bn.length, ascii.length);
      expect(BhorDigits.toAscii(bn), ascii);
      expect(BhorDigits.localize('৫০০', bangla: false), '500');
      expect(BhorDigits.localize('500', bangla: true), '৫০০');
      expect(BhorDigits.parseInt('১২৩'), 123);
      expect(BhorDigits.parseInt(' 45 '), 45);
      expect(BhorDigits.parseInt('১২a'), isNull);
      expect(BhorDigits.parseDouble('১২.৫'), 12.5);
    });

    test('ascii formatter stores Bangla digits as ASCII and keeps the caret', () {
      const TextEditingValue typed = TextEditingValue(text: '০৫', selection: TextSelection.collapsed(offset: 2));
      final TextEditingValue out = BhorDigits.asciiFormatter.formatEditUpdate(TextEditingValue.empty, typed);
      expect(out.text, '05');
      expect(out.selection, const TextSelection.collapsed(offset: 2));
    });

    test('number / phone keyboards are the digit fields', () {
      expect(BhorDigits.isNumericKeyboard(TextInputType.number), isTrue);
      expect(BhorDigits.isNumericKeyboard(const TextInputType.numberWithOptions(decimal: true)), isTrue);
      expect(BhorDigits.isNumericKeyboard(TextInputType.phone), isTrue);
      expect(BhorDigits.isNumericKeyboard(TextInputType.text), isFalse);
      expect(BhorDigits.isNumericKeyboard(null), isFalse);
    });

    for (final Lang lang in Lang.values) {
      testWidgets('a phone field shows ${lang.name} digits and keeps ASCII in the controller', (WidgetTester tester) async {
        final TextEditingController ctrl = TextEditingController(text: '05');
        addTearDown(ctrl.dispose);
        String? changed;
        await pumpDs(
          tester,
          BhorTextField(
            label: 'রোল',
            controller: ctrl,
            keyboardType: TextInputType.phone,
            onChanged: (String v) => changed = v,
          ),
          lang: lang,
        );
        final EditableText editable = tester.widget<EditableText>(find.byType(EditableText));
        final TextSpan shown = editable.controller.buildTextSpan(
          context: tester.element(find.byType(EditableText)),
          withComposing: false,
        );
        expect(shown.toPlainText(), lang == Lang.bn ? '০৫' : '05');
        expect(editable.controller.text, '05');

        // Typed Bangla digits land in the caller's controller as ASCII.
        await tester.enterText(find.byType(EditableText), '০১৭১২');
        await tester.pump();
        expect(ctrl.text, '01712');
        expect(changed, '01712');

        // A programmatic change reaches the field.
        ctrl.text = '99';
        await tester.pump();
        expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, '99');
        expectClean(tester);
      });
    }

    testWidgets('a text field does not localise digits', (WidgetTester tester) async {
      final TextEditingController ctrl = TextEditingController(text: 'Class 9');
      addTearDown(ctrl.dispose);
      await pumpDs(tester, BhorTextField(label: 'নাম', controller: ctrl));
      expect(tester.widget<EditableText>(find.byType(EditableText)).controller, same(ctrl));
    });
  });

  group('ring-free selected states, one field style', () {
    testWidgets('segmented thumb is filled, no edge (dark)', (WidgetTester tester) async {
      await pumpDs(
        tester,
        BhorSegmented<int>(
          segments: const <BhorSegment<int>>[BhorSegment<int>(0, 'দিন'), BhorSegment<int>(1, 'সপ্তাহ')],
          value: 0,
          onChanged: (_) {},
        ),
        brightness: Brightness.dark,
      );
      final BhorColors c = BhorThemeData.dark().colors;
      final BoxDecoration? thumb = _decoWithColor(tester, find.byType(BhorSegmented<int>), c.thumb);
      expect(thumb, isNotNull);
      expect(thumb!.border, isNull);
    });

    testWidgets('radio card: selected is the tint + a filled dot, no ring', (WidgetTester tester) async {
      await pumpDs(tester, BhorRadioCard<int>(value: 1, groupValue: 1, onChanged: (_) {}, title: 'মাসিক'));
      await tester.pumpAndSettle();
      final BhorColors c = BhorThemeData.light().colors;
      final BoxDecoration? card = _decoWithColor(tester, find.byType(BhorRadioCard<int>), c.accentTint);
      expect(card, isNotNull);
      expect(card!.border, isNull);
      final BoxDecoration? dot = _decoWithColor(tester, find.byType(BhorRadioCard<int>), c.accentFill);
      expect(dot, isNotNull);
      expect(dot!.border, isNull);
    });

    for (final Brightness br in Brightness.values) {
      testWidgets('attendance thumb is filled with the status colour, no ring [${br.name}]', (WidgetTester tester) async {
        await pumpDs(
          tester,
          Row(children: <Widget>[
            Expanded(child: BhorAttendanceToggle(value: AttendanceKind.absent, onChanged: (_) {})),
          ]),
          brightness: br,
        );
        await tester.pumpAndSettle();
        final BhorColors c = BhorThemeData.of(br).colors;
        final BoxDecoration? thumb = _decoWithColor(tester, find.byType(BhorAttendanceToggle), c.danger);
        expect(thumb, isNotNull);
        expect(thumb!.border, isNull);
        expectClean(tester);
      });
    }

    testWidgets('calendar: today is a filled tint cell, never a ring', (WidgetTester tester) async {
      await pumpDs(
        tester,
        BhorDatePicker(
          selected: DateTime(2026, 11, 21),
          today: DateTime(2026, 11, 10),
          firstDate: DateTime(2026),
          lastDate: DateTime(2026, 12, 31),
          onChanged: (_) {},
        ),
      );
      final BhorColors c = BhorThemeData.light().colors;
      final BoxDecoration? today = _decoWithColor(tester, find.byType(BhorDatePicker), c.accentTint);
      expect(today, isNotNull);
      expect(today!.border, isNull);
      final BoxDecoration? sel = _decoWithColor(tester, find.byType(BhorDatePicker), c.accentFill);
      expect(sel, isNotNull);
    });

    testWidgets('a focused field keeps the soft fill (no white box)', (WidgetTester tester) async {
      await pumpDs(tester, const BhorTextField(label: 'নাম'));
      await tester.tap(find.byType(EditableText));
      await tester.pumpAndSettle();
      final BhorColors c = BhorThemeData.light().colors;
      expect(_decoWithColor(tester, find.byType(BhorTextField), c.surface), isNull);
      expect(_decoWithColor(tester, find.byType(BhorTextField), c.soft), isNotNull);
    });

    testWidgets('read-only field: text3 text and a lock, same soft fill', (WidgetTester tester) async {
      await pumpDs(tester, const BhorTextField(label: 'বিষয়', initialValue: 'গণিত', readOnly: true));
      final BhorColors c = BhorThemeData.light().colors;
      expect(find.byIcon(BhorIcons.lock), findsOneWidget);
      expect(tester.widget<EditableText>(find.byType(EditableText)).style.color, c.text3);
      expect(_decoWithColor(tester, find.byType(BhorTextField), c.soft), isNotNull);
    });

    testWidgets('picker field: the soft field box, taps with its context', (WidgetTester tester) async {
      BuildContext? anchor;
      await pumpDs(
        tester,
        BhorPickerField(label: 'শুরু', value: '৪:০০', icon: BhorIcons.clock, onTap: (BuildContext ctx) => anchor = ctx),
      );
      final BhorColors c = BhorThemeData.light().colors;
      expect(_decoWithColor(tester, find.byType(BhorPickerField), c.soft), isNotNull);
      expect(_decoWithColor(tester, find.byType(BhorPickerField), c.surface), isNull);
      await tester.tap(find.text('৪:০০'));
      await tester.pump();
      expect(anchor, isNotNull);
      expectClean(tester);
    });

    testWidgets('select: opening keeps the soft field (no white, no ring)', (WidgetTester tester) async {
      await pumpDs(
        tester,
        BhorSelect<int>(
          label: 'ব্যাচ',
          value: 1,
          options: const <BhorOption<int>>[BhorOption<int>(1, 'এক'), BhorOption<int>(2, 'দুই')],
          onChanged: (_) {},
        ),
        size: const Size(1280, 800),
      );
      await tester.tap(find.byType(BhorSelect<int>));
      await tester.pumpAndSettle();
      final BhorFocusRing ring = tester.widget<BhorFocusRing>(
          find.descendant(of: find.byType(BhorSelect<int>), matching: find.byType(BhorFocusRing)));
      expect(ring.visible, isFalse);
      final BhorColors c = BhorThemeData.light().colors;
      expect(_decoWithColor(tester, find.byType(BhorSelect<int>), c.surface), isNull);
    });
  });

  group('BhorTabs', () {
    for (final (Brightness, Lang) c in kDsCases) {
      testWidgets('segmented look, the thumb glides to the tapped tab [${dsCaseLabel(c)}]', (WidgetTester tester) async {
        int tab = 0;
        await pumpDs(
          tester,
          StatefulBuilder(
            builder: (BuildContext context, StateSetter set) => BhorTabs(
              tabs: const <String>['শিক্ষার্থী', 'হাজিরা', 'বেতন', 'রুটিন'],
              index: tab,
              onChanged: (int i) => set(() => tab = i),
            ),
          ),
          brightness: c.$1,
          lang: c.$2,
        );
        await tester.pumpAndSettle();
        double thumbLeft() => tester
            .widget<AnimatedPositioned>(find.descendant(of: find.byType(BhorTabs), matching: find.byType(AnimatedPositioned)))
            .left!;
        expect(thumbLeft(), 0);
        await tester.tap(find.text('বেতন'));
        await tester.pumpAndSettle();
        expect(tab, 2);
        expect(thumbLeft(), greaterThan(0));
        final BhorColors col = BhorThemeData.of(c.$1).colors;
        expect(_decoWithColor(tester, find.byType(BhorTabs), col.soft), isNotNull, reason: 'soft track');
        final BoxDecoration? thumb = _decoWithColor(tester, find.byType(BhorTabs), col.thumb);
        expect(thumb, isNotNull);
        expect(thumb!.border, isNull);
        expectClean(tester);
      });
    }

    testWidgets('expand: segments share the width', (WidgetTester tester) async {
      await pumpDs(tester, BhorTabs(tabs: const <String>['এক', 'দুই'], index: 1, expand: true, onChanged: (_) {}));
      await tester.pumpAndSettle();
      final double a = tester.getSize(find.ancestor(of: find.text('এক'), matching: find.byType(BhorPressable)).first).width;
      final double b = tester.getSize(find.ancestor(of: find.text('দুই'), matching: find.byType(BhorPressable)).first).width;
      expect((a - b).abs(), lessThan(1));
      expectClean(tester);
    });
  });

  group('BhorEmptyState sizes', () {
    for (final (BhorEmptySize size, double circle) in <(BhorEmptySize, double)>[
      (BhorEmptySize.compact, 44),
      (BhorEmptySize.regular, 64),
      (BhorEmptySize.page, 88),
    ]) {
      testWidgets('${size.name}: glyph in a ${circle.toInt()} px tinted circle', (WidgetTester tester) async {
        await pumpDs(
          tester,
          BhorEmptyState(
            size: size,
            icon: BhorIcons.batches,
            title: 'এখনো কোনো ব্যাচ নেই',
            message: 'প্রথম ব্যাচ যোগ করুন।',
            action: BhorButton(label: 'যোগ করুন', onPressed: () {}),
          ),
        );
        final Finder glyph = find.ancestor(of: find.byIcon(BhorIcons.batches), matching: find.byType(Container)).first;
        expect(tester.getSize(glyph), Size(circle, circle));
        final BoxDecoration d = tester.widget<Container>(glyph).decoration! as BoxDecoration;
        expect(d.shape, BoxShape.circle);
        expect(find.text('প্রথম ব্যাচ যোগ করুন।'), findsOneWidget);
        expectClean(tester);
      });
    }
  });

  group('BhorMasonry', () {
    test('columns by width: 1 / 2 / 3', () {
      expect(BhorMasonry.columnsFor(360), 1);
      expect(BhorMasonry.columnsFor(700), 2);
      expect(BhorMasonry.columnsFor(1100), 3);
      expect(BhorMasonry.columnsFor(2400), 3);
      expect(BhorMasonry.columnsFor(double.infinity), 1);
    });

    testWidgets('content-sized cards go to the shortest column', (WidgetTester tester) async {
      const Key a = Key('a');
      const Key b = Key('b');
      const Key cc = Key('c');
      await pumpDs(
        tester,
        const BhorMasonry(
          gap: 10,
          minColumnWidth: 200,
          maxColumns: 2,
          children: <Widget>[
            SizedBox(key: a, height: 300),
            SizedBox(key: b, height: 100),
            SizedBox(key: cc, height: 50),
          ],
        ),
        size: const Size(442, 800),
      );
      // 442 - 32 padding = 410 = 2 x 200 + 10.
      expect(tester.getSize(find.byKey(a)), const Size(200, 300));
      final Offset pa = tester.getTopLeft(find.byKey(a));
      final Offset pb = tester.getTopLeft(find.byKey(b));
      final Offset pc = tester.getTopLeft(find.byKey(cc));
      expect(pb.dx - pa.dx, 210);
      expect(pb.dy, pa.dy);
      // c goes under b (the shorter column), not under a.
      expect(pc.dx, pb.dx);
      expect(pc.dy - pb.dy, 110);
      // The masonry is as tall as its tallest column.
      expect(tester.getSize(find.byType(BhorMasonry)).height, 300);
      expectClean(tester);
    });
  });

  group('selection style', () {
    for (final Brightness br in Brightness.values) {
      testWidgets('a selected card: tint fill + 3 px bar, text not dimmed [${br.name}]', (WidgetTester tester) async {
        await pumpDs(
          tester,
          BhorCard(selected: true, onTap: () {}, child: const Text('নবম শ্রেণি')),
          brightness: br,
        );
        await tester.pumpAndSettle();
        final BhorColors c = BhorThemeData.of(br).colors;
        expect(_decoWithColor(tester, find.byType(BhorCard), BhorSelection.fillOn(c, c.surface)), isNotNull);
        final BoxDecoration? bar = _decoWithColor(tester, find.byType(BhorCard), c.accent);
        expect(bar, isNotNull);
        final Finder barBox = find.descendant(of: find.byType(BhorSelectionBar), matching: find.byType(AnimatedContainer));
        expect(tester.getSize(barBox).width, BhorSelection.barWidth);
        // No overlay over the content: the text keeps the theme text colour.
        final RichText text = tester.widget<RichText>(find.descendant(of: find.byType(BhorCard), matching: find.byType(RichText)));
        expect(text.text.style?.color, c.text);
        expectClean(tester);
      });
    }
  });
}
