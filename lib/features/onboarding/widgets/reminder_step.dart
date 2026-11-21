// Step 4: what class reminders do, in three plain lines. The buttons live in
// the screen's action bar ("Yes, turn on" opens the real permission priming).

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/features/onboarding/widgets/onb_common.dart';

class ReminderStep extends StatelessWidget {
  const ReminderStep({super.key, this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final BhorThemeData b = context.bhor;

    Widget point(IconData icon, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, color: b.colors.accent),
              const SizedBox(width: 12),
              Expanded(child: Text(text, style: b.type.body)),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(
          child: Icon(Icons.notifications_active_outlined, size: 56, color: b.colors.accent),
        ),
        const SizedBox(height: 12),
        OnbHeading(title: l10n.onbRemindTitle),
        const SizedBox(height: 16),
        BhorCard(
          child: Column(
            children: <Widget>[
              point(Icons.notifications_outlined, l10n.onbRemindPoint1),
              point(Icons.touch_app_outlined, l10n.onbRemindPoint2),
              point(Icons.tune, l10n.onbRemindPoint3),
            ],
          ),
        ),
        if (error != null) ...<Widget>[
          const SizedBox(height: 16),
          OnbErrorBox(message: error!),
        ],
      ],
    );
  }
}
