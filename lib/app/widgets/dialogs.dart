// Confirmation dialog and undo snackbar (UX 4 Components).

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';

/// The title states the consequence with numbers; the confirm button (on the
/// right) carries the verb. Returns false when dismissed.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  String? body,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) {
      final tokens = ctx.aurora;
      return AlertDialog(
        title: Text(title),
        content: body == null ? null : Text(body),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            child: Text(ctx.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: destructive
                ? FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    backgroundColor: tokens.error,
                    foregroundColor: tokens.onError,
                  )
                : FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

/// 8 s snackbar with one action: [onUndo] (labelled "Undo") or a custom
/// [actionLabel] + [onAction]. Replaces any snackbar still showing.
void showUndoSnackBar(
  BuildContext context, {
  required String message,
  VoidCallback? onUndo,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  SnackBarAction? action;
  if (onUndo != null) {
    action = SnackBarAction(label: context.l10n.commonUndo, onPressed: onUndo);
  } else if (onAction != null && actionLabel != null) {
    action = SnackBarAction(label: actionLabel, onPressed: onAction);
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 8),
        action: action,
      ),
    );
}
