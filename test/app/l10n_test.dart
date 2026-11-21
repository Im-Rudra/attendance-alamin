import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/l10n/error_text.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/errors/error_codes.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

void main() {
  group('errorText', () {
    for (final locale in const [Locale('bn'), Locale('en')]) {
      final name = locale.languageCode;

      test('covers every ErrorCodes value in $name', () {
        final l10n = lookupAppLocalizations(locale);
        final seen = <String>{};
        for (final code in ErrorCodes.all) {
          final text = errorText(l10n, ValidationException(code));
          expect(text.trim(), isNotEmpty, reason: code);
          if (code != ErrorCodes.unknown) {
            expect(text, isNot(l10n.errUnknown), reason: '$code fell through');
          }
          expect(seen.add(text), isTrue, reason: '$code duplicates a message');
        }
      });

      test('non-AppException and unknown code give errUnknown ($name)', () {
        final l10n = lookupAppLocalizations(locale);
        expect(errorText(l10n, StateError('x')), l10n.errUnknown);
        expect(
          errorText(l10n, const NotFoundException('bogus')),
          l10n.errUnknown,
        );
      });
    }

    test('never exposes the exception detail', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final text = errorText(
        l10n,
        const StorageException(ErrorCodes.storageFailed, detail: 'SQLITE_FULL'),
      );
      expect(text, isNot(contains('SQLITE')));
    });

    test('Bangla copy follows the glossary', () {
      final bn = lookupAppLocalizations(const Locale('bn'));
      expect(bn.errScheduleClash, 'এই সময়ে আরেকটি ক্লাস আছে');
      expect(bn.commonSave, 'সংরক্ষণ');
      expect(bn.commonDelete, 'মুছুন');
      expect(bn.commonSearch, 'খুঁজুন');
      for (final code in ErrorCodes.all) {
        final t = errorTextForCode(bn, code);
        expect(t.contains('কনফ্লিক্ট'), isFalse);
        expect(t.contains('ওভারল্যাপ'), isFalse);
      }
    });
  });

  group('ARB fragments', () {
    test('every ErrorCodes value has an err<Code> key in bn and en', () {
      for (final loc in ['bn', 'en']) {
        final file = File('lib/l10n/fragments/err.$loc.arb');
        final map = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        for (final code in ErrorCodes.all) {
          final key = 'err${code[0].toUpperCase()}${code.substring(1)}';
          expect(map[key], isA<String>(), reason: '$loc missing $key');
          expect((map[key] as String).trim(), isNotEmpty, reason: '$loc $key');
        }
      }
    });
  });

  group('context extensions', () {
    Future<void> pump(
      WidgetTester tester,
      Locale locale,
      void Function(BuildContext) read,
    ) {
      return tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) {
              read(context);
              return const SizedBox();
            },
          ),
        ),
      );
    }

    testWidgets('bn locale gives Bangla digits and strings', (tester) async {
      late Lang lang;
      late String money;
      late String save;
      await pump(tester, const Locale('bn'), (c) {
        lang = c.lang;
        money = c.fmt.money(120000);
        save = c.l10n.commonSave;
      });
      expect(lang, Lang.bn);
      expect(money, '৳ ১,২০,০০০');
      expect(save, 'সংরক্ষণ');
    });

    testWidgets('en locale gives ASCII digits and strings', (tester) async {
      late Lang lang;
      late String money;
      late String save;
      await pump(tester, const Locale('en'), (c) {
        lang = c.lang;
        money = c.fmt.money(120000);
        save = c.l10n.commonSave;
      });
      expect(lang, Lang.en);
      expect(money, '৳ 1,20,000');
      expect(save, 'Save');
    });
  });
}
