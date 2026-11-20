// Empty state (UX 3b rule 3): fills its tile or pane, centred, one sentence and
// at most one button. Never a tiny line in a giant box.

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/theme/theme_x.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.fill = true,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Expand to the whole bounded area of the parent (tile / pane). When the
  /// parent is unbounded the state wraps its content.
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final Widget content = Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ExcludeSemantics(child: Icon(icon, size: 64, color: tokens.accent)),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: tt.titleMedium?.copyWith(color: tokens.textPrimary),
          ),
          if (actionLabel != null && onAction != null) ...<Widget>[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final Widget centred = Center(child: SingleChildScrollView(child: content));
        if (fill && c.hasBoundedHeight && c.hasBoundedWidth) {
          return SizedBox(width: c.maxWidth, height: c.maxHeight, child: centred);
        }
        return SizedBox(width: c.hasBoundedWidth ? c.maxWidth : null, child: content);
      },
    );
  }
}
