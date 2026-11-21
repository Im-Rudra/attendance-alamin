// A digits-only text formatter that shows the app's digit style as the teacher
// types (Bangla digits in Bangla), used by every money / number field.

import 'package:flutter/services.dart';

import 'package:attendance_alamin/core/format/app_format.dart';

/// Digits only, shown in the app's digit style (Bangla digits in bn). With
/// [phone] it also keeps `+`, `-` and spaces, for phone numbers.
class DigitsFormatter extends TextInputFormatter {
  const DigitsFormatter(this.fmt, {this.maxLength = 7, this.phone = false});

  final AppFormat fmt;
  final int maxLength;
  final bool phone;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final String ascii = AppFormat.toAsciiDigits(newValue.text)
        .replaceAll(phone ? RegExp(r'[^0-9+\-\s]') : RegExp(r'[^0-9]'), '');
    final String cut = ascii.length > maxLength ? ascii.substring(0, maxLength) : ascii;
    final String shown = fmt.digits(cut);
    final int at = newValue.selection.isValid ? newValue.selection.extentOffset : shown.length;
    return TextEditingValue(
      text: shown,
      selection: TextSelection.collapsed(offset: at.clamp(0, shown.length).toInt()),
    );
  }
}

/// The whole number typed in a digits field (0 when empty).
int parseDigits(String text) => int.tryParse(AppFormat.toAsciiDigits(text)) ?? 0;
