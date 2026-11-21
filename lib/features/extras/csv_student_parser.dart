// Pure-Dart CSV reader for adding students from a file (no Flutter, no I/O).
// Columns: name (required), guardian phone, roll. The header row is optional;
// without one the order is name, phone, roll. Accepts UTF-8 with or without a
// BOM, CRLF / LF, comma / semicolon / tab, quoted fields and Bangla digits.

import 'dart:convert';
import 'dart:typed_data';

import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/core/validation/validators.dart';

enum CsvProblem { emptyName, badPhone, duplicate }

/// One data row of the file.
class CsvStudentRow {
  const CsvStudentRow({
    required this.line,
    required this.name,
    this.phone,
    this.roll,
    this.problem,
  });

  /// 1-based line number of the row in the file (counting blank lines).
  final int line;

  /// Trimmed name (empty when [problem] is [CsvProblem.emptyName]).
  final String name;

  /// Normalised `01XXXXXXXXX` phone, or null when absent or invalid.
  final String? phone;

  /// Roll with ASCII digits (a single digit is padded to 2), or null to
  /// auto-fill.
  final String? roll;

  /// Rows with a problem are shown flagged and skipped on save.
  final CsvProblem? problem;

  bool get ok => problem == null;

  CsvStudentRow withProblem(CsvProblem p) =>
      CsvStudentRow(line: line, name: name, phone: phone, roll: roll, problem: p);
}

/// Decodes [bytes] as UTF-8 (bad bytes tolerated) and parses.
List<CsvStudentRow> parseStudentCsvBytes(Uint8List bytes) =>
    parseStudentCsv(utf8.decode(bytes, allowMalformed: true));

/// Parses [text] (a leading BOM is ignored). Rows with an empty name, an
/// invalid phone or a name / phone already used by an earlier row get a
/// [CsvStudentRow.problem].
List<CsvStudentRow> parseStudentCsv(String text) {
  final String clean = text.startsWith('﻿') ? text.substring(1) : text;
  final List<_Raw> raws = _tokenize(clean, _delimiterOf(clean));
  if (raws.isEmpty) return const <CsvStudentRow>[];

  int nameCol = 0, phoneCol = 1, rollCol = 2;
  int start = 0;
  final _Header? h = _headerOf(raws.first.cells);
  if (h != null) {
    nameCol = h.name;
    phoneCol = h.phone;
    rollCol = h.roll;
    start = 1;
  }

  String cell(List<String> cells, int i) => i >= 0 && i < cells.length ? cells[i].trim() : '';

  final List<CsvStudentRow> out = <CsvStudentRow>[];
  final Set<String> names = <String>{};
  final Set<String> phones = <String>{};
  for (int i = start; i < raws.length; i++) {
    final _Raw r = raws[i];
    final String name = cell(r.cells, nameCol);
    final String phoneRaw = cell(r.cells, phoneCol);
    final String rollRaw = AppFormat.toAsciiDigits(cell(r.cells, rollCol));
    String? roll = rollRaw.isEmpty ? null : rollRaw;
    if (roll != null && RegExp(r'^\d$').hasMatch(roll)) roll = '0$roll';

    String? phone;
    CsvProblem? problem;
    if (phoneRaw.isNotEmpty) {
      try {
        phone = Validators.phone(_fixLeadingZero(phoneRaw));
      } on Object {
        problem = CsvProblem.badPhone;
      }
    }
    if (name.isEmpty) {
      problem = CsvProblem.emptyName;
    } else if (problem == null && (names.contains(name.toLowerCase()) || (phone != null && phones.contains(phone)))) {
      problem = CsvProblem.duplicate;
    }
    if (problem == null) {
      names.add(name.toLowerCase());
      if (phone != null) phones.add(phone);
    }
    out.add(CsvStudentRow(line: r.line, name: name, phone: phone, roll: roll, problem: problem));
  }
  return out;
}

/// Spreadsheets drop the leading zero of a phone number (1712345678).
String _fixLeadingZero(String raw) {
  final String d = AppFormat.toAsciiDigits(raw).replaceAll(RegExp(r'[\s\-]'), '');
  return RegExp(r'^1[3-9]\d{8}$').hasMatch(d) ? '0$d' : raw;
}

