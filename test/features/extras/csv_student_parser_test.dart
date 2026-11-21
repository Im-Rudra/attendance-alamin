// Table-driven tests of the CSV student parser (pure Dart).

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/features/extras/csv_student_parser.dart';

typedef _Want = ({String name, String? phone, String? roll, CsvProblem? problem});

_Want w(String name, {String? phone, String? roll, CsvProblem? problem}) =>
    (name: name, phone: phone, roll: roll, problem: problem);

List<_Want> _view(List<CsvStudentRow> rows) =>
    <_Want>[for (final CsvStudentRow r in rows) (name: r.name, phone: r.phone, roll: r.roll, problem: r.problem)];

void main() {
  final Map<String, ({String text, List<_Want> want})> cases = <String, ({String text, List<_Want> want})>{
    'BOM and English header': (
      text: '﻿name,phone,roll\nRahim,01712345678,5\n',
      want: <_Want>[w('Rahim', phone: '01712345678', roll: '05')],
    ),
    'Bangla header, Bangla digits': (
      text: 'নাম,ফোন,রোল\nআয়েশা খাতুন,০১৭১২৩৪৫৬৭৮,৭\n',
      want: <_Want>[w('আয়েশা খাতুন', phone: '01712345678', roll: '07')],
    ),
    'no header, CRLF, missing roll': (
      text: 'Rahim,01712345678,5\r\nKarim,01812345678\r\n',
      want: <_Want>[
        w('Rahim', phone: '01712345678', roll: '05'),
        w('Karim', phone: '01812345678'),
      ],
    ),
    'no header, Bangla name and digits': (
      text: 'রহিম,০১৭১২৩৪৫৬৭৮,১২',
      want: <_Want>[w('রহিম', phone: '01712345678', roll: '12')],
    ),
    'semicolons': (
      text: 'name;phone\nRahim;01712345678\nKarim;\n',
      want: <_Want>[w('Rahim', phone: '01712345678'), w('Karim')],
    ),
    'tabs': (
      text: 'Rahim\t01712345678\n',
      want: <_Want>[w('Rahim', phone: '01712345678')],
    ),
    'quoted fields': (
      text: '"Khan, Rahim","017 1234 5678"\n"Say ""Hi"" Karim"\n',
      want: <_Want>[w('Khan, Rahim', phone: '01712345678'), w('Say "Hi" Karim')],
    ),
    'blank lines are skipped': (
      text: '\nA\n\n\nB\n\n',
      want: <_Want>[w('A'), w('B')],
    ),
    'columns in another order': (
      text: 'Phone,Roll,Student Name\n01712345678,3,Rahim\n',
      want: <_Want>[w('Rahim', phone: '01712345678', roll: '03')],
    ),
    'header with only a name column': (
      text: 'নাম\nআয়েশা\n',
      want: <_Want>[w('আয়েশা')],
    ),
    'phone without its leading zero (spreadsheet)': (
      text: 'Rahim,1712345678\n',
      want: <_Want>[w('Rahim', phone: '01712345678')],
    ),
    'bad rows are flagged': (
      text: ',01712345678\nRahim,12345\nKarim,01712345678\nkarim,01812345678\nSalma,01712345678\n',
      want: <_Want>[
        w('', phone: '01712345678', problem: CsvProblem.emptyName),
        w('Rahim', problem: CsvProblem.badPhone),
        w('Karim', phone: '01712345678'),
        w('karim', phone: '01812345678', problem: CsvProblem.duplicate),
        w('Salma', phone: '01712345678', problem: CsvProblem.duplicate),
      ],
    ),
    'empty text': (text: '', want: <_Want>[]),
    'header only': (text: 'name,phone,roll\n', want: <_Want>[]),
  };

  cases.forEach((String title, ({String text, List<_Want> want}) c) {
    test(title, () => expect(_view(parseStudentCsv(c.text)), c.want));
  });

  test('line numbers count blank lines', () {
    final List<CsvStudentRow> rows = parseStudentCsv('A\n\n\nB\n');
    expect(rows.map((CsvStudentRow r) => r.line).toList(), <int>[1, 4]);
  });

  test('bytes with a UTF-8 BOM', () {
    final Uint8List bytes = Uint8List.fromList(<int>[0xEF, 0xBB, 0xBF, ...utf8.encode('নাম,ফোন\nআয়েশা,01712345678')]);
    expect(_view(parseStudentCsvBytes(bytes)), <_Want>[w('আয়েশা', phone: '01712345678')]);
  });

  test('malformed bytes do not throw', () {
    expect(() => parseStudentCsvBytes(Uint8List.fromList(<int>[0x41, 0xFF, 0x42])), returnsNormally);
  });
}
