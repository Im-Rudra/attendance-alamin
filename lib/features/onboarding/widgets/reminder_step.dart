// Step 4: what class reminders do, in three plain lines. The buttons live in
// the screen's action bar ("Yes, turn on" opens the real permission priming).

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/features/onboarding/widgets/onb_common.dart';

class ReminderStep extends StatelessWidget {
  const ReminderStep({super.key, this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final BhorThemeData b = context.bhor;

    Widget point(IconData icon, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, color: b.colors.accent),
              const SizedBox(width: 12),
              Expanded(child: Text(text, style: b.type.body)),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Center(child: BellBadge(size: 72)),
        const SizedBox(height: 12),
        OnbHeading(title: l10n.onbRemindTitle),
        const SizedBox(height: 16),
        BhorCard(
          child: Column(
            children: <Widget>[
              point(BhorIcons.bell, l10n.onbRemindPoint1),
              point(BhorIcons.sparkle, l10n.onbRemindPoint2),
              point(BhorIcons.sliders, l10n.onbRemindPoint3),
            ],
          ),
        ),
        if (error != null) ...<Widget>[
          const SizedBox(height: 16),
          OnbErrorBox(message: error!),
        ],
      ],
    );
  }
}

/// A bell in a soft accent circle that pops in and gives one gentle ring
/// wiggle on enter (still when motion is reduced).
class BellBadge extends StatelessWidget {
  const BellBadge({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    final BhorColors c = context.bhor.colors;
    final bool reduced = BhorMotion.reduced(context);
    final Widget badge = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.accentTint, shape: BoxShape.circle),
      child: Icon(BhorIcons.remind, size: size / 2, color: c.accent),
    );
    if (reduced) return ExcludeSemantics(child: badge);
    return ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: BhorMotion.slow * 2,
        builder: (BuildContext context, double t, Widget? child) {
          final double pop = Interval(0, 0.35, curve: BhorMotion.spring).transform(t);
          // Three decaying swings after the pop.
          final double w = t < 0.3 ? 0 : (1 - t) * math.sin((t - 0.3) * math.pi * 6) * 0.35;
          return Transform.scale(
            scale: pop,
            child: Transform.rotate(angle: w, child: child),
          );
        },
        child: badge,
      ),
    );
  }
}
