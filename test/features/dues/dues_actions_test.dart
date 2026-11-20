// The "reminded today" log (`reminded:<date>`) and the reminder composed from
// the seed's dues and the teacher's settings, in both languages.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/data/repositories/local_meta_repository.dart';
import 'package:attendance_alamin/features/dues/controllers/dues_state.dart';
import 'package:attendance_alamin/features/dues/controllers/reminder_actions.dart';

import '../../helpers/fakes/fake_settings_repos.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/pump_app.dart';

final RegExp _latin = RegExp(r'[0-9]');
final RegExp _bangla = RegExp(r'[০-৯]');

void main() {
  group('reminded today', () {
    test('decode ignores a damaged value and keeps the ids of a good one', () {
      expect(decodeReminded(null), isEmpty);
      expect(decodeReminded(''), isEmpty);
      expect(decodeReminded('not json'), isEmpty);
      expect(decodeReminded('{"a":1}'), isEmpty);
      expect(decodeReminded('["a","b",3]'), <String>{'a', 'b'});
      expect(decodeReminded(encodeReminded(<String>{'b', 'a'})), <String>{'a', 'b'});
    });

    test('markReminded writes the day key once per student', () async {
      final FakeLocalMetaRepository meta = FakeLocalMetaRepository();
      const LocalDate day = LocalDate(2026, 11, 21);
      await markReminded(meta, day, kStuRahim);
      await markReminded(meta, day, kStuSara);
      await markReminded(meta, day, kStuRahim);
      final String? raw = await meta.getRaw(LocalMetaKeys.reminded(day));
      expect(raw, isNotNull);
      expect(decodeReminded(raw), <String>{kStuRahim, kStuSara});
      expect(LocalMetaKeys.reminded(day), 'reminded:20261121');
      // Another day starts empty.
      expect(await meta.getRaw(LocalMetaKeys.reminded(day.addDays(1))), isNull);
    });

    test('the provider follows the log of today', () async {
      final SeededFakes f = seedFakes();
      final ProviderContainer container = makeContainer(overrides: f.overrides);
      final Set<String> first = await readData(container, duesRemindedProvider);
      expect(first, isEmpty);
      await markReminded(f.localMeta, kToday, kStuNila);
      await settle();
      expect(container.read(duesRemindedProvider).value, <String>{kStuNila});
    });
  });

  group('composeReminder', () {
    test('Bangla: the default template with Rahim\'s open month and Bangla digits', () async {
      final SeededFakes f = seedFakes(encodedSettings: <String, Object?>{
        'center_name': 'আলো কোচিং',
        'center_phone': '01712345678',
      });
      final ProviderContainer container = makeContainer(overrides: f.overrides);
      final String? text = await composeReminder(
        container,
        lang: Lang.bn,
        studentId: kStuRahim,
        centerFallback: 'আপনার কোচিং',
      );
      expect(text, isNotNull);
      expect(text, contains('রহিম উদ্দিন-এর ফিজিক্স এ ব্যাচের নভেম্বর মাসের বেতন মোট ৳১,০০০'));
      expect(text, contains('আলো কোচিং (০১৭১২৩৪৫৬৭৮)'));
      expect(_latin.hasMatch(text!), isFalse);
    });

    test('English: the English template with Latin digits', () async {
      final SeededFakes f = seedFakes(encodedSettings: <String, Object?>{
        'center_name': 'Alo Coaching',
        'center_phone': '01712345678',
      });
      final ProviderContainer container = makeContainer(overrides: f.overrides);
      final String? text = await composeReminder(
        container,
        lang: Lang.en,
        studentId: kStuRahim,
        centerFallback: 'Your Coaching',
      );
      expect(text, startsWith('Dear Guardian, রহিম উদ্দিন\'s fee for ফিজিক্স এ for November (total ৳1,000)'));
      expect(text, endsWith('Thank you — Alo Coaching (01712345678)'));
      expect(_bangla.hasMatch(text!), isFalse);
    });

    test('the teacher\'s own template wins, and the center falls back when unset', () async {
      final SeededFakes f = seedFakes(encodedSettings: <String, Object?>{
        'reminder_template_bn': '{student}: {months} {batch} ৳{amount} — {center}',
      });
      final ProviderContainer container = makeContainer(overrides: f.overrides);
      final String? text = await composeReminder(
        container,
        lang: Lang.bn,
        studentId: kStuSara,
        centerFallback: 'আপনার কোচিং',
      );
      // Sara's Chem B October fee (postpaid, due 1 Nov) is the only open month.
      expect(text, 'সারা আক্তার: অক্টোবর কেমিস্ট্রি বি ৳৮০০ — আপনার কোচিং');
    });

    test('a student with nothing due has no reminder', () async {
      final ProviderContainer container = makeContainer(overrides: seedFakes().overrides);
      final String? text = await composeReminder(
        container,
        lang: Lang.bn,
        studentId: kStuKarim,
        centerFallback: 'x',
      );
      expect(text, isNull);
      expect(
        await composeReminder(container, lang: Lang.bn, studentId: 'nobody', centerFallback: 'x'),
        isNull,
      );
    });
  });
}
