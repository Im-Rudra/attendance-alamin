// Parser for typed class times (desktop time picker): "7:30 pm", "19:30",
// "৭:৩০ সন্ধ্যা", "সন্ধ্যা ৭:৩০", "7pm", "0730". Pure Dart; never throws.

import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/core/format/lexicon.dart';

/// Minutes past midnight for [input], or `null` when it cannot be read.
///
/// A bare 12-hour time without am/pm or a Bangla period word ("7:30") is
/// ambiguous: it takes the half of the day of [hintMin] (the time currently
/// shown), and is `null` when there is no hint. 24-hour times ("19:30",
/// "07:30", "0:15", "13") never need a hint.
int? parseTimeInput(String input, {int? hintMin}) {
  var s = AppFormat.toAsciiDigits(input).trim().toLowerCase();
  if (s.isEmpty) return null;
  // "a.m." / "p.m." -> "am" / "pm"; dots between digits stay separators.
  s = s.replaceAllMapped(
      RegExp(r'([ap])\.\s*m\.?'), (Match x) => '${x.group(1)}m');
  s = s.replaceAll('।', ' ');

  int? periodIdx; // index into Lexicon.periodsBn
  bool? pm; // from am / pm
  for (var i = 0; i < Lexicon.periodsBn.length; i++) {
    final word = Lexicon.periodsBn[i];
    if (s.contains(word)) {
      periodIdx = i;
      s = s.replaceAll(word, ' ');
      break;
    }
  }
  final ampm = RegExp(r'(?<![a-z])(am|pm)(?![a-z])').firstMatch(s);
  if (ampm != null) {
    pm = ampm.group(1) == 'pm';
    s = s.replaceRange(ampm.start, ampm.end, ' ');
  } else {
    final glued = RegExp(r'(\d)(am|pm)$').firstMatch(s.trimRight());
    if (glued != null) {
      pm = glued.group(2) == 'pm';
      s = s.trimRight();
      s = s.substring(0, s.length - 2);
    }
  }
  if (periodIdx != null && pm != null) return null;
  s = s.trim();

  int h;
  int m;
  final colon = RegExp(r'^(\d{1,2})\s*[:.]\s*(\d{1,2})$').firstMatch(s);
  if (colon != null) {
    h = int.parse(colon.group(1)!);
    m = int.parse(colon.group(2)!);
    // "7:3" is not a time; minutes are two digits.
    if (colon.group(2)!.length != 2) return null;
  } else {
    final bare = RegExp(r'^(\d{1,4})$').firstMatch(s);
    if (bare == null) return null;
    final digits = bare.group(1)!;
    if (digits.length <= 2) {
      h = int.parse(digits);
      m = 0;
    } else {
      h = int.parse(digits.substring(0, digits.length - 2));
      m = int.parse(digits.substring(digits.length - 2));
    }
  }
  if (m > 59 || h > 23) return null;

  final twentyFourHour = h == 0 || h > 12 || RegExp(r'^0\d').hasMatch(s);

  if (periodIdx != null) {
    // Pick the 24h reading of this hour that lies in the named period.
    final candidates = h > 12 ? <int>{h} : <int>{h % 12, h % 12 + 12};
    for (final c in candidates) {
      if (Lexicon.periodIndex(c * 60) == periodIdx) return c * 60 + m;
    }
    return null;
  }
  if (pm != null) {
    if (h < 1 || h > 12) return null;
    return ((h % 12) + (pm ? 12 : 0)) * 60 + m;
  }
  if (twentyFourHour) return h * 60 + m;
  // Ambiguous 1..12: follow the hint's half of the day.
  if (hintMin == null) return null;
  final hintPm = (hintMin % 1440) >= 720;
  return ((h % 12) + (hintPm ? 12 : 0)) * 60 + m;
}
