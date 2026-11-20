// Sticky bottom action bar (UX 4 Components): 56dp primary button, optional
// live summary above it, and the reason when the button is disabled.

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/theme/theme_x.dart';

class StickyActionBar extends StatelessWidget {
  const StickyActionBar({
    super.key,
    required this.label,
    this.onPressed,
    this.disabledReason,
    this.summary,
  });

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;

  /// Shown under a disabled button so the teacher knows what is missing.
  final String? disabledReason;

  /// Live counts, e.g. "28 present, 2 absent".
  final String? summary;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final bool disabled = onPressed == null;
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
              if (summary != null) ...<Widget>[
                Semantics(
                  liveRegion: true,
                  child: Text(
                    summary!,
                    textAlign: TextAlign.center,
                    style: tt.labelMedium?.copyWith(color: tokens.textSecondary),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              FilledButton(
                onPressed: onPressed,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                child: Text(label),
              ),
              if (disabled && disabledReason != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  disabledReason!,
                  textAlign: TextAlign.center,
                  style: tt.labelMedium?.copyWith(color: tokens.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
