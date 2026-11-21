// Desktop side pane of onboarding: the Bhor hero gradient with the four
// steps (done / now / next) and a plain tip for the current one, so the wide
// window never has an empty half. No illustration, only words.

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';

class OnbContextPane extends StatelessWidget {
  const OnbContextPane({super.key, required this.step});

  /// Zero-based current step.
  final int step;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final Color onHero2 = c.onHero.withValues(alpha: 0.75);
    final BorderRadius br = BorderRadius.circular(BhorRadius.hero);
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
            AnimatedSwitcher(
              duration: BhorMotion.base,
              switchInCurve: BhorMotion.spring,
              transitionBuilder: (Widget w, Animation<double> a) => ScaleTransition(scale: a, child: w),
              child: done
                  ? Icon(
                      BhorIcons.checkCircleFill,
                      key: const ValueKey<String>('done'),
                      color: c.onHero,
                    )
                  : AnimatedContainer(
                      key: const ValueKey<String>('open'),
                      duration: BhorMotion.base,
                      curve: BhorMotion.ease,
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: now ? c.onHero : onHero2, width: 2),
                      ),
                      child: AnimatedContainer(
                        duration: BhorMotion.base,
                        curve: BhorMotion.spring,
                        width: now ? 10 : 0,
                        height: now ? 10 : 0,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: c.onHero),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${context.fmt.number(i + 1)}. ${names[i]}',
                style: (now ? b.type.bodyStrong : b.type.body).copyWith(color: now ? c.onHero : onHero2),
              ),
            ),
          ],
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(gradient: c.heroGradient, borderRadius: br),
      child: ClipRRect(
        borderRadius: br,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints box) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(l10n.onbPaneTitle, style: b.type.title.copyWith(color: c.onHero)),
                      const SizedBox(height: 8),
                      Text(l10n.onbPaneBody, style: b.type.body.copyWith(color: onHero2)),
                      const SizedBox(height: 24),
                      for (int i = 0; i < names.length; i++) row(i),
                      const SizedBox(height: 24),
                      const Spacer(),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: c.onHero.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(BhorRadius.control),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Icon(BhorIcons.sparkle, color: c.onHero),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  tips[step],
                                  key: const Key('onb-pane-tip'),
                                  style: b.type.body.copyWith(color: c.onHero),
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
      ),
    );
  }
}
