// Local Bhor compositions of the batches feature: a dense hairline table
// (header + 48 px rows, no shadows) and labelled bars. Both sit in a
// BhorCard with zero padding.

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';

class BatchColumn<T> {
  const BatchColumn({
    required this.label,
    required this.cell,
    this.flex = 1,
    this.numeric = false,
    this.fixedWidth,
  });

  final String label;
  final Widget Function(T row) cell;
  final int flex;

  /// Right-aligned (counts, money).
  final bool numeric;

  /// A fixed-width column (phone, percent, tag): never truncated; the
  /// flexible columns share the rest.
  final double? fixedWidth;
}

const double _kColGap = BhorSpace.s12;

/// Column children with a 12 px gap between them; fixed columns keep their
/// width, the others share the rest by flex.
List<Widget> _cols<T>(List<BatchColumn<T>> columns, Widget Function(BatchColumn<T> col) cell) {
  return <Widget>[
    for (int i = 0; i < columns.length; i++) ...<Widget>[
      if (i > 0) const SizedBox(width: _kColGap),
      if (columns[i].fixedWidth != null)
        SizedBox(width: columns[i].fixedWidth, child: cell(columns[i]))
      else
        Expanded(flex: columns[i].flex, child: cell(columns[i])),
    ],
  ];
}

class BatchTable<T> extends StatelessWidget {
  const BatchTable({
    super.key,
    required this.columns,
    required this.rows,
    this.onRowTap,
    this.semanticLabel,
    this.isSelected,
  });

  final List<BatchColumn<T>> columns;
  final List<T> rows;
  final ValueChanged<T>? onRowTap;
  final String Function(T row)? semanticLabel;

  /// Rows for which this returns true get the accent tint.
  final bool Function(T row)? isSelected;

  static const double rowHeight = 48;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final bool bounded = c.hasBoundedHeight;
        final Widget list = ListView.builder(
          shrinkWrap: !bounded,
          physics: bounded ? null : const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: rows.length,
          itemBuilder: (BuildContext context, int i) => _row(b, rows[i], i == rows.length - 1),
        );
        return BhorCard(
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _header(b),
              ColoredBox(color: b.colors.line, child: const SizedBox(height: 1)),
              if (bounded) Expanded(child: list) else list,
            ],
          ),
        );
      },
    );
  }

  Widget _header(BhorThemeData b) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s16, vertical: BhorSpace.s8),
      child: Row(
        children: _cols<T>(
          columns,
          (BatchColumn<T> col) => Text(
            col.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: col.numeric ? TextAlign.end : TextAlign.start,
            style: b.type.label.copyWith(color: b.colors.text2),
          ),
        ),
      ),
    );
  }

  Widget _row(BhorThemeData b, T row, bool last) {
    final Widget cells = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: rowHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s16),
        child: Row(
          children: _cols<T>(
            columns,
            (BatchColumn<T> col) => Align(
              alignment: col.numeric ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
              child: col.cell(row),
            ),
          ),
        ),
      ),
    );
    final Widget body = DecoratedBox(
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: b.colors.line)),
      ),
      child: cells,
    );
    if (onRowTap == null) return body;
    return BhorPressable(
      onTap: () => onRowTap!(row),
      semanticLabel: semanticLabel?.call(row),
      radius: 0,
      scaleOnPress: false,
      selected: isSelected?.call(row),
      builder: (BuildContext c, BhorStates st) => DecoratedBox(
        decoration: BoxDecoration(
          color: (isSelected?.call(row) ?? false)
              ? b.colors.accentTint
              : (st.hovered || st.pressed ? b.colors.surface2 : null),
        ),
        child: body,
      ),
    );
  }
}

class BatchBarEntry {
  const BatchBarEntry({required this.label, required this.value, required this.valueText, this.onTap});

  final String label;

  /// Drives the bar length (relative to the largest entry).
  final int value;

  /// Already formatted number shown at the end of the row.
  final String valueText;
  final VoidCallback? onTap;
}

/// Labelled horizontal bars: one hairline row per entry.
class BatchBarList extends StatelessWidget {
  const BatchBarList({super.key, required this.entries});

  final List<BatchBarEntry> entries;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final int maxValue = entries.fold<int>(1, (int m, BatchBarEntry e) => e.value > m ? e.value : m);
    return BhorCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          for (int i = 0; i < entries.length; i++)
            BhorPressable(
              onTap: entries[i].onTap,
              semanticLabel: '${entries[i].label} ${entries[i].valueText}',
              radius: 0,
              scaleOnPress: false,
              builder: (BuildContext c, BhorStates st) => DecoratedBox(
                decoration: BoxDecoration(
                  color: st.hovered || st.pressed ? b.colors.surface2 : null,
                  border: i == entries.length - 1 ? null : Border(bottom: BorderSide(color: b.colors.line)),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: BatchTable.rowHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s16, vertical: BhorSpace.s8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(entries[i].label, style: b.type.body),
                            ),
                            const SizedBox(width: BhorSpace.s8),
                            Text(entries[i].valueText, style: BhorType.tabular(b.type.label)),
                          ],
                        ),
                        const SizedBox(height: BhorSpace.s4),
                        BhorProgress(value: entries[i].value / maxValue),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
