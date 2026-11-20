// StudentProfileScreen: STUB by M5-A (plan section 0). The body belongs to M6-D (students);
// keep the constructor signature (routes are frozen).

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/stub_screen.dart';

class StudentProfileScreen extends StatelessWidget {
  const StudentProfileScreen({super.key, required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context) => StubScreen(
        name: context.l10n.shellTitleStudentProfile,
        icon: Icons.badge_outlined,
        actions: <Widget>[
          IconButton(
            tooltip: context.l10n.commonEdit,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push(Routes.studentEdit(studentId)),
          ),
        ],
      );
}
