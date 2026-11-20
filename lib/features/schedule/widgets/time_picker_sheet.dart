// Period-first time picker (UX 2g): Bangla shows the day-period words, English
// AM / PM, so 7 am and 7 pm can never be confused. Hours of the chosen period,
// :00 :15 :30 :45 and "other minute" (every 5 minutes). Desktop also accepts a
// typed time. A bottom sheet on phones, a dialog on wide windows.

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/core/format/lexicon.dart';
import 'package:attendance_alamin/features/schedule/controllers/time_input_parser.dart';
import 'package:attendance_alamin/features/schedule/widgets/sched_chip.dart';

/// Hours (0..23) offered for each Bangla period, in display order.
const List<List<int>> kBanglaPeriodHours = <List<int>>[
  <int>[4, 5], // ভোর
  <int>[6, 7, 8, 9, 10, 11], // সকাল
  <int>[12, 13, 14], // দুপুর
  <int>[15, 16, 17], // বিকাল
  <int>[18, 19], // সন্ধ্যা
  <int>[20, 21, 22, 23, 0, 1, 2, 3], // রাত
];

/// Hours offered for AM (0) and PM (1).
const List<List<int>> kEnglishHalfHours = <List<int>>[
  <int>[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
  <int>[12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23],
];

Future<int?> openTimePicker(
  BuildContext context, {
  required int initialMin,
  String? title,
}) {
  final bool wide = WindowClass.of(context).isWide;
  final int start = initialMin % 1440;
  if (wide) {
    return showDialog<int>(
      context: context,
      builder: (BuildContext ctx) => Dialog(
        backgroundColor: ctx.aurora.surfaceSolid,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: TimePickerPanel(
            initialMin: start,
            title: title,
            allowTyping: true,
            onDone: (int v) => Navigator.of(ctx).pop(v),
            onCancel: () => Navigator.of(ctx).pop(),
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (BuildContext ctx) => TimePickerPanel(
      initialMin: start,
      title: title,
      allowTyping: false,
      onDone: (int v) => Navigator.of(ctx).pop(v),
      onCancel: () => Navigator.of(ctx).pop(),
    ),
  );
}

class TimePickerPanel extends StatefulWidget {
  const TimePickerPanel({
    super.key,
    required this.initialMin,
    required this.onDone,
    required this.onCancel,
    this.title,
    this.allowTyping = false,
  });

  final int initialMin;
  final String? title;
  final bool allowTyping;
  final ValueChanged<int> onDone;
  final VoidCallback onCancel;

  @override
  State<TimePickerPanel> createState() => _TimePickerPanelState();
}

class _TimePickerPanelState extends State<TimePickerPanel> {
  late int _min = widget.initialMin;
  late bool _otherMinutes = _min % 15 != 0;
  final TextEditingController _typed = TextEditingController();
  bool _typedBad = false;

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  int get _hour => _min ~/ 60;
  int get _minute => _min % 60;

  bool get _bn => context.lang == Lang.bn;

  /// Index of the period (bn) or half (en) the time is in.
  int get _group => _bn ? Lexicon.periodIndex(_min) : (_min >= 720 ? 1 : 0);

  List<List<int>> get _groups => _bn ? kBanglaPeriodHours : kEnglishHalfHours;

  void _setGroup(int g) {
    final hours = _groups[g];
    final int twelve = _hour % 12;
    final int pick = hours.firstWhere((int h) => h % 12 == twelve,
        orElse: () => hours.first);
    setState(() => _min = pick * 60 + _minute);
  }

  void _setHour(int h) => setState(() => _min = h * 60 + _minute);

  void _setMinute(int m) => setState(() => _min = _hour * 60 + m);

  void _onTyped(String text) {
    if (text.trim().isEmpty) {
      setState(() => _typedBad = false);
      return;
    }
    final int? parsed = parseTimeInput(text, hintMin: _min);
    setState(() {
      if (parsed == null) {
        _typedBad = true;
      } else {
        _typedBad = false;
        _min = parsed;
        if (_min % 15 != 0) _otherMinutes = true;
      }
    });
  }

  String _hourLabel(int h) => context.fmt.digits('${h % 12 == 0 ? 12 : h % 12}');

  String _minuteLabel(int m) => context.fmt.digits(':${m.toString().padLeft(2, '0')}');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final fmt = context.fmt;
    final List<int> hours = _groups[_group];

    final Widget readout = Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.accentContainer,
          borderRadius: BorderRadius.circular(AuroraMetrics.radiusDenseList),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Center(
            child: Text(
              fmt.time(_min),
              style: tt.headlineMedium?.copyWith(
                color: tokens.onAccentContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );

    final Widget periodBar = LayoutBuilder(
      builder: (BuildContext _, BoxConstraints c) {
        final int count = _groups.length;
        final int cols = _bn && c.maxWidth < 440 ? 3 : count;
        const double gap = 8;
        final double w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (var g = 0; g < count; g++)
              SizedBox(
                width: w,
                child: SchedChip(
                  label: _bn ? Lexicon.periodsBn[g] : (g == 0 ? 'AM' : 'PM'),
                  selected: g == _group,
                  onTap: () => _setGroup(g),
                ),
              ),
          ],
        );
      },
    );

    final Widget hourGrid = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final int h in hours)
          SchedChip(
            label: _hourLabel(h),
            selected: h == _hour,
            minWidth: 56,
            onTap: () => _setHour(h),
          ),
      ],
    );

    final Widget minuteRow = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final int m in const <int>[0, 15, 30, 45])
          SchedChip(
            label: _minuteLabel(m),
            selected: m == _minute,
            minWidth: 56,
            onTap: () => _setMinute(m),
          ),
        SchedChip(
          label: l10n.schedOtherMinute,
          selected: _otherMinutes,
          leading: _otherMinutes ? Icons.expand_less : Icons.expand_more,
          onTap: () => setState(() => _otherMinutes = !_otherMinutes),
        ),
      ],
    );

    final Widget fiveMinuteGrid = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (var m = 0; m < 60; m += 5)
          SchedChip(
            label: _minuteLabel(m),
            selected: m == _minute,
            minWidth: 56,
            onTap: () => _setMinute(m),
          ),
      ],
    );

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(widget.title ?? l10n.schedPickTime, style: tt.titleLarge),
            ),
            const SizedBox(height: 12),
            readout,
            const SizedBox(height: 16),
            periodBar,
            const SizedBox(height: 12),
            hourGrid,
            const SizedBox(height: 12),
            minuteRow,
            if (_otherMinutes) ...<Widget>[
              const SizedBox(height: 8),
              fiveMinuteGrid,
            ],
            if (widget.allowTyping) ...<Widget>[
              const SizedBox(height: 16),
              TextField(
                controller: _typed,
                onChanged: _onTyped,
                onSubmitted: (_) {
                  if (!_typedBad) widget.onDone(_min);
                },
                decoration: InputDecoration(
                  labelText: l10n.schedTypeTime,
                  hintText: l10n.schedTypeHint,
                  errorText: _typedBad ? l10n.schedTypeError : null,
                  helperText: !_typedBad && _typed.text.trim().isNotEmpty
                      ? l10n.schedTypeEcho(fmt.time(_min))
                      : null,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onCancel,
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    child: Text(l10n.commonCancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _typedBad ? null : () => widget.onDone(_min),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    child: Text(l10n.commonOk),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
