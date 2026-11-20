// FeesScreen: STUB by M5-A (plan section 0). The body belongs to M7-C (dues);
// keep the constructor signature (routes are frozen).
//
// Wide windows (≥ 840) show dues list ‖ payment panel through PaneSplit;
// `/fees/s/:studentId` passes [selectedStudentId].

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/pane_split.dart';
import 'package:attendance_alamin/app/shell/stub_screen.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';

class FeesScreen extends StatelessWidget {
  const FeesScreen({super.key, this.selectedStudentId});

  /// Student whose payment panel is shown on wide windows.
  final String? selectedStudentId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final Widget list = StubScreen(
      name: l10n.navFees,
      icon: Icons.payments_outlined,
      message: l10n.shellStubFees,
      showSearch: true,
      actions: <Widget>[
        IconButton(
          tooltip: l10n.shellTitleCollection,
          icon: const Icon(Icons.receipt_long_outlined),
          onPressed: () => context.go(Routes.feesCollection),
        ),
      ],
    );
    if (!WindowClass.of(context).isWide) return list;
    final bool selected = selectedStudentId != null;
    return PaneSplit(
      screen: 'fees',
      list: list,
      preferList: !selected,
      detail: StubScreen(
        name: selected ? l10n.shellTitlePayment : l10n.shellTitleOverview,
        icon: selected ? Icons.point_of_sale_outlined : Icons.insights_outlined,
        message: selected ? null : l10n.shellStubOverview,
      ),
    );
  }
}
