// ReminderPrimingScreen: STUB by M5-A (plan section 0). The body belongs to M8-D (reminders);
// keep the constructor signature (routes are frozen).

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/shell/stub_screen.dart';

class ReminderPrimingScreen extends StatelessWidget {
  const ReminderPrimingScreen({super.key});

  @override
  Widget build(BuildContext context) => StubScreen(
        name: context.l10n.shellTitleReminderPriming,
        icon: Icons.notifications_active_outlined,
        fullScreen: true,
      );
}
