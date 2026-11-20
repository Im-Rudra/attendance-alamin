// TodayScreen: STUB by M5-A (plan section 0). The body belongs to M8-A (home);
// keep the constructor signature (routes are frozen).

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/shell/language_chip.dart';
import 'package:attendance_alamin/app/shell/stub_screen.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) => StubScreen(
        name: context.l10n.navToday,
        icon: Icons.wb_sunny_outlined,
        message: context.l10n.shellStubToday,
        showSearch: true,
        actions: const <Widget>[LanguageChip()],
      );
}
