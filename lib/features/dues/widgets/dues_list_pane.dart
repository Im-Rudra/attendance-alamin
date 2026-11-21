// The dues list (UX 2d, 3b): summary, filter chips, "remind everyone", then
// sticky severity groups (overdue first) and the collapsed grey
// "ছেড়ে যাওয়া / আর্কাইভ" group. On large windows the same data becomes the
// dues data table.

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/dues_providers.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/features/dues/controllers/dues_model.dart';
import 'package:attendance_alamin/features/dues/controllers/dues_state.dart';
import 'package:attendance_alamin/features/dues/widgets/dues_empty.dart';
import 'package:attendance_alamin/features/dues/widgets/dues_filters.dart';
import 'package:attendance_alamin/features/dues/widgets/dues_group_header.dart';
import 'package:attendance_alamin/features/dues/widgets/dues_overview.dart';
import 'package:attendance_alamin/features/dues/widgets/dues_row.dart';
import 'package:attendance_alamin/features/dues/widgets/dues_table.dart';
import 'package:attendance_alamin/features/dues/widgets/reminder_walkthrough.dart';

class DuesListPane extends ConsumerStatefulWidget {
  const DuesListPane({
    super.key,
    this.selectedId,
    this.table = false,
    this.showSummary = true,
  });

  /// Student whose payment panel is open (wide windows).
  final String? selectedId;

  /// Large windows: the data table instead of rows.
  final bool table;

  /// Show the summary card above the filters (phones and mediums).
  final bool showSummary;

  @override
  ConsumerState<DuesListPane> createState() => _DuesListPaneState();
}

class _DuesListPaneState extends ConsumerState<DuesListPane> {
  bool _showInactive = false;

  void _open(String studentId) => openDuesStudent(context, studentId);

  void _toggleInactive() => setState(() => _showInactive = !_showInactive);

  Future<void> _remindAll(List<DuesRow> rows) async {
    final Set<String> done = ref.read(duesRemindedProvider).value ?? const <String>{};
    final List<DuesRow> todo = <DuesRow>[
      for (final DuesRow r in rows)
        if (!done.contains(r.studentId)) r,
    ];
    if (todo.isEmpty) {
      BhorToast.show(context, message: context.l10n.duesWalkNobody, bottomOffset: 64);
      return;
    }
    await showReminderWalkthrough(context, todo);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final double g = WindowClass.of(context).gutter;
    final AsyncValue<DuesView> async = ref.watch(duesViewProvider);
    final DuesReport? report = ref.watch(duesReportProvider).value;
    return async.when(
      loading: () => const Center(child: BhorSpinner()),
      error: (Object e, StackTrace s) =>
          BhorEmptyState(icon: Icons.error_outline, title: l10n.commonLoadingFailed),
      data: (DuesView view) {
        if (report == null) return const Center(child: BhorSpinner());
        if (report.active.isEmpty && report.inactive.isEmpty) {
          return const DuesEmptyState();
        }
        return widget.table ? _buildTable(view, report, g) : _buildList(view, report, g);
      },
    );
  }

  Widget _remindAllButton(DuesView view) {
    return BhorButton(
      key: const ValueKey<String>('dues-remind-all'),
      variant: BhorButtonVariant.secondary,
      icon: Icons.campaign_outlined,
      label: context.l10n.duesRemindAll,
      onPressed: () => _remindAll(view.active),
    );
  }

  Widget _noMatch() {
    final l10n = context.l10n;
    return BhorEmptyState(
      icon: Icons.filter_alt_off_outlined,
      title: l10n.duesNoMatch,
      action: BhorButton(
        label: l10n.duesShowAll,
        variant: BhorButtonVariant.secondary,
        onPressed: () => ref.read(duesFilterProvider.notifier).reset(),
      ),
    );
  }

