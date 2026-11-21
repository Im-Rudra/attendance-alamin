// The dues list: on phones the summary card (with "remind everyone"), one
// scrolling filter line, then sticky severity groups (overdue first) of rows
// in list cards and the collapsed grey "ছেড়ে যাওয়া / আর্কাইভ" group. On wide
// windows the three summary tiles lead, the filter line carries the "remind
// everyone" button, and each row opens the payment side panel.

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
import 'package:attendance_alamin/features/dues/widgets/reminder_walkthrough.dart';

class DuesListPane extends ConsumerStatefulWidget {
  const DuesListPane({
    super.key,
    this.selectedId,
    this.showSummary = true,
  });

  /// Student whose payment panel is open (wide windows).
  final String? selectedId;

  /// Show the summary card above the filters (phones and mediums); wide
  /// windows show the three summary tiles instead.
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
      BhorToast.show(context, message: context.l10n.duesWalkNobody);
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
      loading: () => const _DuesSkeleton(),
      error: (Object e, StackTrace s) =>
          BhorEmptyState(icon: BhorIcons.warning, title: l10n.commonLoadingFailed),
      data: (DuesView view) {
        if (report == null) return const _DuesSkeleton();
        if (report.active.isEmpty && report.inactive.isEmpty) {
          return const DuesEmptyState();
        }
        return _buildList(view, report, g);
      },
    );
  }

  Widget _remindAllButton(DuesView view) {
    return BhorButton(
      key: const ValueKey<String>('dues-remind-all'),
      variant: BhorButtonVariant.tonal,
      size: BhorButtonSize.sm,
      icon: BhorIcons.bell,
      label: context.l10n.duesRemindAll,
      onPressed: () => _remindAll(view.active),
    );
  }

  Widget _noMatch() {
    final l10n = context.l10n;
    return BhorEmptyState(
      icon: BhorIcons.filter,
      title: l10n.duesNoMatch,
      action: BhorButton(
        label: l10n.duesShowAll,
        variant: BhorButtonVariant.secondary,
        onPressed: () => ref.read(duesFilterProvider.notifier).reset(),
      ),
    );
  }

  Widget _buildList(DuesView view, DuesReport report, double g) {
    final l10n = context.l10n;
    final bool wide = WindowClass.of(context).isWide;
    final Widget? remind = view.active.isEmpty ? null : _remindAllButton(view);
    final List<Widget> slivers = <Widget>[
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(g, BhorSpace.s4, g, BhorSpace.s8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (wide)
                const FeesSummaryTiles()
              else if (widget.showSummary)
                DuesSummaryCard(report: report, action: remind),
              const SizedBox(height: BhorSpace.s12),
              if (wide && remind != null)
                Row(
                  children: <Widget>[
                    const Expanded(child: DuesFilters()),
                    const SizedBox(width: BhorSpace.s12),
                    remind,
                  ],
                )
              else
                const DuesFilters(),
            ],
          ),
        ),
      ),
    ];
    int stagger = 0;
    if (view.isEmpty) {
      slivers.add(SliverToBoxAdapter(child: SizedBox(height: 320, child: _noMatch())));
    } else {
      for (final DueLevel level in kDuesGroupOrder) {
        final List<DuesRow> rows = view.ofLevel(level);
        if (rows.isEmpty) continue;
        slivers.add(_group(DuesGroupHeader.level(level: level, count: rows.length), rows, g, stagger));
        stagger += rows.length;
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
          stagger,
          hint: _showInactive ? l10n.duesInactiveHint : null,
        ));
      }
    }
    // Room for the floating navigation pill, plus (on phones) the floating
    // "টাকা নিন" button: 84 lift + 56 height + margin.
    final double tail = WindowClass.of(context).usesRail ? 112 : 168;
    slivers.add(SliverToBoxAdapter(child: SizedBox(key: const ValueKey<String>('dues-list-tail'), height: tail)));
    return BhorStaggerScope(child: CustomScrollView(slivers: slivers));
  }

  Widget _group(Widget header, List<DuesRow> rows, double g, int offset, {String? hint}) {
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
            padding: EdgeInsets.fromLTRB(g, BhorSpace.s8, g, BhorSpace.s4),
            sliver: SliverToBoxAdapter(
              child: BhorList(
                children: <Widget>[
                  for (int i = 0; i < rows.length; i++)
                    BhorStagger(
                      key: ValueKey<String>('dues-stagger-${rows[i].studentId}'),
                      index: offset + i,
                      child: DuesRowTile(
                        key: ValueKey<String>('dues-row-${rows[i].studentId}'),
                        row: rows[i],
                        selected: rows[i].studentId == widget.selectedId,
                        divider: i < rows.length - 1,
                        onOpen: () => _open(rows[i].studentId),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Placeholder rows with the real row height while the dues load.
class _DuesSkeleton extends StatelessWidget {
  const _DuesSkeleton();

  @override
  Widget build(BuildContext context) {
    final double g = WindowClass.of(context).gutter;
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(g, BhorSpace.s8, g, g),
      children: <Widget>[
        const BhorSkeleton(height: 120, radius: BhorRadius.card),
        const SizedBox(height: BhorSpace.s16),
        for (int i = 0; i < 4; i++) ...<Widget>[
          const BhorSkeleton(height: 72, radius: BhorRadius.card),
          const SizedBox(height: BhorSpace.s8),
        ],
      ],
    );
  }
}
