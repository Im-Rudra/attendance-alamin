// The app's date picker (QA-12): a month grid whose week starts on the day the
// teacher chose in Settings (Saturday by default), with Bangla digits and
// month names. Flutter's showDatePicker cannot take a week start without
// replacing the whole MaterialLocalizations, so this small dialog replaces it.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/core/settings/setting_keys.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/data/repositories/settings_providers.dart';

/// Same shape as `showDatePicker`; the week starts on the Settings week-start
/// day. Dates are date-only [DateTime]s.
Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) async {
  int weekStart = 6;
  try {
    final ProviderContainer container = ProviderScope.containerOf(context, listen: false);
    weekStart = await container.read(settingsRepositoryProvider).get(SettingKeys.weekStart);
  } catch (_) {
    weekStart = 6;
  }
  if (!context.mounted) return null;
  return showDialog<DateTime>(
    context: context,
    builder: (BuildContext ctx) => AppDatePickerDialog(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      weekStart: weekStart,
    ),
  );
}

class AppDatePickerDialog extends StatefulWidget {
  const AppDatePickerDialog({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    this.weekStart = 6,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  /// ISO weekday the grid starts on (6 Saturday, 7 Sunday, 1 Monday).
  final int weekStart;

  @override
  State<AppDatePickerDialog> createState() => _AppDatePickerDialogState();
}

class _AppDatePickerDialogState extends State<AppDatePickerDialog> {
  late DateTime _selected = _dateOnly(widget.initialDate);
  late YearMonth _shown = YearMonth(widget.initialDate.year, widget.initialDate.month);

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  YearMonth get _firstMonth => YearMonth(widget.firstDate.year, widget.firstDate.month);
  YearMonth get _lastMonth => YearMonth(widget.lastDate.year, widget.lastDate.month);

  bool _enabled(DateTime d) =>
      !d.isBefore(_dateOnly(widget.firstDate)) && !d.isAfter(_dateOnly(widget.lastDate));

  YearMonth _clamp(YearMonth ym) {
    if (ym.isBefore(_firstMonth)) return _firstMonth;
    if (ym.isAfter(_lastMonth)) return _lastMonth;
    return ym;
  }

  void _move(int months) {
    final int index = _shown.year * 12 + (_shown.month - 1) + months;
    setState(() => _shown = _clamp(YearMonth(index ~/ 12, index % 12 + 1)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;

    final int daysInMonth = DateTime(_shown.year, _shown.month + 1, 0).day;
    final int firstIso = DateTime(_shown.year, _shown.month, 1).weekday;
    final int offset = (firstIso - widget.weekStart + 7) % 7;
    final int cells = ((offset + daysInMonth + 6) ~/ 7) * 7;

    final bool canPrev = _shown.isAfter(_firstMonth);
    final bool canNext = _shown.isBefore(_lastMonth);

    final Widget header = Row(
      children: <Widget>[
        IconButton(
          tooltip: l10n.commonBack,
          icon: const Icon(Icons.chevron_left),
          onPressed: canPrev ? () => _move(-1) : null,
        ),
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: Text(
              fmt.monthYear(_shown),
              textAlign: TextAlign.center,
              style: tt.titleMedium?.copyWith(color: tokens.textPrimary, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        IconButton(
          tooltip: l10n.commonNext,
          icon: const Icon(Icons.chevron_right),
          onPressed: canNext ? () => _move(1) : null,
        ),
      ],
    );

    final Widget weekdays = Row(
      children: <Widget>[
        for (int i = 0; i < 7; i++)
          Expanded(
            child: Center(
              child: Text(
                fmt.weekdayShort((widget.weekStart - 1 + i) % 7 + 1),
                key: ValueKey<String>('dp-head-$i'),
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: tt.labelMedium?.copyWith(color: tokens.textSecondary),
              ),
            ),
          ),
      ],
    );

    Widget dayCell(int cell) {
      final int day = cell - offset + 1;
      if (day < 1 || day > daysInMonth) return const SizedBox(height: 40);
      final DateTime d = DateTime(_shown.year, _shown.month, day);
      final bool enabled = _enabled(d);
      final bool selected = d == _selected;
      return SizedBox(
        height: 40,
        child: Center(
          child: Semantics(
            button: true,
            selected: selected,
            enabled: enabled,
            label: fmt.date(LocalDate(d.year, d.month, d.day)),
            excludeSemantics: true,
            child: InkResponse(
              key: ValueKey<String>('dp-day-$day'),
              onTap: enabled ? () => setState(() => _selected = d) : null,
              radius: 22,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: selected ? tokens.accent : null,
                  shape: BoxShape.circle,
                ),
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: Center(
                    child: Text(
                      fmt.digits('$day'),
                      style: tt.bodyMedium?.copyWith(
                        color: selected
                            ? tokens.onAccent
                            : (enabled ? tokens.textPrimary : tokens.textDisabled),
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Dialog(
      backgroundColor: tokens.surfaceSolid,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              header,
              const SizedBox(height: 4),
              weekdays,
              const SizedBox(height: 4),
              for (int row = 0; row < cells ~/ 7; row++)
                Row(
                  children: <Widget>[
                    for (int col = 0; col < 7; col++) Expanded(child: dayCell(row * 7 + col)),
                  ],
                ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.commonCancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const ValueKey<String>('dp-ok'),
                    onPressed: _enabled(_selected) ? () => Navigator.of(context).pop(_selected) : null,
                    child: Text(l10n.commonOk),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
