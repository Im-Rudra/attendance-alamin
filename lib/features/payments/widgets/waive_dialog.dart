// Waive and unwaive one billable month (Product 3.3 "মাফ", scenario 10).

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/error_text.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/data/repositories/people_providers.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

/// Asks for an optional reason, then waives [month]; true when waived.
Future<bool> runWaiveDialog(
  BuildContext context, {
  required String enrollmentId,
  required YearMonth month,
}) async {
  final AppLocalizations l10n = context.l10n;
  final String monthText = context.fmt.monthYear(month);
  final ProviderContainer container = ProviderScope.containerOf(context, listen: false);
  final String? reason = await showBhorDialog<String>(
    context,
    builder: (BuildContext ctx) => _WaiveDialog(monthText: monthText),
  );
  if (reason == null) return false;
  try {
    await container
        .read(paymentsRepositoryProvider)
        .waive(enrollmentId, month, reason: reason.isEmpty ? null : reason);
  } on AppException catch (e) {
    if (context.mounted) BhorToast.show(context, message: errorText(l10n, e), tone: BhorTone.danger);
    return false;
  }
  if (context.mounted) BhorToast.show(context, message: l10n.payWaivedToast(monthText), tone: BhorTone.ok);
  return true;
}

/// Confirms, then removes the waiver of [month]; true when removed.
Future<bool> runUnwaiveDialog(
  BuildContext context, {
  required String enrollmentId,
  required YearMonth month,
}) async {
  final AppLocalizations l10n = context.l10n;
  final String monthText = context.fmt.monthYear(month);
  final ProviderContainer container = ProviderScope.containerOf(context, listen: false);
  final bool yes = await showBhorConfirm(
    context,
    title: l10n.payUnwaiveTitle(monthText),
    message: l10n.payUnwaiveBody,
    confirmLabel: l10n.payUnwaive,
  );
  if (!yes) return false;
  try {
    await container.read(paymentsRepositoryProvider).unwaive(enrollmentId, month);
  } on AppException catch (e) {
    if (context.mounted) BhorToast.show(context, message: errorText(l10n, e), tone: BhorTone.danger);
    return false;
  }
  if (context.mounted) BhorToast.show(context, message: l10n.payUnwaivedToast(monthText), tone: BhorTone.ok);
  return true;
}

class _WaiveDialog extends StatefulWidget {
  const _WaiveDialog({required this.monthText});

  final String monthText;

  @override
  State<_WaiveDialog> createState() => _WaiveDialogState();
}

class _WaiveDialogState extends State<_WaiveDialog> {
  final TextEditingController _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BhorDialog(
      title: l10n.payWaiveTitle(widget.monthText),
      body: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(l10n.payWaiveBody),
            const SizedBox(height: BhorSpace.s12),
            BhorTextField(
              key: const ValueKey<String>('pay-waive-reason'),
              controller: _reason,
              textInputAction: TextInputAction.done,
              label: l10n.payWaiveReason,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        BhorButton(
          label: l10n.commonCancel,
          variant: BhorButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        BhorButton(
          key: const ValueKey<String>('pay-waive-confirm'),
          label: l10n.payWaiveConfirm,
          onPressed: () => Navigator.of(context).pop(_reason.text.trim()),
        ),
      ],
    );
  }
}
