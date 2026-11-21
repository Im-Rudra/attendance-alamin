// A digits-only text formatter that shows the app's digit style as the teacher
// types (Bangla digits in Bangla), used by every money / number field.

import 'package:flutter/services.dart';

import 'package:attendance_alamin/core/format/app_format.dart';

/// Digits only, shown in the app's digit style (Bangla digits in bn).
class DigitsFormatter extends TextInputFormatter {
  const DigitsFormatter(this.fmt, {this.maxLength = 7});

  final AppFormat fmt;
  final int maxLength;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final String ascii = AppFormat.toAsciiDigits(newValue.text).replaceAll(RegExp(r'[^0-9]'), '');
    final String cut = ascii.length > maxLength ? ascii.substring(0, maxLength) : ascii;
    final String shown = fmt.digits(cut);
    return TextEditingValue(
      text: shown,
      selection: TextSelection.collapsed(offset: shown.length),
    );
  }
}

/// The whole number typed in a digits field (0 when empty).
int parseDigits(String text) => int.tryParse(AppFormat.toAsciiDigits(text)) ?? 0;
