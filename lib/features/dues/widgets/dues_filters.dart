// Filter chips of the dues list (UX 2d): সব · মেয়াদোত্তীর্ণ · এ মাসে ·
// [ব্যাচ ▾], plus the month chip the collection summary sets.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
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
    final bool monthSet = filter.month != null;

    // One scrolling line (chips + batch select) instead of a wrapping block.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          BhorChip(
            key: const ValueKey<String>('dues-filter-all'),
            label: l10n.duesFilterAll,
            selected: filter.scope == DuesScope.all && !monthSet,
            onSelected: (bool _) {
              ctl.setScope(DuesScope.all);
            },
          ),
          const SizedBox(width: BhorSpace.s8),
          BhorChip(
            key: const ValueKey<String>('dues-filter-overdue'),
            label: l10n.duesFilterOverdue,
            selected: filter.scope == DuesScope.overdue,
            onSelected: (bool _) => ctl.setScope(DuesScope.overdue),
          ),
          const SizedBox(width: BhorSpace.s8),
          BhorChip(
            key: const ValueKey<String>('dues-filter-month'),
            label: l10n.duesFilterThisMonth,
            selected: filter.scope == DuesScope.thisMonth,
            onSelected: (bool _) => ctl.setScope(DuesScope.thisMonth),
          ),
          if (filter.month != null) ...<Widget>[
            const SizedBox(width: BhorSpace.s8),
            BhorTooltip(
              message: l10n.duesFilterClearMonth,
              child: BhorChip(
                key: const ValueKey<String>('dues-filter-picked-month'),
                label: l10n.duesFilterMonth(context.fmt.monthYear(filter.month!)),
                selected: true,
                onSelected: (bool _) => ctl.clearMonth(),
              ),
            ),
          ],
          const SizedBox(width: BhorSpace.s8),
          SizedBox(
            width: 168,
            child: BhorSelect<String>(
              key: const ValueKey<String>('dues-filter-batch'),
              semanticLabel: l10n.duesFilterBatch,
              hint: l10n.duesFilterBatch,
              value: filter.batchId ?? '',
              options: <BhorOption<String>>[
                BhorOption<String>('', l10n.commonAll, icon: BhorIcons.batches),
                for (final Batch b in batches) BhorOption<String>(b.id, b.name, icon: BhorIcons.batches),
              ],
              onChanged: (String id) => ctl.setBatch(id.isEmpty ? null : id),
            ),
          ),
        ],
      ),
    );
  }
}
