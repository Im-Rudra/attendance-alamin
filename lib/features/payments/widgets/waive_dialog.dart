// Waive and unwaive one billable month (Product 3.3 "মাফ", scenario 10).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/l10n/error_text.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/widgets/dialogs.dart';
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
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  final ProviderContainer container = ProviderScope.containerOf(context, listen: false);
  final String? reason = await showDialog<String>(
    context: context,
    builder: (BuildContext ctx) => _WaiveDialog(monthText: monthText),
  );
  if (reason == null) return false;
  try {
    await container
        .read(paymentsRepositoryProvider)
        .waive(enrollmentId, month, reason: reason.isEmpty ? null : reason);
  } on AppException catch (e) {
    messenger?.showSnackBar(SnackBar(content: Text(errorText(l10n, e))));
    return false;
  }
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(l10n.payWaivedToast(monthText))));
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
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  final ProviderContainer container = ProviderScope.containerOf(context, listen: false);
  final bool yes = await showConfirmDialog(
    context,
    title: l10n.payUnwaiveTitle(monthText),
    body: l10n.payUnwaiveBody,
    confirmLabel: l10n.payUnwaive,
  );
  if (!yes) return false;
  try {
    await container.read(paymentsRepositoryProvider).unwaive(enrollmentId, month);
  } on AppException catch (e) {
    messenger?.showSnackBar(SnackBar(content: Text(errorText(l10n, e))));
    return false;
  }
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(l10n.payUnwaivedToast(monthText))));
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
    return AlertDialog(
      title: Text(l10n.payWaiveTitle(widget.monthText)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(l10n.payWaiveBody),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey<String>('pay-waive-reason'),
              controller: _reason,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(labelText: l10n.payWaiveReason),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey<String>('pay-waive-confirm'),
          onPressed: () => Navigator.of(context).pop(_reason.text.trim()),
          style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
          child: Text(l10n.payWaiveConfirm),
        ),
      ],
    );
  }
}
