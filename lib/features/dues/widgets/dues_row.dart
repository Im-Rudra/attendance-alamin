// One student of the dues list (UX 2d): 4dp level bar, name and amount, the
// severity badge (icon + word + day), batches and months, then Call / Remind
// and the Collect button. Also the shared row actions and the desktop
// right-click menu (UX 3b: টাকা নিন · মনে করান · নম্বর কপি · মওকুফ).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/services/contact_actions.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/features/dues/controllers/dues_model.dart';
import 'package:attendance_alamin/features/dues/controllers/dues_state.dart';
import 'package:attendance_alamin/features/dues/controllers/reminder_actions.dart';
import 'package:attendance_alamin/features/payments/payments_entry.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

// ---- shared actions ----------------------------------------------------------

/// Selects a student: the payment panel on wide windows, the profile on phones
/// (the router decides, `/fees/s/:studentId`).
void openDuesStudent(BuildContext context, String studentId) {
  GoRouter.maybeOf(context)?.go(Routes.feesStudent(studentId));
}

Future<void> duesCall(BuildContext context, WidgetRef ref, String studentId) =>
    callStudent(context, ref.read(duesStudentMapProvider)[studentId]);

Future<void> duesRemind(BuildContext context, String studentId) async {
  await remindStudent(context, ProviderScope.containerOf(context, listen: false), studentId);
}

Future<void> duesCollect(BuildContext context, String studentId) async {
  await showCollectPaymentSheet(context, studentId: studentId);
}

// ---- texts -------------------------------------------------------------------

/// "অক্টোবর, নভেম্বর" of the open months of [row].
String duesMonthsText(BuildContext context, DuesRow row, int currentYear) =>
    context.fmt.monthList(row.months, currentYear: currentYear);

String inactiveReasonText(AppLocalizations l10n, InactiveReason? reason) =>
    switch (reason) {
      InactiveReason.left => l10n.duesReasonLeft,
      InactiveReason.archived => l10n.duesReasonArchived,
      InactiveReason.ended => l10n.duesReasonEnded,
      null => l10n.duesInactiveGroup,
    };

/// The severity badge of [row], or the grey reason for the grey group.
class DuesStatusBadge extends StatelessWidget {
  const DuesStatusBadge({super.key, required this.row, this.compact = false});

  final DuesRow row;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final DueLevel? level = row.level;
    if (row.inactive || level == null) {
      return Text(
        inactiveReasonText(context.l10n, row.reason),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(color: context.aurora.textSecondary),
      );
    }
    return SeverityBadge(
      level: level,
      dayInDue: row.dayInDue,
      monthCount: row.monthCount,
      partialRemaining: row.partialRemaining,
      compact: compact,
    );
  }
}

// ---- the row -----------------------------------------------------------------

class DuesRowTile extends ConsumerWidget {
  const DuesRowTile({
    super.key,
    required this.row,
    required this.selected,
    required this.onOpen,
  });

  final DuesRow row;
  final bool selected;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.aurora;
    final l10n = context.l10n;
    final fmt = context.fmt;
    final TextTheme tt = Theme.of(context).textTheme;
    final bool reminded =
        ref.watch(duesRemindedProvider).value?.contains(row.studentId) ?? false;
    final int year = ref.watch(todayProvider).year;
    final String subtitle = <String>[
      row.batchNames.join(' · '),
      duesMonthsText(context, row, year),
    ].where((String s) => s.isNotEmpty).join(' · ');

    final Widget remind = TextButton.icon(
      key: ValueKey<String>('dues-remind-${row.studentId}'),
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      onPressed: () => duesRemind(context, row.studentId),
      icon: Icon(reminded ? Icons.check : Icons.share, size: 18),
      label: Text(reminded ? l10n.duesRemindedToday : l10n.duesRemind),
    );

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapUp: (TapUpDetails d) =>
          showDuesContextMenu(context, ref, d.globalPosition, row),
      child: Material(
        color: selected ? tokens.accentContainer : tokens.surfaceDense,
        child: InkWell(
          onTap: onOpen,
          hoverColor: tokens.track,
          child: Stack(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            row.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.titleMedium?.copyWith(color: tokens.textPrimary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          fmt.money(row.total),
                          maxLines: 1,
                          style: tt.titleMedium?.copyWith(
                            color: row.inactive ? tokens.textSecondary : tokens.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: DuesStatusBadge(row: row),
                    ),
                    if (subtitle.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tt.labelMedium?.copyWith(color: tokens.textSecondary),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Expanded(
                          child: Wrap(
                            spacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: <Widget>[
                              TextButton.icon(
                                key: ValueKey<String>('dues-call-${row.studentId}'),
                                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                                onPressed: () => duesCall(context, ref, row.studentId),
                                icon: Icon(ContactActions.icon, size: 18),
                                label: Text(ContactActions.label(l10n)),
                              ),
                              remind,
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          key: ValueKey<String>('dues-collect-${row.studentId}'),
                          style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                          onPressed: () => duesCollect(context, row.studentId),
                          child: Text(l10n.duesCollect),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: LevelEdgeBar(level: row.inactive ? null : row.level),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---- right-click menu --------------------------------------------------------

enum _MenuAction { collect, remind, copy, waive, open }

/// Desktop context menu on a dues row or table row.
Future<void> showDuesContextMenu(
  BuildContext context,
  WidgetRef ref,
  Offset position,
  DuesRow row,
) async {
  final l10n = context.l10n;
  final RenderObject? overlay = Overlay.maybeOf(context)?.context.findRenderObject();
  if (overlay is! RenderBox) return;
  final Student? student = ref.read(duesStudentMapProvider)[row.studentId];
  final String? number = student?.callNumber;
  final String? waiveEnrollment = row.waiveEnrollmentId;
  final YearMonth? waiveMonth = row.waiveMonth;
  final _MenuAction? choice = await showMenu<_MenuAction>(
    context: context,
    position: RelativeRect.fromRect(
      Rect.fromLTWH(position.dx, position.dy, 0, 0),
      Offset.zero & overlay.size,
    ),
    items: <PopupMenuEntry<_MenuAction>>[
      PopupMenuItem<_MenuAction>(value: _MenuAction.collect, child: Text(l10n.duesCollect)),
      PopupMenuItem<_MenuAction>(value: _MenuAction.remind, child: Text(l10n.duesRemind)),
      if (number != null)
        PopupMenuItem<_MenuAction>(value: _MenuAction.copy, child: Text(l10n.commonCopyNumber)),
      if (waiveEnrollment != null && waiveMonth != null)
        PopupMenuItem<_MenuAction>(value: _MenuAction.waive, child: Text(l10n.duesMenuWaive)),
      PopupMenuItem<_MenuAction>(value: _MenuAction.open, child: Text(l10n.duesOpenProfile)),
    ],
  );
  if (choice == null || !context.mounted) return;
  switch (choice) {
    case _MenuAction.collect:
      await duesCollect(context, row.studentId);
    case _MenuAction.remind:
      await duesRemind(context, row.studentId);
    case _MenuAction.copy:
      final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
      final String copied = l10n.commonCopied;
      await Clipboard.setData(ClipboardData(text: number ?? ''));
      messenger?.showSnackBar(SnackBar(content: Text(copied)));
    case _MenuAction.waive:
      if (waiveEnrollment != null && waiveMonth != null) {
        await showWaiveDialog(context, enrollmentId: waiveEnrollment, month: waiveMonth);
      }
    case _MenuAction.open:
      GoRouter.maybeOf(context)?.go(Routes.student(row.studentId));
  }
}
