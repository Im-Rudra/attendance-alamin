// Schedule conflict card (UX 4 Components, 8 Accessibility): errorContainer,
// warning icon, the clashing lines and 1-2 fix buttons. A live region, so it is
// announced when it appears.

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';

class ConflictFix {
  const ConflictFix({required this.label, required this.onTap, this.primary = false});

  final String label;
  final VoidCallback onTap;
  final bool primary;
}

class ConflictCard extends StatelessWidget {
  const ConflictCard({super.key, required this.lines, this.moreCount = 0, this.fixes = const []});

  final List<String> lines;
  final int moreCount;
  final List<ConflictFix> fixes;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final l10n = context.l10n;
    final TextTheme tt = Theme.of(context).textTheme;
    final Color on = tokens.onErrorContainer;
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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.warning_amber_rounded, color: on, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.uiConflictTitle,
                      style: tt.titleMedium?.copyWith(color: on),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final String line in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(line, style: tt.bodyLarge?.copyWith(color: on)),
                ),
              if (moreCount > 0)
                Text(
                  l10n.uiConflictMore(context.fmt.number(moreCount)),
                  style: tt.labelMedium?.copyWith(color: on),
                ),
              if (fixes.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final ConflictFix f in fixes)
                      f.primary
                          ? FilledButton(
                              onPressed: f.onTap,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(48, 48),
                                backgroundColor: tokens.error,
                                foregroundColor: tokens.onError,
                              ),
                              child: Text(f.label),
                            )
                          : OutlinedButton(
                              onPressed: f.onTap,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(48, 48),
                                foregroundColor: on,
                                side: BorderSide(color: on.withValues(alpha: 0.5)),
                              ),
                              child: Text(f.label),
                            ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
