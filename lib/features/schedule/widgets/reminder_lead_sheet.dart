// Per-batch class-reminder lead (UX 2h, Product 3.11): default (stores null),
// 5 / 10 / 15 / 20 / 30 / 60 minutes, "other" 1..180 (Bangla or ASCII digits)
// or off for this batch (0).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
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
    final TextTheme tt = Theme.of(context).textTheme;
    final tokens = context.aurora;
    final int? result = _result;

    String minutesBefore(int n) => l10n.schedMinutesBefore(fmt.digits('$n'));

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            20, 8, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(header: true, child: Text(l10n.schedLeadTitle, style: tt.titleLarge)),
            const SizedBox(height: 4),
            Text(l10n.schedLeadSubtitle,
                style: tt.bodyMedium?.copyWith(color: tokens.textSecondary)),
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
                child: TextField(
                  controller: _custom,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp('[0-9০-৯]')),
                    LengthLimitingTextInputFormatter(3),
                  ],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: l10n.schedLeadCustomLabel,
                    errorText: _customInvalid ? l10n.schedLeadCustomError : null,
                  ),
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
                  child: OutlinedButton(
                    onPressed: widget.onCancel,
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    child: Text(l10n.commonCancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: result == null ? null : () => widget.onDone(result),
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

class _RadioRow extends StatelessWidget {
  const _RadioRow({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        borderRadius: BorderRadius.circular(AuroraMetrics.radiusField),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: <Widget>[
              const SizedBox(width: 8),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: selected ? tokens.accent : tokens.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: tt.bodyLarge?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
