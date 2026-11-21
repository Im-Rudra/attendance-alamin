// Placeholder body for routes whose feature module has not landed yet (plan
// section 0, "stubs make features independent"), plus the not-found screen.
// A Bhor header and one card holding a full-pane empty state: polished in
// both themes, never a blank page.

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/pane_split.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';

class StubScreen extends StatelessWidget {
  const StubScreen({
    super.key,
    required this.name,
    this.icon = BhorIcons.sparkle,
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
    final l10n = context.l10n;
    final String? actionText = actionLabel;
    return BhorScaffold(
      header: BhorHeader(
        title: name,
        showBack: embedded ? false : null,
        leading: fullScreen
            ? BhorIconButton(
                icon: BhorIcons.close,
                semanticLabel: l10n.commonClose,
                color: context.bhor.colors.text,
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(Routes.today);
                  }
                },
              )
            : null,
        actions: <Widget>[
          ...actions,
          if (showSearch)
            BhorIconButton(
              icon: BhorIcons.search,
              semanticLabel: l10n.commonSearch,
              onPressed: () => context.push(Routes.search),
            ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(g, 4, g, g),
        child: body ??
            BhorCard(
              padding: EdgeInsets.zero,
              child: Center(
                child: SingleChildScrollView(
                  child: BhorEmptyState(
                    icon: icon,
                    title: message ?? l10n.shellStubMessage,
                    action: actionText == null
                        ? null
                        : BhorButton(label: actionText, onPressed: onAction),
                  ),
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
      icon: BhorIcons.explore,
      message: l10n.shellNotFoundMessage,
      actionLabel: l10n.shellGoToToday,
      onAction: () => context.go(Routes.today),
    );
  }
}

/// A section header used by stub bodies (kept here so stubs stay
/// self-contained).
class StubSectionTitle extends StatelessWidget {
  const StubSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Semantics(
        header: true,
        child: Text(text, style: b.type.label.copyWith(color: b.colors.accent)),
      ),
    );
  }
}
