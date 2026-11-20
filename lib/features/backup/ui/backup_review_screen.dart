// BackupReviewScreen: STUB by M5-A (plan section 0). The body belongs to M9-A (backup);
// keep the constructor signature (routes are frozen).

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/shell/stub_screen.dart';

class BackupReviewScreen extends StatelessWidget {
  const BackupReviewScreen({super.key});

  @override
  Widget build(BuildContext context) => StubScreen(
        name: context.l10n.shellTitleBackupReview,
        icon: Icons.fact_check_outlined,
        fullScreen: true,
      );
}
