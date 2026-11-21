// BhorDatePicker (month grid, week starts on the Settings day, Bangla digits)
// and BhorTimePicker (period first: ভোর/সকাল/দুপুর/বিকাল/সন্ধ্যা/রাত, then
// hour, then 5-minute step), inline or in a BhorSheet.

import 'package:flutter/material.dart' show Icons;
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
        decoration: BoxDecoration(
          color: selected ? c.accent : (s.hovered ? c.surface2 : null),
          borderRadius: BorderRadius.circular(BhorRadius.chip),
          border: outlined && !selected ? Border.all(color: c.accentLine, width: 1.5) : null,
        ),
        child: Text(
          label,
          maxLines: 1,
          style: BhorType.tabular(selected ? b.type.bodyStrong : b.type.body).copyWith(
            color: onTap == null ? c.text3 : (selected ? c.onAccent : c.text),
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
  });

  final DateTime? selected;
  final ValueChanged<DateTime> onChanged;
  final DateTime firstDate;
  final DateTime lastDate;
  final int weekStart;

  /// Ringed day (pass the app clock's today; null rings nothing).
  final DateTime? today;

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
                if (day < 1 || day > daysInMonth) return const SizedBox(height: BhorSize.minTap);
                final DateTime d = DateTime(_shown.year, _shown.month, day);
                return Padding(
                  padding: const EdgeInsets.all(1),
                  child: _Cell(
                    label: fmt.digits('$day'),
                    semanticLabel: '${fmt.weekdayName(d.weekday)}, ${fmt.digits('$day')} ${fmt.monthName(d.month)}',
                    selected: sel == d,
                    outlined: today == d,
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
              icon: Icons.chevron_left_rounded,
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
              icon: Icons.chevron_right_rounded,
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

/// Opens a [BhorDatePicker] in a sheet; resolves with the tapped date.
/// Usage: `final d = await showBhorDatePicker(context, initialDate: now, firstDate: a, lastDate: z, weekStart: ws)`.
Future<DateTime?> showBhorDatePicker(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  int weekStart = DateTime.saturday,
  DateTime? today,
}) {
  return showBhorSheet<DateTime>(
    context,
    title: context.l10n.dsPickDate,
    builder: (BuildContext ctx) => SingleChildScrollView(
      child: BhorDatePicker(
        selected: initialDate,
        firstDate: firstDate,
        lastDate: lastDate,
        weekStart: weekStart,
        today: today,
        onChanged: (DateTime d) => Navigator.of(ctx).pop(d),
      ),
    ),
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
  const BhorTimePicker({super.key, required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int> onChanged;

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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          liveRegion: true,
          child: Text(
            widget.value == null ? '—' : fmt.time(widget.value!),
            textAlign: TextAlign.center,
            style: BhorType.tabular(b.type.display),
          ),
        ),
        heading(l10n.dsTimePeriod),
        grid(3, <Widget>[
          for (int p = 0; p < 6; p++)
            _Cell(
              key: ValueKey<String>('bhor-period-$p'),
              label: _periodLabel(l10n, p),
              selected: period == p,
              onTap: () => _pickPeriod(p),
            ),
        ]),
        if (period != null) ...<Widget>[
          heading(l10n.dsTimeHour),
          grid(4, <Widget>[
            for (final int h in kBhorPeriodHours[period])
              _Cell(
                key: ValueKey<String>('bhor-hour-$h'),
                label: _clock(fmt, h),
                semanticLabel: fmt.time(h * 60),
                selected: _hour == h,
                onTap: () => widget.onChanged(h * 60 + _minute),
              ),
          ]),
          heading(l10n.dsTimeMinute),
          grid(6, <Widget>[
            for (int m = 0; m < 60; m += 5)
              _Cell(
                key: ValueKey<String>('bhor-minute-$m'),
                label: fmt.digits(m.toString().padLeft(2, '0')),
                selected: _hour != null && _minute == m,
                onTap: _hour == null ? null : () => widget.onChanged(_hour! * 60 + m),
              ),
          ]),
        ],
      ],
    );
  }
}

/// Opens a [BhorTimePicker] in a sheet with a Done button; resolves with
/// minutes after midnight (null when dismissed).
/// Usage: `final m = await showBhorTimePicker(context, initial: 960)`.
Future<int?> showBhorTimePicker(BuildContext context, {int? initial}) {
  return showBhorSheet<int>(
    context,
    title: context.l10n.dsPickTime,
    builder: (BuildContext ctx) => _TimeSheet(initial: initial),
  );
}

class _TimeSheet extends StatefulWidget {
  const _TimeSheet({required this.initial});

  final int? initial;

  @override
  State<_TimeSheet> createState() => _TimeSheetState();
}

class _TimeSheetState extends State<_TimeSheet> {
  late int? _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          BhorTimePicker(value: _value, onChanged: (int v) => setState(() => _value = v)),
          const SizedBox(height: BhorSpace.s16),
          BhorButton(
            label: context.l10n.commonDone,
            expand: true,
            onPressed: _value == null ? null : () => Navigator.of(context).pop(_value),
          ),
        ],
      ),
    );
  }
}
