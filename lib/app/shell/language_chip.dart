// The always-visible language chip "বাং | EN" (UX 1: one tap, on the Today
// top bar). Switches the whole app instantly; the choice is saved per device.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/app_prefs_providers.dart';
import 'package:attendance_alamin/core/format/lang.dart';

class LanguageChip extends ConsumerWidget {
  const LanguageChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Lang lang = ref.watch(langProvider);
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final l10n = context.l10n;

    Widget segment(Lang value, String label) {
      final bool selected = value == lang;
      return AnimatedContainer(
        duration: BhorMotion.base,
        curve: BhorMotion.curve,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: selected ? c.accentTint : null,
          borderRadius: BorderRadius.circular(BhorRadius.chip - 3),
        ),
        child: Text(
          label,
          style: b.type.label.copyWith(
            color: selected ? c.accent : c.text2,
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
      child: BhorTooltip(
        message: l10n.a11yLanguageSwitch,
        enabled: context.bhorIsWide,
        child: BhorPressable(
          key: const Key('language-chip'),
          onTap: () => ref.read(langProvider.notifier).set(other),
          semanticLabel: l10n.a11yLanguageSwitch,
          excludeChildSemantics: true,
          radius: BhorRadius.chip,
          builder: (BuildContext context, BhorStates s) => ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Center(
              widthFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: s.hovered ? c.surface2 : c.surface,
                  borderRadius: BorderRadius.circular(BhorRadius.chip),
                  border: Border.all(color: s.hovered ? c.accentLine : c.line),
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
    );
  }
}
