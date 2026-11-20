// BatchRollCallLauncher: STUB by M5-A (plan section 0). The body belongs to M7-A (attendance);
// keep the constructor signature (routes are frozen).

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/shell/stub_screen.dart';
import 'package:attendance_alamin/core/time/local_date.dart';

class BatchRollCallLauncher extends StatelessWidget {
  const BatchRollCallLauncher({super.key, required this.batchId, required this.date});

  final String batchId;
  final LocalDate date;

  @override
  Widget build(BuildContext context) => StubScreen(
        name: context.l10n.shellTitleRollCall,
        icon: Icons.fact_check_outlined,
        fullScreen: true,
      );
}
