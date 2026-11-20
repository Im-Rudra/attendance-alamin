// MoreScreen: STUB by M5-A (plan section 0). The body belongs to M6-E
// (settings); keep the constructor signature (routes are frozen).
//
// Until M6-E lands, this placeholder already offers the two appearance
// settings (language, theme: both switch instantly) and links to every page
// under আরও, so the whole shell can be explored.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/app_prefs_providers.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/stub_screen.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/core/format/lang.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tokens = context.aurora;
    final TextStyle? rowLabel = Theme.of(context).textTheme.labelLarge?.copyWith(color: tokens.textSecondary);
    final Lang lang = ref.watch(langProvider);
    final ThemeMode mode = ref.watch(themeModeProvider);

    return StubScreen(
      name: l10n.navMore,
      icon: Icons.menu,
      showSearch: true,
      body: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          StubSectionTitle(l10n.shellAppearance),
          GlassCard(
            dense: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(l10n.shellLanguage, style: rowLabel),
                const SizedBox(height: 8),
                SegmentedChoice<Lang>(
                  key: const Key('more-language'),
                  options: Lang.values,
                  selected: lang,
                  onChanged: (Lang v) => ref.read(langProvider.notifier).set(v),
                  labelOf: (Lang v) => v == Lang.bn ? l10n.shellLangBangla : l10n.shellLangEnglish,
                ),
                const SizedBox(height: 16),
                Text(l10n.shellTheme, style: rowLabel),
                const SizedBox(height: 8),
                SegmentedChoice<ThemeMode>(
                  key: const Key('more-theme'),
                  options: const <ThemeMode>[ThemeMode.system, ThemeMode.light, ThemeMode.dark],
                  selected: mode,
                  onChanged: (ThemeMode v) => ref.read(themeModeProvider.notifier).set(v),
                  labelOf: (ThemeMode v) => switch (v) {
                    ThemeMode.system => l10n.shellThemeSystem,
                    ThemeMode.light => l10n.shellThemeLight,
                    ThemeMode.dark => l10n.shellThemeDark,
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          StubSectionTitle(l10n.shellArchiveGroup),
          _LinkCard(links: <_Link>[
            _Link(Icons.inventory_2_outlined, l10n.shellTitleArchived, Routes.moreArchived),
            _Link(Icons.person_off_outlined, l10n.shellTitleLeft, Routes.moreLeft),
            _Link(Icons.help_outline, l10n.shellTitleHelp, Routes.moreHelp),
          ]),
          const SizedBox(height: 12),
          StubSectionTitle(l10n.shellSettingsGroup),
          _LinkCard(links: <_Link>[
            _Link(Icons.save_alt_outlined, l10n.shellTitleBackup, Routes.moreBackup),
            _Link(Icons.account_balance_wallet_outlined, l10n.shellTitlePaymentMethods, Routes.morePaymentMethods),
            _Link(Icons.edit_note, l10n.shellTitleTemplateReminder, Routes.moreTemplate('reminder')),
            _Link(Icons.edit_note, l10n.shellTitleTemplateReceipt, Routes.moreTemplate('receipt')),
            _Link(Icons.beach_access_outlined, l10n.shellTitleHolidays, Routes.moreHolidays),
            _Link(Icons.monitor_heart_outlined, l10n.shellTitleDiagnostics, Routes.moreDiagnostics),
          ]),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _Link {
  const _Link(this.icon, this.label, this.route);

  final IconData icon;
  final String label;
  final String route;
}

class _LinkCard extends StatelessWidget {
  const _LinkCard({required this.links});

  final List<_Link> links;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    return GlassCard(
      dense: true,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: <Widget>[
            for (int i = 0; i < links.length; i++) ...<Widget>[
              if (i > 0) Divider(indent: 56, color: tokens.track),
              ListTile(
                leading: Icon(links[i].icon, color: tokens.accent),
                title: Text(links[i].label),
                trailing: Icon(Icons.chevron_right, color: tokens.textSecondary),
                onTap: () => context.go(links[i].route),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
