// Placeholder body for routes whose feature module has not landed yet (plan
// section 0, "stubs make features independent"), plus the not-found screen.
// A frosted top bar over the mesh and one glass card holding a full-pane
// empty state: polished in both themes, never a blank page.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/pane_split.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';

class StubScreen extends StatelessWidget {
  const StubScreen({
    super.key,
    required this.name,
    this.icon = Icons.auto_awesome_outlined,
    this.message,
    this.actionLabel,
    this.onAction,
    this.actions = const <Widget>[],
    this.showSearch = false,
    this.fullScreen = false,
    this.body,
  });

  /// Localised screen title.
  final String name;
  final IconData icon;

  /// Empty-state sentence; defaults to "this part is being built".
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Extra top-bar actions (before the search button).
  final List<Widget> actions;

  /// Show the global search button (tab roots).
  final bool showSearch;

  /// Full-screen route (root navigator): a close button that pops, or goes to
  /// Today when the route was opened directly (deep link, reload).
  final bool fullScreen;

  /// Replaces the empty-state card.
  final Widget? body;

  @override
  Widget build(BuildContext context) {
    final double g = WindowClass.of(context).gutter;
    final bool embedded = PaneScope.isEmbedded(context);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !embedded,
        leading: fullScreen
            ? IconButton(
                tooltip: context.l10n.commonClose,
                icon: const Icon(Icons.close),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(Routes.today);
                  }
                },
              )
            : null,
        title: Semantics(header: true, child: Text(name)),
        actions: <Widget>[
          ...actions,
          if (showSearch)
            IconButton(
              tooltip: context.l10n.commonSearch,
              icon: const Icon(Icons.search),
              onPressed: () => context.push(Routes.search),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(g, 4, g, g),
          child: body ??
              GlassCard(
                padding: EdgeInsets.zero,
                child: EmptyState(
                  icon: icon,
                  message: message ?? context.l10n.shellStubMessage,
                  actionLabel: actionLabel,
                  onAction: onAction,
                ),
              ),
        ),
      ),
    );
  }
}

/// Unknown or malformed link: says so and offers the way home.
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return StubScreen(
      name: l10n.shellNotFoundTitle,
      icon: Icons.explore_off_outlined,
      message: l10n.shellNotFoundMessage,
      actionLabel: l10n.shellGoToToday,
      onAction: () => context.go(Routes.today),
    );
  }
}

/// A card-like section header used by stub bodies (kept here so stubs stay
/// self-contained).
class StubSectionTitle extends StatelessWidget {
  const StubSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: Semantics(
          header: true,
          child: Text(
            text,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: context.aurora.accent),
          ),
        ),
      );
}
