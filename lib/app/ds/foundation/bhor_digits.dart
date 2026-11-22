// BhorDigits (docs/council/15-windows-ux-review.md G9, 16-windows-rebuild-plan.md
// W1-B 7): numbers inside fields use the UI's digits (Bangla digits when the
// app is in Bangla) while every value the app reads stays ASCII.
//
// - BhorTextField applies it for `keyboardType` number / phone: the field
//   SHOWS locale digits (a display-only span, the controller text is not
//   rewritten) and typed Bangla digits are stored as ASCII
//   ([BhorDigits.asciiFormatter]). Callers keep reading `controller.text`.
// - Parse field text with [BhorDigits.parseInt] / [BhorDigits.toAscii] so
//   both digit sets work (older fields store Bangla digits through
//   DigitsFormatter).
// Usage: `BhorDigits.parseInt(ctrl.text)`, `BhorDigits.localize('05', bangla: true)`.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/core/format/lang.dart';

abstract final class BhorDigits {
  static const AppFormat _bn = AppFormat(Lang.bn);

  /// Bangla digits (U+09E6..U+09EF) to ASCII; everything else unchanged.
  static String toAscii(String s) => AppFormat.toAsciiDigits(s);

  /// ASCII digits to Bangla digits; everything else unchanged.
  static String toBangla(String s) => _bn.digits(toAscii(s));

  /// [s] in the UI's digits: Bangla when [bangla], else ASCII. Same length
  /// as [s] (one UTF-16 unit per digit in both sets).
  static String localize(String s, {required bool bangla}) => bangla ? toBangla(s) : toAscii(s);

  /// The whole number in [s] (either digit set, surrounding spaces ignored);
  /// null when it is not a number.
  static int? parseInt(String s) => int.tryParse(toAscii(s).trim());

  /// The number in [s] (either digit set); null when it is not a number.
  static double? parseDouble(String s) => double.tryParse(toAscii(s).trim());

  /// True when [context]'s locale shows Bangla digits.
  static bool banglaOf(BuildContext context) => Localizations.maybeLocaleOf(context)?.languageCode == 'bn';

  /// True for keyboards whose fields show locale digits (number, phone).
  static bool isNumericKeyboard(TextInputType? type) =>
      type != null && (type.index == TextInputType.number.index || type.index == TextInputType.phone.index);

  /// Stores typed Bangla digits as ASCII (caret kept: the lengths match).
  static const TextInputFormatter asciiFormatter = _AsciiDigitsFormatter();

  /// [span] with every digit shown in the UI's digits (Bangla when [bangla]).
  static TextSpan localizeSpan(TextSpan span, {required bool bangla}) => TextSpan(
        text: span.text == null ? null : localize(span.text!, bangla: bangla),
        style: span.style,
        recognizer: span.recognizer,
        semanticsLabel: span.semanticsLabel,
        children: span.children == null
            ? null
            : <InlineSpan>[
                for (final InlineSpan c in span.children!)
                  c is TextSpan ? localizeSpan(c, bangla: bangla) : c,
              ],
      );
}

class _AsciiDigitsFormatter extends TextInputFormatter {
  const _AsciiDigitsFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final String ascii = BhorDigits.toAscii(newValue.text);
    if (ascii == newValue.text) return newValue;
    return newValue.copyWith(text: ascii);
  }
}

/// A controller that SHOWS its digits in the UI's digit set without
/// changing its text (selection offsets stay valid: same length).
class BhorDigitsController extends TextEditingController {
  BhorDigitsController({super.text, this.bangla = false});

  BhorDigitsController.fromValue(super.value, {this.bangla = false}) : super.fromValue();

  /// Show Bangla digits.
  bool bangla;

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final TextSpan span = super.buildTextSpan(context: context, style: style, withComposing: withComposing);
    return bangla ? BhorDigits.localizeSpan(span, bangla: true) : span;
  }
}