class _Raw {
  _Raw(this.line, this.cells);
  final int line;
  final List<String> cells;
}

class _Header {
  _Header(this.name, this.phone, this.roll);
  final int name, phone, roll;
}

/// The delimiter used most on the first non-blank line, outside quotes.
String _delimiterOf(String text) {
  final Map<String, int> count = <String, int>{',': 0, ';': 0, '\t': 0};
  bool quoted = false;
  bool seen = false;
  for (final int u in text.runes) {
    final String c = String.fromCharCode(u);
    if (c == '"') {
      quoted = !quoted;
      seen = true;
    } else if (!quoted && (c == '\n' || c == '\r')) {
      if (seen) break;
    } else {
      if (c.trim().isNotEmpty) seen = true;
      if (!quoted && count.containsKey(c)) count[c] = count[c]! + 1;
    }
  }
  String best = ',';
  int top = 0;
  count.forEach((String k, int v) {
    if (v > top) {
      top = v;
      best = k;
    }
  });
  return best;
}

List<_Raw> _tokenize(String text, String delim) {
  final List<_Raw> rows = <_Raw>[];
  List<String> cells = <String>[];
  final StringBuffer cur = StringBuffer();
  bool quoted = false;
  bool wasQuoted = false;
  int line = 1;
  int rowLine = 1;

  void endCell() {
    cells.add(cur.toString());
    cur.clear();
    wasQuoted = false;
  }

  void endRow() {
    endCell();
    if (cells.any((String c) => c.trim().isNotEmpty)) rows.add(_Raw(rowLine, cells));
    cells = <String>[];
    rowLine = line;
  }

  final List<int> r = text.runes.toList();
  for (int i = 0; i < r.length; i++) {
    final String c = String.fromCharCode(r[i]);
    if (quoted) {
      if (c == '"') {
        if (i + 1 < r.length && r[i + 1] == 0x22) {
          cur.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        if (c == '\n') line++;
        cur.write(c);
      }
    } else if (c == '"' && !wasQuoted && cur.toString().trim().isEmpty) {
      quoted = true;
      wasQuoted = true;
      cur.clear();
    } else if (c == delim) {
      endCell();
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < r.length && r[i + 1] == 0x0A) i++;
      line++;
      endRow();
    } else {
      cur.write(c);
    }
  }
  if (cur.isNotEmpty || cells.isNotEmpty) endRow();
  return rows;
}

const List<String> _nameWords = <String>['name', 'student', 'নাম', 'শিক্ষার্থী'];
const List<String> _phoneWords = <String>['phone', 'mobile', 'contact', 'guardian', 'ফোন', 'মোবাইল', 'অভিভাবক'];
const List<String> _rollWords = <String>['roll', 'রোল'];

bool _has(String cell, List<String> words) {
  final String c = cell.toLowerCase();
  return words.any(c.contains);
}

/// Column map when [cells] is a header row (names a known column and has no
/// phone-like value), else null.
_Header? _headerOf(List<String> cells) {
  int name = -1, phone = -1, roll = -1;
  for (int i = 0; i < cells.length; i++) {
    final String c = cells[i].trim();
    if (c.isEmpty) continue;
    if (_has(c, _rollWords)) {
      if (roll < 0) roll = i;
    } else if (_has(c, _phoneWords)) {
      if (phone < 0) phone = i;
    } else if (_has(c, _nameWords)) {
      if (name < 0) name = i;
    }
  }
  if (name < 0 && phone < 0 && roll < 0) return null;
  // A data row with a phone-like value is never a header.
  if (cells.any((String c) => RegExp(r'^[+\d০-৯][\d০-৯\s\-]{8,}$').hasMatch(c.trim()))) return null;
  if (name < 0) {
    for (int i = 0; i < cells.length && name < 0; i++) {
      if (i != phone && i != roll) name = i;
    }
  }
  return _Header(name < 0 ? 0 : name, phone, roll);
}
