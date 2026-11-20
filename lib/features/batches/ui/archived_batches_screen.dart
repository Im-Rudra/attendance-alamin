// ArchivedBatchesScreen: STUB by M5-A (plan section 0). The body belongs to M6-C (batches);
// keep the constructor signature (routes are frozen).

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/shell/stub_screen.dart';

class ArchivedBatchesScreen extends StatelessWidget {
  const ArchivedBatchesScreen({super.key});

  @override
  Widget build(BuildContext context) => StubScreen(
        name: context.l10n.shellTitleArchived,
        icon: Icons.inventory_2_outlined,
      );
}
