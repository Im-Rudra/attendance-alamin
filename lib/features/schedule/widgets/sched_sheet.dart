// A bottom sheet on phones, a centred dialog card on wide windows (UX 3b), for
// the small schedule sheets (reminder lead, effective-from). The panels carry
// their own title.

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';

Future<T?> showSchedSheet<T>(
  BuildContext context, {
  required Widget Function(BuildContext ctx) builder,
  double maxWidth = 480,
}) {
  if (WindowClass.of(context).isWide) {
    return showBhorDialog<T>(
      context,
      builder: (BuildContext ctx) => Padding(
        padding: const EdgeInsets.all(BhorSpace.s24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: BhorCard(padding: EdgeInsets.zero, child: builder(ctx)),
        ),
      ),
    );
  }
  return showBhorSheet<T>(context, builder: builder);
}
