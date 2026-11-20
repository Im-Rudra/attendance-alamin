// OnboardingScreen: STUB by M5-A (plan section 0). The body belongs to M8-C (onboarding);
// keep the constructor signature (routes are frozen).

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/stub_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) => StubScreen(
        name: context.l10n.shellTitleOnboarding,
        icon: Icons.waving_hand_outlined,
        actionLabel: context.l10n.shellOnboardingContinue,
        onAction: () => context.go(Routes.today),
      );
}
