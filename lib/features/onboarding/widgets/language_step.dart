// Step 1: two huge language cards, the theme row and the optional center name.
// The language switches the whole app the moment a card is tapped.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/app_prefs_providers.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/features/onboarding/widgets/onb_common.dart';

class LanguageStep extends ConsumerWidget {
  const LanguageStep({super.key, required this.center, required this.onSubmit});

  final TextEditingController center;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final Lang lang = ref.watch(langProvider);
    final ThemeMode mode = ref.watch(themeModeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        OnbHeading(title: l10n.onbWelcomeTitle, body: l10n.onbWelcomeBody),
        const SizedBox(height: 20),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: _LangCard(
                  key: const Key('onb-lang-bn'),
                  title: l10n.onbLangBn,
                  hint: l10n.onbLangBnHint,
                  selected: lang == Lang.bn,
                  onTap: () => ref.read(langProvider.notifier).set(Lang.bn),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LangCard(
                  key: const Key('onb-lang-en'),
                  title: l10n.onbLangEn,
                  hint: l10n.onbLangEnHint,
                  selected: lang == Lang.en,
                  onTap: () => ref.read(langProvider.notifier).set(Lang.en),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        OnbSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(l10n.onbThemeTitle, style: tt.titleMedium?.copyWith(color: tokens.textPrimary)),
              ),
              const SizedBox(height: 8),
              SegmentedChoice<ThemeMode>(
                options: const <ThemeMode>[ThemeMode.system, ThemeMode.light, ThemeMode.dark],
                selected: mode,
                onChanged: (ThemeMode m) => ref.read(themeModeProvider.notifier).set(m),
                labelOf: (ThemeMode m) => switch (m) {
                  ThemeMode.system => l10n.onbThemeSystem,
                  ThemeMode.light => l10n.onbThemeLight,
                  ThemeMode.dark => l10n.onbThemeDark,
                },
              ),
              const SizedBox(height: 20),
              TextField(
                key: const Key('onb-center'),
                controller: center,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => onSubmit(),
                decoration: InputDecoration(
                  labelText: l10n.onbCenterLabel,
                  hintText: l10n.onbCenterHint,
                  helperText: l10n.onbCenterHelper,
                  helperMaxLines: 2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LangCard extends StatelessWidget {
  const _LangCard({
    super.key,
    required this.title,
    required this.hint,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final BorderRadius br = BorderRadius.circular(AuroraMetrics.radiusGlassCard);
    final Color fg = selected ? tokens.onAccentContainer : tokens.textPrimary;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: '$title. $hint',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? tokens.accentContainer : tokens.surfaceDense,
        shape: RoundedRectangleBorder(
          borderRadius: br,
          side: BorderSide(color: selected ? tokens.accent : tokens.hairline, width: selected ? 2 : 1),
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(borderRadius: br),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 120),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          title,
                          style: tt.headlineMedium?.copyWith(color: fg, fontWeight: FontWeight.w700),
                        ),
                      ),
                      Icon(
                        selected ? Icons.check_circle : Icons.circle_outlined,
                        color: selected ? tokens.onAccentContainer : tokens.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hint,
                    style: tt.bodyMedium?.copyWith(color: selected ? tokens.onAccentContainer : tokens.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
