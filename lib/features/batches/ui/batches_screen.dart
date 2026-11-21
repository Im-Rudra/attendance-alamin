// Batches tab: batch cards grouped by subject (collapsible headers). Wide
// windows show list ‖ detail (‖ context at ≥ 1200) through PaneSplit; with no
// selection the detail pane is a useful overview, never a blank area.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/pane_split.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/features/batches/batches_entry.dart';
import 'package:attendance_alamin/features/batches/controllers/batch_providers.dart';
import 'package:attendance_alamin/features/batches/ui/batch_detail_screen.dart';
import 'package:attendance_alamin/features/batches/ui/batch_form_screen.dart';
import 'package:attendance_alamin/features/batches/widgets/batch_card.dart';
import 'package:attendance_alamin/features/batches/widgets/batch_format.dart';
import 'package:attendance_alamin/features/batches/widgets/batch_overview.dart';

class BatchesScreen extends StatelessWidget {
  const BatchesScreen({super.key, this.selectedId});

  /// Batch shown in the detail pane on wide windows.
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final Widget list = _BatchesList(selectedId: selectedId);
    if (!WindowClass.of(context).isWide) return list;
    final String? id = selectedId;
    return PaneSplit(
      screen: 'batches',
      list: list,
      preferList: id == null,
      detail: id == null
          ? const BatchesOverview()
          : BhorPaneSwitcher(
              paneKey: id,
              child: BatchDetailScreen(key: ValueKey<String>(id), batchId: id),
            ),
      contextPane: id == null ? null : BatchContextPane(batchId: id),
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

  Future<void> _new() async {
    final Object? r = await showBatchFormPanel(context);
    if (!mounted || r is! String) return;
    openPath(context, Routes.batch(r));
  }

  Future<void> _menu(BatchCardData d, Offset at, BuildContext anchor) async {
    final l10n = context.l10n;
    final String? choice = await showBhorPanel<String>(
      context,
      kind: BhorPanelKind.list,
      anchor: anchor,
      width: 320,
      title: d.batch.name,
      builder: (BuildContext ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          BatchMenuRow(
            icon: BhorIcons.batches,
            label: l10n.batchMenuOpen,
            onTap: () => Navigator.of(ctx).pop('open'),
          ),
          BatchMenuRow(
            icon: BhorIcons.edit,
            label: l10n.commonEdit,
            onTap: () => Navigator.of(ctx).pop('edit'),
          ),
          BatchMenuRow(
            icon: BhorIcons.archive,
            label: l10n.batchMenuArchive,
            onTap: () => Navigator.of(ctx).pop('archive'),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'open':
        openPath(context, Routes.batch(d.batch.id));
      case 'edit':
        await showBatchFormPanel(context, batchId: d.batch.id);
      case 'archive':
        await showArchiveBatchDialog(context, batchId: d.batch.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final WindowClass wc = WindowClass.of(context);
    final double g = wc.gutter;
    final AsyncValue<List<SubjectGroup>> async = ref.watch(batchGroupsProvider);
    final List<SubjectGroup>? groups = async.value;
    final bool empty = groups != null && groups.isEmpty;

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
              action: BhorButton(label: l10n.batchNew, onPressed: _new),
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
                    name: grp.name,
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
                BhorButton(
                  icon: BhorIcons.add,
                  label: l10n.batchNew,
                  size: BhorButtonSize.sm,
                  onPressed: _new,
                ),
              BhorIconButton(
                icon: BhorIcons.search,
                semanticLabel: l10n.commonSearch,
                onPressed: () => context.push(Routes.search),
              ),
            ],
          ),
          floating: (empty || wc.usesRail)
              ? null
              : Padding(
                  padding: EdgeInsets.only(bottom: wc.usesRail ? 0 : 84),
                  child: BhorButton(icon: BhorIcons.add, label: l10n.batchNew, onPressed: _new),
                ),
          body: Padding(padding: EdgeInsets.fromLTRB(g, BhorSpace.s4, g, 0), child: body),
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
                context.l10n.batchGroupCount(context.fmt.number(count)),
                style: b.type.label.copyWith(color: b.colors.text3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
