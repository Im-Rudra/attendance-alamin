// Filter chips of the dues list (UX 2d): সব · মেয়াদোত্তীর্ণ · এ মাসে ·
// [ব্যাচ ▾], plus the month chip the collection summary sets.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/features/dues/controllers/dues_model.dart';
import 'package:attendance_alamin/features/dues/controllers/dues_state.dart';

class DuesFilters extends ConsumerWidget {
  const DuesFilters({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final DuesFilter filter = ref.watch(duesFilterProvider);
    final DuesFilterController ctl = ref.read(duesFilterProvider.notifier);
    final List<Batch> batches = ref.watch(duesBatchesProvider).value ?? const <Batch>[];
    String? batchLabel;
    for (final Batch b in batches) {
      if (b.id == filter.batchId) batchLabel = b.name;
    }
    final bool monthSet = filter.month != null;

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        FilterChip(
          key: const ValueKey<String>('dues-filter-all'),
          label: Text(l10n.duesFilterAll),
          selected: filter.scope == DuesScope.all && !monthSet,
          onSelected: (bool _) {
            ctl.setScope(DuesScope.all);
          },
        ),
        FilterChip(
          key: const ValueKey<String>('dues-filter-overdue'),
          label: Text(l10n.duesFilterOverdue),
          selected: filter.scope == DuesScope.overdue,
          onSelected: (bool _) => ctl.setScope(DuesScope.overdue),
        ),
        FilterChip(
          key: const ValueKey<String>('dues-filter-month'),
          label: Text(l10n.duesFilterThisMonth),
          selected: filter.scope == DuesScope.thisMonth,
          onSelected: (bool _) => ctl.setScope(DuesScope.thisMonth),
        ),
        if (filter.month != null)
          InputChip(
            key: const ValueKey<String>('dues-filter-picked-month'),
            selected: true,
            label: Text(l10n.duesFilterMonth(context.fmt.monthYear(filter.month!))),
            deleteButtonTooltipMessage: l10n.duesFilterClearMonth,
            onDeleted: ctl.clearMonth,
            onPressed: () {},
          ),
        PopupMenuButton<String>(
          key: const ValueKey<String>('dues-filter-batch'),
          tooltip: l10n.duesFilterBatch,
          onSelected: (String id) => ctl.setBatch(id.isEmpty ? null : id),
          itemBuilder: (BuildContext ctx) => <PopupMenuEntry<String>>[
            PopupMenuItem<String>(value: '', child: Text(l10n.commonAll)),
            for (final Batch b in batches) PopupMenuItem<String>(value: b.id, child: Text(b.name)),
          ],
          child: SizedBox(
            height: 48,
            child: Center(
              child: Chip(
                avatar: const Icon(Icons.groups_outlined, size: 18),
                label: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          batchLabel ?? l10n.duesFilterBatch,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
