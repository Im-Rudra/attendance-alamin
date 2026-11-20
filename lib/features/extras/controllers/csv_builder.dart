// CSV writing for the Excel export (F23): RFC-4180 quoting, CRLF line ends and
// a UTF-8 byte-order mark so Excel opens Bangla text correctly. Pure Dart, no
// Flutter, so tests can check the exact bytes.

import 'dart:convert';
import 'dart:typed_data';

/// The UTF-8 byte-order mark Excel needs to detect UTF-8.
const List<int> kUtf8Bom = <int>[0xEF, 0xBB, 0xBF];

/// Marks a cell as a phone number (see [csvPhone]). Starts with a control
/// character, which [buildCsv] strips from every ordinary cell.
const String _phoneMark = '\u0001phone:';

/// One cell, quoted when it holds a comma, quote, CR or LF. A cell that a
/// spreadsheet would run as a formula (starts with `=` or `@`, or `+`/`-`
/// followed by a non-digit) gets a leading apostrophe.
String csvCell(String value) {
  String v = value;
  if (v.isNotEmpty) {
    final String c = v[0];
    final bool risky = c == '=' ||
        c == '@' ||
        c == '\t' ||
        c == '\r' ||
        ((c == '+' || c == '-') && !(v.length > 1 && _isDigit(v.codeUnitAt(1))));
    if (risky) v = "'$v";
  }
  if (v.contains(',') || v.contains('"') || v.contains('\n') || v.contains('\r')) {
    return '"${v.replaceAll('"', '""')}"';
  }
  return v;
}

bool _isDigit(int unit) => unit >= 0x30 && unit <= 0x39;

/// A phone number kept as text: Excel would drop the leading zero of
/// `01711223344`, so a digits-only value that starts with 0 is written as the
/// formula `="01711223344"` (opens correctly in Excel and Google Sheets).
String csvPhone(String? phone) {
  final String v = (phone ?? '').trim();
  if (v.isEmpty) return '';
  if (RegExp(r'^0[0-9]+$').hasMatch(v)) return '$_phoneMark$v';
  return v;
}

/// Header and rows as CSV text (CRLF between lines, no BOM).
String buildCsv(List<String> header, List<List<String>> rows) {
  final StringBuffer out = StringBuffer();
  void line(List<String> cells) {
    for (int i = 0; i < cells.length; i++) {
      if (i > 0) out.write(',');
      final String cell = cells[i];
      out.write(cell.startsWith(_phoneMark)
          ? '="${cell.substring(_phoneMark.length)}"'
          : csvCell(cell.replaceAll('\u0001', '')));
    }
    out.write('\r\n');
  }

  line(header);
  rows.forEach(line);
  return out.toString();
}

/// The file bytes: BOM + UTF-8 text.
Uint8List csvBytes(String csv) =>
    Uint8List.fromList(<int>[...kUtf8Bom, ...utf8.encode(csv)]);
