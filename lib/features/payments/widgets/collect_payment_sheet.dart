// "টাকা নিন" as a bottom sheet (UX 2c) and the edit-payment sheet, plus the
// "৳৮০০ জমা হয়েছে" snackbar with রসিদ পাঠান and undo.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/l10n/error_text.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/data/repositories/people_providers.dart';
import 'package:attendance_alamin/domain/models/payment.dart';
import 'package:attendance_alamin/features/payments/controllers/collect_payment_controller.dart';
import 'package:attendance_alamin/features/payments/controllers/pay_providers.dart';
import 'package:attendance_alamin/features/payments/widgets/collect_payment_form.dart';
import 'package:attendance_alamin/features/payments/widgets/receipt_preview.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

/// Opens the collect-payment sheet; returns the receipt id (null when closed
/// without saving). Shows the "recorded" snackbar on the caller's screen.
Future<String?> openCollectPaymentSheet(
  BuildContext context, {
  required String studentId,
  String? enrollmentId,
}) async {
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  final SavedPayment? saved = await showModalBottomSheet<SavedPayment>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (BuildContext ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: CollectPaymentForm(
        studentId: studentId,
        enrollmentId: enrollmentId,
        onClose: () => Navigator.of(ctx).pop(),
        onDone: (SavedPayment s) => Navigator.of(ctx).pop(s),
      ),
    ),
  );
  if (saved == null) return null;
  if (context.mounted) showPaidSnackBar(context, saved, messenger: messenger);
  return saved.receiptId;
}

/// Edits one receipt in the same sheet; true when it was saved.
Future<bool> showEditPaymentSheet(
  BuildContext context, {
  required String receiptId,
  required String studentId,
}) async {
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  final String done = context.l10n.payEditedToast;
  final SavedPayment? saved = await showModalBottomSheet<SavedPayment>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (BuildContext ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: _EditSheet(
        receiptId: receiptId,
        studentId: studentId,
        onClose: () => Navigator.of(ctx).pop(),
        onDone: (SavedPayment s) => Navigator.of(ctx).pop(s),
      ),
    ),
  );
  if (saved == null) return false;
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(done)));
  return true;
}

class _EditSheet extends ConsumerWidget {
  const _EditSheet({
    required this.receiptId,
    required this.studentId,
    required this.onClose,
    required this.onDone,
  });

  final String receiptId;
  final String studentId;
  final VoidCallback onClose;
  final ValueChanged<SavedPayment> onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final AsyncValue<List<Payment>> rows = ref.watch(payReceiptRowsProvider(receiptId));
    if (rows.hasError) {
      return Padding(padding: const EdgeInsets.all(24), child: Text(l10n.commonLoadingFailed));
    }
    final List<Payment>? list = rows.value;
    if (list == null) {
      return const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()));
    }
    if (list.isEmpty) {
      return Padding(padding: const EdgeInsets.all(24), child: Text(l10n.payReceiptMissing));
    }
    return CollectPaymentForm(
      studentId: studentId,
      enrollmentId: list.first.enrollmentId,
      receiptId: receiptId,
      onClose: onClose,
      onDone: onDone,
    );
  }
}

/// "৳৮০০ জমা হয়েছে" with রসিদ পাঠান and undo (UX 2c). [messenger] defaults to
/// the one above [context].
void showPaidSnackBar(
  BuildContext context,
  SavedPayment saved, {
  ScaffoldMessengerState? messenger,
}) {
  final ScaffoldMessengerState? m = messenger ?? ScaffoldMessenger.maybeOf(context);
  if (m == null) return;
  final AppLocalizations l10n = context.l10n;
  final String message = l10n.payPaidToast(context.fmt.money(saved.total));
  final ProviderContainer container = ProviderScope.containerOf(context, listen: false);
  final Color link = Theme.of(context).colorScheme.inversePrimary;
  m
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 8),
        // Auto-dismiss even though it has an action (Flutter 3.29+ keeps
        // action snackbars until dismissed unless persist is false).
        persist: false,
        content: Row(
          children: <Widget>[
            Expanded(child: Text(message)),
            TextButton(
              key: const ValueKey<String>('pay-snack-send'),
              style: TextButton.styleFrom(foregroundColor: link, minimumSize: const Size(48, 48)),
              onPressed: () {
                if (context.mounted) shareReceiptNow(context, receiptId: saved.receiptId);
              },
              child: Text(l10n.paySendReceipt),
            ),
          ],
        ),
        action: SnackBarAction(
          label: l10n.commonUndo,
          onPressed: () async {
            try {
              await container.read(paymentsRepositoryProvider).deleteReceipt(saved.receiptId);
            } on AppException catch (e) {
              m.showSnackBar(SnackBar(content: Text(errorText(l10n, e))));
              return;
            }
            m
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(l10n.payUndone)));
          },
        ),
      ),
    );
}
