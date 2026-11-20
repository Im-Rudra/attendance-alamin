// Shared chrome of the class sheets: a title row with a close button, and the
// modal bottom sheet launcher (root navigator, max 560 wide on desktop).

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';

/// Title, close button and a scrolling [child]; [footer] stays pinned below.
class SheetFrame extends StatelessWidget {
  const SheetFrame({super.key, required this.title, required this.child, this.subtitle, this.footer});

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Semantics(
                        header: true,
                        child: Text(title, style: tt.titleLarge?.copyWith(color: tokens.textPrimary)),
                      ),
                      if (subtitle != null)
                        Text(subtitle!, style: tt.bodyMedium?.copyWith(color: tokens.textSecondary)),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: context.l10n.a11yCloseSheet,
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: child,
          ),
        ),
        if (footer != null) footer!,
      ],
    );
  }
}

/// A tappable labelled row (date, time, batch) with a 56 dp minimum height.
class FieldRow extends StatelessWidget {
  const FieldRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.onTap,
    this.leading,
    this.trailing,
  });

  final String label;
  final String value;
  final IconData? icon;
  final VoidCallback? onTap;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    return Semantics(
      button: onTap != null,
      label: '$label, $value',
      excludeSemantics: true,
      child: Material(
        color: tokens.surfaceDense,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AuroraMetrics.radiusField),
          side: BorderSide(color: tokens.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: <Widget>[
                  if (leading != null) leading! else const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(label, style: tt.labelMedium?.copyWith(color: tokens.textSecondary)),
                        Text(value, style: tt.bodyLarge?.copyWith(color: tokens.textPrimary)),
                      ],
                    ),
                  ),
                  if (trailing != null)
                    trailing!
                  else if (icon != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(icon, color: tokens.textSecondary),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows [builder] as a modal bottom sheet above the whole shell.
Future<T?> showClassSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: builder,
  );
}
