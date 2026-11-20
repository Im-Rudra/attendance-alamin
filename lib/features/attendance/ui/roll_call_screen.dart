// RollCallScreen: STUB by M5-A (plan section 0). The body belongs to M7-A (attendance);
// keep the constructor signature (routes are frozen).

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/shell/stub_screen.dart';

class RollCallScreen extends StatelessWidget {
  const RollCallScreen({super.key, required this.occ});

  /// Occurrence id (`s.<slot>.<yyyymmdd>` or `x.<id>`).
  final String occ;

  @override
  Widget build(BuildContext context) => StubScreen(
        name: context.l10n.shellTitleRollCall,
        icon: Icons.fact_check_outlined,
        fullScreen: true,
      );
}
