// Message-template logic for the editor (Product section 5, 3.12): which
// placeholders each template knows, sample values for the live preview, the
// default-vs-custom storage rule and cursor insertion. Pure Dart + a
// TextEditingValue helper; no providers.

import 'package:flutter/services.dart' show TextEditingValue, TextSelection;

import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/core/settings/setting_keys.dart';
import 'package:attendance_alamin/core/templates/default_templates.dart';
import 'package:attendance_alamin/core/templates/template_engine.dart';

enum TemplateKind {
  reminder,
  receipt;

  /// Route parameter value.
  String get code => name;

  static TemplateKind? parse(String? code) {
    for (final TemplateKind k in TemplateKind.values) {
      if (k.code == code) return k;
    }
    return null;
  }
}

/// Placeholder names (without braces) each template understands, in the order
/// the chips are shown.
List<String> placeholdersOf(TemplateKind kind) => switch (kind) {
      TemplateKind.reminder => const <String>[
          'student',
          'batch',
          'months',
          'amount',
          'center',
          'teacher_phone',
        ],
      TemplateKind.receipt => const <String>[
          'center',
          'student',
          'id',
          'batch',
          'months',
          'amount',
          'method',
          'date',
          'remaining_line',
        ],
    };

/// The synced setting holding the custom text ('' = use the default).
SettingKey<String> templateKey(TemplateKind kind, Lang lang) => switch ((kind, lang)) {
      (TemplateKind.reminder, Lang.bn) => SettingKeys.reminderTemplateBn,
      (TemplateKind.reminder, Lang.en) => SettingKeys.reminderTemplateEn,
      (TemplateKind.receipt, Lang.bn) => SettingKeys.receiptTemplateBn,
      (TemplateKind.receipt, Lang.en) => SettingKeys.receiptTemplateEn,
    };

String defaultTemplate(TemplateKind kind, Lang lang) => switch (kind) {
      TemplateKind.reminder => DefaultTemplates.reminder(lang),
      TemplateKind.receipt => DefaultTemplates.receipt(lang),
    };

/// The text the editor shows for the stored value [stored] ('' = default).
String editorTextFor(TemplateKind kind, Lang lang, String stored) =>
    stored.trim().isEmpty ? defaultTemplate(kind, lang) : stored;

/// What to store for the editor text [text]: '' when it is blank or equals the
/// default (so later default improvements still apply), else the text.
String storedValueFor(TemplateKind kind, Lang lang, String text) {
  if (text.trim().isEmpty) return '';
  if (text == defaultTemplate(kind, lang)) return '';
  return text;
}

/// Whether [stored] is a teacher-written template.
bool isCustomTemplate(String stored) => stored.trim().isNotEmpty;

/// Sample values the preview fills in (the language of the template, not of the
/// app: a Bangla message previews with Bangla details).
Map<String, String> sampleValues(TemplateKind kind, Lang lang) {
  if (lang == Lang.bn) {
    return const <String, String>{
      'student': 'রাহিম',
      'batch': 'পদার্থবিজ্ঞান ব্যাচ A',
      'months': 'অক্টোবর, নভেম্বর',
      'amount': '২,০০০',
      'center': 'আপনার কোচিং',
      'teacher_phone': '০১৭১২৩৪৫৬৭৮',
      'id': 'S-০০১২',
      'method': 'বিকাশ',
      'date': '২১ নভেম্বর ২০২৬',
      'remaining_line': 'বাকি: ৳৫০০',
    };
  }
  return const <String, String>{
    'student': 'Rahim',
    'batch': 'Physics Batch A',
    'months': 'October, November',
    'amount': '2,000',
    'center': 'Your Coaching',
    'teacher_phone': '01712345678',
    'id': 'S-0012',
    'method': 'bKash',
    'date': '21 Nov 2026',
    'remaining_line': 'Remaining: ৳500',
  };
}

/// Live preview of [text] (blank means the default) with sample values.
String renderPreview(TemplateKind kind, Lang lang, String text) {
  final String effective = text.trim().isEmpty ? defaultTemplate(kind, lang) : text;
  return fillTemplate(effective, sampleValues(kind, lang));
}

final RegExp _tokenRe = RegExp(r'\{([A-Za-z0-9_]+)\}');

/// Placeholder names used in [text] that this template does not know (a typo
/// stays visible in the message, so the editor warns about it). Distinct, in
/// order of appearance.
List<String> unknownPlaceholders(TemplateKind kind, String text) {
  final Set<String> known = placeholdersOf(kind).toSet();
  final List<String> out = <String>[];
  for (final RegExpMatch m in _tokenRe.allMatches(text)) {
    final String name = m.group(1)!;
    if (!known.contains(name) && !out.contains(name)) out.add(name);
  }
  return out;
}

final RegExp _pillRe = RegExp(r'\[([^\[\]\n]+)\]');

/// The text the editor shows for the stored [stored]: every known `{name}`
/// becomes a readable pill `[label]` (the teacher never sees raw braces).
/// [labelOf] maps a placeholder name to its label; unknown names stay as
/// typed (the editor flags them).
String toDisplayText(String stored, Map<String, String> labelOf) =>
    stored.replaceAllMapped(_tokenRe, (Match m) {
      final String? label = labelOf[m.group(1)];
      return label == null ? m.group(0)! : '[$label]';
    });

/// The inverse of [toDisplayText]: `[label]` back to the stored `{name}`.
/// [nameOf] maps a label (in any app language) to the placeholder name;
/// brackets around anything else are left alone.
String fromDisplayText(String shown, Map<String, String> nameOf) =>
    shown.replaceAllMapped(_pillRe, (Match m) {
      final String? name = nameOf[m.group(1)];
      return name == null ? m.group(0)! : '{$name}';
    });

/// [value] with `{name}` (or [token] when given) inserted at the cursor
/// (replacing a selection); at the end when there is no valid cursor. The
/// cursor lands after the inserted text.
TextEditingValue insertPlaceholder(TextEditingValue value, String name, {String? token}) {
  token ??= '{$name}';
  final String text = value.text;
  final TextSelection sel = value.selection;
  int start = text.length;
  int end = text.length;
  if (sel.isValid && sel.start >= 0 && sel.end <= text.length) {
    start = sel.start;
    end = sel.end;
  }
  final String next = text.replaceRange(start, end, token);
  return TextEditingValue(
    text: next,
    selection: TextSelection.collapsed(offset: start + token.length),
  );
}
