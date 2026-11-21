// Batch detail (UX table "Batch detail"): header card, tabs
// শিক্ষার্থী · হাজিরা · বেতন · সময়সূচি. The last three tabs belong to other
// features and are reached through their entry files.

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/providers/dues_providers.dart';
import 'package:attendance_alamin/app/providers/schedule_providers.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/pane_split.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/enrollment.dart';
import 'package:attendance_alamin/domain/models/fee_period.dart';
import 'package:attendance_alamin/domain/models/subject.dart';
import 'package:attendance_alamin/features/attendance/attendance_entry.dart';
import 'package:attendance_alamin/features/batches/batches_entry.dart';
import 'package:attendance_alamin/features/batches/controllers/batch_providers.dart';
import 'package:attendance_alamin/features/batches/widgets/batch_card.dart';
import 'package:attendance_alamin/features/batches/widgets/batch_format.dart';
import 'package:attendance_alamin/features/batches/widgets/batch_students_tab.dart';
import 'package:attendance_alamin/features/batches/widgets/delete_batch.dart';
import 'package:attendance_alamin/features/dues/dues_entry.dart';
import 'package:attendance_alamin/features/schedule/schedule_entry.dart';
import 'package:attendance_alamin/features/students/students_entry.dart';

enum _MenuAction { archive, unarchive, delete }

class BatchDetailScreen extends ConsumerStatefulWidget {
  const BatchDetailScreen({super.key, required this.batchId});

  final String batchId;

  @override
  ConsumerState<BatchDetailScreen> createState() => _BatchDetailScreenState();
}

class _BatchDetailScreenState extends ConsumerState<BatchDetailScreen> {
  int _tab = 0;

  Future<void> _onMenu(_MenuAction a) async {
    switch (a) {
      case _MenuAction.archive:
        await showArchiveBatchDialog(context, batchId: widget.batchId);
      case _MenuAction.unarchive:
        await showUnarchiveBatchFlow(context, batchId: widget.batchId);
      case _MenuAction.delete:
        final bool gone = await confirmDeleteBatch(context, batchId: widget.batchId);
        if (gone && mounted) GoRouter.maybeOf(context)?.go(Routes.batches);
    }
  }

  Future<void> _openMenu(Batch b) async {
    final l10n = context.l10n;
    final _MenuAction? a = await showBhorSheet<_MenuAction>(
      context,
      title: b.name,
      builder: (BuildContext ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (b.archived)
            BhorListRow(
              title: l10n.batchMenuUnarchive,
              onTap: () => Navigator.of(ctx).pop(_MenuAction.unarchive),
            )
          else
            BhorListRow(
              title: l10n.batchMenuArchive,
              onTap: () => Navigator.of(ctx).pop(_MenuAction.archive),
            ),
          BhorListRow(
            title: l10n.batchMenuDelete,
            divider: false,
            onTap: () => Navigator.of(ctx).pop(_MenuAction.delete),
          ),
        ],
      ),
    );
    if (a != null && mounted) await _onMenu(a);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final AsyncValue<Batch?> async = ref.watch(batchByIdProvider(widget.batchId));
    final bool embedded = PaneScope.isEmbedded(context);

    Widget frame({String title = '', List<Widget> actions = const <Widget>[], Widget? fab, required Widget body}) {
      final double g = WindowClass.of(context).gutter;
      return BhorScaffold(
        header: BhorHeader(title: title, actions: actions, showBack: embedded ? false : null),
        floating: fab,
        body: Padding(padding: EdgeInsets.fromLTRB(g, BhorSpace.s4, g, 0), child: body),
      );
    }

