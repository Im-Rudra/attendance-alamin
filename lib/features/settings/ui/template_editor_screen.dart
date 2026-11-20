// Message template editor (Product 3.12 / section 5, UX 3a): edit the Bangla or
// English text, tap placeholder chips to insert details at the cursor, see a
// live preview with sample details and restore the default. It saves by itself.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/shell/pane_split.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/data/repositories/settings_providers.dart';
import 'package:attendance_alamin/data/repositories/settings_repository.dart';
import 'package:attendance_alamin/features/settings/data/template_logic.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

class TemplateEditorScreen extends ConsumerStatefulWidget {
  const TemplateEditorScreen({super.key, required this.kind});

  /// `reminder` or `receipt`.
  final String kind;

  @override
  ConsumerState<TemplateEditorScreen> createState() => _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends ConsumerState<TemplateEditorScreen> {
  final TextEditingController _controller = TextEditingController();
  late final SettingsRepository _repo = ref.read(settingsRepositoryProvider);
  Timer? _timer;
  Lang? _lang;
  bool _loaded = false;
  bool _dirty = false;

  TemplateKind get _kind => TemplateKind.parse(widget.kind) ?? TemplateKind.reminder;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
      text: editorTextFor(_kind, lang, stored),
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
    final String value = storedValueFor(_kind, lang, _controller.text);
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
    _controller.value = insertPlaceholder(_controller.value, name);
    _changed(_controller.text);
  }

  void _reset() {
    final Lang lang = _lang!;
    _timer?.cancel();
    _controller.value = TextEditingValue(
      text: defaultTemplate(_kind, lang),
      selection: const TextSelection.collapsed(offset: 0),
    );
    _dirty = false;
    _repo.set<String>(templateKey(_kind, lang), '').catchError((Object _) {});
    setState(() {});
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(context.l10n.setTplResetDone)));
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
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !embedded,
        title: Semantics(header: true, child: Text(title)),
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            final Widget editor = _editorCard(context, lang);
            final Widget preview = _previewCard(context, lang);
            if (c.maxWidth >= WindowClass.expandedMin) {
              return Padding(
                padding: EdgeInsets.fromLTRB(g, 4, g, g),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(child: SingleChildScrollView(child: editor)),
                    SizedBox(width: g),
                    Expanded(child: SingleChildScrollView(child: preview)),
                  ],
                ),
              );
            }
            return ListView(
              padding: EdgeInsets.fromLTRB(g, 4, g, g),
              children: <Widget>[editor, const SizedBox(height: 12), preview],
            );
          },
        ),
      ),
    );
  }

  Widget _editorCard(BuildContext context, Lang lang) {
    final l10n = context.l10n;
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final List<String> unknown = unknownPlaceholders(_kind, _controller.text);
    return GlassCard(
      dense: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l10n.setTplLanguage, style: tt.bodyLarge),
          const SizedBox(height: 8),
          SegmentedChoice<Lang>(
            key: const Key('template-lang'),
            options: Lang.values,
            selected: lang,
            onChanged: _switchLang,
            labelOf: (Lang v) => v == Lang.bn ? l10n.shellLangBangla : l10n.shellLangEnglish,
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('template-field'),
            controller: _controller,
            enabled: _loaded,
            minLines: 6,
            maxLines: 14,
            keyboardType: TextInputType.multiline,
            onChanged: _changed,
            decoration: InputDecoration(
              labelText: l10n.setTplEditor,
              helperText: l10n.setTplEmptyNote,
              helperMaxLines: 2,
              alignLabelWithHint: true,
            ),
          ),
          if (unknown.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.info_outline, size: 18, color: tokens.info),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.setTplUnknown(unknown.map((String n) => '{$n}').join(', ')),
                      style: tt.bodyMedium?.copyWith(color: tokens.info),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Text(l10n.setTplChips, style: tt.bodyMedium?.copyWith(color: tokens.textSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final String name in placeholdersOf(_kind))
                ActionChip(
                  key: Key('chip-$name'),
                  label: Text(_phLabel(l10n, name)),
                  tooltip: '{$name}',
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  onPressed: _loaded ? () => _insert(name) : null,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              key: const Key('template-reset'),
              onPressed: _loaded ? _reset : null,
              icon: const Icon(Icons.restart_alt),
              label: Text(l10n.setTplReset),
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewCard(BuildContext context, Lang lang) {
    final l10n = context.l10n;
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    return GlassCard(
      dense: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(header: true, child: Text(l10n.setTplPreview, style: tt.titleMedium)),
          const SizedBox(height: 4),
          Text(l10n.setTplSampleNote, style: tt.bodyMedium?.copyWith(color: tokens.textSecondary)),
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.accentContainer,
              borderRadius: BorderRadius.circular(AuroraMetrics.radiusField),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                renderPreview(_kind, lang, _controller.text),
                key: const Key('template-preview'),
                style: tt.bodyLarge?.copyWith(color: tokens.textPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
