// BatchesScreen: STUB by M5-A (plan section 0). The body belongs to M6-C
// (batches); keep the constructor signature (routes are frozen).
//
// Wide windows (≥ 840) show list ‖ detail through PaneSplit (width remembered
// per device); `/batches/:batchId` passes [selectedId].

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/shell/pane_split.dart';
import 'package:attendance_alamin/app/shell/stub_screen.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/features/batches/ui/batch_detail_screen.dart';

class BatchesScreen extends StatelessWidget {
  const BatchesScreen({super.key, this.selectedId});

  /// Batch shown in the detail pane on wide windows.
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final Widget list = StubScreen(
      name: l10n.navBatches,
      icon: Icons.groups_outlined,
      message: l10n.shellStubBatches,
      showSearch: true,
    );
    if (!WindowClass.of(context).isWide) return list;
    final String? id = selectedId;
    return PaneSplit(
      screen: 'batches',
      list: list,
      preferList: id == null,
      detail: id == null
          ? StubScreen(
              name: l10n.shellTitleOverview,
              icon: Icons.insights_outlined,
              message: l10n.shellStubOverview,
            )
          : BatchDetailScreen(batchId: id),
    );
  }
}
