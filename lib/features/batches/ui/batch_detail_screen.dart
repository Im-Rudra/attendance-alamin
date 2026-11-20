// Batch detail (UX table "Batch detail"): glass header card, tabs
// শিক্ষার্থী · হাজিরা · বেতন · সময়সূচি. The last three tabs belong to other
// features and are reached through their entry files.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/providers/dues_providers.dart';
import 'package:attendance_alamin/app/providers/schedule_providers.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/pane_split.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
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

class _BatchDetailScreenState extends ConsumerState<BatchDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this)..addListener(_onTab);

  void _onTab() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabs
      ..removeListener(_onTab)
      ..dispose();
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final AsyncValue<Batch?> async = ref.watch(batchByIdProvider(widget.batchId));
    final bool embedded = PaneScope.isEmbedded(context);

    Widget frame({String title = '', List<Widget> actions = const <Widget>[], Widget? fab, required Widget body}) {
      final double g = WindowClass.of(context).gutter;
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !embedded,
          title: Semantics(header: true, child: Text(title)),
          actions: <Widget>[...actions, const SizedBox(width: 8)],
        ),
        floatingActionButton: fab,
        body: SafeArea(
          top: false,
          child: Padding(padding: EdgeInsets.fromLTRB(g, 4, g, 0), child: body),
        ),
      );
    }

    return async.when(
      loading: () => frame(body: const Center(child: CircularProgressIndicator())),
      error: (Object e, StackTrace s) => frame(
        body: EmptyState(
          icon: Icons.error_outline,
          message: l10n.commonLoadingFailed,
          actionLabel: l10n.commonRetry,
          onAction: () => ref.invalidate(batchByIdProvider(widget.batchId)),
        ),
      ),
      data: (Batch? b) {
        if (b == null) {
          return frame(
            body: EmptyState(icon: Icons.search_off, message: l10n.errNotFound),
          );
        }
        final bool compact = !WindowClass.of(context).usesRail;
        final bool showFab = _tabs.index == 0 && !b.archived;
        return frame(
          title: b.name,
          actions: <Widget>[
            IconButton(
              tooltip: l10n.commonEdit,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push(Routes.batchEdit(b.id)),
            ),
            PopupMenuButton<_MenuAction>(
              tooltip: l10n.commonMore,
              onSelected: _onMenu,
              itemBuilder: (BuildContext ctx) => <PopupMenuEntry<_MenuAction>>[
                if (b.archived)
                  PopupMenuItem<_MenuAction>(
                    value: _MenuAction.unarchive,
                    child: Text(l10n.batchMenuUnarchive),
                  )
                else
                  PopupMenuItem<_MenuAction>(
                    value: _MenuAction.archive,
                    child: Text(l10n.batchMenuArchive),
                  ),
                const PopupMenuDivider(),
                PopupMenuItem<_MenuAction>(
                  value: _MenuAction.delete,
                  child: Text(l10n.batchMenuDelete),
                ),
              ],
            ),
          ],
          fab: showFab
              ? Padding(
                  padding: EdgeInsets.only(bottom: compact ? 84 : 0),
                  child: FloatingActionButton.extended(
                    heroTag: null,
                    onPressed: () => showAddStudentToBatchSheet(context, batchId: b.id),
                    icon: const Icon(Icons.person_add_alt_1),
                    label: Text(l10n.batchAddStudent),
                  ),
                )
              : null,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _BatchHeader(batch: b),
              const SizedBox(height: 8),
              TabBar(
                controller: _tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: <Widget>[
                  Tab(text: l10n.batchTabStudents),
                  Tab(text: l10n.batchTabAttendance),
                  Tab(text: l10n.batchTabFees),
                  Tab(text: l10n.batchTabSchedule),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
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

/// Glass header: subject, fee, billing pill, take-attendance, and (wide) the
/// three stat tiles.
class _BatchHeader extends ConsumerWidget {
  const _BatchHeader({required this.batch});

  final Batch batch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
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
        return GlassCard(
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
                      style: tt.bodyMedium?.copyWith(color: tokens.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  BillingPill(type: batch.billingType),
                ],
              ),
              const SizedBox(height: 4),
              if (!tiles)
                Text(
                  facts.join(' · '),
                  style: tt.bodyLarge?.copyWith(color: tokens.textPrimary),
                )
              else ...<Widget>[
                if (fee != null)
                  Text(
                    l10n.batchFeePerMonth(fmt.money(fee)),
                    style: tt.titleMedium?.copyWith(color: tokens.textPrimary),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: StatTile(label: l10n.batchStatStudents, value: fmt.number(students)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatTile(
                        label: l10n.batchStatToday,
                        value: pct == null ? l10n.batchStatNone : fmt.percent(pct),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatTile(
                        label: l10n.batchStatDues,
                        value: fmt.money(dues?.total ?? 0),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              if (batch.archived)
                _ArchivedBanner(batch: batch)
              else
                FilledButton.icon(
                  onPressed: () => openRollCallForBatchDate(context, batchId: batch.id, date: today),
                  icon: const Icon(Icons.how_to_reg_outlined),
                  label: Text(l10n.batchTakeAttendance),
                  style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
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
    final tokens = context.aurora;
    final l10n = context.l10n;
    final LocalDate? on = batch.archivedOn;
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Icon(Icons.inventory_2_outlined, color: tokens.textSecondary),
        if (on != null)
          Text(
            l10n.batchArchivedBanner(context.fmt.date(on)),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: tokens.textSecondary),
          ),
        OutlinedButton(
          onPressed: () => showUnarchiveBatchFlow(context, batchId: batch.id),
          style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
          child: Text(l10n.batchMenuUnarchive),
        ),
      ],
    );
  }
}
