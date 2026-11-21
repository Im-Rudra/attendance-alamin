// Every Bhor component renders in light/dark x bn/en at phone and desktop
// widths without exceptions (incl. overflow) and without Material widgets.

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/core/format/lang.dart';

import 'ds_harness.dart';

Widget _sink() {
  const List<BhorNavItem> nav = <BhorNavItem>[
    BhorNavItem(icon: Icons.today_outlined, label: 'আজ'),
    BhorNavItem(icon: Icons.groups_outlined, label: 'ব্যাচ', badge: '৩'),
    BhorNavItem(icon: Icons.person_outline, label: 'শিক্ষার্থী'),
  ];
  return Builder(builder: (BuildContext context) {
    final BhorThemeData b = context.bhor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const BhorHeader(title: 'আজ', subtitle: 'শনিবার, ২১ নভেম্বর', showBack: true),
        Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
          for (final BhorButtonVariant v in BhorButtonVariant.values)
            BhorButton(label: 'বোতাম ${v.name}', variant: v, onPressed: () {}),
          BhorButton(label: 'ছোট', size: BhorButtonSize.sm, icon: Icons.add, onPressed: () {}),
          const BhorButton(label: 'Disabled', onPressed: null, disabledReason: 'কারণ'),
          BhorIconButton(icon: Icons.search, semanticLabel: 'খুঁজুন', badge: '২', onPressed: () {}),
        ]),
        const BhorTextField(label: 'নাম', hint: 'যেমন: রহিম', helper: 'সাহায্য'),
        const BhorTextField(label: 'ফোন', initialValue: '০১৭', error: 'ভুল নম্বর', prefix: Icon(Icons.phone)),
        BhorSelect<int>(
          label: 'ব্যাচ',
          value: 1,
          options: const <BhorOption<int>>[BhorOption<int>(1, 'নবম'), BhorOption<int>(2, 'দশম')],
          onChanged: (_) {},
        ),
        BhorSegmented<int>(
          segments: const <BhorSegment<int>>[BhorSegment<int>(0, 'দিন'), BhorSegment<int>(1, 'সপ্তাহ')],
          value: 1,
          onChanged: (_) {},
        ),
        BhorTabs(tabs: const <String>['শিক্ষার্থী', 'রুটিন', 'বেতন'], index: 0, onChanged: (_) {}),
        Wrap(spacing: 8, children: <Widget>[
          BhorChip(label: 'সব', selected: true, onSelected: (_) {}),
          BhorChip(label: 'বকেয়া', count: '১২', selected: false, onSelected: (_) {}),
          for (final BhorTone t in BhorTone.values) BhorTag(label: t.name, tone: t),
          for (final SeverityLevel l in SeverityLevel.values) BhorTag.severity(level: l, label: l.name),
        ]),
        Row(children: <Widget>[
          BhorSwitch(value: true, onChanged: (_) {}, semanticLabel: 'চালু'),
          const BhorSwitch(value: false, onChanged: null),
          Expanded(child: BhorCheckbox(value: true, onChanged: (_) {}, label: 'সবাই')),
        ]),
        BhorRadioCard<int>(value: 1, groupValue: 1, onChanged: (_) {}, title: 'মাসিক', subtitle: 'প্রতি মাসে'),
        const BhorCard(child: Text('কার্ড')),
        BhorCard.hero(child: Text('হিরো', style: b.type.title.copyWith(color: b.colors.onHero))),
        BhorListRow(
          leading: const BhorAvatar(name: 'রহিম উদ্দিন'),
          title: 'রহিম উদ্দিন',
          subtitle: 'রোল ৩',
          trailing: const BhorTag(label: 'পরিশোধিত', tone: BhorTone.ok),
          onTap: () {},
        ),
        BhorSectionHeader(title: 'আজকের ক্লাস', count: '৩', actionLabel: 'সব', onAction: () {}),
        const BhorProgress(value: 0.6),
        const BhorSkeleton(width: 120),
        const BhorSpinner(),
        BhorEmptyState(
          icon: Icons.groups_outlined,
          title: 'কিছু নেই',
          message: 'প্রথম ব্যাচ যোগ করুন',
          action: BhorButton(label: 'যোগ করুন', onPressed: () {}),
        ),
        BhorAttendanceToggle(value: AttendanceKind.absent, onChanged: (_) {}),
        const BhorEscalationBar(day: 7),
        const BhorEscalationBar(day: 12),
        const BhorMoney(150000),
        const Row(children: <Widget>[
          Expanded(child: BhorStatText(label: 'উপস্থিত', value: '২৪')),
          Expanded(child: BhorStatText.money(label: 'বকেয়া', amount: 4500)),
        ]),
        BhorDatePicker(
          selected: DateTime(2026, 11, 21),
          firstDate: DateTime(2026),
          lastDate: DateTime(2026, 12, 31),
          onChanged: (_) {},
        ),
        BhorTimePicker(value: 16 * 60 + 30, onChanged: (_) {}),
        const BhorSheetFrame(title: 'শিট', child: Text('ভেতরের লেখা')),
        BhorDialog(
          title: 'মুছবেন?',
          message: 'ফেরানো যাবে না',
          actions: <Widget>[BhorButton(label: 'মুছুন', variant: BhorButtonVariant.danger, onPressed: () {})],
        ),
        SizedBox(height: 80, child: BhorBottomNav(items: nav, index: 1, onTap: (_) {})),
        SizedBox(
          height: 300,
          child: Row(children: <Widget>[
            BhorSidebar(brand: 'হাজিরা খাতা', items: nav, index: 0, onTap: (_) {}, onToggleCollapsed: () {}),
            const Expanded(child: SizedBox()),
          ]),
        ),
      ],
    );
  });
}

void main() {
  for (final (Brightness, Lang) c in kDsCases) {
    for (final Size size in const <Size>[Size(360, 4200), Size(1280, 4200)]) {
      testWidgets('all components render [${dsCaseLabel(c)} ${size.width.toInt()}]', (WidgetTester tester) async {
        await pumpDs(tester, _sink(), brightness: c.$1, lang: c.$2, size: size);
        await tester.pump(const Duration(milliseconds: 300));
        expectClean(tester, dsCaseLabel(c));
        expect(find.byType(BhorDatePicker), findsOneWidget);
        expect(find.byType(BhorSidebar), findsOneWidget);
        expect(materialWidgetsIn(tester), isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
        expectClean(tester, 'unmount');
      });
    }
  }

  testWidgets('context.bhor falls back to platform brightness', (WidgetTester tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    late BhorThemeData seen;
    await tester.pumpWidget(MediaQuery.fromView(
      view: tester.view,
      child: Builder(builder: (BuildContext context) {
        seen = context.bhor;
        return const SizedBox();
      }),
    ));
    expect(seen.isDark, isTrue);
  });

  test('type scale uses Hind Siliguri at line height 1.45', () {
    final BhorType t = BhorThemeData.light().type;
    for (final TextStyle s in <TextStyle>[t.display, t.title, t.heading, t.body, t.label, t.meta, t.caption, t.stat]) {
      expect(s.fontFamily, 'HindSiliguri');
      expect(s.height, 1.45);
    }
    expect(t.display.fontSize, 24);
    expect(t.stat.fontFeatures, isNotEmpty);
  });

  test('avatar initials are grapheme-safe', () {
    expect(BhorAvatar.initialsOf('রহিম উদ্দিন'), 'রউ');
    expect(BhorAvatar.initialsOf('Fatema Akter'), 'FA');
    expect(BhorAvatar.initialsOf('  '), '?');
  });
}
