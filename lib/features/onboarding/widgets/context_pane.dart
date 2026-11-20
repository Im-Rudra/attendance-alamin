// Desktop side pane of onboarding: the Aurora hero gradient with the four
// steps (done / now / next) and a plain tip for the current one, so the wide
// window never has an empty half. No illustration, only words.

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';

class OnbContextPane extends StatelessWidget {
  const OnbContextPane({super.key, required this.step});

  /// Zero-based current step.
  final int step;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final g = context.gradients;
    final TextTheme tt = Theme.of(context).textTheme;
    final BorderRadius br = BorderRadius.circular(AuroraMetrics.radiusHero);
    final List<String> names = <String>[
      l10n.onbStepNameLang,
      l10n.onbStepNameBatch,
      l10n.onbStepNameStudents,
      l10n.onbStepNameRemind,
    ];
    final List<String> tips = <String>[
      l10n.onbTipLang,
      l10n.onbTipBatch,
      l10n.onbTipStudents,
      l10n.onbTipRemind,
    ];

    Widget row(int i) {
      final bool done = i < step;
      final bool now = i == step;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: <Widget>[
            Icon(
              done ? Icons.check_circle : (now ? Icons.radio_button_checked : Icons.radio_button_unchecked),
              color: now || done ? g.heroText : g.heroTextSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${context.fmt.number(i + 1)}. ${names[i]}',
                style: tt.titleMedium?.copyWith(
                  color: now ? g.heroText : g.heroTextSecondary,
                  fontWeight: now ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: br,
        boxShadow: <BoxShadow>[
          BoxShadow(color: g.heroShadow, blurRadius: 32, offset: const Offset(0, 12)),
        ],
      ),
      child: ClipRRect(
        borderRadius: br,
        child: Stack(
          children: <Widget>[
            Positioned.fill(child: ColoredBox(color: g.heroBase)),
            for (final RadialGradient r in g.heroRadials)
              Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: r))),
            Positioned(left: 24, right: 24, top: 0, height: 1, child: ColoredBox(color: g.heroTopHighlight)),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints box) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: IntrinsicHeight(
                     child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          l10n.onbPaneTitle,
                          style: tt.headlineSmall?.copyWith(color: g.heroText, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(l10n.onbPaneBody, style: tt.bodyLarge?.copyWith(color: g.heroTextSecondary)),
                        const SizedBox(height: 24),
                        for (int i = 0; i < names.length; i++) row(i),
                        const SizedBox(height: 24),
                        const Spacer(),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: g.heroText.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AuroraMetrics.radiusDenseList),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Icon(Icons.lightbulb_outline, color: g.heroText),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    tips[step],
                                    key: const Key('onb-pane-tip'),
                                    style: tt.bodyLarge?.copyWith(color: g.heroText),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                     ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
