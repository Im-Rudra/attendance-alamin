// BulkAddScreen: STUB by M5-A (plan section 0). The body belongs to M9-B (extras);
// keep the constructor signature (routes are frozen).

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/shell/stub_screen.dart';

class BulkAddScreen extends StatelessWidget {
  const BulkAddScreen({super.key, required this.batchId});

  final String batchId;

  @override
  Widget build(BuildContext context) => StubScreen(
        name: context.l10n.shellTitleBulkAdd,
        icon: Icons.group_add_outlined,
        fullScreen: true,
      );
}
