// Choice controls (docs/council/13-fluid-ui-spec.md): BhorSegmented (soft
// track, surface thumb that glides with the spring), BhorChip (pill, the
// check slides in), BhorSwitch (50x30, spring thumb that stretches while
// pressed), BhorCheckbox (the check draws in) and BhorRadioCard.

import 'dart:ui' show PathMetric;

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/foundation/bhor_icons.dart';
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

/// Equal-width segmented control: soft track r14 with 4 px padding; the
/// filled thumb ([BhorColors.thumb], no edge) glides (spring, 400 ms) and the
/// labels cross-fade.
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

  /// 38 tall instead of 46.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final int index = segments.indexWhere((BhorSegment<T> s) => s.value == value);
    final double h = compact ? BhorSize.compact : BhorSize.control;
    final int n = segments.length;
    final Duration fast = BhorMotion.of(context, BhorMotion.fast);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Container(
        height: h,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: c.soft,
          borderRadius: BorderRadius.circular(BhorRadius.control),
        ),
        child: Stack(
          children: <Widget>[
            if (index >= 0)
              AnimatedAlign(
                alignment: Alignment(n == 1 ? 0 : -1 + 2 * index / (n - 1), 0),
                duration: BhorMotion.of(context, BhorMotion.glide),
                curve: BhorMotion.curveOf(context, BhorMotion.spring),
                child: FractionallySizedBox(
                  widthFactor: 1 / n,
                  heightFactor: 1,
                  child: Container(
                    // Filled thumb, never an outline ring (review L1): white
                    // in light, the lifted dark grey in dark.
                    decoration: BoxDecoration(
                      color: c.thumb,
                      borderRadius: BorderRadius.circular(BhorRadius.control - 4),
                      boxShadow: c.thumbShadow,
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
                      scaleOnPress: false,
                      radius: BhorRadius.control - 4,
                      builder: (BuildContext context, BhorStates s) {
                        final bool sel = i == index;
                        final Color fg = sel ? c.text : (s.hovered ? c.text : c.text2);
                        return Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              if (segments[i].icon != null) ...<Widget>[
                                TweenAnimationBuilder<Color?>(
                                  tween: ColorTween(end: fg),
                                  duration: fast,
                                  builder: (BuildContext context, Color? col, Widget? _) =>
                                      Icon(segments[i].icon, size: BhorIconSize.inline, color: col),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Flexible(
                                child: AnimatedDefaultTextStyle(
                                  duration: fast,
                                  curve: BhorMotion.ease,
                                  style: (sel ? b.type.bodyStrong : b.type.body)
                                      .copyWith(color: fg, fontSize: compact ? 13.5 : 14.5),
                                  child: Text(
                                    segments[i].label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
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

/// Filter / choice chip: pill h38, soft fill; selected = accent tint +
/// accent text + a check that slides in (width 0 -> 20, spring).
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
    final Duration fast = BhorMotion.of(context, BhorMotion.fast);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: BhorPressable(
        onTap: onSelected == null ? null : () => onSelected!(!selected),
        selected: selected,
        semanticLabel: count == null ? label : '$label, $count',
        excludeChildSemantics: true,
        radius: BhorSize.compact / 2,
        builder: (BuildContext context, BhorStates s) {
          final Color fg = selected ? c.accent : c.text2;
          return AnimatedContainer(
            duration: fast,
            curve: BhorMotion.ease,
            height: BhorSize.compact,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: selected ? c.accentTint : (s.hovered || s.pressed ? c.soft2 : c.soft),
              borderRadius: BorderRadius.circular(BhorRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // Reserved check slot: grows 0 -> 20 with the spring.
                AnimatedContainer(
                  duration: BhorMotion.of(context, BhorMotion.glide),
                  curve: selected ? BhorMotion.curveOf(context, BhorMotion.spring) : BhorMotion.ease,
                  width: selected ? 20 : 0,
                  child: ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.centerLeft,
                      maxWidth: 20,
                      minWidth: 20,
                      child: AnimatedOpacity(
                        opacity: selected ? 1 : 0,
                        duration: fast,
                        child: Icon(BhorIcons.check, size: BhorIconSize.inline, color: fg),
                      ),
                    ),
                  ),
                ),
                if (!selected && icon != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(icon, size: BhorIconSize.inline, color: fg),
                  ),
                AnimatedDefaultTextStyle(
                  duration: fast,
                  style: b.type.label.copyWith(color: selected ? c.accent : c.text, fontSize: 13.5),
                  child: Text(label),
                ),
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

/// On/off switch: 50x30 track, the thumb spring-slides and stretches to
/// 30 px while pressed; the track colour fades. 44 tall target.
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
    final bool reduced = BhorMotion.reduced(context);
    return BhorPressable(
      onTap: enabled ? () => onChanged!(!value) : null,
      toggled: value,
      isButton: false,
      semanticLabel: semanticLabel,
      radius: 15,
      scaleOnPress: false,
      builder: (BuildContext context, BhorStates s) => SizedBox(
        width: 54,
        height: BhorSize.minTap,
        child: Center(
          child: AnimatedOpacity(
            opacity: enabled ? 1 : 0.45,
            duration: BhorMotion.of(context, BhorMotion.fast),
            child: AnimatedContainer(
              duration: BhorMotion.of(context, BhorMotion.fast),
              curve: BhorMotion.ease,
              width: 50,
              height: 30,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: value ? c.accentFill : c.soft2,
                borderRadius: BorderRadius.circular(15),
              ),
              child: AnimatedAlign(
                duration: BhorMotion.of(context, BhorMotion.glide),
                curve: BhorMotion.curveOf(context, BhorMotion.spring),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: AnimatedContainer(
                  duration: BhorMotion.of(context, BhorMotion.fast),
                  curve: BhorMotion.ease,
                  width: s.pressed && !reduced ? 30 : 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: c.isDark ? (value ? c.onAccentFill : c.text2) : c.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: c.thumbShadow,
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

/// Checkbox with optional label to its right (whole row is the target). The
/// box fills and the check path draws in.
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
    final Duration fast = BhorMotion.of(context, BhorMotion.fast);
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
                  duration: fast,
                  curve: BhorMotion.ease,
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: value ? c.accentFill : (s.hovered ? c.soft2 : c.soft),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: value ? c.accentFill : c.text3, width: 1.5),
                  ),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: value ? 1 : 0),
                    duration: fast,
                    curve: BhorMotion.ease,
                    builder: (BuildContext context, double t, Widget? _) =>
                        CustomPaint(painter: BhorCheckPainter(progress: t, color: c.onAccentFill, strokeWidth: 2)),
                  ),
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

/// Paints a check mark drawn up to [progress] (0..1) of its length.
class BhorCheckPainter extends CustomPainter {
  BhorCheckPainter({required this.progress, required this.color, this.strokeWidth = 2});

  final double progress;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final double w = size.width;
    final double h = size.height;
    final Path path = Path()
      ..moveTo(w * 0.26, h * 0.52)
      ..lineTo(w * 0.43, h * 0.68)
      ..lineTo(w * 0.75, h * 0.34);
    final Path drawn = Path();
    double total = 0;
    final List<PathMetric> metrics = path.computeMetrics().toList();
    for (final PathMetric m in metrics) {
      total += m.length;
    }
    double left = total * progress.clamp(0.0, 1.0);
    for (final PathMetric m in metrics) {
      if (left <= 0) break;
      final double take = left < m.length ? left : m.length;
      drawn.addPath(m.extractPath(0, take), Offset.zero);
      left -= take;
    }
    canvas.drawPath(
      drawn,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(BhorCheckPainter old) =>
      old.progress != progress || old.color != color || old.strokeWidth != strokeWidth;
}

/// A selectable card with a radio dot (one of a group). Soft fill; the
/// chosen card gets the accent tint and a filled dot that pops (no ring).
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
    final Duration fast = BhorMotion.of(context, BhorMotion.fast);
    return BhorPressable(
      onTap: onChanged == null ? null : () => onChanged!(value),
      checked: sel,
      inMutuallyExclusiveGroup: true,
      isButton: false,
      semanticLabel: subtitle == null ? title : '$title, $subtitle',
      excludeChildSemantics: true,
      radius: BhorRadius.card,
      builder: (BuildContext context, BhorStates s) => AnimatedContainer(
        duration: fast,
        curve: BhorMotion.ease,
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s16, vertical: BhorSpace.s12),
        // Selected = the accent tint fill and a filled dot; no ring (L1).
        decoration: BoxDecoration(
          color: sel ? c.accentTint : (s.hovered || s.pressed ? c.soft2 : c.soft),
          borderRadius: BorderRadius.circular(BhorRadius.card),
        ),
        child: Row(
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: BhorIconSize.row, color: sel ? c.accent : c.text2),
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
            // The dot: an empty circle (the affordance) that fills with the
            // accent and pops a white centre when chosen.
            AnimatedContainer(
              duration: fast,
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: sel ? null : Border.all(color: c.text3, width: 1.5),
                color: sel ? c.accentFill : c.surface,
              ),
              alignment: Alignment.center,
              child: AnimatedScale(
                scale: sel ? 1 : 0,
                duration: BhorMotion.of(context, BhorMotion.glide),
                curve: sel ? BhorMotion.curveOf(context, BhorMotion.spring) : BhorMotion.ease,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: c.onAccentFill, shape: BoxShape.circle),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
