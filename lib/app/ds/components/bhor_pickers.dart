// BhorDatePicker (month grid, week starts on the Settings day, Bangla digits)
// and BhorTimePicker (period first: ভোর/সকাল/দুপুর/বিকাল/সন্ধ্যা/রাত, then
// hour, then 5-minute step), inline or opened by showBhorDatePicker /
// showBhorTimePicker: a bottom sheet on phones, a popover anchored to the
// field that opened it on desktop (>= 840; a centred dialog when there is no
// field to anchor to). Never a sheet on desktop.

import 'package:attendance_alamin/app/ds/foundation/bhor_icons.dart';
import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/components/bhor_button.dart';
import 'package:attendance_alamin/app/ds/components/bhor_overlays.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_interaction.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_theme.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_tokens.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/core/format/lexicon.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Small square choice cell shared by both pickers.
class _Cell extends StatelessWidget {
  const _Cell({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.outlined = false,
    this.semanticLabel,
    this.height = BhorSize.minTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool outlined;
  final String? semanticLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    return BhorPressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: semanticLabel ?? label,
      excludeChildSemantics: true,
      radius: BhorRadius.chip,
      builder: (BuildContext context, BhorStates s) => AnimatedContainer(
        duration: BhorMotion.fast,
        height: height,
        alignment: Alignment.center,
        // Selected = solid accent; today ([outlined], the older name) = the
        // accent tint with accent text. Filled, never a ring (review L1).
        decoration: BoxDecoration(
          color: selected
              ? c.accentFill
              : outlined
                  ? (s.hovered ? c.accentLine : c.accentTint)
                  : (s.hovered ? c.surface2 : null),
          borderRadius: BorderRadius.circular(BhorRadius.chip),
        ),
        child: Text(
          label,
          maxLines: 1,
          style: BhorType.tabular(selected || outlined ? b.type.bodyStrong : b.type.body).copyWith(
            color: onTap == null
                ? c.text3
                : selected
                    ? c.onAccentFill
                    : (outlined ? c.accent : c.text),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- Date ----

/// Inline month calendar. [weekStart] is the ISO weekday the grid starts on
/// (6 Saturday, the app default; 7 Sunday; 1 Monday).
/// Usage: `BhorDatePicker(selected: d, firstDate: a, lastDate: z, weekStart: 6, onChanged: f)`.
class BhorDatePicker extends StatefulWidget {
  const BhorDatePicker({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.firstDate,
    required this.lastDate,
    this.weekStart = DateTime.saturday,
    this.today,
    this.cellHeight = BhorSize.minTap,
  });

  final DateTime? selected;
  final ValueChanged<DateTime> onChanged;
  final DateTime firstDate;
  final DateTime lastDate;
  final int weekStart;

  /// Marked day (pass the app clock's today; null marks nothing): a filled
  /// accent-tint cell, never a ring.
  final DateTime? today;

  /// Height of a day cell (40 in the desktop popover).
  final double cellHeight;

  @override
  State<BhorDatePicker> createState() => _BhorDatePickerState();
}

class _BhorDatePickerState extends State<BhorDatePicker> {
  late YearMonth _shown = _initialMonth();

  YearMonth _initialMonth() {
    final DateTime d = widget.selected ?? widget.today ?? widget.firstDate;
    return _clamp(YearMonth(d.year, d.month));
  }

  YearMonth get _first => YearMonth(widget.firstDate.year, widget.firstDate.month);
  YearMonth get _last => YearMonth(widget.lastDate.year, widget.lastDate.month);

  YearMonth _clamp(YearMonth ym) {
    if (ym.isBefore(_first)) return _first;
    if (ym.isAfter(_last)) return _last;
    return ym;
  }

  bool _enabled(DateTime d) =>
      !d.isBefore(_dateOnly(widget.firstDate)) && !d.isAfter(_dateOnly(widget.lastDate));

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final AppFormat fmt = context.fmt;
    final AppLocalizations l10n = context.l10n;

    final int daysInMonth = DateTime(_shown.year, _shown.month + 1, 0).day;
    final int firstIso = DateTime(_shown.year, _shown.month, 1).weekday;
    final int offset = (firstIso - widget.weekStart + 7) % 7;
    final int cells = ((offset + daysInMonth + 6) ~/ 7) * 7;
    final DateTime? sel = widget.selected == null ? null : _dateOnly(widget.selected!);
    final DateTime? today = widget.today == null ? null : _dateOnly(widget.today!);

    final List<Widget> rows = <Widget>[];
    for (int r = 0; r < cells ~/ 7; r++) {
      rows.add(Row(
        children: <Widget>[
          for (int col = 0; col < 7; col++)
            Expanded(
              child: Builder(builder: (BuildContext context) {
                final int day = r * 7 + col - offset + 1;
                if (day < 1 || day > daysInMonth) return SizedBox(height: widget.cellHeight);
                final DateTime d = DateTime(_shown.year, _shown.month, day);
                return Padding(
                  padding: const EdgeInsets.all(1),
                  child: _Cell(
                    label: fmt.digits('$day'),
                    semanticLabel: '${fmt.weekdayName(d.weekday)}, ${fmt.digits('$day')} ${fmt.monthName(d.month)}',
                    selected: sel == d,
                    outlined: today == d,
                    height: widget.cellHeight,
                    onTap: _enabled(d) ? () => widget.onChanged(d) : null,
                  ),
                );
              }),
            ),
        ],
      ));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            BhorIconButton(
              icon: BhorIcons.chevronLeft,
              semanticLabel: l10n.dsPrevMonth,
              onPressed: _shown.isAfter(_first) ? () => setState(() => _shown = _shown.addMonths(-1)) : null,
            ),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(fmt.monthYear(_shown), textAlign: TextAlign.center, style: b.type.heading),
              ),
            ),
            BhorIconButton(
              icon: BhorIcons.chevronRight,
              semanticLabel: l10n.dsNextMonth,
              onPressed: _shown.isBefore(_last) ? () => setState(() => _shown = _shown.addMonths(1)) : null,
            ),
          ],
        ),
        const SizedBox(height: BhorSpace.s4),
        ExcludeSemantics(
          child: Row(
            children: <Widget>[
              for (int i = 0; i < 7; i++)
                Expanded(
                  child: Text(
                    fmt.weekdayShort((widget.weekStart - 1 + i) % 7 + 1),
                    key: ValueKey<String>('bhor-weekday-$i'),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: b.type.caption.copyWith(color: c.text3, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: BhorSpace.s4),
        ...rows,
      ],
    );
  }
}

/// Opens a [BhorDatePicker]; resolves with the tapped date. Phone: a
/// bottom sheet. Desktop: a popover calendar (40 px cells) anchored to
/// [anchor] (default: [context] when it is the date field, else the control
/// just tapped), a centred dialog when there is nothing to anchor to.
/// Usage: `final d = await showBhorDatePicker(context, initialDate: now, firstDate: a, lastDate: z, weekStart: ws)`.
Future<DateTime?> showBhorDatePicker(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  int weekStart = DateTime.saturday,
  DateTime? today,
  BuildContext? anchor,
}) {
  final bool wide = context.bhorIsWide;
  Widget picker(BuildContext ctx) => BhorDatePicker(
        selected: initialDate,
        firstDate: firstDate,
        lastDate: lastDate,
        weekStart: weekStart,
        today: today,
        cellHeight: wide ? 40 : BhorSize.minTap,
        onChanged: (DateTime d) => Navigator.of(ctx).pop(d),
      );
  if (wide) {
    return showBhorPopover<DateTime>(
      context,
      anchor: anchor,
      title: context.l10n.dsPickDate,
      width: 336,
      padding: const EdgeInsets.fromLTRB(BhorSpace.s8, 0, BhorSpace.s8, BhorSpace.s8),
      builder: picker,
    );
  }
  return showBhorSheet<DateTime>(
    context,
    title: context.l10n.dsPickDate,
    builder: (BuildContext ctx) => SingleChildScrollView(child: picker(ctx)),
  );
}

// ----------------------------------------------------------------- Time ----

/// 24-hour clock hours of each day period, in picker order.
const List<List<int>> kBhorPeriodHours = <List<int>>[
  <int>[4, 5],
  <int>[6, 7, 8, 9, 10, 11],
  <int>[12, 13, 14],
  <int>[15, 16, 17],
  <int>[18, 19],
  <int>[20, 21, 22, 23, 0, 1, 2, 3],
];

String _periodLabel(AppLocalizations l10n, int i) => switch (i) {
      0 => l10n.dsPeriodDawn,
      1 => l10n.dsPeriodMorning,
      2 => l10n.dsPeriodNoon,
      3 => l10n.dsPeriodAfternoon,
      4 => l10n.dsPeriodEvening,
      _ => l10n.dsPeriodNight,
    };

/// Inline time picker: period, then hour, then minute (5-minute steps).
/// [value] is minutes after midnight. Usage: `BhorTimePicker(value: 960, onChanged: f)`.
class BhorTimePicker extends StatefulWidget {
  const BhorTimePicker({super.key, required this.value, required this.onChanged, this.columns = false});

  final int? value;
  final ValueChanged<int> onChanged;

  /// Period · hour · minute side by side (the desktop popover) instead of
  /// stacked.
  final bool columns;

  @override
  State<BhorTimePicker> createState() => _BhorTimePickerState();
}

class _BhorTimePickerState extends State<BhorTimePicker> {
  late int? _period = widget.value == null ? null : Lexicon.periodIndex(widget.value!);

  @override
  void didUpdateWidget(BhorTimePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != null) {
      _period = Lexicon.periodIndex(widget.value!);
    }
  }

  int? get _hour => widget.value == null ? null : (widget.value! ~/ 60) % 24;
  int get _minute => widget.value == null ? 0 : (widget.value! % 60) ~/ 5 * 5;

  void _pickPeriod(int p) {
    setState(() => _period = p);
    final List<int> hours = kBhorPeriodHours[p];
    if (_hour == null || !hours.contains(_hour)) {
      widget.onChanged(hours.first * 60 + _minute);
    }
  }

  String _clock(AppFormat fmt, int h) => fmt.digits('${h % 12 == 0 ? 12 : h % 12}');

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final AppFormat fmt = context.fmt;
    final AppLocalizations l10n = context.l10n;
    Widget heading(String t) => Padding(
          padding: const EdgeInsets.only(top: BhorSpace.s12, bottom: BhorSpace.s4),
          child: Semantics(header: true, child: Text(t, style: b.type.label.copyWith(color: b.colors.text2))),
        );
    Widget grid(int perRow, List<Widget> cells) {
      final List<Widget> rows = <Widget>[];
      for (int i = 0; i < cells.length; i += perRow) {
        rows.add(Row(
          children: <Widget>[
            for (int j = i; j < i + perRow; j++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: j < cells.length ? cells[j] : const SizedBox.shrink(),
                ),
              ),
          ],
        ));
      }
      return Column(mainAxisSize: MainAxisSize.min, children: rows);
    }

    final int? period = _period;
    final double cellH = widget.columns ? 40 : BhorSize.minTap;
    final List<Widget> periods = <Widget>[
      for (int p = 0; p < 6; p++)
        _Cell(
          key: ValueKey<String>('bhor-period-$p'),
          label: _periodLabel(l10n, p),
          selected: period == p,
          height: cellH,
          onTap: () => _pickPeriod(p),
        ),
    ];
    final List<Widget> hours = <Widget>[
      if (period != null)
        for (final int h in kBhorPeriodHours[period])
          _Cell(
            key: ValueKey<String>('bhor-hour-$h'),
            label: _clock(fmt, h),
            semanticLabel: fmt.time(h * 60),
            selected: _hour == h,
            height: cellH,
            onTap: () => widget.onChanged(h * 60 + _minute),
          ),
    ];
    final List<Widget> minutes = <Widget>[
      for (int m = 0; m < 60; m += 5)
        _Cell(
          key: ValueKey<String>('bhor-minute-$m'),
          label: fmt.digits(m.toString().padLeft(2, '0')),
          selected: _hour != null && _minute == m,
          height: cellH,
          onTap: _hour == null ? null : () => widget.onChanged(_hour! * 60 + m),
        ),
    ];
    final Widget readout = Semantics(
      liveRegion: true,
      child: Text(
        widget.value == null ? '—' : fmt.time(widget.value!),
        textAlign: TextAlign.center,
        style: BhorType.tabular(widget.columns ? b.type.title : b.type.display),
      ),
    );
    if (widget.columns) {
      Widget column(String title, Widget body) => Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[heading(title), body],
            ),
          );
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          readout,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              column(l10n.dsTimePeriod, grid(1, periods)),
              const SizedBox(width: BhorSpace.s8),
              column(l10n.dsTimeHour, grid(2, hours)),
              const SizedBox(width: BhorSpace.s8),
              column(l10n.dsTimeMinute, grid(3, minutes)),
            ],
          ),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        readout,
        heading(l10n.dsTimePeriod),
        grid(3, periods),
        if (period != null) ...<Widget>[
          heading(l10n.dsTimeHour),
          grid(4, hours),
          heading(l10n.dsTimeMinute),
          grid(6, minutes),
        ],
      ],
    );
  }
}

