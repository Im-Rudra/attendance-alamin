// Developer gallery of every Bhor component, in light / dark / both themes
// and at phone (360) / desktop (1024) / fit widths. Hidden route
// `/more/design-system` (long-press the version row in More › Diagnostics).
// Demo labels are sample content, not product copy.

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/core/format/app_format.dart';

enum _ThemePick { light, dark, both }

enum _WidthPick { phone, desktop, fit }

class DsGalleryScreen extends StatefulWidget {
  const DsGalleryScreen({super.key, this.initialTheme = 0, this.initialWidth = 2});

  /// 0 light, 1 dark, 2 both.
  final int initialTheme;

  /// 0 phone, 1 desktop, 2 fit.
  final int initialWidth;

  @override
  State<DsGalleryScreen> createState() => _DsGalleryScreenState();
}

class _DsGalleryScreenState extends State<DsGalleryScreen> {
  late _ThemePick _theme = _ThemePick.values[widget.initialTheme];
  late _WidthPick _width = _WidthPick.values[widget.initialWidth];
  final _DemoState _demo = _DemoState();

  @override
  void dispose() {
    _demo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BhorThemeData chrome = _theme == _ThemePick.dark ? BhorThemeData.dark() : BhorThemeData.light();
    return BhorTheme(
      data: chrome,
      child: BhorScaffold(
        header: BhorHeader(title: context.l10n.dsGalleryTitle, subtitle: 'ভোর · Bhor', divider: true),
        body: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints box) {
            final double avail = box.maxWidth - 32;
            final double w = switch (_width) {
              _WidthPick.phone => 360,
              _WidthPick.desktop => 1024,
              _WidthPick.fit => _theme == _ThemePick.both && avail >= 900 ? (avail - 16) / 2 : avail,
            };
            final List<BhorThemeData> themes = switch (_theme) {
              _ThemePick.light => <BhorThemeData>[BhorThemeData.light()],
              _ThemePick.dark => <BhorThemeData>[BhorThemeData.dark()],
              _ThemePick.both => <BhorThemeData>[BhorThemeData.light(), BhorThemeData.dark()],
            };
            final bool sideBySide = themes.length == 2 && avail >= 2 * w + 16;
            final List<Widget> panels = <Widget>[
              for (final BhorThemeData t in themes)
                _Panel(key: ValueKey<Brightness>(t.brightness), theme: t, width: w, demo: _demo),
            ];
            return ListView(
              padding: const EdgeInsets.all(BhorSpace.s16),
              children: <Widget>[
                BhorSegmented<_ThemePick>(
                  segments: const <BhorSegment<_ThemePick>>[
                    BhorSegment<_ThemePick>(_ThemePick.light, 'Light', icon: Icons.light_mode_outlined),
                    BhorSegment<_ThemePick>(_ThemePick.dark, 'Dark', icon: Icons.dark_mode_outlined),
                    BhorSegment<_ThemePick>(_ThemePick.both, 'Both'),
                  ],
                  value: _theme,
                  onChanged: (_ThemePick v) => setState(() => _theme = v),
                ),
                const SizedBox(height: BhorSpace.s8),
                BhorSegmented<_WidthPick>(
                  segments: const <BhorSegment<_WidthPick>>[
                    BhorSegment<_WidthPick>(_WidthPick.phone, 'Phone 360', icon: Icons.smartphone_outlined),
                    BhorSegment<_WidthPick>(_WidthPick.desktop, 'Desktop 1024', icon: Icons.desktop_windows_outlined),
                    BhorSegment<_WidthPick>(_WidthPick.fit, 'Fit'),
                  ],
                  value: _width,
                  onChanged: (_WidthPick v) => setState(() => _width = v),
                ),
                const SizedBox(height: BhorSpace.s16),
                if (sideBySide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[panels[0], const SizedBox(width: BhorSpace.s16), panels[1]],
                  )
                else
                  for (final Widget p in panels) ...<Widget>[
                    SingleChildScrollView(scrollDirection: Axis.horizontal, child: p),
                    const SizedBox(height: BhorSpace.s16),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Shared demo state so both theme panels mirror each other.
class _DemoState extends ChangeNotifier {
  int segment = 0;
  int tab = 0;
  Set<int> chips = <int>{0};
  bool switchOn = true;
  bool checked = false;
  int radio = 1;
  String? batch = 'b1';
  AttendanceKind? attendance = AttendanceKind.present;
  DateTime date = DateTime(2026, 11, 21);
  int time = 16 * 60;
  int nav = 0;
  bool collapsed = false;
  final TextEditingController name = TextEditingController();
  final TextEditingController fee = TextEditingController(text: '১৫০০');

  void set(void Function() f) {
    f();
    notifyListeners();
  }

  @override
  void dispose() {
    name.dispose();
    fee.dispose();
    super.dispose();
  }
}

class _Panel extends StatelessWidget {
  const _Panel({super.key, required this.theme, required this.width, required this.demo});

  final BhorThemeData theme;
  final double width;
  final _DemoState demo;

  @override
  Widget build(BuildContext context) {
    return BhorTheme(
      data: theme,
      child: Builder(
        builder: (BuildContext context) {
          final BhorColors c = context.bhor.colors;
          return Container(
            width: width,
            decoration: BoxDecoration(
              color: c.bg,
              borderRadius: BorderRadius.circular(BhorRadius.card),
              border: Border.all(color: c.line),
            ),
            padding: const EdgeInsets.all(BhorSpace.s16),
            child: ListenableBuilder(
              listenable: demo,
              builder: (BuildContext context, Widget? _) => _Sections(demo: demo, wide: width >= 700),
            ),
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.children);

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BhorSpace.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          BhorSectionHeader(title: title),
          const SizedBox(height: BhorSpace.s8),
          ...children,
        ],
      ),
    );
  }
}

Widget _wrap(List<Widget> children) => Wrap(
      spacing: BhorSpace.s8,
      runSpacing: BhorSpace.s8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );

class _Sections extends StatelessWidget {
  const _Sections({required this.demo, required this.wide});

  final _DemoState demo;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final AppFormat fmt = context.fmt;
    final DateTime today = DateTime(2026, 11, 21);
    final List<BhorNavItem> nav = <BhorNavItem>[
      const BhorNavItem(icon: Icons.today_outlined, activeIcon: Icons.today, label: 'আজ'),
      const BhorNavItem(icon: Icons.groups_outlined, activeIcon: Icons.groups, label: 'ব্যাচ'),
      const BhorNavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'শিক্ষার্থী'),
      BhorNavItem(icon: Icons.payments_outlined, activeIcon: Icons.payments, label: 'বেতন', badge: fmt.number(3)),
      const BhorNavItem(icon: Icons.more_horiz, label: 'আরও'),
    ];
    final List<(String, Color)> swatches = <(String, Color)>[
      ('bg', c.bg),
      ('surface', c.surface),
      ('surface2', c.surface2),
      ('line', c.line),
      ('text', c.text),
      ('text2', c.text2),
      ('text3', c.text3),
      ('accent', c.accent),
      ('accentTint', c.accentTint),
      ('ok', c.ok),
      ('danger', c.danger),
      ('absent', c.absent),
      ('late', c.lateText),
    ];

    final Widget pickers = wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: _datePicker(demo, today)),
              const SizedBox(width: BhorSpace.s24),
              Expanded(child: _timePicker(demo)),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[_datePicker(demo, today), const SizedBox(height: BhorSpace.s16), _timePicker(demo)],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Section('Tokens', <Widget>[
          _wrap(<Widget>[
            for (final (String n, Color col) in swatches)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: col,
                      borderRadius: BorderRadius.circular(BhorRadius.control),
                      border: Border.all(color: c.line),
                    ),
                  ),
                  Text(n, style: b.type.caption),
                ],
              ),
          ]),
          const SizedBox(height: BhorSpace.s12),
          Text('প্রদর্শন · Display 24', style: b.type.display),
          Text('শিরোনাম · Title 18', style: b.type.title),
          Text('উপশিরোনাম · Heading 15', style: b.type.heading),
          Text('মূল লেখা · Body 14 — আজ সকাল ১০টায় ক্লাস।', style: b.type.body),
          Text('Body strong 14', style: b.type.bodyStrong),
          Text('Label 12.5', style: b.type.label),
          Text('Meta 12 · বৃহস্পতিবার, ১৯ নভেম্বর', style: b.type.meta),
          Text('Caption 11', style: b.type.caption),
          BhorMoney(125000, style: b.type.stat, muteSign: true),
        ]),
        _Section('Buttons', <Widget>[
          _wrap(<Widget>[
            BhorButton(label: 'হাজিরা নিন', icon: Icons.how_to_reg_outlined, onPressed: () {}),
            BhorButton(label: 'সম্পাদনা', variant: BhorButtonVariant.secondary, onPressed: () {}),
            BhorButton(label: 'বাতিল', variant: BhorButtonVariant.ghost, onPressed: () {}),
            BhorButton(label: 'মুছুন', variant: BhorButtonVariant.danger, onPressed: () {}),
            BhorButton(label: 'সংরক্ষণ হচ্ছে', loading: true, onPressed: () {}),
            const BhorButton(label: 'নিষ্ক্রিয়', onPressed: null, disabledReason: 'আগে একটি ব্যাচ বেছে নিন'),
            BhorButton(label: 'ছোট', size: BhorButtonSize.sm, onPressed: () {}),
            BhorButton(
                label: 'ছোট', size: BhorButtonSize.sm, variant: BhorButtonVariant.secondary, onPressed: () {}),
          ]),
          const SizedBox(height: BhorSpace.s8),
          _wrap(<Widget>[
            BhorIconButton(icon: Icons.search, semanticLabel: 'খুঁজুন', onPressed: () {}),
            BhorIconButton(
              icon: Icons.notifications_none,
              semanticLabel: 'বিজ্ঞপ্তি',
              badge: fmt.number(2),
              onPressed: () {},
            ),
            BhorIconButton(
              icon: Icons.add,
              semanticLabel: 'যোগ করুন',
              variant: BhorButtonVariant.primary,
              onPressed: () {},
            ),
            BhorIconButton(
              icon: Icons.tune,
              semanticLabel: 'ফিল্টার',
              variant: BhorButtonVariant.secondary,
              size: BhorButtonSize.sm,
              onPressed: () {},
            ),
            const BhorIconButton(icon: Icons.delete_outline, semanticLabel: 'মুছুন', onPressed: null),
          ]),
          const SizedBox(height: BhorSpace.s8),
          BhorButton(label: 'পুরো প্রস্থ', expand: true, onPressed: () {}),
        ]),
        _Section('Text fields', <Widget>[
          BhorTextField(
            label: 'শিক্ষার্থীর নাম',
            hint: 'যেমন: রহিম উদ্দিন',
            helper: 'বাংলা বা ইংরেজিতে লিখুন',
            controller: demo.name,
          ),
          const SizedBox(height: BhorSpace.s12),
          BhorTextField(
            label: 'মাসিক বেতন',
            controller: demo.fee,
            prefix: Text(AppFormat.takaSign, style: b.type.body.copyWith(color: c.text2)),
            tabular: true,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: BhorSpace.s12),
          const BhorTextField(
            label: 'ফোন',
            initialValue: '০১৭১',
            error: 'ফোন নম্বর ১১ সংখ্যার হতে হবে',
            prefix: Icon(Icons.phone_outlined),
          ),
          const SizedBox(height: BhorSpace.s12),
          const BhorTextField(label: 'নোট', hint: 'ঐচ্ছিক', maxLines: 3, minLines: 3),
          const SizedBox(height: BhorSpace.s12),
          const BhorTextField(label: 'নিষ্ক্রিয়', initialValue: 'পরিবর্তন করা যাবে না', enabled: false),
        ]),
        _Section('Select', <Widget>[
          BhorSelect<String>(
            label: 'ব্যাচ',
            hint: 'ব্যাচ বেছে নিন',
            value: demo.batch,
            options: const <BhorOption<String>>[
              BhorOption<String>('b1', 'নবম শ্রেণি · গণিত', icon: Icons.groups_outlined),
              BhorOption<String>('b2', 'দশম শ্রেণি · পদার্থ', icon: Icons.groups_outlined),
              BhorOption<String>('b3', 'এসএসসি ব্যাচ ২০২৭', icon: Icons.groups_outlined),
            ],
            onChanged: (String v) => demo.set(() => demo.batch = v),
          ),
        ]),
        _Section('Segmented · Tabs', <Widget>[
          BhorSegmented<int>(
            segments: const <BhorSegment<int>>[
              BhorSegment<int>(0, 'দিন'),
              BhorSegment<int>(1, 'সপ্তাহ'),
              BhorSegment<int>(2, 'মাস'),
            ],
            value: demo.segment,
            onChanged: (int v) => demo.set(() => demo.segment = v),
          ),
          const SizedBox(height: BhorSpace.s12),
          BhorTabs(
            tabs: const <String>['শিক্ষার্থী', 'রুটিন', 'বেতন', 'হাজিরা'],
            index: demo.tab,
            onChanged: (int v) => demo.set(() => demo.tab = v),
          ),
        ]),
        _Section('Chips · Tags', <Widget>[
          _wrap(<Widget>[
            for (final (int i, String l) in <(int, String)>[(0, 'সব'), (1, 'বকেয়া'), (2, 'পরিশোধিত'), (3, 'ছাড়')])
              BhorChip(
                label: l,
                count: i == 1 ? fmt.number(12) : null,
                selected: demo.chips.contains(i),
                onSelected: (bool on) => demo.set(() => on ? demo.chips.add(i) : demo.chips.remove(i)),
              ),
          ]),
          const SizedBox(height: BhorSpace.s8),
          _wrap(const <Widget>[
            BhorTag(label: 'সাধারণ'),
            BhorTag(label: 'চলছে', tone: BhorTone.accent),
            BhorTag(label: 'পরিশোধিত', tone: BhorTone.ok, icon: Icons.check),
            BhorTag(label: 'বাতিল', tone: BhorTone.danger),
            BhorTag(label: 'দেরি', tone: BhorTone.late),
            BhorTag(label: 'অনুপস্থিত', tone: BhorTone.absent),
          ]),
          const SizedBox(height: BhorSpace.s8),
          _wrap(<Widget>[
            for (final SeverityLevel l in SeverityLevel.values) BhorTag.severity(level: l, label: l.name),
          ]),
        ]),
        _Section('Switch · Checkbox · Radio card', <Widget>[
          Row(
            children: <Widget>[
              BhorSwitch(
                value: demo.switchOn,
                semanticLabel: 'রিমাইন্ডার',
                onChanged: (bool v) => demo.set(() => demo.switchOn = v),
              ),
              Text('রিমাইন্ডার', style: b.type.body),
              const Spacer(),
              const BhorSwitch(value: false, onChanged: null, semanticLabel: 'নিষ্ক্রিয়'),
            ],
          ),
          BhorCheckbox(
            value: demo.checked,
            label: 'সবাইকে উপস্থিত ধরুন',
            onChanged: (bool v) => demo.set(() => demo.checked = v),
          ),
          const SizedBox(height: BhorSpace.s8),
          for (final (int v, String t, String s) in <(int, String, String)>[
            (1, 'মাসিক', 'প্রতি মাসে একবার বেতন'),
            (2, 'কোর্সভিত্তিক', 'একবারে পুরো কোর্সের বেতন'),
          ]) ...<Widget>[
            BhorRadioCard<int>(
              value: v,
              groupValue: demo.radio,
              title: t,
              subtitle: s,
              icon: Icons.calendar_month_outlined,
              onChanged: (int x) => demo.set(() => demo.radio = x),
            ),
            const SizedBox(height: BhorSpace.s8),
          ],
        ]),
        _Section('Cards', <Widget>[
          BhorCard.hero(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('পরের ক্লাস · ৪০ মিনিট পর', style: b.type.meta.copyWith(color: c.onHero)),
                Text('নবম শ্রেণি · গণিত', style: b.type.title.copyWith(color: c.onHero)),
                Text('বিকাল ৪:০০–৫:০০', style: BhorType.tabular(b.type.body.copyWith(color: c.onHero))),
              ],
            ),
          ),
          const SizedBox(height: BhorSpace.s12),
          BhorCard(
            onTap: () {},
            semanticLabel: 'এই মাসের হিসাব',
            child: Row(
              children: <Widget>[
                Expanded(child: BhorStatText(label: 'উপস্থিত', value: fmt.number(24))),
                const Expanded(child: BhorStatText.money(label: 'আদায়', amount: 18500)),
                Expanded(child: BhorStatText.money(label: 'বকেয়া', amount: 4500, color: c.danger)),
              ],
            ),
          ),
        ]),
        _Section('List rows · Avatar', <Widget>[
          BhorCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                BhorListRow(
                  leading: const BhorAvatar(name: 'রহিম উদ্দিন'),
                  title: 'রহিম উদ্দিন',
                  subtitle: 'রোল ৩ · নবম শ্রেণি',
                  trailing: const BhorTag(label: 'পরিশোধিত', tone: BhorTone.ok),
                  onTap: () {},
                ),
                BhorListRow(
                  leading: const BhorAvatar(name: 'Fatema Akter'),
                  title: 'Fatema Akter',
                  subtitle: 'Roll 7',
                  trailing: const BhorTag.severity(level: SeverityLevel.overdue, label: 'মেয়াদোত্তীর্ণ'),
                  onTap: () {},
                  selected: true,
                ),
                const BhorListRow(
                  leading: BhorAvatar(name: 'করিম'),
                  title: 'করিম',
                  subtitle: 'রোল ১২',
                  divider: false,
                ),
              ],
            ),
          ),
        ]),
        _Section('Attendance · Escalation · Money', <Widget>[
          BhorAttendanceToggle(
            value: demo.attendance,
            onChanged: (AttendanceKind k) => demo.set(() => demo.attendance = k),
          ),
          const SizedBox(height: BhorSpace.s8),
          Row(children: <Widget>[
            BhorAttendanceToggle(
              value: demo.attendance,
              compact: true,
              onChanged: (AttendanceKind k) => demo.set(() => demo.attendance = k),
            ),
          ]),
          const SizedBox(height: BhorSpace.s12),
          for (final int d in <int>[0, 3, 7, 10, 12]) ...<Widget>[
            Row(
              children: <Widget>[
                SizedBox(width: 40, child: Text(fmt.number(d), style: b.type.meta)),
                Expanded(child: BhorEscalationBar(day: d)),
              ],
            ),
            const SizedBox(height: BhorSpace.s8),
          ],
          _wrap(<Widget>[
            const BhorMoney(1500),
            BhorMoney(-200, color: c.danger),
            BhorMoney(1250000, style: b.type.stat, muteSign: true),
          ]),
        ]),
        _Section('Progress · Skeleton · Empty', <Widget>[
          const BhorProgress(value: 0.72, semanticLabel: 'উপস্থিতি'),
          const SizedBox(height: BhorSpace.s12),
          const Row(children: <Widget>[
            BhorSkeleton(width: 36, height: 36, radius: BhorRadius.avatar),
            SizedBox(width: BhorSpace.s12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                BhorSkeleton(width: 160),
                SizedBox(height: 6),
                BhorSkeleton(width: 100, height: 10),
              ]),
            ),
          ]),
          const SizedBox(height: BhorSpace.s8),
          BhorEmptyState(
            icon: Icons.groups_outlined,
            title: 'এখনো কোনো ব্যাচ নেই',
            message: 'প্রথম ব্যাচ যোগ করলে এখানে রুটিন আর হাজিরা দেখা যাবে।',
            action: BhorButton(label: 'ব্যাচ যোগ করুন', icon: Icons.add, onPressed: () {}),
          ),
        ]),
        _Section('Date · Time pickers', <Widget>[pickers]),
        _Section('Sheet · Dialog · Toast', <Widget>[
          _wrap(<Widget>[
            BhorButton(
              label: 'Sheet',
              variant: BhorButtonVariant.secondary,
              onPressed: () => showBhorSheet<void>(
                context,
                title: 'অন্যান্য আয় যোগ করুন',
                builder: (BuildContext ctx) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const BhorTextField(label: 'বিবরণ', hint: 'যেমন: বই বিক্রি'),
                    const SizedBox(height: BhorSpace.s16),
                    BhorButton(label: 'সংরক্ষণ', expand: true, onPressed: () => Navigator.of(ctx).pop()),
                  ],
                ),
              ),
            ),
            BhorButton(
              label: 'Dialog',
              variant: BhorButtonVariant.secondary,
              onPressed: () => showBhorConfirm(
                context,
                title: 'ব্যাচটি মুছবেন?',
                message: 'এই ব্যাচের সব হাজিরা ও বেতনের হিসাব মুছে যাবে।',
                confirmLabel: 'মুছুন',
                destructive: true,
              ),
            ),
            BhorButton(
              label: 'Toast',
              variant: BhorButtonVariant.secondary,
              onPressed: () => BhorToast.show(
                context,
                message: 'হাজিরা সংরক্ষিত হয়েছে',
                tone: BhorTone.ok,
                icon: Icons.check_circle_outline,
                actionLabel: 'ফেরান',
                onAction: () {},
              ),
            ),
            BhorButton(
              label: 'Date sheet',
              variant: BhorButtonVariant.ghost,
              onPressed: () async {
                final DateTime? d = await showBhorDatePicker(
                  context,
                  initialDate: demo.date,
                  firstDate: DateTime(2025),
                  lastDate: DateTime(2027, 12, 31),
                  today: today,
                );
                if (d != null) demo.set(() => demo.date = d);
              },
            ),
            BhorButton(
              label: 'Time sheet',
              variant: BhorButtonVariant.ghost,
              onPressed: () async {
                final int? m = await showBhorTimePicker(context, initial: demo.time);
                if (m != null) demo.set(() => demo.time = m);
              },
            ),
          ]),
          const SizedBox(height: BhorSpace.s12),
          ClipRRect(
            borderRadius: BorderRadius.circular(BhorRadius.sheet),
            child: const BhorSheetFrame(
              title: 'Sheet (inline preview)',
              child: Text('Drag handle, title, close button, safe-area padding.'),
            ),
          ),
          const SizedBox(height: BhorSpace.s12),
          BhorDialog(
            title: 'ব্যাচটি মুছবেন?',
            message: 'Inline dialog preview.',
            actions: <Widget>[
              BhorButton(label: 'বাতিল', variant: BhorButtonVariant.secondary, onPressed: () {}),
              BhorButton(label: 'মুছুন', variant: BhorButtonVariant.danger, onPressed: () {}),
            ],
          ),
        ]),
        _Section('Header · Bottom nav · Sidebar · Scaffold', <Widget>[
          _Framed(
            height: 260,
            child: BhorScaffold(
              header: BhorHeader(
                title: 'আজ',
                subtitle: 'শনিবার, ২১ নভেম্বর',
                large: true,
                showBack: false,
                actions: <Widget>[BhorIconButton(icon: Icons.search, semanticLabel: 'খুঁজুন', onPressed: () {})],
              ),
              body: const Center(child: Text('BhorScaffold body')),
              bottomNav: BhorBottomNav(
                items: nav,
                index: demo.nav,
                onTap: (int i) => demo.set(() => demo.nav = i),
              ),
            ),
          ),
          const SizedBox(height: BhorSpace.s12),
          _Framed(
            height: 380,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                BhorSidebar(
                  brand: 'হাজিরা খাতা',
                  items: nav,
                  index: demo.nav,
                  onTap: (int i) => demo.set(() => demo.nav = i),
                  collapsed: demo.collapsed,
                  toggleLabel: 'সাইডবার',
                  onToggleCollapsed: () => demo.set(() => demo.collapsed = !demo.collapsed),
                ),
                Expanded(
                  child: ColoredBox(
                    color: c.bg,
                    child: wide
                        ? const Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              BhorHeader(title: 'ব্যাচ', subtitle: '৩টি সক্রিয়', showBack: true, divider: true),
                            ],
                          )
                        : const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
        ]),
      ],
    );
  }

  static Widget _datePicker(_DemoState demo, DateTime today) => BhorDatePicker(
        selected: demo.date,
        today: today,
        firstDate: DateTime(2025),
        lastDate: DateTime(2027, 12, 31),
        onChanged: (DateTime d) => demo.set(() => demo.date = d),
      );

  static Widget _timePicker(_DemoState demo) =>
      BhorTimePicker(value: demo.time, onChanged: (int m) => demo.set(() => demo.time = m));
}

/// Fixed-height bordered box for chrome previews (MediaQuery padding removed).
class _Framed extends StatelessWidget {
  const _Framed({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final BhorColors c = context.bhor.colors;
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(BhorRadius.card),
        border: Border.all(color: c.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        removeBottom: true,
        removeLeft: true,
        removeRight: true,
        child: child,
      ),
    );
  }
}
