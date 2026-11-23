// Message template editor (Product 3.12 / section 5, UX 3a): edit the Bangla or
// English text, tap variable chips to insert details at the cursor, see a live
// preview with sample details and restore the default. It saves by itself.
//
// The teacher never sees raw `{student}` braces (review M4): the editor shows
// each variable as a readable pill ("[ছাত্রের নাম]") and converts it back to
// the stored `{student}` placeholder when it saves, so the stored template is
// unchanged. On desktop the editor and the live preview sit side by side in a
// wide side panel (720); on phones they stack.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/shell/pane_split.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/data/repositories/settings_providers.dart';
import 'package:attendance_alamin/data/repositories/settings_repository.dart';
import 'package:attendance_alamin/features/settings/data/template_logic.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

/// A text controller that paints `[label]` variable pills (accent on a soft
/// tint) inside the text. The text length is the text length: the cursor
/// and selection need no mapping.
class PillTextController extends TextEditingController {
  /// The labels that are variables (the others are plain text in brackets).
  Set<String> labels = <String>{};
  Color? pillColor;
  Color? pillBackground;

  static final RegExp _re = RegExp(r'\[([^\[\]\n]+)\]');

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final Color? fg = pillColor;
    final Color? bg = pillBackground;
    if (labels.isEmpty || fg == null || bg == null || (withComposing && value.composing.isValid)) {
      return super.buildTextSpan(context: context, style: style, withComposing: withComposing);
    }
    final TextStyle pill = (style ?? const TextStyle()).copyWith(
      color: fg,
      backgroundColor: bg,
      fontWeight: FontWeight.w600,
    );
    final String t = text;
    final List<InlineSpan> spans = <InlineSpan>[];
    int at = 0;
    for (final RegExpMatch m in _re.allMatches(t)) {
      if (!labels.contains(m.group(1))) continue;
      if (m.start > at) spans.add(TextSpan(text: t.substring(at, m.start)));
      spans.add(TextSpan(text: m.group(0), style: pill));
      at = m.end;
    }
    if (at < t.length) spans.add(TextSpan(text: t.substring(at)));
    return TextSpan(style: style, children: spans);
  }
}

class TemplateEditorScreen extends ConsumerStatefulWidget {
  const TemplateEditorScreen({super.key, required this.kind, this.embedded = false});

  /// Width of the desktop side panel: editor | preview side by side.
  static const double panelWidth = 720;

  /// True inside a desktop side panel: only the content, no page chrome.
  final bool embedded;

  /// `reminder` or `receipt`.
  final String kind;

  @override
  ConsumerState<TemplateEditorScreen> createState() => _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends ConsumerState<TemplateEditorScreen> {
  final PillTextController _controller = PillTextController();
  late final SettingsRepository _repo = ref.read(settingsRepositoryProvider);
  Timer? _timer;
  Lang? _lang;
  bool _loaded = false;
  bool _dirty = false;

  TemplateKind get _kind => TemplateKind.parse(widget.kind) ?? TemplateKind.reminder;

  /// name -> label in the app language (what the pills and chips show).
  Map<String, String> _labelOf(AppLocalizations l10n) =>
      <String, String>{for (final String n in placeholdersOf(_kind)) n: _phLabel(l10n, n)};

  /// label -> name, in every app language, so a message typed in one language
  /// still saves right after the app language changed.
  Map<String, String> _nameOf() {
    final Map<String, String> out = <String, String>{};
    for (final AppLocalizations l in <AppLocalizations>[
      lookupAppLocalizations(const Locale('bn')),
      lookupAppLocalizations(const Locale('en')),
      context.l10n,
    ]) {
      _labelOf(l).forEach((String name, String label) => out[label] = name);
    }
    return out;
  }

  /// The stored form (`{name}`) of the text in the field.
  String _storedText() => fromDisplayText(_controller.text, _nameOf());

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final BhorColors c = context.bhor.colors;
    _controller
      ..labels = _labelOf(context.l10n).values.toSet()
      ..pillColor = c.accent
      ..pillBackground = c.accentTint;
    if (_lang == null) {
      _lang = context.lang;
      _load(_lang!);
    }
  }

  Future<void> _load(Lang lang) async {
    String stored = '';
    try {
      stored = await _repo.get<String>(templateKey(_kind, lang));
    } on Object {
      stored = '';
    }
    if (!mounted || _lang != lang) return;
    _controller.value = TextEditingValue(
      text: toDisplayText(editorTextFor(_kind, lang, stored), _labelOf(context.l10n)),
      selection: const TextSelection.collapsed(offset: 0),
    );
    setState(() {
      _loaded = true;
      _dirty = false;
    });
  }

