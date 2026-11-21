// Small selectable chip used by the time picker (hours, minutes, periods), the
// weekday chips and the reminder presets. A Bhor chip: the selected state is a
// filled accent tint, an accent border and bold text, so it never relies on
// colour alone.

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';

class SchedChip extends StatelessWidget {
  const SchedChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.minWidth = 48,
    this.semanticLabel,
    this.leading,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double minWidth;
  final String? semanticLabel;
  final IconData? leading;

  @override
  Widget build(BuildContext context) {
    final Widget chip = ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth),
      child: BhorChip(label: label, selected: selected, icon: leading, onSelected: (_) => onTap()),
    );
    if (semanticLabel == null) return chip;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      excludeSemantics: true,
      onTap: onTap,
      child: chip,
    );
  }
}
