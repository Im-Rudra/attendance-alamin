// Dense data table for wide layouts (UX 3b rule 2): sticky header, 48dp rows,
// fills its pane (header fixed, rows scroll). On `surfaceDense`.

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/theme/theme_x.dart';

class DenseColumn<T> {
  const DenseColumn({
    required this.label,
    required this.cell,
    this.flex = 1,
    this.numeric = false,
  });

  final String label;
  final Widget Function(T row) cell;
  final int flex;

  /// Right-aligned (money, counts).
  final bool numeric;
}

class DenseTable<T> extends StatelessWidget {
  const DenseTable({
    super.key,
    required this.columns,
    required this.rows,
    this.onRowTap,
    this.selected,
  });

  final List<DenseColumn<T>> columns;
  final List<T> rows;
  final ValueChanged<T>? onRowTap;
  final T? selected;

  static const double rowHeight = 48;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final BorderRadius br = BorderRadius.circular(AuroraMetrics.radiusDenseList);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final bool bounded = c.hasBoundedHeight;
        final Widget list = ListView.builder(
          shrinkWrap: !bounded,
          physics: bounded ? null : const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: rows.length,
          itemBuilder: (BuildContext context, int i) {
            final T row = rows[i];
            return _DenseRow<T>(
              columns: columns,
              row: row,
              selected: selected != null && row == selected,
              onTap: onRowTap == null ? null : () => onRowTap!(row),
            );
          },
        );
        return ClipRRect(
          borderRadius: br,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.surfaceDense,
              borderRadius: br,
              border: Border.all(color: tokens.hairline),
            ),
            child: Column(
              mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _DenseHeader<T>(columns: columns),
                if (bounded) Expanded(child: list) else list,
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DenseHeader<T> extends StatelessWidget {
  const _DenseHeader({required this.columns});

  final List<DenseColumn<T>> columns;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final TextStyle? style = Theme.of(context)
        .textTheme
        .labelMedium
        ?.copyWith(color: tokens.textSecondary, fontWeight: FontWeight.w600);
    return DecoratedBox(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: tokens.hairline))),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: DenseTable.rowHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: <Widget>[
              for (final DenseColumn<T> col in columns)
                Expanded(
                  flex: col.flex,
                  child: Semantics(
                    header: true,
                    child: Text(
                      col.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: col.numeric ? TextAlign.end : TextAlign.start,
                      style: style,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DenseRow<T> extends StatelessWidget {
  const _DenseRow({
    required this.columns,
    required this.row,
    required this.selected,
    required this.onTap,
  });

  final List<DenseColumn<T>> columns;
  final T row;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    return Semantics(
      selected: selected,
      container: true,
      child: Material(
        color: selected ? tokens.accentContainer : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          hoverColor: tokens.track,
          child: DecoratedBox(
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: tokens.track))),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: DenseTable.rowHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: <Widget>[
                    for (final DenseColumn<T> col in columns)
                      Expanded(
                        flex: col.flex,
                        child: Align(
                          alignment:
                              col.numeric ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
                          child: col.cell(row),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