  void _changed(String _) {
    setState(() => _dirty = true);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 500), _flush);
  }

  /// Writes the pending edit now.
  void _flush() {
    _timer?.cancel();
    final Lang? lang = _lang;
    if (!_dirty || !_loaded || lang == null) return;
    _dirty = false;
    final String value = storedValueFor(_kind, lang, _storedText());
    _repo.set<String>(templateKey(_kind, lang), value).catchError((Object _) {});
  }

  Future<void> _switchLang(Lang lang) async {
    if (lang == _lang) return;
    _flush();
    setState(() {
      _lang = lang;
      _loaded = false;
    });
    await _load(lang);
  }

  void _insert(String name) {
    final String label = _phLabel(context.l10n, name);
    _controller.value = insertPlaceholder(_controller.value, name, token: '[$label]');
    _changed(_controller.text);
  }

  void _reset() {
    final Lang lang = _lang!;
    _timer?.cancel();
    _controller.value = TextEditingValue(
      text: toDisplayText(defaultTemplate(_kind, lang), _labelOf(context.l10n)),
      selection: const TextSelection.collapsed(offset: 0),
    );
    _dirty = false;
    _repo.set<String>(templateKey(_kind, lang), '').catchError((Object _) {});
    setState(() {});
    BhorToast.show(context, message: context.l10n.setTplResetDone);
  }

  @override
  void dispose() {
    _flush();
    _controller.dispose();
    super.dispose();
  }

  String _phLabel(AppLocalizations l10n, String name) => switch (name) {
        'student' => l10n.setPhStudent,
        'batch' => l10n.setPhBatch,
        'months' => l10n.setPhMonths,
        'amount' => l10n.setPhAmount,
        'center' => l10n.setPhCenter,
        'teacher_phone' => l10n.setPhTeacherPhone,
        'id' => l10n.setPhId,
        'method' => l10n.setPhMethod,
        'date' => l10n.setPhDate,
        'remaining_line' => l10n.setPhRemainingLine,
        'receipt_no' => l10n.setPhReceiptNo,
        _ => name,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final double g = WindowClass.of(context).gutter;
    final bool embedded = PaneScope.isEmbedded(context);
    final String title = switch (_kind) {
      TemplateKind.reminder => l10n.shellTitleTemplateReminder,
      TemplateKind.receipt => l10n.shellTitleTemplateReceipt,
    };
    final Lang lang = _lang ?? context.lang;
    // Side by side from 600 wide (the 720 side panel gives ~670), stacked below.
    final Widget body = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final Widget editor = _editorCard(context, lang);
        final Widget preview = _previewCard(context, lang);
        if (c.maxWidth >= 600) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: editor),
              const SizedBox(width: BhorSpace.s12),
              Expanded(child: preview),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[editor, const SizedBox(height: BhorSpace.s12), preview],
        );
      },
    );
    if (widget.embedded) return body;
    return BhorScaffold(
      header: BhorHeader(title: title, showBack: embedded ? false : null),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(g, 4, g, g),
        child: body,
      ),
    );
  }

  Widget _editorCard(BuildContext context, Lang lang) {
    final l10n = context.l10n;
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final List<String> unknown = unknownPlaceholders(_kind, _storedText());
    return BhorCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l10n.setTplLanguage, style: b.type.body),
          const SizedBox(height: BhorSpace.s8),
          BhorSegmented<Lang>(
            key: const Key('template-lang'),
            segments: <BhorSegment<Lang>>[
              for (final Lang v in Lang.values)
                BhorSegment<Lang>(v, v == Lang.bn ? l10n.shellLangBangla : l10n.shellLangEnglish),
            ],
            value: lang,
            onChanged: _switchLang,
          ),
          const SizedBox(height: BhorSpace.s16),
          BhorTextField(
            key: const Key('template-field'),
            controller: _controller,
            enabled: _loaded,
            minLines: 6,
            maxLines: 14,
            keyboardType: TextInputType.multiline,
            onChanged: _changed,
            label: l10n.setTplEditor,
            helper: l10n.setTplEmptyNote,
          ),
          if (unknown.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: BhorSpace.s8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(BhorIcons.info, size: 18, color: c.accent),
                  const SizedBox(width: BhorSpace.s8),
                  Expanded(
                    child: Text(
                      l10n.setTplUnknown(unknown.map((String n) => '{$n}').join(', ')),
                      style: b.type.meta.copyWith(color: c.accent),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: BhorSpace.s16),
          Text(l10n.setTplChips, style: b.type.meta),
          const SizedBox(height: BhorSpace.s8),
          Wrap(
            spacing: BhorSpace.s8,
            runSpacing: BhorSpace.s4,
            children: <Widget>[
              for (final String name in placeholdersOf(_kind))
                BhorChip(
                  key: Key('chip-$name'),
                  label: _phLabel(l10n, name),
                  selected: false,
                  onSelected: _loaded ? (bool _) => _insert(name) : null,
                ),
            ],
          ),
          const SizedBox(height: BhorSpace.s16),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: BhorButton(
              key: const Key('template-reset'),
              variant: BhorButtonVariant.secondary,
              onPressed: _loaded ? _reset : null,
              icon: BhorIcons.refresh,
              label: l10n.setTplReset,
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewCard(BuildContext context, Lang lang) {
    final l10n = context.l10n;
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    return BhorCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(header: true, child: Text(l10n.setTplPreview, style: b.type.heading)),
          const SizedBox(height: BhorSpace.s4),
          Text(l10n.setTplSampleNote, style: b.type.meta),
          const SizedBox(height: BhorSpace.s12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: c.accentTint,
              borderRadius: BorderRadius.circular(BhorRadius.control),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                renderPreview(_kind, lang, _storedText()),
                key: const Key('template-preview'),
                style: b.type.body,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
