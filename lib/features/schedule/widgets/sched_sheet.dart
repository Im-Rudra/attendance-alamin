// A bottom sheet on phones, a centred dialog on wide windows (UX 3b), for the
// small schedule sheets (reminder lead, effective-from).

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';

Future<T?> showSchedSheet<T>(
  BuildContext context, {
  required Widget Function(BuildContext ctx) builder,
  double maxWidth = 480,
}) {
  if (WindowClass.of(context).isWide) {
    return showDialog<T>(
      context: context,
      builder: (BuildContext ctx) => Dialog(
        backgroundColor: ctx.aurora.surfaceSolid,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: builder(ctx),
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: builder,
  );
}
