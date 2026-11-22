// Per-batch class-reminder lead (UX 2h, Product 3.11): default (stores null),
// 5 / 10 / 15 / 20 / 30 / 60 minutes, "other" 1..180 (Bangla or ASCII digits)
// or off for this batch (0).
//
// One short single-choice list (BhorPanelKind.choice), the same look and
// behaviour as the Settings reminder chooser (review B8): a row per choice,
// a check on the chosen one, a tap picks it. "Other" opens a number field.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/widgets/digits_formatter.dart';
import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/core/format/app_format.dart';

/// What the sheet returns for "use the default" (the batch stores `null`). The
/// frozen signature has no way to say "null = chosen"; `null` means dismissed.
const int kReminderLeadUseDefault = -1;

/// Maps a sheet result to the value a batch stores (`null` = default,
/// `0` = off, 1..180); `null` when the sheet was dismissed.
int? storedLeadOf(int? sheetResult) =>
    sheetResult == kReminderLeadUseDefault ? null : sheetResult;

const List<int> kLeadPresets = <int>[5, 10, 15, 20, 30, 60];

/// [anchor] is the control that opened the chooser (the popover hangs from
/// it); without one the container uses the control just pressed.
Future<int?> openReminderLeadSheet(
  BuildContext context, {
  required int? current,
  required int defaultLead,
  BuildContext? anchor,
}) =>
    showBhorPanel<int>(
      context,
      kind: BhorPanelKind.choice,
      anchor: anchor,
      title: context.l10n.schedLeadTitle,
      builder: (BuildContext ctx) => ReminderLeadPanel(
        current: current,
        defaultLead: defaultLead,
        onDone: (int v) => Navigator.of(ctx).pop(v),
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    );

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
  final TextEditingController _custom = TextEditingController();

  /// The "other" field is open (the stored value is not a preset, or the
  /// teacher tapped "other").
  late bool _otherOpen;

  @override
  void initState() {
    super.initState();
    final int? cur = widget.current;
    _otherOpen = cur != null && cur != 0 && !kLeadPresets.contains(cur);
    if (_otherOpen) _custom.text = '$cur';
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

  bool get _customInvalid => _custom.text.trim().isNotEmpty && _customValue == null;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final BhorThemeData b = context.bhor;
    final int? cur = widget.current;

    String minutesBefore(int n) => l10n.schedMinutesBefore(fmt.digits('$n'));

    Widget row(String title, {required bool chosen, required VoidCallback onTap}) => BhorListRow(
          title: title,
          selected: chosen,
          divider: false,
          trailing: chosen ? Icon(BhorIcons.check, color: b.colors.accent) : null,
          onTap: onTap,
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(BhorSpace.s12, 0, BhorSpace.s12, BhorSpace.s8),
          child: Text(l10n.schedLeadSubtitle, style: b.type.body.copyWith(color: b.colors.text2)),
        ),
        row(
          l10n.schedLeadUseDefault(l10n.schedMinutes(fmt.digits('${widget.defaultLead}'))),
          chosen: cur == null,
          onTap: () => widget.onDone(kReminderLeadUseDefault),
        ),
        for (final int n in kLeadPresets)
          row(
            minutesBefore(n),
            chosen: cur == n,
            onTap: () => widget.onDone(n),
          ),
        row(
          l10n.schedLeadOther,
          chosen: _otherOpen,
          onTap: () => setState(() => _otherOpen = true),
        ),
        if (_otherOpen)
          Padding(
            padding: const EdgeInsets.fromLTRB(BhorSpace.s12, BhorSpace.s4, BhorSpace.s12, BhorSpace.s8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: BhorTextField(
                    controller: _custom,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      DigitsFormatter(context.fmt, maxLength: 3),
                    ],
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) {
                      final int? v = _customValue;
                      if (v != null) widget.onDone(v);
                    },
                    label: l10n.schedLeadCustomLabel,
                    error: _customInvalid ? l10n.schedLeadCustomError : null,
                  ),
                ),
                const SizedBox(width: BhorSpace.s8),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: BhorButton(
                    label: l10n.commonOk,
                    onPressed: _customValue == null ? null : () => widget.onDone(_customValue!),
                  ),
                ),
              ],
            ),
          ),
        row(
          l10n.schedLeadOff,
          chosen: cur == 0,
          onTap: () => widget.onDone(0),
        ),
      ],
    );
  }
}