    return async.when(
      loading: () => frame(body: const Center(child: BhorSpinner())),
      error: (Object e, StackTrace s) => frame(
        body: BhorEmptyState(
          icon: Icons.error_outline,
          title: l10n.commonLoadingFailed,
          action: BhorButton(
            label: l10n.commonRetry,
            variant: BhorButtonVariant.secondary,
            onPressed: () => ref.invalidate(batchByIdProvider(widget.batchId)),
          ),
        ),
      ),
      data: (Batch? b) {
        if (b == null) {
          return frame(body: BhorEmptyState(icon: Icons.search_off, title: l10n.errNotFound));
        }
        final bool compact = !WindowClass.of(context).usesRail;
        final bool showFab = _tab == 0 && !b.archived;
        return frame(
          title: b.name,
          actions: <Widget>[
            if (!b.archived)
              BhorIconButton(
                key: const Key('batch-bulk-add'),
                semanticLabel: l10n.batchBulkAdd,
                icon: Icons.group_add_outlined,
                onPressed: () => context.push(Routes.batchBulkAdd(b.id)),
              ),
            BhorIconButton(
              semanticLabel: l10n.commonEdit,
              icon: Icons.edit_outlined,
              onPressed: () => context.push(Routes.batchEdit(b.id)),
            ),
            BhorIconButton(
              semanticLabel: l10n.commonMore,
              icon: Icons.more_vert,
              onPressed: () => _openMenu(b),
            ),
          ],
          fab: showFab
              ? Padding(
                  padding: EdgeInsets.only(bottom: compact ? 84 : 0),
                  child: BhorButton(
                    icon: Icons.person_add_alt_1,
                    label: l10n.batchAddStudent,
                    onPressed: () => showAddStudentToBatchSheet(context, batchId: b.id),
                  ),
                )
              : null,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _BatchHeader(batch: b),
              const SizedBox(height: BhorSpace.s8),
              BhorTabs(
                tabs: <String>[
                  l10n.batchTabStudents,
                  l10n.batchTabAttendance,
                  l10n.batchTabFees,
                  l10n.batchTabSchedule,
                ],
                index: _tab,
                onChanged: (int i) => setState(() => _tab = i),
              ),
              Expanded(
                child: IndexedStack(
                  index: _tab,
                  children: <Widget>[
                    BatchStudentsTab(batchId: b.id, archived: b.archived),
                    BatchAttendanceTab(batchId: b.id),
                    BatchFeesTab(batchId: b.id),
                    BatchScheduleTab(batchId: b.id),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Header card: subject, fee, billing pill, take-attendance, and (wide) the
/// three stat tiles.
class _BatchHeader extends ConsumerWidget {
  const _BatchHeader({required this.batch});

  final Batch batch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final BhorThemeData th = context.bhor;
    final LocalDate today = ref.watch(todayProvider);

    String subjectName = '';
    for (final Subject s in ref.watch(batchSubjectsProvider).value ?? const <Subject>[]) {
      if (s.id == batch.subjectId) subjectName = s.name;
    }
    final List<FeePeriod> fees = ref.watch(batchFeesProvider(batch.id)).value ?? const <FeePeriod>[];
    final int? fee = feeIn(fees, today.yearMonth);
    final int students = <Enrollment>[
      for (final Enrollment e in ref.watch(batchEnrollmentsProvider(batch.id)).value ?? const <Enrollment>[])
        if (e.endDate == null) e,
    ].length;
    final int? pct = BatchCard.todayPercent(ref.watch(dayPlanProvider(today)).value, batch.id);
    final BatchDuesSummary? dues = ref.watch(batchDuesProvider(batch.id)).value;

    final List<String> facts = <String>[
      if (fee != null) l10n.batchFeePerMonth(fmt.money(fee)),
      l10n.batchStudentCount(fmt.number(students)),
      if (pct != null) l10n.batchTodayPercent(fmt.percent(pct)),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final bool tiles = c.maxWidth >= 480 && MediaQuery.sizeOf(context).height >= 600;
        return BhorCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      subjectName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: th.type.body.copyWith(color: th.colors.text2),
                    ),
                  ),
                  const SizedBox(width: BhorSpace.s8),
                  BillingPill(type: batch.billingType),
                ],
              ),
              const SizedBox(height: BhorSpace.s4),
              if (!tiles)
                Text(facts.join(' · '), style: th.type.body)
              else ...<Widget>[
                if (fee != null) Text(l10n.batchFeePerMonth(fmt.money(fee)), style: th.type.heading),
                const SizedBox(height: BhorSpace.s8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(child: BhorStatText(label: l10n.batchStatStudents, value: fmt.number(students))),
                    const SizedBox(width: BhorSpace.s8),
                    Expanded(
                      child: BhorStatText(
                        label: l10n.batchStatToday,
                        value: pct == null ? l10n.batchStatNone : fmt.percent(pct),
                      ),
                    ),
                    const SizedBox(width: BhorSpace.s8),
                    Expanded(child: BhorStatText.money(label: l10n.batchStatDues, amount: dues?.total ?? 0)),
                  ],
                ),
              ],
              const SizedBox(height: BhorSpace.s8),
              if (batch.archived)
                _ArchivedBanner(batch: batch)
              else
                BhorButton(
                  icon: Icons.how_to_reg_outlined,
                  label: l10n.batchTakeAttendance,
                  onPressed: () => openRollCallForBatchDate(context, batchId: batch.id, date: today),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ArchivedBanner extends StatelessWidget {
  const _ArchivedBanner({required this.batch});

  final Batch batch;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData th = context.bhor;
    final l10n = context.l10n;
    final LocalDate? on = batch.archivedOn;
    return Wrap(
      spacing: BhorSpace.s12,
      runSpacing: BhorSpace.s8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Icon(Icons.inventory_2_outlined, color: th.colors.text2),
        if (on != null)
          Text(
            l10n.batchArchivedBanner(context.fmt.date(on)),
            style: th.type.body.copyWith(color: th.colors.text2),
          ),
        BhorButton(
          label: l10n.batchMenuUnarchive,
          variant: BhorButtonVariant.secondary,
          onPressed: () => showUnarchiveBatchFlow(context, batchId: batch.id),
        ),
      ],
    );
  }
}
