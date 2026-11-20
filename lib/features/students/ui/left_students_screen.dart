// LeftStudentsScreen: STUB by M5-A (plan section 0). The body belongs to M6-D (students);
// keep the constructor signature (routes are frozen).

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/shell/stub_screen.dart';

class LeftStudentsScreen extends StatelessWidget {
  const LeftStudentsScreen({super.key});

  @override
  Widget build(BuildContext context) => StubScreen(
        name: context.l10n.shellTitleLeft,
        icon: Icons.person_off_outlined,
      );
}
