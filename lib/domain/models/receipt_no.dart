/// Receipt (slip) numbers (schema v2, feedback item 2): `{year}-{seq}` with
/// the sequence zero-padded to 4 digits (`2026-0007`; `2026-12345` past 9999).
/// The year is the year of the payment date, the sequence restarts every year
/// and a number is never given out twice (deleted receipts keep theirs).
abstract final class ReceiptNo {
  static String format(int year, int seq) =>
      '$year-${seq.toString().padLeft(4, '0')}';

  /// `(year, seq)` of a stored number, or null when it is not one.
  static (int, int)? tryParse(String? s) {
    if (s == null) return null;
    final RegExpMatch? m = _re.firstMatch(s);
    if (m == null) return null;
    return (int.parse(m.group(1)!), int.parse(m.group(2)!));
  }

  static final RegExp _re = RegExp(r'^(\d{4})-(\d{4,})$');
}
