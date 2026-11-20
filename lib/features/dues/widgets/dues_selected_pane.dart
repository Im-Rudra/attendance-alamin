// The payment panel of the Fees screen on wide windows (UX 3b): the selected
// student's header (name, worst badge, call / remind / profile) above the
// inline `CollectPaymentPanel`.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/services/contact_actions.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/app/providers/dues_providers.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/features/dues/controllers/dues_state.dart';
import 'package:attendance_alamin/features/dues/widgets/dues_row.dart';
import 'package:attendance_alamin/features/payments/payments_entry.dart';

class DuesSelectedPane extends ConsumerWidget {
  const DuesSelectedPane({super.key, required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.aurora;
    final l10n = context.l10n;
    final fmt = context.fmt;
    final TextTheme tt = Theme.of(context).textTheme;
    final double g = WindowClass.of(context).gutter;
    final Student? student = ref.watch(duesStudentMapProvider)[studentId];
    final StudentDues? dues = ref.watch(studentDuesProvider(studentId)).value;
    final String name = student?.name ?? dues?.name ?? '';
    final DueLevel? worst = dues?.worst;

    final Widget header = GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              InitialsAvatar(name: name, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleMedium?.copyWith(color: tokens.textPrimary),
                    ),
                    if (dues != null)
                      Row(
                        children: <Widget>[
                          if (worst != null)
                            Flexible(
                              child: SeverityBadge(
                                level: worst,
                                dayInDue: dues.worstDay,
                                monthCount: dues.openDueMonths,
                                compact: true,
                              ),
                            ),
                          if (worst != null) const SizedBox(width: 8),
                          Text(
                            fmt.money(dues.totalOutstanding),
                            style: tt.titleSmall?.copyWith(
                              color: tokens.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: l10n.commonClose,
                icon: const Icon(Icons.close),
                onPressed: () => GoRouter.maybeOf(context)?.go(Routes.fees),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            children: <Widget>[
              TextButton.icon(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () => duesCall(context, ref, studentId),
                icon: Icon(ContactActions.icon, size: 18),
                label: Text(ContactActions.label(l10n)),
              ),
              if (dues != null)
                TextButton.icon(
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: () => duesRemind(context, studentId),
                  icon: const Icon(Icons.share, size: 18),
                  label: Text(l10n.duesRemind),
                ),
              TextButton.icon(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () => GoRouter.maybeOf(context)?.go(Routes.student(studentId)),
                icon: const Icon(Icons.person_outline, size: 18),
                label: Text(l10n.duesOpenProfile),
              ),
            ],
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: EdgeInsets.fromLTRB(g, 8, g, g),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            header,
            const SizedBox(height: 8),
            Expanded(child: CollectPaymentPanel(studentId: studentId)),
          ],
        ),
      ),
    );
  }
}
