import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/core/templates/default_templates.dart';
import 'package:attendance_alamin/core/templates/template_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('fillTemplate', () {
    // (template, values, expected)
    const table = <(String, Map<String, String>, String)>[
      ('', {}, ''),
      ('no placeholders', {'a': '1'}, 'no placeholders'),
      ('{a}', {'a': '1'}, '1'),
      ('x {a} y {b} z', {'a': '1', 'b': '2'}, 'x 1 y 2 z'),
      ('{a}{a}{a}', {'a': 'ab'}, 'ababab'),
      ('{a} {missing} {b}', {'a': '1', 'b': '2'}, '1 {missing} 2'),
      ('{missing}', {}, '{missing}'),
      ('{a}', {'a': ''}, ''),
      ('{a}', {'a': '{b}', 'b': 'no'}, '{b}'), // values are not re-scanned
      ('{a}', {'a': r'$1 \1 $&'}, r'$1 \1 $&'),
      ('{{a}}', {'a': 'x'}, '{x}'),
      ('{ a }', {'a': 'x'}, '{ a }'), // spaces are not part of a key
      ('{}', {'a': 'x'}, '{}'),
      ('{a', {'a': 'x'}, '{a'),
      ('a}', {'a': 'x'}, 'a}'),
      ('{teacher_phone}', {'teacher_phone': '017'}, '017'),
      ('{A} {a}', {'a': 'lower'}, '{A} lower'), // keys are case-sensitive
      ('{student}-এর', {'student': 'রহিম'}, 'রহিম-এর'),
      ('৳{amount}', {'amount': '২,০০০'}, '৳২,০০০'),
      ('line1\n{a}\nline3', {'a': 'L2'}, 'line1\nL2\nline3'),
    ];
    for (final (template, values, expected) in table) {
      test('"${template.replaceAll('\n', r'\n')}" with $values', () {
        expect(fillTemplate(template, values), expected);
      });
    }
  });

  group('DefaultTemplates', () {
    final placeholderRe = RegExp(r'\{([A-Za-z0-9_]+)\}');
    const reminderKeys = {
      'student',
      'batch',
      'months',
      'amount',
      'center',
      'teacher_phone',
    };
    const receiptKeys = {
      'center',
      'student',
      'id',
      'batch',
      'months',
      'amount',
      'method',
      'date',
      'remaining_line',
      'receipt_no',
    };

    Set<String> keysOf(String t) =>
        placeholderRe.allMatches(t).map((m) => m.group(1)!).toSet();

    test('reminder templates use exactly the reminder placeholders', () {
      expect(keysOf(DefaultTemplates.reminderBn), reminderKeys);
      expect(keysOf(DefaultTemplates.reminderEn), reminderKeys);
    });

    test('receipt templates use exactly the receipt placeholders', () {
      expect(keysOf(DefaultTemplates.receiptBn), receiptKeys);
      expect(keysOf(DefaultTemplates.receiptEn), receiptKeys);
    });

    test('reminderBn is the Product text verbatim', () {
      expect(
        DefaultTemplates.reminderBn,
        'সম্মানিত অভিভাবক,\n'
        '{student}-এর {batch} ব্যাচের {months} মাসের বেতন মোট ৳{amount} এখনো বাকি আছে। '
        'অনুগ্রহ করে দ্রুত পরিশোধ করুন।\n'
        'ধন্যবাদ — {center} ({teacher_phone})',
      );
    });

    test('reminderEn is the Product text verbatim', () {
      expect(
        DefaultTemplates.reminderEn,
        "Dear Guardian, {student}'s fee for {batch} for {months} (total ৳{amount}) "
        'is still due. Please pay at your earliest. Thank you — {center} ({teacher_phone})',
      );
    });

    test('receiptBn is the Product text verbatim', () {
      expect(
        DefaultTemplates.receiptBn,
        'রসিদ নং {receipt_no} — {center}\n'
        'শিক্ষার্থী: {student} ({id})\n'
        'ব্যাচ: {batch}\n'
        'মাস: {months}\n'
        'জমা: ৳{amount} ({method}), তারিখ {date}\n'
        '{remaining_line}\n'
        'ধন্যবাদ।',
      );
    });

    test('language selectors', () {
      expect(DefaultTemplates.reminder(Lang.bn), DefaultTemplates.reminderBn);
      expect(DefaultTemplates.reminder(Lang.en), DefaultTemplates.reminderEn);
      expect(DefaultTemplates.receipt(Lang.bn), DefaultTemplates.receiptBn);
      expect(DefaultTemplates.receipt(Lang.en), DefaultTemplates.receiptEn);
    });

    test('Scenario 14: Bangla reminder fills completely', () {
      final text = fillTemplate(DefaultTemplates.reminderBn, {
        'student': 'রহিম',
        'batch': 'Physics A',
        'months': 'অক্টোবর, নভেম্বর',
        'amount': '২,০০০',
        'center': 'আলো কোচিং',
        'teacher_phone': '০১৭১২৩৪৫৬৭৮',
      });
      expect(
        text,
        'সম্মানিত অভিভাবক,\n'
        'রহিম-এর Physics A ব্যাচের অক্টোবর, নভেম্বর মাসের বেতন মোট ৳২,০০০ এখনো বাকি আছে। '
        'অনুগ্রহ করে দ্রুত পরিশোধ করুন।\n'
        'ধন্যবাদ — আলো কোচিং (০১৭১২৩৪৫৬৭৮)',
      );
      expect(placeholderRe.hasMatch(text), isFalse);
    });

    test('Scenario 14: English reminder fills completely', () {
      final text = fillTemplate(DefaultTemplates.reminderEn, {
        'student': 'Rahim',
        'batch': 'Physics A',
        'months': 'October, November',
        'amount': '2,000',
        'center': 'Alo Coaching',
        'teacher_phone': '01712345678',
      });
      expect(
        text,
        "Dear Guardian, Rahim's fee for Physics A for October, November "
        '(total ৳2,000) is still due. Please pay at your earliest. '
        'Thank you — Alo Coaching (01712345678)',
      );
    });

    test('Scenario 5: Bangla receipt', () {
      final text = fillTemplate(DefaultTemplates.receiptBn, {
        'center': 'আলো কোচিং',
        'student': 'রহিম',
        'id': '১২',
        'batch': 'Physics A',
        'months': 'সেপ্টেম্বর, অক্টোবর, নভেম্বর (আংশিক)',
        'amount': '২,৫০০',
        'method': 'ক্যাশ',
        'date': '৫ নভেম্বর ২০২৬',
        'remaining_line': 'বাকি: ৳৫০০',
        'receipt_no': '২০২৬-০০০৭',
      });
      expect(
        text,
        'রসিদ নং ২০২৬-০০০৭ — আলো কোচিং\n'
        'শিক্ষার্থী: রহিম (১২)\n'
        'ব্যাচ: Physics A\n'
        'মাস: সেপ্টেম্বর, অক্টোবর, নভেম্বর (আংশিক)\n'
        'জমা: ৳২,৫০০ (ক্যাশ), তারিখ ৫ নভেম্বর ২০২৬\n'
        'বাকি: ৳৫০০\n'
        'ধন্যবাদ।',
      );
    });

    test('English receipt', () {
      final text = fillTemplate(DefaultTemplates.receiptEn, {
        'center': 'Alo Coaching',
        'student': 'Rahim',
        'id': '12',
        'batch': 'Physics A',
        'months': 'November',
        'amount': '1,000',
        'method': 'Cash',
        'date': '5 Nov 2026',
        'remaining_line': 'All fees paid',
        'receipt_no': '2026-0007',
      });
      expect(
        text,
        'Receipt #2026-0007 — Alo Coaching\n'
        'Student: Rahim (12)\n'
        'Batch: Physics A\n'
        'Months: November\n'
        'Paid: ৳1,000 (Cash), date 5 Nov 2026\n'
        'All fees paid\n'
        'Thank you.',
      );
    });
  });
}
