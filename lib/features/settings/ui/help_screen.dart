// Help: short "how do I...?" answers in plain language. Questions open on tap.

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/shell/pane_split.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/features/settings/widgets/setting_widgets.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

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
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final double g = WindowClass.of(context).gutter;
    final bool embedded = PaneScope.isEmbedded(context);
    final List<(String, String)> items = _items(l10n);

    Widget tile((String, String) qa) => ExpansionTile(
          key: PageStorageKey<String>(qa.$1),
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          expandedAlignment: Alignment.centerLeft,
          title: Text(qa.$1, style: tt.bodyLarge?.copyWith(color: tokens.textPrimary)),
          iconColor: tokens.accent,
          collapsedIconColor: tokens.textSecondary,
          children: <Widget>[
            Text(qa.$2, style: tt.bodyMedium?.copyWith(color: tokens.textSecondary)),
          ],
        );

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !embedded,
        title: Semantics(header: true, child: Text(l10n.shellTitleHelp)),
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            final bool wide = c.maxWidth >= WindowClass.expandedMin;
            final List<Widget> cards = wide
                ? <Widget>[
                    SettingsCard(children: <Widget>[for (final qa in items.sublist(0, 3)) tile(qa)]),
                    SettingsCard(children: <Widget>[for (final qa in items.sublist(3)) tile(qa)]),
                  ]
                : <Widget>[
                    SettingsCard(children: <Widget>[for (final qa in items) tile(qa)]),
                  ];
            return ListView(
              padding: EdgeInsets.fromLTRB(g, 4, g, g),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                  child: Text(
                    l10n.setHelpIntro,
                    style: tt.bodyMedium?.copyWith(color: tokens.textSecondary),
                  ),
                ),
                SettingsColumns(twoUp: wide, children: cards),
              ],
            );
          },
        ),
      ),
    );
  }
}
