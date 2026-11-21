// "কবে থেকে নতুন সময়?" (UX 2g): [আজ থেকে] / [তারিখ বাছুন]. Past classes and
// attendance never change (Product 3.9). Returns the chosen date or null.

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/features/schedule/widgets/sched_sheet.dart';

Future<LocalDate?> askEffectiveFrom(BuildContext context, {required LocalDate today}) =>
    showSchedSheet<LocalDate>(
      context,
      builder: (BuildContext ctx) => EffectiveFromPanel(
        today: today,
        onDone: (LocalDate d) => Navigator.of(ctx).pop(d),
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    );

class EffectiveFromPanel extends StatefulWidget {
  const EffectiveFromPanel({
    super.key,
    required this.today,
    required this.onDone,
    required this.onCancel,
  });

  final LocalDate today;
  final ValueChanged<LocalDate> onDone;
  final VoidCallback onCancel;

  @override
  State<EffectiveFromPanel> createState() => _EffectiveFromPanelState();
}

class _EffectiveFromPanelState extends State<EffectiveFromPanel> {
  LocalDate? _picked;
  bool _useToday = true;

  LocalDate get _date => _useToday ? widget.today : (_picked ?? widget.today);

  Future<void> _pick() async {
    final LocalDate t = widget.today;
    final DateTime? d = await showAppDatePicker(
      context: context,
      initialDate: DateTime(_date.year, _date.month, _date.day),
      firstDate: DateTime(t.year, t.month, t.day),
      lastDate: DateTime(t.year + 2, t.month, t.day),
    );
    if (d == null || !mounted) return;
    setState(() {
      _picked = LocalDate(d.year, d.month, d.day);
      _useToday = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final LocalDate? picked = _picked;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(header: true, child: Text(l10n.schedFromTitle, style: tt.titleLarge)),
            const SizedBox(height: 16),
            SegmentedChoice<bool>(
              options: const <bool>[true, false],
              selected: _useToday,
              onChanged: (bool today) {
                if (today) {
                  setState(() => _useToday = true);
                } else {
                  _pick();
                }
              },
              labelOf: (bool today) => today
                  ? l10n.schedFromToday
                  : (picked == null
                      ? l10n.schedFromPick
                      : l10n.schedFromPicked(fmt.date(picked))),
            ),
            const SizedBox(height: 12),
            Text(l10n.schedFromHint,
                style: tt.bodyMedium?.copyWith(color: tokens.textSecondary)),
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
                    onPressed: () => widget.onDone(_date),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    child: Text(l10n.commonSave),
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
