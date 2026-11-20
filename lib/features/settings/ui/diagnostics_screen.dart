// DiagnosticsScreen: STUB by M5-A (plan section 0). The body belongs to M6-E (settings);
// keep the constructor signature (routes are frozen).

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/shell/stub_screen.dart';

class DiagnosticsScreen extends StatelessWidget {
  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context) => StubScreen(
        name: context.l10n.shellTitleDiagnostics,
        icon: Icons.monitor_heart_outlined,
      );
}