/// Opens a [BhorTimePicker] with a Done button; resolves with minutes
/// after midnight. The pick applies live: [onChanged] fires on every tap and
/// Done only closes, so an outside click or Esc keeps the current selection
/// (the future still resolves with it; null only when nothing was ever
/// chosen). Phone: a bottom sheet (title and ✕ on one row). Desktop: a
/// 3-column popover (period · hour · minute) anchored to [anchor] / the field
/// that opened it, a centred dialog when there is nothing to anchor to. Done
/// sits in a pinned footer, so it is visible even in a short window.
/// [title] names the time being picked (default "সময় বেছে নিন").
/// Usage: `final m = await showBhorTimePicker(context, initial: 960, title: 'শুরু')`.
Future<int?> showBhorTimePicker(
  BuildContext context, {
  int? initial,
  String? title,
  BuildContext? anchor,
  ValueChanged<int>? onChanged,
}) async {
  final String t = title ?? context.l10n.dsPickTime;
  final ValueNotifier<int?> value = ValueNotifier<int?>(initial);
  final bool wide = context.bhorIsWide;
  Widget body(BuildContext ctx) => _TimeSheet(value: value, columns: wide, onChanged: onChanged);
  Widget footer(BuildContext ctx) => ValueListenableBuilder<int?>(
        valueListenable: value,
        builder: (BuildContext c, int? v, Widget? _) => BhorButton(
          label: c.l10n.commonDone,
          expand: true,
          onPressed: v == null ? null : () => Navigator.of(c).pop(v),
        ),
      );
  // Not disposed: the exit animation still listens after the future resolves.
  final int? popped = wide
      ? await showBhorPopover<int>(
          context,
          anchor: anchor,
          title: t,
          width: 460,
          padding: const EdgeInsets.fromLTRB(BhorSpace.s12, 0, BhorSpace.s12, BhorSpace.s12),
          builder: body,
          footer: footer,
        )
      : await showBhorSheet<int>(context, title: t, builder: body, footer: footer);
  return popped ?? value.value;
}

class _TimeSheet extends StatelessWidget {
  const _TimeSheet({required this.value, required this.onChanged, this.columns = false});

  final ValueNotifier<int?> value;
  final ValueChanged<int>? onChanged;
  final bool columns;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int?>(
        valueListenable: value,
        builder: (BuildContext c, int? v, Widget? _) => BhorTimePicker(
          value: v,
          columns: columns,
          onChanged: (int m) {
            value.value = m;
            onChanged?.call(m);
          },
        ),
      );
}
