// Navigation helpers that are safe without a router (widget tests pump bare
// MaterialApps): they do nothing when no GoRouter is mounted.

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/routes.dart';

void stuGo(BuildContext context, String path, {Object? extra}) {
  GoRouter.maybeOf(context)?.go(path, extra: extra);
}

void stuPush(BuildContext context, String path, {Object? extra}) {
  GoRouter.maybeOf(context)?.push(path, extra: extra);
}

/// Closes a full-screen route; goes to the student list when the route was
/// opened directly (nothing to pop).
void stuClose(BuildContext context, {String fallback = Routes.students}) {
  final NavigatorState nav = Navigator.of(context);
  if (nav.canPop()) {
    nav.pop();
    return;
  }
  stuGo(context, fallback);
}
