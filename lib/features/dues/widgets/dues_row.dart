// One student of the dues list: avatar, name and amount, the calm pill tag
// (icon + word + day), batches and months, then (wide) Call / Remind and the
// secondary "টাকা নিন" button that opens the payment panel; phones keep one
// compact line and put call / remind behind a long press. Also the shared
// row actions and the desktop right-click menu (টাকা নিন · মনে করান ·
// নম্বর কপি · মওকুফ).

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/app/services/contact_actions.dart';
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

/// Opens the payment flow of a student: the floating side panel on wide
/// windows, the profile on phones (the router decides, `/fees/s/:studentId`).
void openDuesStudent(BuildContext context, String studentId) {
  if (WindowClass.of(context).isWide) {
    unawaited(duesCollect(context, studentId));
    return;
  }
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
    this.divider = true,
  });

  final DuesRow row;
  final bool selected;
  final VoidCallback onOpen;

  /// Hairline under the row (off for the last row of a list card).
  final bool divider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final l10n = context.l10n;
    final bool wide = context.bhorIsWide;
    final bool reminded =
        ref.watch(duesRemindedProvider).value?.contains(row.studentId) ?? false;
    final int year = ref.watch(todayProvider).year;
    final String subtitle = <String>[
      row.batchNames.join(' · '),
      duesMonthsText(context, row, year),
    ].where((String s) => s.isNotEmpty).join(' · ');

    final String remindLabel = reminded ? l10n.duesRemindedToday : l10n.duesRemind;
    final Widget call = BhorIconButton(
            key: ValueKey<String>('dues-call-${row.studentId}'),
            icon: ContactActions.icon,
            semanticLabel: ContactActions.label(l10n),
            size: BhorButtonSize.sm,
            onPressed: () => duesCall(context, ref, row.studentId),
          );
    final Widget remind = BhorIconButton(
            key: ValueKey<String>('dues-remind-${row.studentId}'),
            icon: reminded ? BhorIcons.check : BhorIcons.share,
            semanticLabel: remindLabel,
            size: BhorButtonSize.sm,
            onPressed: () => duesRemind(context, row.studentId),
          );
    final Widget collect = BhorButton(
      key: ValueKey<String>('dues-collect-${row.studentId}'),
      variant: BhorButtonVariant.secondary,
      size: BhorButtonSize.sm,
      label: l10n.duesCollect,
      onPressed: () => duesCollect(context, row.studentId),
    );
    final Widget name = Text(
      row.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: b.type.bodyStrong,
    );
    final Widget amount = BhorMoney(
      row.total,
      style: b.type.bodyStrong,
      color: row.inactive ? c.text2 : null,
    );
    final Widget details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        name,
        const SizedBox(height: 2),
        Align(alignment: AlignmentDirectional.centerStart, child: DuesStatusBadge(row: row)),
        if (reminded && !wide) ...<Widget>[
          const SizedBox(height: 2),
          Text(remindLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: b.type.meta),
        ],
        if (subtitle.isNotEmpty) ...<Widget>[
          const SizedBox(height: 2),
          Text(subtitle, maxLines: wide ? 1 : 2, overflow: TextOverflow.ellipsis, style: b.type.meta),
        ],
      ],
    );

    final Widget content = wide
        ? Row(
            children: <Widget>[
              BhorAvatar(name: row.name, size: 40),
              const SizedBox(width: BhorSpace.s12),
              Expanded(child: details),
              const SizedBox(width: BhorSpace.s12),
              call,
              remind,
              const SizedBox(width: BhorSpace.s12),
              SizedBox(width: 104, child: Align(alignment: AlignmentDirectional.centerEnd, child: amount)),
              const SizedBox(width: BhorSpace.s12),
              collect,
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              BhorAvatar(name: row.name, size: 40),
              const SizedBox(width: BhorSpace.s12),
              Expanded(child: details),
              const SizedBox(width: BhorSpace.s8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  amount,
                  const SizedBox(height: BhorSpace.s4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (!row.inactive) remind,
                      const SizedBox(width: BhorSpace.s4),
                      collect,
                    ],
                  ),
                ],
              ),
            ],
          );

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapUp: (TapUpDetails d) =>
          showDuesContextMenu(context, ref, d.globalPosition, row),
      // Phones: call / remind / copy live behind a long press.
      onLongPress: () => showDuesContextMenu(context, ref, Offset.zero, row),
      child: BhorPressable(
        onTap: onOpen,
        semanticLabel: row.name,
        selected: selected,
        scaleOnPress: false,
        radius: 0,
        builder: (BuildContext context, BhorStates s) => AnimatedContainer(
          duration: BhorMotion.of(context, BhorMotion.instant),
          padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s16, vertical: BhorSpace.s12),
          decoration: BoxDecoration(
            color: selected ? c.accentTint : (s.hovered || s.pressed ? c.soft : c.soft.withValues(alpha: 0)),
            border: divider ? Border(bottom: BorderSide(color: c.line)) : null,
          ),
          child: content,
        ),
      ),
    );
  }
}

// ---- right-click menu --------------------------------------------------------

enum _MenuAction { collect, call, remind, copy, waive, open }

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
    if (number != null) (_MenuAction.call, ContactActions.label(l10n)),
    (_MenuAction.remind, l10n.duesRemind),
    if (number != null) (_MenuAction.copy, l10n.commonCopyNumber),
    if (waiveEnrollment != null && waiveMonth != null) (_MenuAction.waive, l10n.duesMenuWaive),
    (_MenuAction.open, l10n.duesOpenProfile),
  ];
  final _MenuAction? choice = await showBhorPanel<_MenuAction>(
    context,
    kind: BhorPanelKind.menu,
    anchor: context,
    title: row.name,
    builder: (BuildContext ctx) => Column(
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
  );
  if (choice == null || !context.mounted) return;
  switch (choice) {
    case _MenuAction.collect:
      await duesCollect(context, row.studentId);
    case _MenuAction.call:
      await duesCall(context, ref, row.studentId);
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
