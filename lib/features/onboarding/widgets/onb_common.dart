// Small shared pieces of the onboarding screens: heading, progress dots, the
// section wrapper, the error box and the bottom action bar.

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';

/// Number of onboarding steps.
const int kOnbSteps = 4;

/// Step title (large) and one plain sentence under it.
class OnbHeading extends StatelessWidget {
  const OnbHeading({super.key, required this.title, this.body});

  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            title,
            style: tt.headlineSmall?.copyWith(color: tokens.textPrimary, fontWeight: FontWeight.w700),
          ),
        ),
        if (body != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(body!, style: tt.bodyLarge?.copyWith(color: tokens.textSecondary)),
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
    final tokens = context.aurora;
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
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: i == step ? 28 : 10,
                height: 10,
                decoration: BoxDecoration(
                  color: i <= step ? tokens.accent : tokens.track,
                  borderRadius: BorderRadius.circular(AuroraMetrics.radiusPill),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Form group on `surfaceDense`. On wide windows the whole step already sits
/// on a dense card, so only narrow windows add the wrapper.
class OnbSection extends StatelessWidget {
  const OnbSection({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (WindowClass.of(context).isWide) return child;
    return GlassCard(dense: true, child: child);
  }
}

/// Plain-words error under the form (live region).
class OnbErrorBox extends StatelessWidget {
  const OnbErrorBox({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.errorContainer,
          borderRadius: BorderRadius.circular(AuroraMetrics.radiusDenseList),
          border: Border.all(color: tokens.errorContainerBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              Icon(Icons.error_outline, color: tokens.onErrorContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(message, style: tt.bodyLarge?.copyWith(color: tokens.onErrorContainer)),
              ),
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
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surfaceDense,
        border: Border(top: BorderSide(color: tokens.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (onPressed == null && disabledReason != null) ...<Widget>[
                Text(
                  disabledReason!,
                  textAlign: TextAlign.center,
                  style: tt.labelMedium?.copyWith(color: tokens.textSecondary),
                ),
                const SizedBox(height: 8),
              ],
              FilledButton(
                key: const Key('onb-primary'),
                onPressed: onPressed,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                child: Text(label),
              ),
              if (secondaryLabel != null) ...<Widget>[
                const SizedBox(height: 4),
                TextButton(
                  key: const Key('onb-secondary'),
                  onPressed: onSecondary,
                  style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: Text(secondaryLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
