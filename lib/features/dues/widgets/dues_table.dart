// The dues data table of large windows (UX 3b): নাম · ব্যাচ · মাস · পরিমাণ ·
// অবস্থা · মনে করানো · actions, severity sorted, on `surfaceDense` with a
// sticky header. The grey group follows the active rows when it is expanded.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/services/contact_actions.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/features/dues/controllers/dues_model.dart';
import 'package:attendance_alamin/features/dues/controllers/dues_state.dart';
import 'package:attendance_alamin/features/dues/widgets/dues_row.dart';

class DuesTable extends ConsumerWidget {
  const DuesTable({
    super.key,
    required this.rows,
    required this.selectedId,
    required this.onSelect,
  });

  final List<DuesRow> rows;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  /// The batch and months columns need room; below this width they are left
  /// out.
  static const double wideColumnsFrom = 760;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.aurora;
    final l10n = context.l10n;
    final fmt = context.fmt;
    final TextTheme tt = Theme.of(context).textTheme;
    final Set<String> reminded = ref.watch(duesRemindedProvider).value ?? const <String>{};
    final int year = ref.watch(todayProvider).year;
    DuesRow? selected;
    for (final DuesRow r in rows) {
      if (r.studentId == selectedId) selected = r;
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final bool extras = c.maxWidth >= wideColumnsFrom;
        final List<DenseColumn<DuesRow>> columns = <DenseColumn<DuesRow>>[
          DenseColumn<DuesRow>(
            label: l10n.duesColName,
            flex: 3,
            cell: (DuesRow r) => SizedBox(
              width: double.infinity,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onSecondaryTapUp: (TapUpDetails d) =>
                    showDuesContextMenu(context, ref, d.globalPosition, r),
                child: Text(
                  r.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodyMedium?.copyWith(color: tokens.textPrimary),
                ),
              ),
            ),
          ),
          if (extras)
            DenseColumn<DuesRow>(
              label: l10n.duesColBatch,
              flex: 2,
              cell: (DuesRow r) => Text(
                r.batchNames.join(', '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.bodyMedium?.copyWith(color: tokens.textSecondary),
              ),
            ),
          if (extras)
            DenseColumn<DuesRow>(
              label: l10n.duesColMonths,
              flex: 2,
              cell: (DuesRow r) => Text(
                duesMonthsText(context, r, year),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.bodyMedium?.copyWith(color: tokens.textSecondary),
              ),
            ),
          DenseColumn<DuesRow>(
            label: l10n.duesColAmount,
            flex: 2,
            numeric: true,
            cell: (DuesRow r) => Text(
              fmt.money(r.total),
              maxLines: 1,
              style: tt.bodyMedium?.copyWith(
                color: r.inactive ? tokens.textSecondary : tokens.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          DenseColumn<DuesRow>(
            label: l10n.duesColStatus,
            flex: 3,
            cell: (DuesRow r) => FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: DuesStatusBadge(row: r, compact: true),
            ),
          ),
          if (extras)
            DenseColumn<DuesRow>(
              label: l10n.duesColReminded,
              flex: 1,
              cell: (DuesRow r) => reminded.contains(r.studentId)
                  ? Tooltip(
                      message: l10n.duesRemindedToday,
                      child: Icon(Icons.check_circle_outline, size: 20, color: tokens.accent),
                    )
                  : Text('—', style: tt.bodyMedium?.copyWith(color: tokens.textDisabled)),
            ),
          DenseColumn<DuesRow>(
            label: l10n.duesColActions,
            flex: 3,
            cell: (DuesRow r) => FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    tooltip: ContactActions.label(l10n),
                    icon: Icon(ContactActions.icon, size: 20),
                    onPressed: () => duesCall(context, ref, r.studentId),
                  ),
                  IconButton(
                    tooltip: reminded.contains(r.studentId)
                        ? l10n.duesRemindedToday
                        : l10n.duesRemind,
                    icon: Icon(reminded.contains(r.studentId) ? Icons.check : Icons.share, size: 20),
                    onPressed: () => duesRemind(context, r.studentId),
                  ),
                  IconButton(
                    tooltip: l10n.duesCollect,
                    icon: const Icon(Icons.payments_outlined, size: 20),
                    onPressed: () => duesCollect(context, r.studentId),
                  ),
                ],
              ),
            ),
          ),
        ];
        return DenseTable<DuesRow>(
          columns: columns,
          rows: rows,
          selected: selected,
          onRowTap: (DuesRow r) => onSelect(r.studentId),
        );
      },
    );
  }
}
