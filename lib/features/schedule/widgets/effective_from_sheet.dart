// "কবে থেকে নতুন সময়?" (UX 2g): [আজ থেকে] / [তারিখ বাছুন]. Past classes and
// attendance never change (Product 3.9). Returns the chosen date or null.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/features/schedule/widgets/sched_sheet.dart';

Future<LocalDate?> askEffectiveFrom(BuildContext context, {required LocalDate today}) {
  final int weekStart =
      ProviderScope.containerOf(context, listen: false).read(weekStartProvider).value ?? DateTime.saturday;
  return showSchedSheet<LocalDate>(
    context,
    builder: (BuildContext ctx) => EffectiveFromPanel(
      today: today,
      weekStart: weekStart,
      onDone: (LocalDate d) => Navigator.of(ctx).pop(d),
      onCancel: () => Navigator.of(ctx).pop(),
    ),
  );
}

class EffectiveFromPanel extends StatefulWidget {
  const EffectiveFromPanel({
    super.key,
    required this.today,
    required this.onDone,
    required this.onCancel,
    this.weekStart = DateTime.saturday,
  });

  final LocalDate today;
  final ValueChanged<LocalDate> onDone;
  final VoidCallback onCancel;

  /// ISO weekday the date picker's week starts on (the app setting).
  final int weekStart;

  @override
  State<EffectiveFromPanel> createState() => _EffectiveFromPanelState();
}

class _EffectiveFromPanelState extends State<EffectiveFromPanel> {
  LocalDate? _picked;
  bool _useToday = true;

  LocalDate get _date => _useToday ? widget.today : (_picked ?? widget.today);

  Future<void> _pick() async {
    final LocalDate t = widget.today;
    final DateTime? d = await showBhorDatePicker(
      context,
      initialDate: DateTime(_date.year, _date.month, _date.day),
      firstDate: DateTime(t.year, t.month, t.day),
      lastDate: DateTime(t.year + 2, t.month, t.day),
      weekStart: widget.weekStart,
      today: DateTime(t.year, t.month, t.day),
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
    final BhorThemeData b = context.bhor;
    final LocalDate? picked = _picked;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(BhorSpace.s20, BhorSpace.s8, BhorSpace.s20, BhorSpace.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(header: true, child: Text(l10n.schedFromTitle, style: b.type.title)),
            const SizedBox(height: BhorSpace.s16),
            BhorSegmented<bool>(
              segments: <BhorSegment<bool>>[
                BhorSegment<bool>(value: true, label: l10n.schedFromToday),
                BhorSegment<bool>(
                  value: false,
                  label: picked == null ? l10n.schedFromPick : l10n.schedFromPicked(fmt.date(picked)),
                ),
              ],
              value: _useToday,
              onChanged: (bool today) {
                if (today) {
                  setState(() => _useToday = true);
                } else {
                  _pick();
                }
              },
            ),
            const SizedBox(height: BhorSpace.s12),
            Text(l10n.schedFromHint, style: b.type.body.copyWith(color: b.colors.text2)),
            const SizedBox(height: BhorSpace.s16),
            Row(
              children: <Widget>[
                Expanded(
                  child: BhorButton(
                    label: l10n.commonCancel,
                    variant: BhorButtonVariant.secondary,
                    expand: true,
                    onPressed: widget.onCancel,
                  ),
                ),
                const SizedBox(width: BhorSpace.s12),
                Expanded(
                  child: BhorButton(label: l10n.commonSave, expand: true, onPressed: () => widget.onDone(_date)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
