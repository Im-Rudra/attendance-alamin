// SlotEditorScreen: STUB by M5-A (plan section 0). The body belongs to M6-A (schedule);
// keep the constructor signature (routes are frozen).

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/shell/stub_screen.dart';

class SlotEditorScreen extends StatelessWidget {
  const SlotEditorScreen({super.key, required this.batchId});

  final String batchId;

  @override
  Widget build(BuildContext context) => StubScreen(
        name: context.l10n.shellTitleSlotEditor,
        icon: Icons.schedule,
        fullScreen: true,
      );
}
