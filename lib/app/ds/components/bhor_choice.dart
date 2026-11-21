// Choice controls: BhorSegmented (sliding thumb), BhorChip (filter),
// BhorSwitch, BhorCheckbox, BhorRadioCard.

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/foundation/bhor_interaction.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_theme.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_tokens.dart';

/// One segment of a [BhorSegmented].
class BhorSegment<T> {
  const BhorSegment(this.value, this.label, {this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// Equal-width segmented control with a sliding thumb.
/// Usage: `BhorSegmented<int>(segments: [...], value: v, onChanged: f)`.
class BhorSegmented<T> extends StatelessWidget {
  const BhorSegmented({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  final List<BhorSegment<T>> segments;
  final T value;
  final ValueChanged<T>? onChanged;

  /// 36 tall instead of 44.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final int index = segments.indexWhere((BhorSegment<T> s) => s.value == value);
    final double h = compact ? BhorSize.compact : BhorSize.control;
    final int n = segments.length;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Container(
        height: h,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: BorderRadius.circular(BhorRadius.control),
        ),
        child: Stack(
          children: <Widget>[
            if (index >= 0)
              AnimatedAlign(
                alignment: Alignment(n == 1 ? 0 : -1 + 2 * index / (n - 1), 0),
                duration: BhorMotion.slow,
                curve: BhorMotion.curve,
                child: FractionallySizedBox(
                  widthFactor: 1 / n,
                  heightFactor: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: c.isDark ? c.line : c.surface,
                      borderRadius: BorderRadius.circular(BhorRadius.control - 3),
                      border: Border.all(color: c.isDark ? c.accentLine : c.line),
                    ),
                  ),
                ),
              ),
            Row(
              children: <Widget>[
                for (int i = 0; i < n; i++)
                  Expanded(
                    child: BhorPressable(
                      onTap: onChanged == null ? null : () => onChanged!(segments[i].value),
                      selected: i == index,
                      inMutuallyExclusiveGroup: true,
                      semanticLabel: segments[i].label,
                      excludeChildSemantics: true,
                      radius: BhorRadius.control - 3,
                      builder: (BuildContext context, BhorStates s) {
                        final bool sel = i == index;
                        final Color fg = sel ? c.text : (s.hovered ? c.text : c.text2);
                        return Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              if (segments[i].icon != null) ...<Widget>[
                                Icon(segments[i].icon, size: 16, color: fg),
                                const SizedBox(width: 6),
                              ],
                              Flexible(
                                child: Text(
                                  segments[i].label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: (sel ? b.type.bodyStrong : b.type.body)
                                      .copyWith(color: fg, fontSize: compact ? 13 : 14),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Filter chip (radius 10, 36 visual in a 44 target).
/// Usage: `BhorChip(label: 'বকেয়া', selected: on, onSelected: (v) => ...)`.
class BhorChip extends StatelessWidget {
  const BhorChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
    this.count,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final IconData? icon;

  /// Trailing count ("১২"), already formatted.
  final String? count;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: BhorPressable(
        onTap: onSelected == null ? null : () => onSelected!(!selected),
        selected: selected,
        semanticLabel: count == null ? label : '$label, $count',
        excludeChildSemantics: true,
        radius: BhorRadius.chip,
        builder: (BuildContext context, BhorStates s) {
          final Color fg = selected ? c.accent : c.text2;
          return AnimatedContainer(
            duration: BhorMotion.fast,
            height: BhorSize.compact,
            padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s12),
            decoration: BoxDecoration(
              color: selected ? c.accentTint : (s.hovered ? c.surface2 : c.surface),
              borderRadius: BorderRadius.circular(BhorRadius.chip),
              border: Border.all(color: selected ? c.accentLine : c.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (selected)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(Icons.check_rounded, size: 16, color: fg),
                  )
                else if (icon != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(icon, size: 16, color: fg),
                  ),
                Text(label, style: b.type.label.copyWith(color: selected ? c.accent : c.text)),
                if (count != null) ...<Widget>[
                  const SizedBox(width: 6),
                  Text(count!, style: BhorType.tabular(b.type.caption.copyWith(color: fg))),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// On/off switch (40x24 track in a 44 target).
/// Usage: `BhorSwitch(value: on, onChanged: (v) => ..., semanticLabel: 'রিমাইন্ডার')`.
class BhorSwitch extends StatelessWidget {
  const BhorSwitch({super.key, required this.value, required this.onChanged, this.semanticLabel});

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final BhorColors c = context.bhor.colors;
    final bool enabled = onChanged != null;
    return BhorPressable(
      onTap: enabled ? () => onChanged!(!value) : null,
      toggled: value,
      isButton: false,
      semanticLabel: semanticLabel,
      radius: 12,
      scaleOnPress: false,
      builder: (BuildContext context, BhorStates s) => SizedBox(
        width: 48,
        height: BhorSize.minTap,
        child: Center(
          child: AnimatedOpacity(
            opacity: enabled ? 1 : 0.45,
            duration: BhorMotion.fast,
            child: AnimatedContainer(
              duration: BhorMotion.base,
              curve: BhorMotion.curve,
              width: 40,
              height: 24,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: value ? c.accent : c.surface2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: value ? c.accent : c.line),
              ),
              child: AnimatedAlign(
                duration: BhorMotion.base,
                curve: BhorMotion.curve,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: value ? c.onAccent : c.text3,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Checkbox with optional label to its right (whole row is the target).
/// Usage: `BhorCheckbox(value: v, onChanged: (x) => ..., label: 'সবাই')`.
class BhorCheckbox extends StatelessWidget {
  const BhorCheckbox({super.key, required this.value, required this.onChanged, this.label, this.semanticLabel});

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final bool enabled = onChanged != null;
    return BhorPressable(
      onTap: enabled ? () => onChanged!(!value) : null,
      checked: value,
      isButton: false,
      semanticLabel: semanticLabel ?? label,
      excludeChildSemantics: true,
      radius: 8,
      scaleOnPress: false,
      builder: (BuildContext context, BhorStates s) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: BhorSize.minTap, minWidth: BhorSize.minTap),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: BhorSize.minTap,
              child: Center(
                child: AnimatedContainer(
                  duration: BhorMotion.fast,
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: value ? c.accent : c.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: value ? c.accent : (s.hovered ? c.accentLine : c.text3),
                      width: 1.5,
                    ),
                  ),
                  child: value ? Icon(Icons.check_rounded, size: 15, color: c.onAccent) : null,
                ),
              ),
            ),
            if (label != null)
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(right: BhorSpace.s8),
                  child: Text(label!, style: b.type.body.copyWith(color: enabled ? c.text : c.text3)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A selectable card with a radio dot (one of a group).
/// Usage: `BhorRadioCard<int>(value: 1, groupValue: g, onChanged: f, title: 'মাসিক')`.
class BhorRadioCard<T> extends StatelessWidget {
  const BhorRadioCard({
    super.key,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    required this.title,
    this.subtitle,
    this.icon,
  });

  final T value;
  final T? groupValue;
  final ValueChanged<T>? onChanged;
  final String title;
  final String? subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final bool sel = value == groupValue;
    return BhorPressable(
      onTap: onChanged == null ? null : () => onChanged!(value),
      checked: sel,
      inMutuallyExclusiveGroup: true,
      isButton: false,
      semanticLabel: subtitle == null ? title : '$title, $subtitle',
      excludeChildSemantics: true,
      radius: BhorRadius.card,
      builder: (BuildContext context, BhorStates s) => AnimatedContainer(
        duration: BhorMotion.fast,
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.all(BhorSpace.s12),
        decoration: BoxDecoration(
          color: sel ? c.accentTint : c.surface,
          borderRadius: BorderRadius.circular(BhorRadius.card),
          border: Border.all(color: sel ? c.accent : (s.hovered ? c.accentLine : c.line), width: sel ? 1.5 : 1),
        ),
        child: Row(
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 20, color: sel ? c.accent : c.text2),
              const SizedBox(width: BhorSpace.s12),
            ],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: b.type.bodyStrong),
                  if (subtitle != null) Text(subtitle!, style: b.type.meta),
                ],
              ),
            ),
            const SizedBox(width: BhorSpace.s8),
            AnimatedContainer(
              duration: BhorMotion.fast,
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: sel ? c.accent : c.text3, width: sel ? 6 : 1.5),
                color: c.surface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
