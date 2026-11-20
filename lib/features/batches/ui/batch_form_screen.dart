// BatchFormScreen: STUB by M5-A (plan section 0). The body belongs to M6-C (batches);
// keep the constructor signature (routes are frozen).

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/shell/stub_screen.dart';

class BatchFormScreen extends StatelessWidget {
  const BatchFormScreen({super.key, this.batchId});

  /// null = create a new batch.
  final String? batchId;

  @override
  Widget build(BuildContext context) => StubScreen(
        name: batchId == null ? context.l10n.shellTitleBatchNew : context.l10n.shellTitleBatchEdit,
        icon: Icons.edit_note,
        fullScreen: true,
      );
}
