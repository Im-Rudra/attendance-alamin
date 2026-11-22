// Developer gallery of every Bhor component and motion
// (docs/council/13-fluid-ui-spec.md), in light / dark / both themes and at
// phone (360) / desktop (1024) / fit widths, plus the four page templates
// (lib/app/shell/templates) in framed previews. Hidden route
// `/more/design-system` (long-press the version row in More › Diagnostics).
// Demo labels are sample content, not product copy.

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/shell/templates/templates.dart';
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
                    BhorSegment<_ThemePick>(_ThemePick.light, 'Light', icon: BhorIcons.light),
                    BhorSegment<_ThemePick>(_ThemePick.dark, 'Dark', icon: BhorIcons.dark),
                    BhorSegment<_ThemePick>(_ThemePick.both, 'Both'),
                  ],
                  value: _theme,
                  onChanged: (_ThemePick v) => setState(() => _theme = v),
                ),
                const SizedBox(height: BhorSpace.s8),
                BhorSegmented<_WidthPick>(
                  segments: const <BhorSegment<_WidthPick>>[
                    BhorSegment<_WidthPick>(_WidthPick.phone, 'Phone 360', icon: BhorIcons.phoneDevice),
                    BhorSegment<_WidthPick>(_WidthPick.desktop, 'Desktop 1024', icon: BhorIcons.desktop),
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
  List<AttendanceKind> roll = <AttendanceKind>[AttendanceKind.present, AttendanceKind.absent, AttendanceKind.late];
  DateTime date = DateTime(2026, 11, 21);
  int time = 16 * 60;
  int nav = 0;
  bool collapsed = false;
  int months = 2;
  int collected = 18500;
  int pane = 0;
  int view = 0;
  int replay = 0;
  bool saving = false;
  bool saved = false;
  int pick = 0;
  String section = 'look';
  final TextEditingController name = TextEditingController();
  final TextEditingController fee = TextEditingController(text: '১৫০০');
  final TextEditingController phone = TextEditingController(text: '01712345678');

  void set(void Function() f) {
    f();
    notifyListeners();
  }

  @override
  void dispose() {
    name.dispose();
    fee.dispose();
    phone.dispose();
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

/// A short sample form used by the panel / sheet demos.
Widget _demoForm(BuildContext ctx) => const Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        BhorTextField(label: 'টাকার পরিমাণ', initialValue: '১০০০', tabular: true),
        SizedBox(height: BhorSpace.s12),
        BhorTextField(label: 'নোট', hint: 'ঐচ্ছিক'),
      ],
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
      const BhorNavItem(icon: BhorIcons.today, activeIcon: BhorIcons.todayFill, label: 'আজ'),
      const BhorNavItem(icon: BhorIcons.batches, activeIcon: BhorIcons.batchesFill, label: 'ব্যাচ'),
      const BhorNavItem(icon: BhorIcons.students, activeIcon: BhorIcons.studentsFill, label: 'শিক্ষার্থী'),
      BhorNavItem(icon: BhorIcons.fees, activeIcon: BhorIcons.feesFill, label: 'বেতন', badge: fmt.number(3)),
      const BhorNavItem(icon: BhorIcons.more, activeIcon: BhorIcons.moreFill, label: 'আরও'),
    ];
    final List<(String, Color)> swatches = <(String, Color)>[
      ('bg', c.bg),
      ('surface', c.surface),
      ('soft', c.soft),
      ('soft2', c.soft2),
      ('line', c.line),
      ('text', c.text),
      ('text2', c.text2),
      ('text3', c.text3),
      ('accent', c.accent),
      ('accentFill', c.accentFill),
      ('accentTint', c.accentTint),
      ('ok', c.ok),
      ('warn', c.warn),
      ('overdue', c.overdue),
      ('absent', c.absentText),
      ('late', c.late),
      ('error', c.danger),
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

    final List<(String, String, AttendanceKind)> roster = <(String, String, AttendanceKind)>[
      ('রহিম উদ্দিন', 'রোল ৩', demo.roll[0]),
      ('Fatema Akter', 'Roll 7', demo.roll[1]),
      ('করিম', 'রোল ১২', demo.roll[2]),
    ];
    final int present = demo.roll.where((AttendanceKind k) => k == AttendanceKind.present).length;

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
          Text('প্রদর্শন · Display 26', style: b.type.display),
          Text('শিরোনাম · Title 19', style: b.type.title),
          Text('উপশিরোনাম · Heading 16', style: b.type.heading),
          Text('মূল লেখা · Body 14.5 — আজ সকাল ১০টায় ক্লাস।', style: b.type.body),
          Text('Body strong 14.5', style: b.type.bodyStrong),
          Text('Label 13', style: b.type.label),
          Text('Meta 12.5 · বৃহস্পতিবার, ১৯ নভেম্বর', style: b.type.meta),
          Text('Caption 12.5', style: b.type.caption),
          BhorMoney(125000, style: b.type.stat, muteSign: true),
          const SizedBox(height: BhorSpace.s8),
          _wrap(<Widget>[
            for (final IconData i in <IconData>[
              BhorIcons.today,
              BhorIcons.batches,
              BhorIcons.students,
              BhorIcons.fees,
              BhorIcons.more,
              BhorIcons.search,
              BhorIcons.rollCall,
              BhorIcons.takeMoney,
              BhorIcons.remind,
              BhorIcons.share,
              BhorIcons.holiday,
              BhorIcons.backupUp,
              BhorIcons.late,
              BhorIcons.edit,
              BhorIcons.delete,
              BhorIcons.warning,
            ])
              Icon(i, size: BhorIconSize.nav, color: c.text2),
            Icon(BhorIcons.checkCircleFill, size: BhorIconSize.nav, color: c.ok),
            Icon(BhorIcons.warningFill, size: BhorIconSize.nav, color: c.danger),
          ]),
        ]),
        _Section('Buttons', <Widget>[
          _wrap(<Widget>[
            BhorButton(label: 'হাজিরা নিন', icon: BhorIcons.rollCall, onPressed: () {}),
            BhorButton(label: 'পরের ধাপ', arrow: true, onPressed: () {}),
            BhorButton(label: 'সম্পাদনা', variant: BhorButtonVariant.secondary, onPressed: () {}),
            BhorButton(label: 'টাকা নিন', variant: BhorButtonVariant.tonal, icon: BhorIcons.takeMoney, onPressed: () {}),
            BhorButton(label: 'বাতিল', variant: BhorButtonVariant.ghost, onPressed: () {}),
            BhorButton(label: 'মুছুন', variant: BhorButtonVariant.danger, onPressed: () {}),
            BhorButton(
              label: 'সেভ করুন',
              loading: demo.saving,
              done: demo.saved,
              onPressed: () => demo.set(() {
                if (demo.saved) {
                  demo.saved = false;
                } else if (demo.saving) {
                  demo.saving = false;
                  demo.saved = true;
                } else {
                  demo.saving = true;
                }
              }),
            ),
            const BhorButton(label: 'নিষ্ক্রিয়', onPressed: null, disabledReason: 'আগে একটি ব্যাচ বেছে নিন'),
            BhorButton(label: 'ছোট', size: BhorButtonSize.sm, onPressed: () {}),
            BhorButton(
                label: 'ছোট', size: BhorButtonSize.sm, variant: BhorButtonVariant.secondary, onPressed: () {}),
          ]),
          const SizedBox(height: BhorSpace.s8),
          _wrap(<Widget>[
            BhorIconButton(icon: BhorIcons.search, semanticLabel: 'খুঁজুন', onPressed: () {}),
            BhorIconButton(
              icon: BhorIcons.search,
              semanticLabel: 'খুঁজুন',
              variant: BhorButtonVariant.secondary,
              circle: true,
              onPressed: () {},
            ),
            BhorIconButton(
              icon: BhorIcons.bell,
              semanticLabel: 'বিজ্ঞপ্তি',
              badge: fmt.number(2),
              onPressed: () {},
            ),
            BhorIconButton(
              icon: BhorIcons.add,
              semanticLabel: 'যোগ করুন',
              variant: BhorButtonVariant.primary,
              onPressed: () {},
            ),
            BhorIconButton(
              icon: BhorIcons.filter,
              semanticLabel: 'ফিল্টার',
              variant: BhorButtonVariant.secondary,
              size: BhorButtonSize.sm,
              onPressed: () {},
            ),
            const BhorIconButton(icon: BhorIcons.delete, semanticLabel: 'মুছুন', onPressed: null),
          ]),
          const SizedBox(height: BhorSpace.s8),
          BhorButton(label: 'পুরো প্রস্থ', expand: true, size: BhorButtonSize.lg, onPressed: () {}),
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
            prefix: Icon(BhorIcons.phone),
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
              BhorOption<String>('b1', 'নবম শ্রেণি · গণিত', icon: BhorIcons.batches),
              BhorOption<String>('b2', 'দশম শ্রেণি · পদার্থ', icon: BhorIcons.batches),
              BhorOption<String>('b3', 'এসএসসি ব্যাচ ২০২৭', icon: BhorIcons.batches),
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
            BhorTag(label: 'পরিশোধিত', tone: BhorTone.ok, icon: BhorIcons.check),
            BhorTag(label: 'আংশিক', tone: BhorTone.warn),
            BhorTag(label: 'মেয়াদোত্তীর্ণ', tone: BhorTone.overdue),
            BhorTag(label: 'বাতিল', tone: BhorTone.danger),
            BhorTag(label: 'দেরি', tone: BhorTone.late),
            BhorTag(label: 'অনুপস্থিত', tone: BhorTone.absent),
          ]),
          const SizedBox(height: BhorSpace.s8),
          _wrap(<Widget>[
            for (final SeverityLevel l in SeverityLevel.values) BhorTag.severity(level: l, label: l.name),
          ]),
        ]),
        _Section('Switch · Checkbox · Radio card · Stepper', <Widget>[
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
              icon: BhorIcons.calendar,
              onChanged: (int x) => demo.set(() => demo.radio = x),
            ),
            const SizedBox(height: BhorSpace.s8),
          ],
          Row(children: <Widget>[
            BhorStepper(
              value: demo.months,
              min: 1,
              max: 12,
              semanticLabel: 'মাস',
              onChanged: (int v) => demo.set(() => demo.months = v),
            ),
            const SizedBox(width: BhorSpace.s12),
            Text('মাস', style: b.type.body),
          ]),
        ]),
        _Section('Cards', <Widget>[
          BhorCard.hero(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text('পরের ক্লাস · ৪০ মিনিট পর', style: b.type.meta.copyWith(color: c.onHero)),
                Text('নবম শ্রেণি · গণিত', style: b.type.title.copyWith(color: c.onHero)),
                Text('বিকাল ৪:০০–৫:০০', style: BhorType.tabular(b.type.body.copyWith(color: c.onHero))),
                const SizedBox(height: BhorSpace.s12),
                BhorButton(label: 'হাজিরা নিন', variant: BhorButtonVariant.hero, expand: true, onPressed: () {}),
              ],
            ),
          ),
          const SizedBox(height: BhorSpace.s12),
          BhorCard(
            onTap: () {},
            semanticLabel: 'এই মাসের হিসাব',
            child: Row(
              children: <Widget>[
                const Expanded(child: BhorStatText.count(label: 'উপস্থিত', count: 24)),
                Expanded(child: BhorStatText.money(label: 'আদায়', amount: demo.collected, countUp: true)),
                Expanded(child: BhorStatText.money(label: 'বকেয়া', amount: 4500, color: c.danger)),
              ],
            ),
          ),
        ]),
        _Section('List · Rows · Avatar', <Widget>[
          BhorList(
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
                trailing: const BhorMoney(1500),
                onTap: () {},
                selected: true,
              ),
              const BhorListRow(
                leading: BhorAvatar(name: 'করিম'),
                title: 'করিম',
                subtitle: 'রোল ১২',
                trailing: BhorTag.severity(level: SeverityLevel.overdue, label: 'মেয়াদোত্তীর্ণ'),
              ),
            ],
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
          const SizedBox(height: BhorSpace.s8),
          _wrap(<Widget>[
            BhorTag(label: 'উপস্থিত ${fmt.number(present)}', tone: BhorTone.ok),
            BhorTag(label: 'অনুপস্থিত ${fmt.number(demo.roll.where((AttendanceKind k) => k == AttendanceKind.absent).length)}', tone: BhorTone.absent),
            BhorTag(label: 'দেরি ${fmt.number(demo.roll.where((AttendanceKind k) => k == AttendanceKind.late).length)}', tone: BhorTone.late),
          ]),
          const SizedBox(height: BhorSpace.s8),
          BhorList(
            children: <Widget>[
              for (int i = 0; i < roster.length; i++)
                BhorListRow(
                  leading: BhorAvatar(name: roster[i].$1),
                  title: roster[i].$1,
                  subtitle: roster[i].$2,
                  trailing: BhorAttendanceToggle(
                    value: roster[i].$3,
                    iconOnly: true,
                    onChanged: (AttendanceKind k) => demo.set(() => demo.roll[i] = k),
                  ),
                ),
            ],
          ),
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
          BhorProgress(value: demo.collected / 25000, semanticLabel: 'আদায়'),
          const SizedBox(height: BhorSpace.s12),
          const Row(children: <Widget>[
            BhorSkeleton(width: 36, height: 36, radius: 18),
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
            icon: BhorIcons.batches,
            title: 'এখনো কোনো ব্যাচ নেই',
            message: 'প্রথম ব্যাচ যোগ করলে এখানে রুটিন আর হাজিরা দেখা যাবে।',
            action: BhorButton(label: 'ব্যাচ যোগ করুন', icon: BhorIcons.add, onPressed: () {}),
          ),
        ]),
        _Section('Motion', <Widget>[
          _wrap(<Widget>[
            BhorButton(
              label: 'Replay stagger',
              variant: BhorButtonVariant.secondary,
              size: BhorButtonSize.sm,
              onPressed: () => demo.set(() => demo.replay++),
            ),
            BhorButton(
              label: '+৳১,০০০',
              variant: BhorButtonVariant.secondary,
              size: BhorButtonSize.sm,
              onPressed: () => demo.set(() => demo.collected += 1000),
            ),
            BhorButton(
              label: 'Switch view',
              variant: BhorButtonVariant.secondary,
              size: BhorButtonSize.sm,
              onPressed: () => demo.set(() => demo.view = 1 - demo.view),
            ),
            BhorButton(
              label: 'Next pane',
              variant: BhorButtonVariant.secondary,
              size: BhorButtonSize.sm,
              onPressed: () => demo.set(() => demo.pane = (demo.pane + 1) % 3),
            ),
          ]),
          const SizedBox(height: BhorSpace.s12),
          BhorCountUp.money(amount: demo.collected, style: b.type.stat, muteSign: true),
          const SizedBox(height: BhorSpace.s12),
          KeyedSubtree(
            key: ValueKey<int>(demo.replay),
            child: BhorStaggerScope(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (int i = 0; i < 4; i++)
                    BhorStagger(
                      index: i,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: BhorCard(
                          padding: const EdgeInsets.all(BhorSpace.s12),
                          child: Text('তালিকার সারি ${fmt.number(i + 1)}', style: b.type.body),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: BhorSpace.s12),
          BhorFadeThrough(
            child: KeyedSubtree(
              key: ValueKey<int>(demo.view),
              child: BhorCard(
                child: Text(demo.view == 0 ? 'বকেয়া (fade through)' : 'আদায় (fade through)', style: b.type.heading),
              ),
            ),
          ),
          const SizedBox(height: BhorSpace.s12),
          BhorPaneSwitcher(
            paneKey: demo.pane,
            child: BhorCard(
              child: Text('Detail pane ${fmt.number(demo.pane + 1)} (cross-fade + rise)', style: b.type.body),
            ),
          ),
          const SizedBox(height: BhorSpace.s12),
          const Center(child: BhorSuccess(size: 56, label: 'হয়েছে')),
        ]),
        _Section('Date · Time pickers', <Widget>[pickers]),
        _Section('Adaptive panel · Sheet · Side panel · Dialog · Toast', <Widget>[
          _wrap(<Widget>[
            BhorButton(
              label: 'showBhorPanel (form)',
              variant: BhorButtonVariant.secondary,
              onPressed: () => showBhorPanel<void>(
                context,
                title: 'টাকা নিন',
                builder: _demoForm,
                footer: (BuildContext ctx) => BhorButton(
                  label: 'সেভ করুন',
                  expand: true,
                  onPressed: () => showBhorSuccess<void>(ctx, label: 'জমা হয়েছে', toast: '৳১,০০০ জমা হয়েছে'),
                ),
              ),
            ),
            BhorButton(
              label: 'showBhorPanel (confirm)',
              variant: BhorButtonVariant.secondary,
              onPressed: () => showBhorPanel<void>(
                context,
                kind: BhorPanelKind.confirm,
                title: 'ছুটি দিন?',
                builder: (BuildContext ctx) => Text('আজ সবার ছুটি থাকবে।', style: b.type.body),
                footer: (BuildContext ctx) =>
                    BhorButton(label: 'ঠিক আছে', onPressed: () => Navigator.of(ctx).pop()),
              ),
            ),
            BhorButton(
              label: 'Expanding sheet',
              variant: BhorButtonVariant.secondary,
              onPressed: () => showBhorSheet<void>(
                context,
                title: 'নতুন শিক্ষার্থী',
                expanding: true,
                builder: (BuildContext ctx) => SingleChildScrollView(child: _demoForm(ctx)),
                footer: (BuildContext ctx) =>
                    BhorButton(label: 'সেভ করুন', expand: true, onPressed: () => Navigator.of(ctx).pop()),
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
                message: 'হাজিরা সেভ হয়েছে',
                tone: BhorTone.ok,
                icon: BhorIcons.checkCircleFill,
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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(BhorRadius.sheet)),
            child: const BhorSheetFrame(
              title: 'Sheet (inline preview)',
              child: Text('Grab handle, title, close button, safe-area padding.'),
            ),
          ),
          const SizedBox(height: BhorSpace.s12),
          _Framed(
            height: 300,
            child: ColoredBox(
              color: c.bg,
              child: BhorSidePanelFrame(
                title: 'Side panel (inline)',
                width: wide ? 420 : 300,
                child: _demoForm(context),
              ),
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
            height: 280,
            child: BhorScaffold(
              header: BhorHeader(
                overline: 'শনিবার, ২১ নভেম্বর',
                title: 'শুভ সকাল',
                large: true,
                showBack: false,
                actions: <Widget>[
                  BhorIconButton(
                    icon: BhorIcons.search,
                    semanticLabel: 'খুঁজুন',
                    variant: BhorButtonVariant.secondary,
                    circle: true,
                    onPressed: () {},
                  ),
                ],
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
            height: 400,
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
        _Section('Selection · Picker field · Empty sizes', <Widget>[
          for (int i = 0; i < 2; i++) ...<Widget>[
            BhorCard(
              selected: demo.pick == i,
              onTap: () => demo.set(() => demo.pick = i),
              semanticLabel: i == 0 ? 'নবম শ্রেণি · গণিত' : 'দশম শ্রেণি · পদার্থ',
              child: Row(
                children: <Widget>[
                  BhorAvatar(name: i == 0 ? 'নবম' : 'দশম', size: 40),
                  const SizedBox(width: BhorSpace.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(i == 0 ? 'নবম শ্রেণি · গণিত' : 'দশম শ্রেণি · পদার্থ', style: b.type.heading),
                        Text('শনি · সোম · বুধ  ৪:০০', style: b.type.meta),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: BhorSpace.s8),
          ],
          BhorPickerField(
            label: 'শুরুর সময়',
            value: fmt.time(demo.time),
            icon: BhorIcons.clock,
            onTap: (BuildContext _) {},
          ),
          const SizedBox(height: BhorSpace.s8),
          BhorPickerField(label: 'তারিখ', value: null, placeholder: 'তারিখ বেছে নিন', icon: BhorIcons.calendar, onTap: null),
          const SizedBox(height: BhorSpace.s8),
          const BhorTextField(label: 'বিষয়', initialValue: 'গণিত', readOnly: true),
          const SizedBox(height: BhorSpace.s8),
          BhorTextField(label: 'ফোন', controller: demo.phone, keyboardType: TextInputType.phone),
          const BhorEmptyState(
            size: BhorEmptySize.compact,
            icon: BhorIcons.receipt,
            title: 'আজ কোনো পেমেন্ট নেই',
            message: 'টাকা নিলে এখানে দেখা যাবে।',
          ),
          const BhorEmptyState(
            size: BhorEmptySize.page,
            icon: BhorIcons.holiday,
            title: 'কোনো ছুটি নেই',
            message: 'ছুটির দিন যোগ করলে সেদিন ক্লাস হবে না।',
          ),
        ]),
        _Section('Page templates', <Widget>[
          Text('BhorDashboardPage', style: b.type.label),
          const SizedBox(height: BhorSpace.s4),
          _Framed(
            height: 360,
            child: BhorDashboardPage(
              overline: 'শনিবার, ২১ নভেম্বর',
              title: 'শুভ সকাল',
              actions: <Widget>[BhorButton(label: 'নতুন', icon: BhorIcons.add, size: BhorButtonSize.sm, onPressed: () {})],
              hero: BhorCard.hero(child: Text('পরের ক্লাস · ৪:০০', style: b.type.heading.copyWith(color: c.onHero))),
              children: <Widget>[
                BhorCard(child: Text('আজকের ক্লাস', style: b.type.heading)),
                BhorCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('সাম্প্রতিক পেমেন্ট', style: b.type.heading),
                      const SizedBox(height: BhorSpace.s8),
                      for (int i = 0; i < 4; i++) Text('রহিম · ৳${fmt.number(500 + i * 100)}', style: b.type.body),
                    ],
                  ),
                ),
                BhorCard(child: Text('ব্যাকআপ', style: b.type.heading)),
              ],
            ),
          ),
          const SizedBox(height: BhorSpace.s12),
          Text('BhorMasterDetailPage', style: b.type.label),
          const SizedBox(height: BhorSpace.s4),
          _Framed(
            height: 360,
            child: BhorMasterDetailPage(
              master: ListView(
                padding: const EdgeInsets.all(BhorSpace.s12),
                children: <Widget>[
                  for (int i = 0; i < 3; i++) ...<Widget>[
                    BhorCard(
                      selected: demo.pick == i,
                      onTap: () => demo.set(() => demo.pick = i),
                      child: Text('ব্যাচ ${fmt.number(i + 1)}', style: b.type.bodyStrong),
                    ),
                    const SizedBox(height: BhorSpace.s8),
                  ],
                ],
              ),
              detail: Builder(
                builder: (BuildContext context) {
                  final Widget? rail = BhorMasterDetailPage.foldedRailOf(context);
                  return ListView(
                    padding: const EdgeInsets.all(BhorSpace.s16),
                    children: <Widget>[
                      Text('ব্যাচ ${fmt.number(demo.pick + 1)}', style: b.type.title),
                      const SizedBox(height: BhorSpace.s12),
                      BhorTabs(
                        tabs: const <String>['শিক্ষার্থী', 'হাজিরা', 'বেতন'],
                        index: demo.tab % 3,
                        onChanged: (int v) => demo.set(() => demo.tab = v),
                      ),
                      const SizedBox(height: BhorSpace.s12),
                      ?rail,
                    ],
                  );
                },
              ),
              rail: BhorCard(child: Text('সাপ্তাহিক রুটিন', style: b.type.heading)),
            ),
          ),
          const SizedBox(height: BhorSpace.s12),
          Text('BhorSettingsPage', style: b.type.label),
          const SizedBox(height: BhorSpace.s4),
          _Framed(
            height: 360,
            child: BhorSettingsPage(
              sections: const <BhorSettingsSection>[
                BhorSettingsSection(id: 'look', label: 'চেহারা', icon: BhorIcons.light),
                BhorSettingsSection(id: 'fees', label: 'বেতন ও পেমেন্ট', icon: BhorIcons.money),
                BhorSettingsSection(id: 'holidays', label: 'ছুটি', icon: BhorIcons.holiday),
              ],
              selected: demo.section,
              onSelect: (String id) => demo.set(() => demo.section = id),
              crumb: demo.section == 'fees' ? 'বেতন ও পেমেন্ট' : null,
              onCrumb: () => demo.set(() => demo.section = 'look'),
              title: demo.section == 'fees' ? 'রসিদের টেমপ্লেট' : 'চেহারা',
              child: BhorList(
                children: <Widget>[
                  BhorListRow(title: 'থিম', subtitle: 'সিস্টেম অনুযায়ী', onTap: () {}),
                  BhorListRow(title: 'ভাষা', subtitle: 'বাংলা', onTap: () {}),
                ],
              ),
            ),
          ),
          const SizedBox(height: BhorSpace.s12),
          Text('BhorFocusPage', style: b.type.label),
          const SizedBox(height: BhorSpace.s4),
          _Framed(
            height: 360,
            child: BhorFocusPage(
              title: 'হাজিরা · নবম গণিত',
              subtitle: 'শনিবার, ২১ নভেম্বর',
              onBack: () {},
              escToBack: false,
              summary: Text('${fmt.number(present)} উপস্থিত · ${fmt.number(demo.roll.length - present)} অনুপস্থিত'),
              primary: BhorButton(label: 'সংরক্ষণ', onPressed: () {}),
              body: Column(
                children: <Widget>[
                  for (int i = 0; i < roster.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: BhorSpace.s8),
                      child: Row(
                        children: <Widget>[
                          Expanded(child: Text(roster[i].$1, style: b.type.bodyStrong)),
                          BhorAttendanceToggle(
                            value: demo.roll[i],
                            iconOnly: true,
                            onChanged: (AttendanceKind k) => demo.set(() => demo.roll[i] = k),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
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
