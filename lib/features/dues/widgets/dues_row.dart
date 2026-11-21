// One student of the dues list (UX 2d): 4dp level bar, name and amount, the
// severity tag (icon + word + day), batches and months, then Call / Remind
// and the Collect button. Also the shared row actions and the desktop
// right-click menu (UX 3b: টাকা নিন · মনে করান · নম্বর কপি · মওকুফ).

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/services/contact_actions.dart';
import 'package:attendance_alamin/app/widgets/theme_mapping.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/features/dues/controllers/dues_model.dart';
import 'package:attendance_alamin/features/dues/controllers/dues_state.dart';
import 'package:attendance_alamin/features/dues/controllers/reminder_actions.dart';
import 'package:attendance_alamin/features/dues/widgets/dues_tags.dart';
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

/// The severity tag of [row], or the grey reason for the grey group.
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
        style: context.bhor.type.meta,
      );
    }
    return dueLevelTag(
      context,
      level,
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
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final l10n = context.l10n;
    final bool reminded =
        ref.watch(duesRemindedProvider).value?.contains(row.studentId) ?? false;
    final int year = ref.watch(todayProvider).year;
    final String subtitle = <String>[
      row.batchNames.join(' · '),
      duesMonthsText(context, row, year),
    ].where((String s) => s.isNotEmpty).join(' · ');
    final DueLevel? level = row.inactive ? null : row.level;

    final Widget remind = BhorButton(
      key: ValueKey<String>('dues-remind-${row.studentId}'),
      variant: BhorButtonVariant.ghost,
      icon: reminded ? Icons.check : Icons.share,
      label: reminded ? l10n.duesRemindedToday : l10n.duesRemind,
      onPressed: () => duesRemind(context, row.studentId),
    );

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapUp: (TapUpDetails d) =>
          showDuesContextMenu(context, ref, d.globalPosition, row),
      child: BhorPressable(
        onTap: onOpen,
        semanticLabel: row.name,
        selected: selected,
        radius: BhorRadius.card,
        builder: (BuildContext context, BhorStates s) => AnimatedContainer(
          duration: BhorMotion.fast,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: selected ? c.accentTint : c.surface,
            borderRadius: BorderRadius.circular(BhorRadius.card),
            border: Border.all(color: selected || s.hovered ? c.accentLine : c.line),
          ),
          child: Stack(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(BhorSpace.s16, 10, BhorSpace.s12, BhorSpace.s8),
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
                            style: b.type.heading,
                          ),
                        ),
                        const SizedBox(width: BhorSpace.s8),
                        BhorMoney(
                          row.total,
                          style: b.type.heading,
                          color: row.inactive ? c.text2 : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: BhorSpace.s4),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: DuesStatusBadge(row: row),
                    ),
                    if (subtitle.isNotEmpty) ...<Widget>[
                      const SizedBox(height: BhorSpace.s4),
                      Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: b.type.meta),
                    ],
                    const SizedBox(height: BhorSpace.s4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Expanded(
                          child: Wrap(
                            spacing: BhorSpace.s4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: <Widget>[
                              BhorButton(
                                key: ValueKey<String>('dues-call-${row.studentId}'),
                                variant: BhorButtonVariant.ghost,
                                icon: ContactActions.icon,
                                label: ContactActions.label(l10n),
                                onPressed: () => duesCall(context, ref, row.studentId),
                              ),
                              remind,
                            ],
                          ),
                        ),
                        const SizedBox(width: BhorSpace.s8),
                        BhorButton(
                          key: ValueKey<String>('dues-collect-${row.studentId}'),
                          label: l10n.duesCollect,
                          onPressed: () => duesCollect(context, row.studentId),
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
                child: ExcludeSemantics(
                  child: Container(
                    width: 4,
                    color: level == null ? null : c.sevHue[level.severityLevel.index],
                  ),
                ),
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

/// Desktop context menu on a dues row or table row (a small dialog of the
/// student's actions; [position] is kept for the callers' signature).
Future<void> showDuesContextMenu(
  BuildContext context,
  WidgetRef ref,
  Offset position,
  DuesRow row,
) async {
  final l10n = context.l10n;
  final Student? student = ref.read(duesStudentMapProvider)[row.studentId];
  final String? number = student?.callNumber;
  final String? waiveEnrollment = row.waiveEnrollmentId;
  final YearMonth? waiveMonth = row.waiveMonth;
  final List<(_MenuAction, String)> entries = <(_MenuAction, String)>[
    (_MenuAction.collect, l10n.duesCollect),
    (_MenuAction.remind, l10n.duesRemind),
    if (number != null) (_MenuAction.copy, l10n.commonCopyNumber),
    if (waiveEnrollment != null && waiveMonth != null) (_MenuAction.waive, l10n.duesMenuWaive),
    (_MenuAction.open, l10n.duesOpenProfile),
  ];
  final _MenuAction? choice = await showBhorDialog<_MenuAction>(
    context,
    builder: (BuildContext ctx) => BhorDialog(
      title: row.name,
      body: BhorCard(
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int i = 0; i < entries.length; i++)
              BhorListRow(
                title: entries[i].$2,
                divider: i < entries.length - 1,
                onTap: () => Navigator.of(ctx).pop(entries[i].$1),
              ),
          ],
        ),
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  switch (choice) {
    case _MenuAction.collect:
      await duesCollect(context, row.studentId);
    case _MenuAction.remind:
      await duesRemind(context, row.studentId);
    case _MenuAction.copy:
      final String copied = l10n.commonCopied;
      await Clipboard.setData(ClipboardData(text: number ?? ''));
      if (context.mounted) BhorToast.show(context, message: copied);
    case _MenuAction.waive:
      if (waiveEnrollment != null && waiveMonth != null) {
        await showWaiveDialog(context, enrollmentId: waiveEnrollment, month: waiveMonth);
      }
    case _MenuAction.open:
      GoRouter.maybeOf(context)?.go(Routes.student(row.studentId));
  }
}