  /// Total and "N unpaid · M overdue" in one compact line (wide windows keep
  /// the summary card in the overview pane).
  Widget _headline(DuesReport report) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final BhorThemeData b = context.bhor;
    return Wrap(
      spacing: BhorSpace.s12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        BhorMoney(report.totalOutstandingActive, style: b.type.stat),
        Text(
          l10n.duesHeadline(
            fmt.number(report.studentsWithDues),
            fmt.number(report.overdueStudents),
          ),
          style: b.type.bodyStrong.copyWith(color: b.colors.text2),
        ),
      ],
    );
  }

  // ---- rows (phone, medium, narrow panes) ------------------------------------

  Widget _buildList(DuesView view, DuesReport report, double g) {
    final l10n = context.l10n;
    final List<Widget> slivers = <Widget>[
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(g, 4, g, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (widget.showSummary)
                DuesSummaryCard(report: report)
              else
                _headline(report),
              const SizedBox(height: 12),
              const DuesFilters(),
              if (view.active.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _remindAllButton(view),
                ),
              ],
            ],
          ),
        ),
      ),
    ];
    if (view.isEmpty) {
      slivers.add(SliverToBoxAdapter(child: SizedBox(height: 320, child: _noMatch())));
    } else {
      for (final DueLevel level in kDuesGroupOrder) {
        final List<DuesRow> rows = view.ofLevel(level);
        if (rows.isEmpty) continue;
        slivers.add(_group(DuesGroupHeader.level(level: level, count: rows.length), rows, g));
      }
      if (view.inactive.isNotEmpty) {
        slivers.add(_group(
          DuesGroupHeader.inactive(
            count: view.inactive.length,
            expanded: _showInactive,
            onToggle: _toggleInactive,
          ),
          _showInactive ? view.inactive : const <DuesRow>[],
          g,
          hint: _showInactive ? l10n.duesInactiveHint : null,
        ));
      }
    }
    // Room for the floating navigation pill, plus (on phones) the floating
    // "টাকা নিন" button: 84 lift + 56 height + margin.
    final double tail = WindowClass.of(context).usesRail ? 112 : 168;
    slivers.add(SliverToBoxAdapter(child: SizedBox(key: const ValueKey<String>('dues-list-tail'), height: tail)));
    return CustomScrollView(slivers: slivers);
  }

  Widget _group(Widget header, List<DuesRow> rows, double g, {String? hint}) {
    return SliverMainAxisGroup(
      slivers: <Widget>[
        SliverPersistentHeader(
          pinned: true,
          delegate: DuesGroupHeaderDelegate(child: header),
        ),
        if (hint != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(g, 8, g, 0),
              child: Text(hint, style: context.bhor.type.meta),
            ),
          ),
        if (rows.isNotEmpty)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(g, 8, g, 4),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int i) {
                  final DuesRow r = rows[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: DuesRowTile(
                      key: ValueKey<String>('dues-row-${r.studentId}'),
                      row: r,
                      selected: r.studentId == widget.selectedId,
                      onOpen: () => _open(r.studentId),
                    ),
                  );
                },
                childCount: rows.length,
              ),
            ),
          ),
      ],
    );
  }

  // ---- data table (large windows) --------------------------------------------

  Widget _buildTable(DuesView view, DuesReport report, double g) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final List<DuesRow> rows = <DuesRow>[
      ...view.active,
      if (_showInactive) ...view.inactive,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(g, 4, g, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _headline(report),
              const SizedBox(height: 8),
              const DuesFilters(),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  if (view.active.isNotEmpty) _remindAllButton(view),
                  if (view.inactive.isNotEmpty)
                    BhorChip(
                      key: const ValueKey<String>('dues-toggle-inactive'),
                      icon: Icons.inventory_2_outlined,
                      label:
                          '${l10n.duesInactiveGroup} · ${l10n.duesGroupCount(fmt.number(view.inactive.length))}',
                      selected: _showInactive,
                      onSelected: (bool _) => _toggleInactive(),
                    ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: rows.isEmpty
              ? _noMatch()
              : Padding(
                  padding: EdgeInsets.fromLTRB(g, 0, g, g),
                  child: DuesTable(
                    rows: rows,
                    selectedId: widget.selectedId,
                    onSelect: _open,
                  ),
                ),
        ),
      ],
    );
  }
}
