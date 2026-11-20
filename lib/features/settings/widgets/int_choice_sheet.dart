// A bottom sheet that picks one whole number: tappable presets and, when a
// range is given, an "another number" field that accepts Bangla or Latin
// digits. Used for the default reminder lead, the billing cutoff day and the
// backup reminder interval.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
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

/// Shows the sheet; returns the picked number or null when dismissed.
Future<int?> showIntChoiceSheet(
  BuildContext context, {
  required String title,
  required List<int> options,
  required int? current,
  required String Function(int value) labelOf,
  int? customMin,
  int? customMax,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 560),
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
    final tokens = context.aurora;
    final l10n = context.l10n;
    final TextTheme tt = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Semantics(
                header: true,
                child: Text(widget.title, style: tt.titleMedium),
              ),
            ),
            for (final int o in widget.options)
              ListTile(
                minTileHeight: 52,
                title: Text(widget.labelOf(o)),
                selected: o == widget.current,
                selectedColor: tokens.accent,
                trailing: o == widget.current ? Icon(Icons.check, color: tokens.accent) : null,
                onTap: () => Navigator.of(context).pop(o),
              ),
            if (_hasCustom)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _custom,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9০-৯]')),
                          LengthLimitingTextInputFormatter(4),
                        ],
                        decoration: InputDecoration(
                          labelText: l10n.setCustomOther,
                          helperText: l10n.setCustomRange(
                            context.fmt.digits(widget.customMin.toString()),
                            context.fmt.digits(widget.customMax.toString()),
                          ),
                          errorText: _invalid
                              ? l10n.setCustomRange(
                                  context.fmt.digits(widget.customMin.toString()),
                                  context.fmt.digits(widget.customMax.toString()),
                                )
                              : null,
                        ),
                        onChanged: (_) {
                          if (_invalid) setState(() => _invalid = false);
                        },
                        onSubmitted: (_) => _apply(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: FilledButton(
                        onPressed: _apply,
                        child: Text(l10n.setCustomApply),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
