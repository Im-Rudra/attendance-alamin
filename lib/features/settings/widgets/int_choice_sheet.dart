// A short single-choice list that picks one whole number: tappable presets and,
// when a range is given, an "another number" field that accepts Bangla or
// Latin digits. Used for the default reminder lead, the billing cutoff day and
// the backup reminder interval. On desktop it is a narrow popover anchored to
// the row that opened it (BhorPanelKind.choice); on phones a bottom sheet.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/widgets/digits_formatter.dart';
import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/core/format/app_format.dart';

/// Parses typed digits (Bangla or Latin) and checks [min]..[max]; null when the
/// text is not a whole number in range.
int? parseNumberInRange(String raw, {required int min, required int max}) {
  final String t = AppFormat.toAsciiDigits(raw.trim());
  if (t.isEmpty) return null;
  final int? v = int.tryParse(t);
  if (v == null || v < min || v > max) return null;
  return v;
}

/// Shows the choice anchored to [context] (pass the row's own context);
/// returns the picked number or null when dismissed.
Future<int?> showIntChoiceSheet(
  BuildContext context, {
  required String title,
  required List<int> options,
  required int? current,
  required String Function(int value) labelOf,
  int? customMin,
  int? customMax,
}) {
  return showBhorPanel<int>(
    context,
    kind: BhorPanelKind.choice,
    title: title,
    builder: (BuildContext ctx) => IntChoiceSheet(
      title: title,
      options: options,
      current: current,
      labelOf: labelOf,
      customMin: customMin,
      customMax: customMax,
    ),
  );
}

class IntChoiceSheet extends StatefulWidget {
  const IntChoiceSheet({
    super.key,
    required this.title,
    required this.options,
    required this.current,
    required this.labelOf,
    this.customMin,
    this.customMax,
  });

  final String title;
  final List<int> options;
  final int? current;
  final String Function(int value) labelOf;
  final int? customMin;
  final int? customMax;

  @override
  State<IntChoiceSheet> createState() => _IntChoiceSheetState();
}

class _IntChoiceSheetState extends State<IntChoiceSheet> {
  TextEditingController? _customController;
  bool _invalid = false;

  bool get _hasCustom => widget.customMin != null && widget.customMax != null;

  @override
  void dispose() {
    _customController?.dispose();
    super.dispose();
  }

  TextEditingController get _custom => _customController ??= TextEditingController(
        text: widget.current != null && !widget.options.contains(widget.current)
            ? context.fmt.digits(widget.current.toString())
            : '',
      );

  void _apply() {
    final int? v = parseNumberInRange(_custom.text, min: widget.customMin!, max: widget.customMax!);
    if (v == null) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.of(context).pop(v);
  }

  @override
  Widget build(BuildContext context) {
    final BhorColors c = context.bhor.colors;
    final l10n = context.l10n;
    final String range = _hasCustom
        ? l10n.setCustomRange(
            context.fmt.digits(widget.customMin.toString()),
            context.fmt.digits(widget.customMax.toString()),
          )
        : '';
    // The container scrolls; this is just the column of choices.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final int o in widget.options)
          BhorListRow(
            title: widget.labelOf(o),
            selected: o == widget.current,
            divider: false,
            trailing: o == widget.current ? Icon(BhorIcons.check, color: c.accent) : null,
            onTap: () => Navigator.of(context).pop(o),
          ),
        if (_hasCustom)
          Padding(
            padding: const EdgeInsets.only(top: BhorSpace.s8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: BhorTextField(
                    controller: _custom,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    inputFormatters: <TextInputFormatter>[
                      DigitsFormatter(context.fmt, maxLength: 4),
                    ],
                    label: l10n.setCustomOther,
                    helper: range,
                    error: _invalid ? range : null,
                    onChanged: (_) {
                      if (_invalid) setState(() => _invalid = false);
                    },
                    onSubmitted: (_) => _apply(),
                  ),
                ),
                const SizedBox(width: BhorSpace.s12),
                Padding(
                  padding: const EdgeInsets.only(top: 22),
                  child: BhorButton(label: l10n.setCustomApply, onPressed: _apply),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
