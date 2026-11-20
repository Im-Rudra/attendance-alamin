// Batches tab: batch cards grouped by subject (collapsible headers). Wide
// windows show list ‖ detail (‖ context at ≥ 1200) through PaneSplit; with no
// selection the detail pane is a useful overview, never a blank area.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/pane_split.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
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
    final RelativeRect position = RelativeRect.fromLTRB(at.dx, at.dy, at.dx, at.dy);
    final String? choice = await showMenu<String>(
      context: context,
      position: position,
      items: <PopupMenuEntry<String>>[
        PopupMenuItem<String>(value: 'open', child: Text(l10n.batchMenuOpen)),
        PopupMenuItem<String>(value: 'edit', child: Text(l10n.commonEdit)),
        PopupMenuItem<String>(value: 'archive', child: Text(l10n.batchMenuArchive)),
      ],
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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object e, StackTrace s) => EmptyState(
        icon: Icons.error_outline,
        message: l10n.commonLoadingFailed,
        actionLabel: l10n.commonRetry,
        onAction: () => ref.invalidate(batchGroupsProvider),
      ),
      data: (List<SubjectGroup> loaded) {
        if (loaded.isEmpty) {
          return GlassCard(
            padding: EdgeInsets.zero,
            child: EmptyState(
              icon: Icons.groups_outlined,
              message: l10n.batchEmptyList,
              actionLabel: l10n.batchNew,
              onAction: _new,
            ),
          );
        }
        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            final int cols = c.maxWidth >= 560 ? 2 : 1;
            const double gap = 12;
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
                      padding: const EdgeInsets.only(bottom: 8),
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
        child: Scaffold(
          appBar: AppBar(
            title: Semantics(header: true, child: Text(l10n.navBatches)),
            actions: <Widget>[
              IconButton(
                tooltip: l10n.commonSearch,
                icon: const Icon(Icons.search),
                onPressed: () => context.push(Routes.search),
              ),
              const SizedBox(width: 8),
            ],
          ),
          floatingActionButton: empty
              ? null
              : Padding(
                  padding: EdgeInsets.only(bottom: wc.usesRail ? 0 : 84),
                  child: FloatingActionButton.extended(
                    heroTag: null,
                    onPressed: _new,
                    icon: const Icon(Icons.add),
                    label: Text(l10n.batchNew),
                  ),
                ),
          body: SafeArea(
            top: false,
            child: Padding(padding: EdgeInsets.fromLTRB(g, 4, g, 0), child: body),
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
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    return Semantics(
      header: true,
      button: true,
      expanded: !collapsed,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: <Widget>[
              Icon(collapsed ? Icons.chevron_right : Icons.expand_more, color: tokens.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.titleMedium?.copyWith(color: tokens.textPrimary),
                ),
              ),
              Text(
                context.l10n.batchGroupCount(context.fmt.number(count)),
                style: tt.labelMedium?.copyWith(color: tokens.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
