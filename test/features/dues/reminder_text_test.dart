// The reminder message (scenario 14): Bangla digits in bn, Latin in en, the
// teacher's template wins over the default, and an empty phone leaves no "()".

import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/core/templates/default_templates.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/features/dues/reminder_text.dart';

const List<YearMonth> _octNov = <YearMonth>[YearMonth(2026, 10), YearMonth(2026, 11)];

String _build(
  Lang lang, {
  String? template,
  String phone = '01712345678',
  String center = 'Alo Coaching',
}) =>
    buildReminderText(
      lang: lang,
      template: template ?? DefaultTemplates.reminder(lang),
      student: 'Rahim',
      batches: 'Physics A',
      months: _octNov,
      amount: 2000,
      currentYear: 2026,
      center: center,
      teacherPhone: phone,
    );

final RegExp _latin = RegExp(r'[0-9]');
final RegExp _bangla = RegExp(r'[০-৯]');

void main() {
  test('Bangla: Bangla template, month names, money and every digit in Bangla', () {
    final String text = _build(Lang.bn);
    expect(text, contains('সম্মানিত অভিভাবক'));
    expect(text, contains('Rahim-এর Physics A ব্যাচের অক্টোবর, নভেম্বর মাসের বেতন মোট ৳২,০০০'));
    expect(text, contains('Alo Coaching (০১৭১২৩৪৫৬৭৮)'));
    expect(_latin.hasMatch(text), isFalse, reason: 'no Latin digit may be left in a Bangla message');
    expect(text, isNot(contains('{')));
  });

  test('English: English template, month names, money and every digit Latin', () {
    final String text = _build(Lang.en);
    expect(
      text,
      "Dear Guardian, Rahim's fee for Physics A for October, November "
      '(total ৳2,000) is still due. Please pay at your earliest. '
      'Thank you — Alo Coaching (01712345678)',
    );
    expect(_bangla.hasMatch(text), isFalse, reason: 'no Bangla digit may be left in an English message');
  });

  test('a custom template replaces the default and its digits follow the language', () {
    const String template = 'Hi {student}: {months} = ৳{amount} (due 5th) {center}';
    expect(
      _build(Lang.en, template: template),
      'Hi Rahim: October, November = ৳2,000 (due 5th) Alo Coaching',
    );
    final String bn = _build(Lang.bn, template: 'Hi {student}: {months} = ৳{amount} (due 5th)');
    expect(bn, 'Hi Rahim: অক্টোবর, নভেম্বর = ৳২,০০০ (due ৫th)');
  });

  test('digits typed in the other script are converted too', () {
    final String en = _build(Lang.en, template: 'pay ৳{amount} by ৫ তারিখ');
    expect(en, 'pay ৳2,000 by 5 তারিখ');
  });

  test('an empty teacher phone drops the parentheses instead of printing ()', () {
    final String bn = _build(Lang.bn, phone: '');
    expect(bn, isNot(contains('()')));
    expect(bn.trim().endsWith('ধন্যবাদ — Alo Coaching'), isTrue);
    final String en = _build(Lang.en, phone: '  ');
    expect(en, isNot(contains('()')));
    expect(en.endsWith('Thank you — Alo Coaching'), isTrue);
  });

  test('months of another year carry their year', () {
    final String text = buildReminderText(
      lang: Lang.en,
      template: '{months}',
      student: 'R',
      batches: 'B',
      months: const <YearMonth>[YearMonth(2025, 12), YearMonth(2026, 1)],
      amount: 100,
      currentYear: 2026,
      center: 'C',
      teacherPhone: '',
    );
    expect(text, 'December 2025, January');
  });
}
