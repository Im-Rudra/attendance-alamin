// Small shared pieces of the onboarding screens: heading, progress dots, the
// section wrapper, the error box and the bottom action bar.

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';

/// Number of onboarding steps.
const int kOnbSteps = 4;

/// Step title (large) and one plain sentence under it.
class OnbHeading extends StatelessWidget {
  const OnbHeading({super.key, required this.title, this.body});

  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(title, style: b.type.title),
        ),
        if (body != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(body!, style: b.type.body.copyWith(color: b.colors.text2)),
        ],
      ],
    );
  }
}

/// Four dots; the current one is a longer pill. Spoken as "Step 2 of 4".
class OnbProgressDots extends StatelessWidget {
  const OnbProgressDots({super.key, required this.step});

  /// Zero-based current step.
  final int step;

  @override
  Widget build(BuildContext context) {
    final BhorColors c = context.bhor.colors;
    final String label = context.l10n.onbStepOf(
      context.fmt.number(step + 1),
      context.fmt.number(kOnbSteps),
    );
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int i = 0; i < kOnbSteps; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s4),
              child: AnimatedContainer(
                duration: BhorMotion.base,
                width: i == step ? 28 : 10,
                height: 10,
                decoration: BoxDecoration(
                  color: i <= step ? c.accent : c.line,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Form group on a card. On wide windows the whole step already sits on a
/// card, so only narrow windows add the wrapper.
class OnbSection extends StatelessWidget {
  const OnbSection({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (WindowClass.of(context).isWide) return child;
    return BhorCard(child: child);
  }
}

/// Plain-words error under the form (live region).
class OnbErrorBox extends StatelessWidget {
  const OnbErrorBox({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.dangerBg,
          borderRadius: BorderRadius.circular(BhorRadius.control),
          border: Border.all(color: c.danger.withValues(alpha: 0.4)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(BhorSpace.s12),
          child: Row(
            children: <Widget>[
              Icon(Icons.error_outline, color: c.danger),
              const SizedBox(width: BhorSpace.s8),
              Expanded(child: Text(message, style: b.type.body)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom bar: why the button is off (if so), the primary button and an
/// optional quiet secondary button.
class OnbActionBar extends StatelessWidget {
  const OnbActionBar({
    super.key,
    required this.label,
    required this.onPressed,
    this.disabledReason,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String label;
  final VoidCallback? onPressed;
  final String? disabledReason;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(BhorSpace.s16, BhorSpace.s12, BhorSpace.s16, BhorSpace.s12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (onPressed == null && disabledReason != null) ...<Widget>[
                Text(disabledReason!, textAlign: TextAlign.center, style: b.type.meta),
                const SizedBox(height: BhorSpace.s8),
              ],
              BhorButton(
                key: const Key('onb-primary'),
                label: label,
                onPressed: onPressed,
                expand: true,
              ),
              if (secondaryLabel != null) ...<Widget>[
                const SizedBox(height: BhorSpace.s4),
                BhorButton(
                  key: const Key('onb-secondary'),
                  label: secondaryLabel!,
                  variant: BhorButtonVariant.ghost,
                  onPressed: onSecondary,
                  expand: true,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
