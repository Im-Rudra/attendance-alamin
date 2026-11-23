// Batches tab: batch cards grouped by subject (collapsible headers), then the
// private tuitions as one group (item 1); "New…" makes a batch or a tuition. Wide
// windows use BhorMasterDetailPage (list 360 | detail, the context rail only
// as a 4th column >= 1600); with no selection the detail pane is a compact
// overview, never a blank area. The global search lives in the shell (no
// search button of its own here).

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/pane_split.dart';
import 'package:attendance_alamin/app/shell/templates/templates.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/data/repositories/place_providers.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/features/batches/batches_entry.dart';
import 'package:attendance_alamin/features/batches/controllers/batch_providers.dart';
import 'package:attendance_alamin/features/batches/ui/batch_detail_screen.dart';
import 'package:attendance_alamin/features/batches/ui/batch_form_screen.dart';
import 'package:attendance_alamin/features/batches/widgets/batch_card.dart';
import 'package:attendance_alamin/features/batches/widgets/batch_format.dart';
import 'package:attendance_alamin/features/batches/widgets/batch_overview.dart';
import 'package:attendance_alamin/features/settings/settings_entry.dart';

class BatchesScreen extends StatelessWidget {
  const BatchesScreen({super.key, this.selectedId});

  /// Batch shown in the detail pane on wide windows.
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final Widget list = _BatchesList(selectedId: selectedId);
    if (!WindowClass.of(context).isWide) return list;
    final String? id = selectedId;
    // Master-detail template: the rail (dues by level + attendance trend) is a
    // 4th column only >= 1600; below that the detail folds it into its
    // overview (review B1).
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final bool twoPane = BhorMasterDetailPage.twoPane(box.maxWidth);
        Widget? detail;
        if (id != null) {
          final Widget d = BhorPaneSwitcher(
            paneKey: id,
            child: BatchDetailScreen(key: ValueKey<String>(id), batchId: id),
          );
          // Beside the list the window owns navigation (no back arrow); alone
          // the detail keeps its own back arrow.
          detail = twoPane ? PaneScope(child: d) : d;
        }
        return BhorMasterDetailPage(
          master: PaneScope(child: list),
          detail: detail,
          emptyDetail: const PaneScope(child: BatchesOverview()),
          rail: id == null ? null : BatchContextPane(batchId: id),
        );
      },
    );
  }
}

class _BatchesList extends ConsumerStatefulWidget {
  const _BatchesList({required this.selectedId});

  final String? selectedId;

  @override
  ConsumerState<_BatchesList> createState() => _BatchesListState();
}

class _BatchesListState extends ConsumerState<_BatchesList> {
  final Set<String> _collapsed = <String>{};

  Future<void> _new([BatchKind kind = BatchKind.batch]) async {
    final Object? r = await showBatchFormPanel(context, kind: kind);
    if (!mounted || r is! String) return;
    openPath(context, Routes.batch(r));
  }

  /// "New…": a batch or a private tuition.
  void _newMenu(BuildContext anchor) {
    final l10n = context.l10n;
    showBhorMenu(
      anchor,
      anchor: anchor,
      items: <BhorMenuItem>[
        BhorMenuItem(
          key: const ValueKey<String>('menu-new-batch'),
          icon: BhorIcons.batches,
          label: l10n.batchNew,
          onTap: () => _new(),
        ),
        BhorMenuItem(
          key: const ValueKey<String>('menu-new-tuition'),
          icon: BhorIcons.students,
          label: l10n.batchNewTuition,
          onTap: () => _new(BatchKind.tuition),
        ),
      ],
    );
  }

