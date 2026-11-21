// Per-batch class-reminder lead (UX 2h, Product 3.11): default (stores null),
// 5 / 10 / 15 / 20 / 30 / 60 minutes, "other" 1..180 (Bangla or ASCII digits)
// or off for this batch (0).

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/widgets/digits_formatter.dart';
import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/features/schedule/widgets/sched_chip.dart';
import 'package:attendance_alamin/features/schedule/widgets/sched_sheet.dart';

/// What the sheet returns for "use the default" (the batch stores `null`). The
/// frozen signature has no way to say "null = chosen"; `null` means dismissed.
const int kReminderLeadUseDefault = -1;

/// Maps a sheet result to the value a batch stores (`null` = default,
/// `0` = off, 1..180); `null` when the sheet was dismissed.
int? storedLeadOf(int? sheetResult) =>
    sheetResult == kReminderLeadUseDefault ? null : sheetResult;

const List<int> kLeadPresets = <int>[5, 10, 15, 20, 30, 60];

Future<int?> openReminderLeadSheet(
  BuildContext context, {
  required int? current,
  required int defaultLead,
}) =>
    showSchedSheet<int>(
      context,
      builder: (BuildContext ctx) => ReminderLeadPanel(
        current: current,
        defaultLead: defaultLead,
        onDone: (int v) => Navigator.of(ctx).pop(v),
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    );

enum _Choice { useDefault, preset, other, off }

class ReminderLeadPanel extends StatefulWidget {
  const ReminderLeadPanel({
    super.key,
    required this.current,
    required this.defaultLead,
    required this.onDone,
    required this.onCancel,
  });

  final int? current;
  final int defaultLead;
  final ValueChanged<int> onDone;
  final VoidCallback onCancel;

  @override
  State<ReminderLeadPanel> createState() => _ReminderLeadPanelState();
}

class _ReminderLeadPanelState extends State<ReminderLeadPanel> {
  late _Choice _choice;
  int _preset = 15;
  final TextEditingController _custom = TextEditingController();

  @override
  void initState() {
    super.initState();
    final int? cur = widget.current;
    if (cur == null) {
      _choice = _Choice.useDefault;
    } else if (cur == 0) {
      _choice = _Choice.off;
    } else if (kLeadPresets.contains(cur)) {
      _choice = _Choice.preset;
      _preset = cur;
    } else {
      _choice = _Choice.other;
      _custom.text = '$cur';
    }
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  /// The custom number, or null when empty / out of 1..180.
  int? get _customValue {
    final int? n = int.tryParse(AppFormat.toAsciiDigits(_custom.text.trim()));
    if (n == null || n < 1 || n > 180) return null;
    return n;
  }

  bool get _customInvalid =>
      _choice == _Choice.other && _custom.text.trim().isNotEmpty && _customValue == null;

  int? get _result => switch (_choice) {
        _Choice.useDefault => kReminderLeadUseDefault,
        _Choice.preset => _preset,
        _Choice.other => _customValue,
        _Choice.off => 0,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final BhorThemeData b = context.bhor;
    final int? result = _result;

    String minutesBefore(int n) => l10n.schedMinutesBefore(fmt.digits('$n'));

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(BhorSpace.s20, BhorSpace.s8, BhorSpace.s20, BhorSpace.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(header: true, child: Text(l10n.schedLeadTitle, style: b.type.title)),
            const SizedBox(height: 4),
            Text(l10n.schedLeadSubtitle, style: b.type.body.copyWith(color: b.colors.text2)),
            const SizedBox(height: 12),
            _RadioRow(
              label: l10n.schedLeadUseDefault(
                  l10n.schedMinutes(fmt.digits('${widget.defaultLead}'))),
              selected: _choice == _Choice.useDefault,
              onTap: () => setState(() => _choice = _Choice.useDefault),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final int n in kLeadPresets)
                  SchedChip(
                    label: minutesBefore(n),
                    selected: _choice == _Choice.preset && _preset == n,
                    onTap: () => setState(() {
                      _choice = _Choice.preset;
                      _preset = n;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _RadioRow(
              label: l10n.schedLeadOther,
              selected: _choice == _Choice.other,
              onTap: () => setState(() => _choice = _Choice.other),
            ),
            if (_choice == _Choice.other)
              Padding(
                padding: const EdgeInsets.fromLTRB(40, 4, 0, 4),
                child: BhorTextField(
                  controller: _custom,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    DigitsFormatter(context.fmt, maxLength: 3),
                  ],
                  onChanged: (_) => setState(() {}),
                  label: l10n.schedLeadCustomLabel,
                  error: _customInvalid ? l10n.schedLeadCustomError : null,
                ),
              ),
            const SizedBox(height: 8),
            _RadioRow(
              label: l10n.schedLeadOff,
              selected: _choice == _Choice.off,
              onTap: () => setState(() => _choice = _Choice.off),
            ),
            const SizedBox(height: 16),
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
                  child: BhorButton(
                    label: l10n.commonOk,
                    expand: true,
                    onPressed: result == null ? null : () => widget.onDone(result),
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

class _RadioRow extends StatelessWidget {
  const _RadioRow({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    return BhorPressable(
      onTap: onTap,
      semanticLabel: label,
      checked: selected,
      isButton: false,
      inMutuallyExclusiveGroup: true,
      excludeChildSemantics: true,
      builder: (BuildContext c, BhorStates st) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: BhorSize.minTap),
        child: Row(
          children: <Widget>[
            const SizedBox(width: BhorSpace.s8),
            Icon(
              selected ? BhorIcons.checkCircleFill : BhorIcons.checkCircle,
              color: selected ? b.colors.accent : b.colors.text2,
            ),
            const SizedBox(width: BhorSpace.s12),
            Expanded(child: Text(label, style: selected ? b.type.bodyStrong : b.type.body)),
          ],
        ),
      ),
    );
  }
}
