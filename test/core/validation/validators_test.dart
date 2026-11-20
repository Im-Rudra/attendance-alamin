import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/errors/error_codes.dart';
import 'package:attendance_alamin/core/validation/validators.dart';
import 'package:flutter_test/flutter_test.dart';

Matcher throwsValidation(String code, String field) => throwsA(
      isA<ValidationException>()
          .having((e) => e.code, 'code', code)
          .having((e) => e.field, 'field', field),
    );

void main() {
  group('Validators.name', () {
    const ok = <(String, String)>[
      ('Rahim', 'Rahim'),
      ('  Rahim Uddin  ', 'Rahim Uddin'),
      ('\tরহিম\n', 'রহিম'),
      ('a', 'a'),
    ];
    for (final (raw, expected) in ok) {
      test('accepts "$raw"', () {
        expect(Validators.name(raw), expected);
      });
    }

    for (final raw in ['', '   ', '\n\t ']) {
      test('rejects blank "${raw.replaceAll('\n', r'\n').replaceAll('\t', r'\t')}"', () {
        expect(
          () => Validators.name(raw),
          throwsValidation(ErrorCodes.nameRequired, 'name'),
        );
      });
    }

    test('80 characters is the limit', () {
      expect(Validators.name('a' * 80), 'a' * 80);
      expect(Validators.name('  ${'a' * 80}  '), 'a' * 80);
      expect(
        () => Validators.name('a' * 81),
        throwsValidation(ErrorCodes.nameTooLong, 'name'),
      );
    });

    test('length counts Bangla code points, not UTF-16 units', () {
      expect(Validators.name('ক' * 80), 'ক' * 80);
      expect(
        () => Validators.name('ক' * 81),
        throwsValidation(ErrorCodes.nameTooLong, 'name'),
      );
    });
  });

  group('Validators.phone', () {
    test('null and blank give null', () {
      expect(Validators.phone(null), isNull);
      expect(Validators.phone(''), isNull);
      expect(Validators.phone('   '), isNull);
    });

    const ok = <(String, String)>[
      ('01712345678', '01712345678'),
      ('01312345678', '01312345678'),
      ('01912345678', '01912345678'),
      ('+8801712345678', '01712345678'),
      ('8801712345678', '01712345678'),
      ('+88 01712-345678', '01712345678'),
      ('017 1234 5678', '01712345678'),
      ('017-1234-5678', '01712345678'),
      (' 01712345678 ', '01712345678'),
      ('০১৭১২৩৪৫৬৭৮', '01712345678'),
      ('+৮৮০১৭১২৩৪৫৬৭৮', '01712345678'),
    ];
    for (final (raw, expected) in ok) {
      test('accepts "$raw"', () {
        expect(Validators.phone(raw), expected);
      });
    }

    const bad = <String>[
      '01212345678', // third digit must be 3..9
      '01012345678',
      '1712345678',
      '0171234567', // too short
      '017123456789', // too long
      '02112345678',
      'abc',
      '01a12345678',
      '+88',
      '+8801212345678',
      '88017123456789',
      '+880171234567',
      '--',
    ];
    for (final raw in bad) {
      test('rejects "$raw"', () {
        expect(
          () => Validators.phone(raw),
          throwsValidation(ErrorCodes.phoneInvalid, 'phone'),
        );
      });
    }
  });

  group('Validators.amount', () {
    const ok = <(String, int)>[
      ('0', 0),
      ('1', 1),
      ('800', 800),
      ('1500', 1500),
      ('১৫০০', 1500),
      ('1,500', 1500),
      ('১,৫০০', 1500),
      ('৳1,500', 1500),
      ('৳ ১,২০,০০০', 120000),
      (' 800 ', 800),
      ('1000000', 1000000),
      ('১০,০০,০০০', 1000000),
      ('000000000000005', 5),
      ('0000', 0),
    ];
    for (final (raw, expected) in ok) {
      test('accepts "$raw" = $expected', () {
        expect(Validators.amount(raw), expected);
      });
    }

    for (final raw in ['', '  ', 'abc', '-5', '12.5', '1e3', '1500tk', '৳', ',']) {
      test('rejects "$raw" as invalid', () {
        expect(
          () => Validators.amount(raw),
          throwsValidation(ErrorCodes.amountInvalid, 'amount'),
        );
      });
    }

    for (final raw in ['1000001', '2000000', '9999999', '99999999999999999999']) {
      test('rejects "$raw" as too large', () {
        expect(
          () => Validators.amount(raw),
          throwsValidation(ErrorCodes.amountTooLarge, 'amount'),
        );
      });
    }
  });

  group('Validators.intLoose', () {
    const table = <(String, int?)>[
      ('12', 12),
      ('0', 0),
      ('-3', -3),
      ('১২', 12),
      ('১,২০০', 1200),
      ('1,200', 1200),
      (' 45 ', 45),
      ('', null),
      ('  ', null),
      ('x', null),
      ('1.5', null),
      ('-', null),
      ('1234567890123456', null),
      ('123456789012345', 123456789012345),
    ];
    for (final (raw, expected) in table) {
      test('"$raw" -> $expected', () {
        expect(Validators.intLoose(raw), expected);
      });
    }
  });
}
