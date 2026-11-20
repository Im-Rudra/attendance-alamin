// TemplateEditorScreen: STUB by M5-A (plan section 0). The body belongs to M6-E (settings);
// keep the constructor signature (routes are frozen).

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/shell/stub_screen.dart';

class TemplateEditorScreen extends StatelessWidget {
  const TemplateEditorScreen({super.key, required this.kind});

  /// `reminder` or `receipt`.
  final String kind;

  @override
  Widget build(BuildContext context) => StubScreen(
        name: switch (kind) {
          'reminder' => context.l10n.shellTitleTemplateReminder,
          'receipt' => context.l10n.shellTitleTemplateReceipt,
          _ => context.l10n.shellTitleTemplate,
        },
        icon: Icons.edit_note,
      );
}
