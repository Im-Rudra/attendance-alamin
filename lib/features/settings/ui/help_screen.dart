// Help: short "how do I...?" answers in plain language. Questions open on tap.

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/shell/pane_split.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/features/settings/widgets/setting_widgets.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key, this.embedded = false});

  /// True inside a desktop dialog: only the content, no page chrome.
  final bool embedded;

  static List<(String, String)> _items(AppLocalizations l10n) => <(String, String)>[
        (l10n.setHelpQ1, l10n.setHelpA1),
        (l10n.setHelpQ2, l10n.setHelpA2),
        (l10n.setHelpQ3, l10n.setHelpA3),
        (l10n.setHelpQ4, l10n.setHelpA4),
        (l10n.setHelpQ5, l10n.setHelpA5),
        (l10n.setHelpQ6, l10n.setHelpA6),
      ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final BhorThemeData b = context.bhor;
    final double g = WindowClass.of(context).gutter;
    final bool inPane = PaneScope.isEmbedded(context);
    final List<(String, String)> items = _items(l10n);

    Widget tile((String, String) qa) => _FaqTile(key: ValueKey<String>(qa.$1), question: qa.$1, answer: qa.$2);

    if (embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(l10n.setHelpIntro, style: b.type.meta.copyWith(color: b.colors.text2)),
          const SizedBox(height: 12),
          SettingsCard(children: <Widget>[for (final qa in items) tile(qa)]),
        ],
      );
    }
    return BhorScaffold(
      header: BhorHeader(title: l10n.shellTitleHelp, showBack: inPane ? false : null),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints c) {
          final List<Widget> cards = <Widget>[
            SettingsCard(children: <Widget>[for (final qa in items) tile(qa)]),
          ];
          return ListView(
            padding: EdgeInsets.fromLTRB(g, 4, g, g),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                child: Text(l10n.setHelpIntro, style: b.type.meta.copyWith(color: b.colors.text2)),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: SettingsColumns(children: cards),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One question; tapping it shows or hides the answer.
class _FaqTile extends StatefulWidget {
  const _FaqTile({super.key, required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        BhorPressable(
          onTap: () => setState(() => _open = !_open),
          semanticLabel: widget.question,
          semanticHint: null,
          scaleOnPress: false,
          excludeChildSemantics: true,
          builder: (BuildContext context, BhorStates s) => Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s16, vertical: 10),
            color: s.hovered || s.pressed ? c.surface2 : null,
            child: Row(
              children: <Widget>[
                Expanded(child: Text(widget.question, style: b.type.body)),
                const SizedBox(width: BhorSpace.s8),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: BhorMotion.base,
                  curve: BhorMotion.spring,
                  child: Icon(BhorIcons.chevronDown, color: _open ? c.accent : c.text3),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: BhorMotion.base,
          curve: BhorMotion.ease,
          alignment: Alignment.topCenter,
          child: _open
              ? TweenAnimationBuilder<double>(
                  key: const ValueKey<String>('answer'),
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: BhorMotion.base,
                  curve: BhorMotion.ease,
                  builder: (BuildContext context, double t, Widget? child) => Opacity(opacity: t, child: child),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(BhorSpace.s16, 0, BhorSpace.s16, 14),
                    child: Text(widget.answer, style: b.type.meta.copyWith(color: c.text2)),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
