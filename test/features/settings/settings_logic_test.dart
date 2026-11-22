// Pure logic of Settings & More: custom payment methods (validation, storage
// format) and message templates (preview, default/custom storage, chips).

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/core/settings/setting_keys.dart';
import 'package:attendance_alamin/core/templates/default_templates.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/features/settings/data/payment_methods_config.dart';
import 'package:attendance_alamin/features/settings/data/template_logic.dart';
import 'package:attendance_alamin/features/settings/widgets/int_choice_sheet.dart';

void main() {
  group('custom payment method validation', () {
    const PaymentMethodsConfig empty = PaymentMethodsConfig.empty;

    test('blank is rejected', () {
      expect(empty.checkCustomLabel(''), CustomLabelCheck.empty);
      expect(empty.checkCustomLabel('   '), CustomLabelCheck.empty);
      expect(empty.withCustom('  '), isNull);
    });

    test('longer than 20 characters is rejected, exactly 20 is fine', () {
      expect(empty.checkCustomLabel('a' * 21), CustomLabelCheck.tooLong);
      expect(empty.checkCustomLabel('a' * 20), CustomLabelCheck.ok);
    });

    test('a label is trimmed and becomes custom:<label>', () {
      final PaymentMethodsConfig? c = empty.withCustom('  উপায়  ');
      expect(c, isNotNull);
      expect(c!.custom, <String>['উপায়']);
      expect(c.visible.last.code, 'custom:উপায়');
      expect(c.visible.last.isCustom, isTrue);
      expect(c.visible.last.customLabel, 'উপায়');
    });

    test('duplicates are rejected, ignoring case and spaces', () {
      final PaymentMethodsConfig c = empty.withCustom('Upay')!;
      expect(c.checkCustomLabel('upay'), CustomLabelCheck.duplicate);
      expect(c.checkCustomLabel(' UPAY '), CustomLabelCheck.duplicate);
      expect(c.withCustom('Upay'), isNull);
    });

    test('built-in names (code or shown name) are reserved', () {
      expect(empty.checkCustomLabel('cash'), CustomLabelCheck.duplicate);
      expect(empty.checkCustomLabel('Bkash'), CustomLabelCheck.duplicate);
      expect(
        empty.checkCustomLabel('বিকাশ', reserved: const <String>['ক্যাশ', 'বিকাশ']),
        CustomLabelCheck.duplicate,
      );
      expect(empty.checkCustomLabel('বিকাশ'), CustomLabelCheck.ok);
    });

    test('removing a custom method', () {
      final PaymentMethodsConfig c = empty.withCustom('Upay')!.withCustom('Tap')!;
      expect(c.withoutCustom('Upay').custom, <String>['Tap']);
    });
  });

  group('payment method configuration', () {
    test('default text and garbage read as "all built-ins, no custom"', () {
      for (final String? text in <String?>[null, '', '[]', 'nonsense', '42', '{"hidden": 3}']) {
        final PaymentMethodsConfig c = PaymentMethodsConfig.decode(text);
        expect(c.hidden, isEmpty, reason: '$text');
        expect(c.custom, isEmpty, reason: '$text');
        expect(c.visible, PaymentMethod.builtIns);
      }
    });

    test('an untouched configuration encodes to the default []', () {
      expect(PaymentMethodsConfig.empty.encode(), '[]');
    });

    test('hide and custom survive a round trip; unknown entries are dropped', () {
      final PaymentMethodsConfig c = PaymentMethodsConfig.empty
          .withBuiltInShown(PaymentMethod.rocket, shown: false)
          .withCustom('Upay')!;
      final PaymentMethodsConfig back = PaymentMethodsConfig.decode(c.encode());
      expect(back, c);
      expect(back.visible.map((PaymentMethod m) => m.code),
          <String>['cash', 'bkash', 'nagad', 'bank', 'other', 'custom:Upay']);

      final PaymentMethodsConfig messy = PaymentMethodsConfig.decode(
          '{"hidden":["rocket","nope",5],"custom":["Upay","upay","",7,"${'x' * 30}"]}');
      expect(messy.hidden, <String>{'rocket'});
      expect(messy.custom, <String>['Upay']);
    });

    test('the last visible method cannot be hidden', () {
      PaymentMethodsConfig c = PaymentMethodsConfig.empty;
      for (final PaymentMethod m in PaymentMethod.builtIns) {
        c = c.withBuiltInShown(m, shown: false);
      }
      expect(c.visibleCount, 1);
      // With a custom method present every built-in may go.
      c = PaymentMethodsConfig.empty.withCustom('Upay')!;
      for (final PaymentMethod m in PaymentMethod.builtIns) {
        c = c.withBuiltInShown(m, shown: false);
      }
      expect(c.visible.map((PaymentMethod m) => m.code), <String>['custom:Upay']);
    });

    test('the stored text is valid for the typed setting key', () {
      final String text = PaymentMethodsConfig.empty.withCustom('Upay')!.encode();
      expect(SettingKeys.paymentMethods.decode(SettingKeys.paymentMethods.encode(text)), text);
    });
  });

  group('message templates', () {
    test('a blank template previews as the default with sample details', () {
      final String p = renderPreview(TemplateKind.reminder, Lang.bn, '');
      expect(p, isNot(contains('{')));
      expect(p, contains('রাহিম'));
      expect(p, contains('২,০০০'));
      expect(renderPreview(TemplateKind.receipt, Lang.en, ''), contains('Rahim'));
      expect(renderPreview(TemplateKind.receipt, Lang.en, ''), contains('Remaining: ৳500'));
    });

    test('the preview follows the edited text live', () {
      expect(
        renderPreview(TemplateKind.reminder, Lang.en, 'Hi {student}, {amount} due'),
        'Hi Rahim, 2,000 due',
      );
    });

    test('an unknown placeholder stays visible and is reported once', () {
      const String text = 'Hi {student} {studnet} {studnet} {amount}';
      expect(renderPreview(TemplateKind.reminder, Lang.en, text), contains('{studnet}'));
      expect(unknownPlaceholders(TemplateKind.reminder, text), <String>['studnet']);
      // {id} is a receipt field, not a reminder field.
      expect(unknownPlaceholders(TemplateKind.reminder, '{id}'), <String>['id']);
      expect(unknownPlaceholders(TemplateKind.receipt, '{id}'), isEmpty);
    });

    test('every default template uses only known placeholders', () {
      for (final TemplateKind k in TemplateKind.values) {
        for (final Lang l in Lang.values) {
          expect(unknownPlaceholders(k, defaultTemplate(k, l)), isEmpty, reason: '$k $l');
        }
      }
    });

    test('reset: the default text is stored as empty, a custom text as itself', () {
      for (final TemplateKind k in TemplateKind.values) {
        for (final Lang l in Lang.values) {
          expect(storedValueFor(k, l, defaultTemplate(k, l)), '');
          expect(storedValueFor(k, l, '   '), '');
          expect(editorTextFor(k, l, ''), defaultTemplate(k, l));
        }
      }
      expect(storedValueFor(TemplateKind.reminder, Lang.bn, 'আমার বার্তা'), 'আমার বার্তা');
      expect(editorTextFor(TemplateKind.reminder, Lang.bn, 'আমার বার্তা'), 'আমার বার্তা');
      expect(isCustomTemplate(''), isFalse);
      expect(isCustomTemplate('x'), isTrue);
    });

    test('each kind and language has its own setting key', () {
      expect(templateKey(TemplateKind.reminder, Lang.bn), SettingKeys.reminderTemplateBn);
      expect(templateKey(TemplateKind.reminder, Lang.en), SettingKeys.reminderTemplateEn);
      expect(templateKey(TemplateKind.receipt, Lang.bn), SettingKeys.receiptTemplateBn);
      expect(templateKey(TemplateKind.receipt, Lang.en), SettingKeys.receiptTemplateEn);
      expect(defaultTemplate(TemplateKind.reminder, Lang.bn), DefaultTemplates.reminderBn);
    });

    test('a chip inserts {name} at the cursor, replacing a selection', () {
      final TextEditingValue v = insertPlaceholder(
        const TextEditingValue(text: 'Dear , hi', selection: TextSelection.collapsed(offset: 5)),
        'student',
      );
      expect(v.text, 'Dear {student}, hi');
      expect(v.selection.baseOffset, 14);

      final TextEditingValue r = insertPlaceholder(
        const TextEditingValue(text: 'abcdef', selection: TextSelection(baseOffset: 1, extentOffset: 4)),
        'batch',
      );
      expect(r.text, 'a{batch}ef');

      final TextEditingValue end = insertPlaceholder(const TextEditingValue(text: 'abc'), 'amount');
      expect(end.text, 'abc{amount}');
    });

    test('variables show as [label] pills and convert back to the stored {name}', () {
      const Map<String, String> label = <String, String>{'student': 'ছাত্রের নাম', 'amount': 'টাকা'};
      const Map<String, String> name = <String, String>{'ছাত্রের নাম': 'student', 'টাকা': 'amount'};
      const String stored = 'প্রিয় {student}, {amount} বাকি {x}';
      final String shown = toDisplayText(stored, label);
      expect(shown, 'প্রিয় [ছাত্রের নাম], [টাকা] বাকি {x}');
      expect(fromDisplayText(shown, name), stored, reason: 'a round trip stores the same placeholders');
      // Brackets around anything else are plain text.
      expect(fromDisplayText('see [note] [টাকা]', name), 'see [note] {amount}');
    });

    test('a pill token is inserted at the cursor like a placeholder', () {
      final TextEditingValue v = insertPlaceholder(
        const TextEditingValue(text: 'Dear , hi', selection: TextSelection.collapsed(offset: 5)),
        'student',
        token: '[Student]',
      );
      expect(v.text, 'Dear [Student], hi');
      expect(v.selection.baseOffset, 14);
    });

    test('placeholders per kind match the Product section 5 lists', () {
      expect(placeholdersOf(TemplateKind.reminder),
          <String>['student', 'batch', 'months', 'amount', 'center', 'teacher_phone']);
      expect(placeholdersOf(TemplateKind.receipt), contains('remaining_line'));
      expect(TemplateKind.parse('receipt'), TemplateKind.receipt);
      expect(TemplateKind.parse('x'), isNull);
    });
  });

  group('typed number in a sheet', () {
    test('accepts Bangla and Latin digits inside the range only', () {
      expect(parseNumberInRange('২০', min: 1, max: 180), 20);
      expect(parseNumberInRange(' 45 ', min: 1, max: 180), 45);
      expect(parseNumberInRange('0', min: 1, max: 180), isNull);
      expect(parseNumberInRange('181', min: 1, max: 180), isNull);
      expect(parseNumberInRange('', min: 1, max: 28), isNull);
      expect(parseNumberInRange('abc', min: 1, max: 28), isNull);
    });
  });
}
