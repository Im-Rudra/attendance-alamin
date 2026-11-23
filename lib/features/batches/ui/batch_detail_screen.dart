// Batch detail (UX table "Batch detail"): header card, tabs
// শিক্ষার্থী · হাজিরা · বেতন · সময়সূচি. The last three tabs belong to other
// features and are reached through their entry files.

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
import 'package:attendance_alamin/app/shell/templates/templates.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/enrollment.dart';
import 'package:attendance_alamin/domain/models/fee_period.dart';
import 'package:attendance_alamin/domain/models/subject.dart';
import 'package:attendance_alamin/features/attendance/attendance_entry.dart';
import 'package:attendance_alamin/features/batches/batches_entry.dart';
import 'package:attendance_alamin/features/batches/controllers/batch_providers.dart';
import 'package:attendance_alamin/features/batches/ui/batch_form_screen.dart';
import 'package:attendance_alamin/features/batches/widgets/batch_card.dart';
import 'package:attendance_alamin/features/batches/widgets/batch_format.dart';
import 'package:attendance_alamin/features/batches/widgets/batch_overview.dart';
import 'package:attendance_alamin/features/batches/widgets/batch_students_tab.dart';
import 'package:attendance_alamin/features/batches/widgets/delete_batch.dart';
import 'package:attendance_alamin/features/dues/dues_entry.dart';
import 'package:attendance_alamin/features/extras/ui/bulk_add_screen.dart';
import 'package:attendance_alamin/features/schedule/schedule_entry.dart';
import 'package:attendance_alamin/features/students/students_entry.dart';

class BatchDetailScreen extends ConsumerStatefulWidget {
  const BatchDetailScreen({super.key, required this.batchId});

  final String batchId;

  @override
  ConsumerState<BatchDetailScreen> createState() => _BatchDetailScreenState();
}

class _BatchDetailScreenState extends ConsumerState<BatchDetailScreen> {
  int _tab = 0;

  Future<void> _openMenu(Batch b, BuildContext anchor) async {
    final l10n = context.l10n;
    await showBhorMenu(
      context,
      anchor: anchor,
      items: <BhorMenuItem>[
        if (!b.archived)
          BhorMenuItem(
            icon: BhorIcons.add,
            label: l10n.batchBulkAdd,
            onTap: () => showBulkAddPanel(context, batchId: widget.batchId),
          ),
        if (b.archived)
          BhorMenuItem(
            icon: BhorIcons.archive,
            label: l10n.batchMenuUnarchive,
            onTap: () => showUnarchiveBatchFlow(context, batchId: widget.batchId),
          )
        else
          BhorMenuItem(
            icon: BhorIcons.archive,
            label: l10n.batchMenuArchive,
            onTap: () => showArchiveBatchDialog(context, batchId: widget.batchId),
          ),
        // Destructive: last, in the error colour, then the confirm.
        BhorMenuItem(
          icon: BhorIcons.delete,
          label: l10n.batchMenuDelete,
          destructive: true,
          onTap: () async {
            final bool gone = await confirmDeleteBatch(context, batchId: widget.batchId);
            if (gone && mounted) GoRouter.maybeOf(context)?.go(Routes.batches);
          },
        ),
      ],
    );
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
          icon: BhorIcons.warning,
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
          return frame(body: BhorEmptyState(icon: BhorIcons.search, title: l10n.errNotFound));
        }
        final bool compact = !WindowClass.of(context).usesRail;
        // Phones: a FAB on the Students tab. Desktop: the header actions are
        // the same on every tab (review B3), "Add student" always among them.
        final bool showFab = _tab == 0 && !b.archived;
        return frame(
          title: b.name,
          actions: <Widget>[
            if (!compact && !b.archived)
              BhorButton(
                icon: BhorIcons.add,
                label: l10n.batchAddStudent,
                size: BhorButtonSize.sm,
                onPressed: () => showAddStudentToBatchSheet(context, batchId: b.id),
              ),
            BhorIconButton(
              semanticLabel: l10n.commonEdit,
              icon: BhorIcons.edit,
              onPressed: () => showBatchFormPanel(context, batchId: b.id),
            ),
            Builder(
              builder: (BuildContext bc) => BhorIconButton(
                semanticLabel: l10n.commonMore,
                icon: BhorIcons.overflowVertical,
                onPressed: () => _openMenu(b, bc),
              ),
            ),
          ],
          fab: (showFab && compact)
              ? Padding(
                  padding: EdgeInsets.only(bottom: compact ? 84 : 0),
                  child: BhorButton(
                    icon: BhorIcons.add,
                    label: l10n.batchAddStudent,
                    onPressed: () => showAddStudentToBatchSheet(context, batchId: b.id),
                  ),
                )
              : null,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _BatchHeader(batch: b, foldInsights: BhorMasterDetailPage.foldedRailOf(context) != null),
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
  const _BatchHeader({required this.batch, this.foldInsights = false});

  final Batch batch;

  /// The master-detail template folded its context rail (< 1600): show the
  /// dues by level and the attendance trend here (review B1).
  final bool foldInsights;

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
      if (fee != null) fee == 0 ? l10n.batchNoFeeYet : l10n.batchFeePerMonth(fmt.money(fee)),
      l10n.studentCountText(students, fmt.number(students)),
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
                if (fee != null)
                  Text(
                    fee == 0 ? l10n.batchNoFeeYet : l10n.batchFeePerMonth(fmt.money(fee)),
                    style: th.type.heading,
                  ),
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
              // One "take attendance" lives in the Attendance tab (review B4).
              if (foldInsights && tiles && !batch.archived && MediaQuery.sizeOf(context).height >= 700) ...<Widget>[
                const SizedBox(height: BhorSpace.s12),
                SizedBox(height: 1, child: ColoredBox(color: th.colors.line)),
                const SizedBox(height: BhorSpace.s12),
                BatchInsightsPanel(batchId: batch.id),
              ],
              if (batch.archived) ...<Widget>[
                const SizedBox(height: BhorSpace.s8),
                _ArchivedBanner(batch: batch),
              ],
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
        Icon(BhorIcons.archive, color: th.colors.text2),
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
