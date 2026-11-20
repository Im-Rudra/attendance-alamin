// The always-visible language chip "বাং | EN" (UX 1: one tap, on the Today
// top bar). Switches the whole app instantly; the choice is saved per device.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/app_prefs_providers.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/core/format/lang.dart';

class LanguageChip extends ConsumerWidget {
  const LanguageChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Lang lang = ref.watch(langProvider);
    final tokens = context.aurora;
    final l10n = context.l10n;
    final TextStyle? base = Theme.of(context).textTheme.labelMedium;

    Widget segment(Lang value, String label) {
      final bool selected = value == lang;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: ShapeDecoration(
          shape: const StadiumBorder(),
          color: selected ? tokens.accentContainer : Colors.transparent,
        ),
        child: Text(
          label,
          style: base?.copyWith(
            color: selected ? tokens.onAccentContainer : tokens.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      );
    }

    final Lang other = lang == Lang.bn ? Lang.en : Lang.bn;
    return Semantics(
      button: true,
      label: l10n.a11yLanguageSwitch,
      value: lang == Lang.bn ? l10n.shellLangBangla : l10n.shellLangEnglish,
      excludeSemantics: true,
      child: Tooltip(
        message: l10n.a11yLanguageSwitch,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: const Key('language-chip'),
            customBorder: const StadiumBorder(),
            onTap: () => ref.read(langProvider.notifier).set(other),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Center(
                widthFactor: 1,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    shape: StadiumBorder(side: BorderSide(color: tokens.hairline)),
                    color: tokens.glassNoBlur,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        segment(Lang.bn, l10n.shellLangChipBn),
                        segment(Lang.en, l10n.shellLangChipEn),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
