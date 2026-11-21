// Step 1: two huge language cards, the theme row and the optional center name.
// The language switches the whole app the moment a card is tapped.

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/app_prefs_providers.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/features/onboarding/widgets/onb_common.dart';

class LanguageStep extends ConsumerWidget {
  const LanguageStep({super.key, required this.center, required this.onSubmit});

  final TextEditingController center;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final BhorThemeData b = context.bhor;
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
                child: Text(l10n.onbThemeTitle, style: b.type.heading),
              ),
              const SizedBox(height: 8),
              BhorSegmented<ThemeMode>(
                segments: <BhorSegment<ThemeMode>>[
                  BhorSegment<ThemeMode>(ThemeMode.system, l10n.onbThemeSystem),
                  BhorSegment<ThemeMode>(ThemeMode.light, l10n.onbThemeLight),
                  BhorSegment<ThemeMode>(ThemeMode.dark, l10n.onbThemeDark),
                ],
                value: mode,
                onChanged: (ThemeMode m) => ref.read(themeModeProvider.notifier).set(m),
              ),
              const SizedBox(height: 20),
              BhorTextField(
                key: const Key('onb-center'),
                controller: center,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => onSubmit(),
                label: l10n.onbCenterLabel,
                hint: l10n.onbCenterHint,
                helper: l10n.onbCenterHelper,
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
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    return BhorPressable(
      onTap: onTap,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      semanticLabel: '$title. $hint',
      excludeChildSemantics: true,
      radius: BhorRadius.card,
      builder: (BuildContext context, BhorStates s) => AnimatedContainer(
        duration: BhorMotion.fast,
        constraints: const BoxConstraints(minHeight: 120),
        padding: const EdgeInsets.all(BhorSpace.s16),
        decoration: BoxDecoration(
          color: selected ? c.accentTint : c.surface,
          borderRadius: BorderRadius.circular(BhorRadius.card),
          border: Border.all(
            color: selected ? c.accent : (s.hovered ? c.accentLine : c.line),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: Text(title, style: b.type.title.copyWith(color: selected ? c.accent : c.text))),
                AnimatedSwitcher(
                  duration: BhorMotion.base,
                  switchInCurve: BhorMotion.spring,
                  transitionBuilder: (Widget w, Animation<double> a) => ScaleTransition(scale: a, child: w),
                  child: selected
                      ? Icon(BhorIcons.checkCircleFill, key: const ValueKey<String>('on'), color: c.accent)
                      : Container(
                          key: const ValueKey<String>('off'),
                          width: 22,
                          height: 22,
                          margin: const EdgeInsets.all(1),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: c.text3, width: 1.5),
                          ),
                        ),
                ),
              ],
            ),
            const SizedBox(height: BhorSpace.s4),
            Text(hint, style: b.type.meta),
          ],
        ),
      ),
    );
  }
}