  Future<void> _menu(BatchCardData d, Offset at, BuildContext anchor) async {
    final l10n = context.l10n;
    await showBhorMenu(
      context,
      anchor: anchor,
      items: <BhorMenuItem>[
        BhorMenuItem(
          icon: BhorIcons.batches,
          label: l10n.batchMenuOpen,
          onTap: () => openPath(context, Routes.batch(d.batch.id)),
        ),
        BhorMenuItem(
          icon: BhorIcons.edit,
          label: l10n.commonEdit,
          onTap: () => showBatchFormPanel(context, batchId: d.batch.id, kind: d.batch.kind),
        ),
        BhorMenuItem(
          icon: BhorIcons.archive,
          label: d.batch.isTuition ? l10n.batchMenuArchiveTuition : l10n.batchMenuArchive,
          onTap: () => showArchiveBatchDialog(context, batchId: d.batch.id),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final WindowClass wc = WindowClass.of(context);
    final double g = wc.gutter;
    final AsyncValue<List<SubjectGroup>> async = ref.watch(batchGroupsProvider);
    final List<SubjectGroup>? groups = async.value;
    final bool empty = groups != null && groups.isEmpty;
    final bool many = ref.watch(hasManyPlacesProvider);

    final Widget body = async.when(
      loading: () => const Center(child: BhorSpinner()),
      error: (Object e, StackTrace s) => BhorEmptyState(
        icon: BhorIcons.warning,
        title: l10n.commonLoadingFailed,
        action: BhorButton(
          label: l10n.commonRetry,
          variant: BhorButtonVariant.secondary,
          onPressed: () => ref.invalidate(batchGroupsProvider),
        ),
      ),
      data: (List<SubjectGroup> loaded) {
        if (loaded.isEmpty) {
          return BhorCard(
            padding: EdgeInsets.zero,
            child: BhorEmptyState(
              icon: BhorIcons.batches,
              title: l10n.batchEmptyList,
              action: Wrap(
                alignment: WrapAlignment.center,
                spacing: BhorSpace.s8,
                runSpacing: BhorSpace.s8,
                children: <Widget>[
                  BhorButton(label: l10n.batchNew, onPressed: _new),
                  BhorButton(
                    key: const ValueKey<String>('batches-new-tuition'),
                    label: l10n.batchNewTuition,
                    variant: BhorButtonVariant.secondary,
                    onPressed: () => _new(BatchKind.tuition),
                  ),
                ],
              ),
            ),
          );
        }
        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            final int cols = c.maxWidth >= 560 ? 2 : 1;
            const double gap = BhorSpace.s12;
            final double w = (c.maxWidth - gap * (cols - 1)) / cols;
            int staggerAt = 0;
            return BhorStaggerScope(
              child: ListView(
              padding: EdgeInsets.only(bottom: wc.usesRail ? 96 : 168),
              children: <Widget>[
                for (final SubjectGroup grp in loaded) ...<Widget>[
                  _GroupHeader(
                    name: grp.tuitions ? l10n.batchGroupTuitions : grp.name,
                    count: grp.batches.length,
                    collapsed: _collapsed.contains(grp.subjectId),
                    onToggle: () => setState(() {
                      if (!_collapsed.remove(grp.subjectId)) _collapsed.add(grp.subjectId);
                    }),
                  ),
                  if (!_collapsed.contains(grp.subjectId))
                    Padding(
                      padding: const EdgeInsets.only(bottom: BhorSpace.s8),
                      child: Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: <Widget>[
                          for (final BatchCardData d in grp.batches)
                            SizedBox(
                              width: w,
                              child: BhorStagger(
                                index: staggerAt++,
                                child: Builder(
                                  builder: (BuildContext cardContext) => BatchCard(
                                    data: d,
                                    selected: d.batch.id == widget.selectedId,
                                    onTap: () => openPath(context, Routes.batch(d.batch.id)),
                                    onSecondaryTap: (Offset at) => _menu(d, at, cardContext),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ],
              ),
            );
          },
        );
      },
    );

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): _new,
      },
      child: Focus(
        autofocus: wc.isWide,
        child: BhorScaffold(
          header: BhorHeader(
            title: l10n.navBatches,
            large: true,
            showBack: false,
            actions: <Widget>[
              if (wc.usesRail && !empty)
                Builder(
                  builder: (BuildContext bc) => BhorButton(
                    key: const ValueKey<String>('batches-new-menu'),
                    icon: BhorIcons.add,
                    label: l10n.batchNewMenu,
                    size: BhorButtonSize.sm,
                    onPressed: () => _newMenu(bc),
                  ),
                ),
            ],
          ),
          floating: (empty || wc.usesRail)
              ? null
              : Padding(
                  padding: EdgeInsets.only(bottom: wc.usesRail ? 0 : 84),
                  child: Builder(
                    builder: (BuildContext bc) => BhorButton(
                      key: const ValueKey<String>('batches-new-menu'),
                      icon: BhorIcons.add,
                      label: l10n.batchNewMenu,
                      onPressed: () => _newMenu(bc),
                    ),
                  ),
                ),
          body: Padding(
            padding: EdgeInsets.fromLTRB(g, BhorSpace.s4, g, 0),
            // 2+ places: the place filter leads the list (the list pane is
            // too narrow on desktop for it beside the title and New).
            child: many
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const Align(alignment: AlignmentDirectional.centerStart, child: PlaceFilterChip()),
                      const SizedBox(height: BhorSpace.s8),
                      Expanded(child: body),
                    ],
                  )
                : body,
          ),
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.name,
    required this.count,
    required this.collapsed,
    required this.onToggle,
  });

  final String name;
  final int count;
  final bool collapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    return Semantics(
      header: true,
      expanded: !collapsed,
      child: BhorPressable(
        onTap: onToggle,
        semanticLabel: name,
        builder: (BuildContext c, BhorStates st) => ConstrainedBox(
          constraints: const BoxConstraints(minHeight: BhorSize.phoneRow),
          child: Row(
            children: <Widget>[
              AnimatedRotation(
                turns: collapsed ? -0.25 : 0,
                duration: BhorMotion.of(context, BhorMotion.fast),
                curve: BhorMotion.curveOf(context, BhorMotion.spring),
                child: Icon(BhorIcons.chevronDown, size: BhorIconSize.chip, color: b.colors.text2),
              ),
              const SizedBox(width: BhorSpace.s8),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: b.type.label.copyWith(color: b.colors.text2),
                ),
              ),
              Text(
                context.l10n.groupCountText(count, context.fmt.number(count)),
                style: b.type.label.copyWith(color: b.colors.text3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
