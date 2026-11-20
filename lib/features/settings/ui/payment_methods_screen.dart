// PaymentMethodsScreen: STUB by M5-A (plan section 0). The body belongs to M6-E (settings);
// keep the constructor signature (routes are frozen).

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/shell/stub_screen.dart';

class PaymentMethodsScreen extends StatelessWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context) => StubScreen(
        name: context.l10n.shellTitlePaymentMethods,
        icon: Icons.account_balance_wallet_outlined,
      );
}
