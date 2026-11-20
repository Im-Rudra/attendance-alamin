// Schedule state pill: statePill colours + icon + word (UX 4 Components).

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';

enum ClassState { now, moved, cancelled, extra }

class StatePill extends StatelessWidget {
  const StatePill({super.key, required this.state});

  final ClassState state;

  IconData get _icon {
    switch (state) {
      case ClassState.now:
        return Icons.fiber_manual_record;
      case ClassState.moved:
        return Icons.autorenew;
      case ClassState.cancelled:
        return Icons.block;
      case ClassState.extra:
        return Icons.add;
    }
  }

  String _label(BuildContext context) {
    final l10n = context.l10n;
    switch (state) {
      case ClassState.now:
        return l10n.uiClassNow;
      case ClassState.moved:
        return l10n.uiClassMoved;
      case ClassState.cancelled:
        return l10n.uiClassCancelled;
      case ClassState.extra:
        return l10n.uiClassExtra;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final String label = _label(context);
    return Semantics(
      container: true,
      label: label,
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 28),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: ShapeDecoration(color: tokens.statePillBg, shape: const StadiumBorder()),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(_icon, size: state == ClassState.now ? 10 : 14, color: tokens.statePillText),
            const SizedBox(width: 4),
            Text(
              label,
              maxLines: 1,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: tokens.statePillText),
            ),
          ],
        ),
      ),
    );
  }
}
