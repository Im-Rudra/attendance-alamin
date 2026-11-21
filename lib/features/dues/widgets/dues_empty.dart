// The honest empty state of the dues list: "everyone paid" only when this
// month really had fees and nothing is owed; when billing simply has not
// started yet it says when it will, with a link to the students.

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/dues_providers.dart';
import 'package:attendance_alamin/app/routes.dart';

/// Message for the zero-dues state of [status] (null while loading).
String duesEmptyMessage(BuildContext context, BillingStatus? status) {
  final l10n = context.l10n;
  if (status != null && status.notStarted) {
    return l10n.duesNotStarted(context.fmt.monthYear(status.firstUpcoming!));
  }
  if (status != null && status.billedThisMonth) return l10n.duesAllPaid;
  return l10n.duesNoneYet;
}

class DuesEmptyState extends ConsumerWidget {
  const DuesEmptyState({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BillingStatus? status = ref.watch(billingStatusProvider).value;
    final bool notStarted = status != null && status.notStarted;
    return BhorEmptyState(
      icon: notStarted ? Icons.schedule : Icons.check_circle_outline,
      title: duesEmptyMessage(context, status),
      action: notStarted
          ? BhorButton(
              label: context.l10n.duesSeeStudents,
              variant: BhorButtonVariant.secondary,
              onPressed: () => GoRouter.maybeOf(context)?.go(Routes.students),
            )
          : null,
    );
  }
}
