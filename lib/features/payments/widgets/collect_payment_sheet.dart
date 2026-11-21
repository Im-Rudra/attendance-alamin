// "টাকা নিন" as a bottom sheet (UX 2c) and the edit-payment sheet, plus the
// "৳৮০০ জমা হয়েছে" toast with রসিদ পাঠান and undo.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/error_text.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/data/repositories/people_providers.dart';
import 'package:attendance_alamin/domain/models/payment.dart';
import 'package:attendance_alamin/features/payments/controllers/collect_payment_controller.dart';
import 'package:attendance_alamin/features/payments/controllers/pay_providers.dart';
import 'package:attendance_alamin/features/payments/widgets/collect_payment_form.dart';
import 'package:attendance_alamin/features/payments/widgets/paid_toast.dart';
import 'package:attendance_alamin/features/payments/widgets/receipt_preview.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

/// Opens the collect-payment sheet; returns the receipt id (null when closed
/// without saving). Shows the "recorded" toast on the caller's screen.
Future<String?> openCollectPaymentSheet(
  BuildContext context, {
  required String studentId,
  String? enrollmentId,
}) async {
  final SavedPayment? saved = await showBhorSheet<SavedPayment>(
    context,
    builder: (BuildContext ctx) => CollectPaymentForm(
      studentId: studentId,
      enrollmentId: enrollmentId,
      onClose: () => Navigator.of(ctx).pop(),
      onDone: (SavedPayment s) => Navigator.of(ctx).pop(s),
    ),
  );
  if (saved == null) return null;
  if (context.mounted) showPaidSnackBar(context, saved);
  return saved.receiptId;
}

/// Edits one receipt in the same sheet; true when it was saved.
Future<bool> showEditPaymentSheet(
  BuildContext context, {
  required String receiptId,
  required String studentId,
}) async {
  final String done = context.l10n.payEditedToast;
  final double lift = context.bhorIsWide ? 0 : 64;
  final SavedPayment? saved = await showBhorSheet<SavedPayment>(
    context,
    builder: (BuildContext ctx) => _EditSheet(
      receiptId: receiptId,
      studentId: studentId,
      onClose: () => Navigator.of(ctx).pop(),
      onDone: (SavedPayment s) => Navigator.of(ctx).pop(s),
    ),
  );
  if (saved == null) return false;
  if (context.mounted) BhorToast.show(context, message: done, tone: BhorTone.ok, bottomOffset: lift);
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
      return Padding(padding: const EdgeInsets.all(BhorSpace.s24), child: Text(l10n.commonLoadingFailed));
    }
    final List<Payment>? list = rows.value;
    if (list == null) {
      return const SizedBox(height: 160, child: Center(child: BhorSpinner()));
    }
    if (list.isEmpty) {
      return Padding(padding: const EdgeInsets.all(BhorSpace.s24), child: Text(l10n.payReceiptMissing));
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

/// "৳৮০০ জমা হয়েছে" with রসিদ পাঠান and undo (UX 2c).
void showPaidSnackBar(BuildContext context, SavedPayment saved) {
  final AppLocalizations l10n = context.l10n;
  final String message = l10n.payPaidToast(context.fmt.money(saved.total));
  final ProviderContainer container = ProviderScope.containerOf(context, listen: false);
  final double lift = context.bhorIsWide ? 0 : 64;
  showPaidToast(
    context,
    message: message,
    bottomOffset: lift,
    actions: <PaidToastAction>[
      PaidToastAction(
        key: const ValueKey<String>('pay-snack-send'),
        label: l10n.paySendReceipt,
        onPressed: () {
          if (context.mounted) shareReceiptNow(context, receiptId: saved.receiptId);
        },
      ),
      PaidToastAction(
        key: const ValueKey<String>('pay-snack-undo'),
        label: l10n.commonUndo,
        onPressed: () async {
          try {
            await container.read(paymentsRepositoryProvider).deleteReceipt(saved.receiptId);
          } on AppException catch (e) {
            if (context.mounted) {
              BhorToast.show(context, message: errorText(l10n, e), tone: BhorTone.danger, bottomOffset: lift);
            }
            return;
          }
          if (context.mounted) BhorToast.show(context, message: l10n.payUndone, bottomOffset: lift);
        },
      ),
    ],
  );
}
