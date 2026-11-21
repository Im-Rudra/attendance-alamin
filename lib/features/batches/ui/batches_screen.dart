// Batches tab: batch cards grouped by subject (collapsible headers). Wide
// windows show list ‖ detail (‖ context at ≥ 1200) through PaneSplit; with no
// selection the detail pane is a useful overview, never a blank area.

import 'package:flutter/material.dart' show Icons;
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
          : BatchDetailScreen(key: ValueKey<String>(id), batchId: id),
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

  void _new() => context.push(Routes.batchNew);

  Future<void> _menu(BatchCardData d, Offset at) async {
    final l10n = context.l10n;
    final String? choice = await showBhorSheet<String>(
      context,
      title: d.batch.name,
      builder: (BuildContext ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          BhorListRow(title: l10n.batchMenuOpen, onTap: () => Navigator.of(ctx).pop('open')),
          BhorListRow(title: l10n.commonEdit, onTap: () => Navigator.of(ctx).pop('edit')),
          BhorListRow(
            title: l10n.batchMenuArchive,
            divider: false,
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
        context.push(Routes.batchEdit(d.batch.id));
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
        icon: Icons.error_outline,
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
              icon: Icons.groups_outlined,
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
            return ListView(
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
                              child: BatchCard(
                                data: d,
                                selected: d.batch.id == widget.selectedId,
                                onTap: () => openPath(context, Routes.batch(d.batch.id)),
                                onSecondaryTap: (Offset at) => _menu(d, at),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ],
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
            actions: <Widget>[
              BhorIconButton(
                icon: Icons.search,
                semanticLabel: l10n.commonSearch,
                onPressed: () => context.push(Routes.search),
              ),
            ],
          ),
          floating: empty
              ? null
              : Padding(
                  padding: EdgeInsets.only(bottom: wc.usesRail ? 0 : 84),
                  child: BhorButton(icon: Icons.add, label: l10n.batchNew, onPressed: _new),
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
              Icon(collapsed ? Icons.chevron_right : Icons.expand_more, color: b.colors.text2),
              const SizedBox(width: BhorSpace.s4),
              Expanded(
                child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: b.type.heading),
              ),
              Text(
                context.l10n.batchGroupCount(context.fmt.number(count)),
                style: b.type.label.copyWith(color: b.colors.text2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
