// The desktop side panel of the dues screen: the same form as the sheet, drawn
// in place. After a save it shows the "recorded" toast and starts over for
// the next payment.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/features/payments/controllers/collect_payment_controller.dart';
import 'package:attendance_alamin/features/payments/widgets/collect_payment_form.dart';
import 'package:attendance_alamin/features/payments/widgets/collect_payment_sheet.dart';

class CollectPaymentPanelBody extends ConsumerStatefulWidget {
  const CollectPaymentPanelBody({super.key, required this.studentId, this.enrollmentId});

  final String studentId;
  final String? enrollmentId;

  @override
  ConsumerState<CollectPaymentPanelBody> createState() => _CollectPaymentPanelBodyState();
}

class _CollectPaymentPanelBodyState extends ConsumerState<CollectPaymentPanelBody> {
  int _generation = 0;

  void _saved(SavedPayment saved) {
    showPaidSnackBar(context, saved);
    ref.invalidate(collectPaymentControllerProvider(
        (studentId: widget.studentId, enrollmentId: widget.enrollmentId, receiptId: null)));
    setState(() => _generation++);
  }

  @override
  Widget build(BuildContext context) {
    return BhorCard(
      padding: const EdgeInsets.fromLTRB(BhorSpace.s12, BhorSpace.s12, BhorSpace.s12, 0),
      child: CollectPaymentForm(
        key: ValueKey<String>('${widget.studentId}/${widget.enrollmentId}/$_generation'),
        studentId: widget.studentId,
        enrollmentId: widget.enrollmentId,
        onDone: _saved,
      ),
    );
  }
}
