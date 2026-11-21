// The payment panel of the Fees screen on wide windows (UX 3b): the selected
// student's header (name, worst tag, call / remind / profile) above the
// inline `CollectPaymentPanel`.

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/services/contact_actions.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/app/providers/dues_providers.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/features/dues/controllers/dues_state.dart';
import 'package:attendance_alamin/features/dues/widgets/dues_row.dart';
import 'package:attendance_alamin/features/dues/widgets/dues_tags.dart';
import 'package:attendance_alamin/features/payments/payments_entry.dart';

class DuesSelectedPane extends ConsumerWidget {
  const DuesSelectedPane({super.key, required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BhorThemeData b = context.bhor;
    final l10n = context.l10n;
    final double g = WindowClass.of(context).gutter;
    final Student? student = ref.watch(duesStudentMapProvider)[studentId];
    final StudentDues? dues = ref.watch(studentDuesProvider(studentId)).value;
    final String name = student?.name ?? dues?.name ?? '';
    final DueLevel? worst = dues?.worst;

    final Widget header = BhorCard(
      padding: const EdgeInsets.all(BhorSpace.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              BhorAvatar(name: name, size: 44),
              const SizedBox(width: BhorSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: b.type.heading),
                    if (dues != null)
                      Row(
                        children: <Widget>[
                          if (worst != null)
                            Flexible(
                              child: dueLevelTag(
                                context,
                                worst,
                                dayInDue: dues.worstDay,
                                monthCount: dues.openDueMonths,
                                compact: true,
                              ),
                            ),
                          if (worst != null) const SizedBox(width: BhorSpace.s8),
                          BhorMoney(dues.totalOutstanding, style: b.type.bodyStrong),
                        ],
                      ),
                  ],
                ),
              ),
              BhorIconButton(
                icon: Icons.close,
                semanticLabel: l10n.commonClose,
                onPressed: () => GoRouter.maybeOf(context)?.go(Routes.fees),
              ),
            ],
          ),
          const SizedBox(height: BhorSpace.s4),
          Wrap(
            spacing: BhorSpace.s4,
            children: <Widget>[
              BhorButton(
                variant: BhorButtonVariant.ghost,
                icon: ContactActions.icon,
                label: ContactActions.label(l10n),
                onPressed: () => duesCall(context, ref, studentId),
              ),
              if (dues != null)
                BhorButton(
                  variant: BhorButtonVariant.ghost,
                  icon: Icons.share,
                  label: l10n.duesRemind,
                  onPressed: () => duesRemind(context, studentId),
                ),
              BhorButton(
                variant: BhorButtonVariant.ghost,
                icon: Icons.person_outline,
                label: l10n.duesOpenProfile,
                onPressed: () => GoRouter.maybeOf(context)?.go(Routes.student(studentId)),
              ),
            ],
          ),
        ],
      ),
    );

    return BhorScaffold(
      body: Padding(
        padding: EdgeInsets.fromLTRB(g, BhorSpace.s8, g, g),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            header,
            const SizedBox(height: BhorSpace.s8),
            Expanded(child: CollectPaymentPanel(studentId: studentId)),
          ],
        ),
      ),
    );
  }
}
