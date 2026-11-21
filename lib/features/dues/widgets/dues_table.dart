// The dues data table of large windows (UX 3b): নাম · ব্যাচ · মাস · পরিমাণ ·
// অবস্থা · মনে করানো · actions, severity sorted, on a card with a sticky
// header. The grey group follows the active rows when it is expanded.

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/services/contact_actions.dart';
import 'package:attendance_alamin/features/dues/controllers/dues_model.dart';
import 'package:attendance_alamin/features/dues/controllers/dues_state.dart';
import 'package:attendance_alamin/features/dues/widgets/dues_row.dart';

/// One column of the table: header label, flex, cell builder.
class _Col {
  const _Col({required this.label, required this.cell, this.flex = 1, this.numeric = false});

  final String label;
  final Widget Function(DuesRow row) cell;
  final int flex;
  final bool numeric;
}

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

  static const double _rowHeight = 48;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final l10n = context.l10n;
    final Set<String> reminded = ref.watch(duesRemindedProvider).value ?? const <String>{};
    final int year = ref.watch(todayProvider).year;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final bool extras = box.maxWidth >= wideColumnsFrom;
        final List<_Col> columns = <_Col>[
          _Col(
            label: l10n.duesColName,
            flex: 3,
            cell: (DuesRow r) => SizedBox(
              width: double.infinity,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onSecondaryTapUp: (TapUpDetails d) =>
                    showDuesContextMenu(context, ref, d.globalPosition, r),
                child: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: b.type.body),
              ),
            ),
          ),
          if (extras)
            _Col(
              label: l10n.duesColBatch,
              flex: 2,
              cell: (DuesRow r) => Text(
                r.batchNames.join(', '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: b.type.body.copyWith(color: c.text2),
              ),
            ),
          if (extras)
            _Col(
              label: l10n.duesColMonths,
              flex: 2,
              cell: (DuesRow r) => Text(
                duesMonthsText(context, r, year),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: b.type.body.copyWith(color: c.text2),
              ),
            ),
          _Col(
            label: l10n.duesColAmount,
            flex: 2,
            numeric: true,
            cell: (DuesRow r) => BhorMoney(
              r.total,
              style: b.type.bodyStrong,
              color: r.inactive ? c.text2 : null,
            ),
          ),
          _Col(
            label: l10n.duesColStatus,
            flex: 3,
            cell: (DuesRow r) => FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: DuesStatusBadge(row: r, compact: true),
            ),
          ),
          if (extras)
            _Col(
              label: l10n.duesColReminded,
              flex: 1,
              cell: (DuesRow r) => reminded.contains(r.studentId)
                  ? BhorTooltip(
                      message: l10n.duesRemindedToday,
                      child: Icon(Icons.check_circle_outline, size: 20, color: c.accent),
                    )
                  : Text('—', style: b.type.body.copyWith(color: c.text3)),
            ),
          _Col(
            label: l10n.duesColActions,
            flex: 3,
            cell: (DuesRow r) => FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  BhorIconButton(
                    icon: ContactActions.icon,
                    semanticLabel: ContactActions.label(l10n),
                    onPressed: () => duesCall(context, ref, r.studentId),
                  ),
                  BhorIconButton(
                    icon: reminded.contains(r.studentId) ? Icons.check : Icons.share,
                    semanticLabel:
                        reminded.contains(r.studentId) ? l10n.duesRemindedToday : l10n.duesRemind,
                    onPressed: () => duesRemind(context, r.studentId),
                  ),
                  BhorIconButton(
                    icon: Icons.payments_outlined,
                    semanticLabel: l10n.duesCollect,
                    onPressed: () => duesCollect(context, r.studentId),
                  ),
                ],
              ),
            ),
          ),
        ];

        Widget cells(DuesRow? row) => Row(
              children: <Widget>[
                for (final _Col col in columns)
                  Expanded(
                    flex: col.flex,
                    child: row == null
                        ? Semantics(
                            header: true,
                            child: Text(
                              col.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: col.numeric ? TextAlign.end : TextAlign.start,
                              style: b.type.label.copyWith(color: c.text2),
                            ),
                          )
                        : Align(
                            alignment: col.numeric
                                ? AlignmentDirectional.centerEnd
                                : AlignmentDirectional.centerStart,
                            child: col.cell(row),
                          ),
                  ),
              ],
            );

        final Widget list = ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: rows.length,
          itemBuilder: (BuildContext context, int i) {
            final DuesRow r = rows[i];
            final bool selected = r.studentId == selectedId;
            return BhorPressable(
              onTap: () => onSelect(r.studentId),
              semanticLabel: r.name,
              selected: selected,
              scaleOnPress: false,
              radius: 0,
              builder: (BuildContext context, BhorStates s) => Container(
                constraints: const BoxConstraints(minHeight: _rowHeight),
                padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s16),
                decoration: BoxDecoration(
                  color: selected ? c.accentTint : (s.hovered ? c.surface2 : null),
                  border: Border(bottom: BorderSide(color: c.line)),
                ),
                child: cells(r),
              ),
            );
          },
        );

        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(BhorRadius.card),
            border: Border.all(color: c.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(
                constraints: const BoxConstraints(minHeight: _rowHeight),
                padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s16),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
                alignment: Alignment.centerLeft,
                child: cells(null),
              ),
              Expanded(child: list),
            ],
          ),
        );
      },
    );
  }
}
