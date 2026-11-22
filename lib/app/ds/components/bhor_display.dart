// Display components (docs/council/13-fluid-ui-spec.md): BhorTag (pill),
// BhorCard (+ hero, the only gradient), BhorList (surface card r20 with a
// line edge holding rows), BhorListRow (inset hairline, soft hover/press),
// BhorSectionHeader, BhorAvatar (circle), BhorProgress (animated fill),
// BhorSkeleton (shimmer sweep), BhorEmptyState (compact / regular / page),
// the one selection style for list cards and rows (BhorSelection:
// accentTint fill + a 3 px accent bar, text never dimmed; review B2) and
// BhorMasonry (content-sized dashboard columns).

import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/foundation/bhor_interaction.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_theme.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_tokens.dart';
import 'package:attendance_alamin/app/theme/tokens.dart' show SeverityLevel;

enum BhorTone { neutral, accent, ok, danger, late, absent, warn, overdue }

/// Status tag: a tinted pill (tint fill + coloured text, one style on every
/// screen). Never colour alone: always a word.
/// Usage: `BhorTag(label: 'পরিশোধিত', tone: BhorTone.ok)` or
/// `BhorTag.severity(level: SeverityLevel.urgent, label: 'জরুরি')`.
class BhorTag extends StatelessWidget {
  const BhorTag({super.key, required this.label, this.tone = BhorTone.neutral, this.icon})
      : severity = null,
        solid = false;

  /// Dues severity tag: the honey -> rose tints; overdue is the tinted
  /// raspberry pill (overdueBg + overdue text), the same as
  /// `BhorTone.overdue`. [solid] is only for a single compact count badge
  /// (at most one per screen, e.g. "মোট বকেয়া ৩"): solid raspberry, white
  /// text.
  const BhorTag.severity({
    super.key,
    required SeverityLevel level,
    required this.label,
    this.icon,
    this.solid = false,
  })  : severity = level,
        tone = BhorTone.neutral;

  final String label;
  final BhorTone tone;
  final SeverityLevel? severity;
  final IconData? icon;

  /// Solid fill (a lone count badge); tags are tinted otherwise.
  final bool solid;

  /// Fill and text colour of a severity tag.
  static (Color, Color) severityColorsOf(BhorColors c, SeverityLevel level, {bool solid = false}) {
    if (level == SeverityLevel.overdue) {
      return solid ? (c.sevFill[level.index], c.sevText[level.index]) : (c.overdueBg, c.overdue);
    }
    return (c.sevFill[level.index], c.sevText[level.index]);
  }

  /// Fill and text colour of [tone].
  static (Color, Color) colorsOf(BhorColors c, BhorTone tone) => switch (tone) {
        BhorTone.neutral => (c.soft, c.text2),
        BhorTone.accent => (c.accentTint, c.accent),
        BhorTone.ok => (c.okBg, c.ok),
        BhorTone.danger => (c.dangerBg, c.danger),
        BhorTone.late => (c.lateBg, c.late),
        BhorTone.absent => (c.absentBg, c.absentText),
        BhorTone.warn => (c.warnBg, c.warn),
        BhorTone.overdue => (c.overdueBg, c.overdue),
      };

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final (Color bg, Color fg) =
        severity != null ? severityColorsOf(c, severity!, solid: solid) : colorsOf(c, tone);
    return Semantics(
      container: true,
      label: label,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: BhorMotion.of(context, BhorMotion.fast),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(BhorRadius.pill)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: b.type.caption.copyWith(color: fg, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Surface card with a 1 px line edge (r18); `hero` paints the signature
/// gradient (r22, white text) and is the only gradient in the app.
/// Tappable when [onTap] is set (hover edge, press scale). [selected] is the
/// one list-card selection style ([BhorSelection]): accent-tint fill and a
/// 3 px accent bar at the start; the content keeps its colours.
/// Usage: `BhorCard(child: ...)`, `BhorCard(selected: id == current, onTap: f, child: ...)`,
/// `BhorCard.hero(child: ...)`.
class BhorCard extends StatelessWidget {
  const BhorCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.semanticLabel,
    this.selected = false,
  }) : hero = false;

  const BhorCard.hero({super.key, required this.child, this.padding, this.onTap, this.semanticLabel})
      : hero = true,
        selected = false;

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final bool hero;

  /// The selected list card (master list).
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final double radius = hero ? BhorRadius.hero : BhorRadius.card;
    final Color selectedFill = BhorSelection.fillOn(c, c.surface);
    Widget box(BhorStates s) => AnimatedContainer(
          duration: BhorMotion.of(context, BhorMotion.fast),
          curve: BhorMotion.ease,
          padding: padding ?? EdgeInsets.all(hero ? BhorSpace.s20 : BhorSpace.s16),
          decoration: BoxDecoration(
            color: hero ? null : (selected ? selectedFill : c.surface),
            gradient: hero ? c.heroGradient : null,
            borderRadius: BorderRadius.circular(radius),
            // Selected: the edge melts into the fill (no ring).
            border: hero
                ? null
                : Border.all(color: selected ? selectedFill : (s.hovered ? c.accentLine : c.line)),
          ),
          foregroundDecoration:
              s.pressed ? BoxDecoration(color: c.pressShade, borderRadius: BorderRadius.circular(radius)) : null,
          child: hero
              ? DefaultTextStyle.merge(
                  style: TextStyle(color: c.onHero),
                  child: IconTheme.merge(data: IconThemeData(color: c.onHero), child: child),
                )
              : child,
        );
    Widget framed(BhorStates s) => hero
        ? box(s)
        : Stack(
            fit: StackFit.passthrough,
            children: <Widget>[
              box(s),
              Positioned.fill(child: BhorSelectionBar(selected: selected)),
            ],
          );
    if (onTap == null) return Semantics(selected: selected ? true : null, child: framed(const BhorStates()));
    return BhorPressable(
      onTap: onTap,
      selected: selected ? true : null,
      semanticLabel: semanticLabel,
      radius: radius,
      pressScale: 0.985,
      builder: (BuildContext context, BhorStates s) => framed(s),
    );
  }
}

/// The one selection style of list cards and rows (docs/council/16 W1-B 4,
/// review B2): the accent-tint fill plus a 3 px accent bar at the leading
/// edge. Text and icons keep their normal colours: a selected item never
/// looks dimmed (light) and never turns into a solid indigo slab (dark).
/// [BhorCard] and [BhorListRow] take `selected:`; custom tiles use
/// [BhorSelectable] or [fillOn] + [BhorSelectionBar].
abstract final class BhorSelection {
  /// Width of the leading accent bar.
  static const double barWidth = 3;

  /// Vertical inset of the bar from the item's top and bottom.
  static const double barInset = BhorSpace.s12;

  /// The selected fill, painted opaque over [under] (surface for cards).
  static Color fillOn(BhorColors c, Color under) => Color.alphaBlend(c.accentTint, under);
}

/// The 3 px accent bar of the selection style; fills its parent's height
/// (inset [BhorSelection.barInset]) and slides in with the spring.
/// Usage: `Stack(children: [tile, Positioned.fill(child: BhorSelectionBar(selected: on))])`.
class BhorSelectionBar extends StatelessWidget {
  const BhorSelectionBar({super.key, required this.selected, this.inset = BhorSelection.barInset});

  final bool selected;

  /// Top and bottom inset.
  final double inset;

  @override
  Widget build(BuildContext context) {
    final BhorColors c = context.bhor.colors;
    return IgnorePointer(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: inset),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: AnimatedContainer(
            duration: BhorMotion.of(context, BhorMotion.fast),
            curve: BhorMotion.ease,
            width: BhorSelection.barWidth,
            decoration: BoxDecoration(
              color: selected ? c.accent : c.accent.withValues(alpha: 0),
              borderRadius: const BorderRadiusDirectional.horizontal(end: Radius.circular(2)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the selection style behind / beside any tile: the accent-tint
/// fill under [child] (which should be transparent where the fill must show)
/// and the leading bar over it. Prefer `BhorCard(selected:)` for cards.
/// Usage: `BhorSelectable(selected: on, child: myTile)`.
class BhorSelectable extends StatelessWidget {
  const BhorSelectable({super.key, required this.selected, required this.child, this.radius = BhorRadius.card});

  final bool selected;
  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final BhorColors c = context.bhor.colors;
    return Semantics(
      selected: selected ? true : null,
      child: AnimatedContainer(
        duration: BhorMotion.of(context, BhorMotion.fast),
        curve: BhorMotion.ease,
        decoration: BoxDecoration(
          color: selected ? c.accentTint : c.accentTint.withValues(alpha: 0),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Stack(
          fit: StackFit.passthrough,
          children: <Widget>[
            child,
            Positioned.fill(child: BhorSelectionBar(selected: selected)),
          ],
        ),
      ),
    );
  }
}

/// A list surface: surface card r20 with a 1 px line edge; put
/// [BhorListRow]s in [children] (the last row's hairline is dropped).
/// Usage: `BhorList(children: [BhorListRow(...), BhorListRow(...)])`.
class BhorList extends StatelessWidget {
  const BhorList({super.key, required this.children, this.header});

  final List<Widget> children;

  /// Optional title row inside the card, above the rows.
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final BhorColors c = context.bhor.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(BhorRadius.list),
        border: Border.all(color: c.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ?header,
          for (int i = 0; i < children.length; i++)
            _LastRow(last: i == children.length - 1, child: children[i]),
        ],
      ),
    );
  }
}

/// Tells a [BhorListRow] it is the last one of a [BhorList] (no hairline).
class _LastRow extends InheritedWidget {
  const _LastRow({required this.last, required super.child});

  final bool last;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_LastRow>()?.last ?? false;

  @override
  bool updateShouldNotify(_LastRow oldWidget) => oldWidget.last != last;
}

/// Dense row with an inset hairline divider (48 tall on phones, 44 on
/// desktop); hover / press paint the soft fill; [selected] is the selection
/// style (accent tint + leading bar, text unchanged). Money goes in [trailing]
/// (right-aligned, bold, tabular: `BhorMoney`).
/// Usage: `BhorListRow(title: 'রহিম', subtitle: 'রোল ৩', trailing: tag, onTap: f)`.
class BhorListRow extends StatelessWidget {
  const BhorListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.divider = true,
    this.selected = false,
    this.semanticLabel,
    this.dividerIndent,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool divider;
  final bool selected;
  final String? semanticLabel;

  /// Start inset of the hairline (default: text start).
  final double? dividerIndent;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final double minH = context.bhorIsWide ? BhorSize.minTap : BhorSize.phoneRow;
    final bool showLine = divider && !_LastRow.of(context);
    final double indent = dividerIndent ?? (leading != null ? BhorSpace.s16 + 36 + BhorSpace.s12 : BhorSpace.s16);
    Widget row(BhorStates s) => AnimatedContainer(
          duration: BhorMotion.of(context, BhorMotion.instant),
          constraints: BoxConstraints(minHeight: minH),
          color: selected ? c.accentTint : (s.hovered || s.pressed ? c.soft : c.soft.withValues(alpha: 0)),
          child: Stack(
            alignment: AlignmentDirectional.centerStart,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s16, vertical: 8),
                child: Row(
                  children: <Widget>[
                    if (leading != null) ...<Widget>[leading!, const SizedBox(width: BhorSpace.s12)],
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: b.type.bodyStrong),
                          if (subtitle != null)
                            Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: b.type.meta),
                        ],
                      ),
                    ),
                    if (trailing != null) ...<Widget>[const SizedBox(width: BhorSpace.s12), trailing!],
                  ],
                ),
              ),
              if (showLine)
                PositionedDirectional(
                  start: indent,
                  end: 0,
                  bottom: 0,
                  height: 1,
                  child: ColoredBox(color: c.line),
                ),
              Positioned.fill(child: BhorSelectionBar(selected: selected, inset: BhorSpace.s8)),
            ],
          ),
        );
    if (onTap == null && onLongPress == null) {
      return Semantics(container: true, label: semanticLabel, child: row(const BhorStates()));
    }
    return BhorPressable(
      onTap: onTap,
      onLongPress: onLongPress,
      selected: selected,
      semanticLabel: semanticLabel,
      scaleOnPress: false,
      radius: 0,
      builder: (BuildContext context, BhorStates s) => row(s),
    );
  }
}

/// Section title with an optional count and trailing action.
/// Usage: `BhorSectionHeader(title: 'আজকের ক্লাস', actionLabel: 'সব', onAction: f)`.
class BhorSectionHeader extends StatelessWidget {
  const BhorSectionHeader({super.key, required this.title, this.count, this.actionLabel, this.onAction});

  final String title;

  /// Already formatted count shown after the title.
  final String? count;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    return Padding(
      padding: const EdgeInsets.only(top: BhorSpace.s8, bottom: BhorSpace.s4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Semantics(
              header: true,
              child: Text.rich(
                TextSpan(children: <InlineSpan>[
                  TextSpan(text: title),
                  if (count != null) TextSpan(text: '  $count', style: b.type.meta.copyWith(color: c.text3)),
                ]),
                style: b.type.heading,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            BhorPressable(
              onTap: onAction,
              semanticLabel: actionLabel,
              excludeChildSemantics: true,
              radius: 10,
              builder: (BuildContext context, BhorStates s) => ConstrainedBox(
                constraints: const BoxConstraints(minHeight: BhorSize.minTap),
                child: AnimatedContainer(
                  duration: BhorMotion.of(context, BhorMotion.instant),
                  padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s12),
                  decoration: BoxDecoration(
                    color: s.hovered || s.pressed ? c.accentTint : c.accentTint.withValues(alpha: 0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    widthFactor: 1,
                    child: Text(actionLabel!, style: b.type.label.copyWith(color: c.accent)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Circle initials avatar: accent tint, accent initials.
/// Usage: `BhorAvatar(name: 'রহিম উদ্দিন', size: 36)`.
class BhorAvatar extends StatelessWidget {
  const BhorAvatar({super.key, required this.name, this.size = 36, this.image});

  final String name;
  final double size;
  final ImageProvider? image;

  /// First letter of the first two words (grapheme-safe for Bangla).
  static String initialsOf(String name) {
    final List<String> words = name.trim().split(RegExp(r'\s+')).where((String w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    String first(String w) => w.characters.first;
    if (words.length == 1) return first(words.first);
    return first(words[0]) + first(words[1]);
  }

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    return Semantics(
      label: name,
      image: image != null,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: c.accentTint,
          shape: BoxShape.circle,
          image: image == null ? null : DecorationImage(image: image!, fit: BoxFit.cover),
        ),
        alignment: Alignment.center,
        child: image != null
            ? null
            : Text(
                initialsOf(name),
                maxLines: 1,
                style: b.type.label.copyWith(color: c.accent, fontSize: size * 0.36, height: 1.2),
              ),
      ),
    );
  }
}

/// Thin progress bar (0..1). The fill animates from 0 on first appearance
/// and from old to new on change (480 ms, count curve).
/// Usage: `BhorProgress(value: 0.7, semanticLabel: 'উপস্থিতি ৭০%')`.
class BhorProgress extends StatelessWidget {
  const BhorProgress({super.key, required this.value, this.height = 6, this.color, this.semanticLabel});

  final double value;
  final double height;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final BhorColors c = context.bhor.colors;
    final double v = value.clamp(0.0, 1.0);
    final bool reduced = BhorMotion.reduced(context);
    return Semantics(
      label: semanticLabel,
      value: '${(v * 100).round()}%',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: SizedBox(
          height: height,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: reduced ? v : 0, end: v),
            duration: reduced ? Duration.zero : BhorMotion.countUpMax,
            curve: BhorMotion.countCurve,
            builder: (BuildContext context, double t, Widget? _) => Stack(
              children: <Widget>[
                Positioned.fill(child: ColoredBox(color: c.soft)),
                FractionallySizedBox(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: t.clamp(0.0, 1.0),
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color ?? c.accentFill,
                      borderRadius: BorderRadius.circular(height / 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Loading placeholder block with a 1.2 s shimmer sweep (a static soft
/// block when motion is reduced). Match the real row heights.
/// Usage: `BhorSkeleton(width: 120, height: 14)`.
class BhorSkeleton extends StatefulWidget {
  const BhorSkeleton({super.key, this.width, this.height = 14, this.radius = 6});

  final double? width;
  final double height;
  final double radius;

  @override
  State<BhorSkeleton> createState() => _BhorSkeletonState();
}

class _BhorSkeletonState extends State<BhorSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (BhorMotion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BhorColors c = context.bhor.colors;
    final Color base = c.soft;
    final Color shine = Color.lerp(c.soft, c.surface, c.isDark ? 0.12 : 0.7)!;
    final bool still = BhorMotion.reduced(context);
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _c,
        builder: (BuildContext context, Widget? _) => Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: still
                ? null
                : LinearGradient(
                    begin: const Alignment(-1.0, -0.36),
                    end: const Alignment(1.0, 0.36),
                    colors: <Color>[base, shine, base],
                    stops: const <double>[0.35, 0.5, 0.65],
                    transform: _SweepTransform(_c.value),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Moves the shimmer band from off the left edge to off the right edge.
class _SweepTransform extends GradientTransform {
  const _SweepTransform(this.t);

  final double t;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * (t * 2 - 1), 0, 0);
}

/// Size of a [BhorEmptyState].
enum BhorEmptySize {
  /// Inside a card or a short list (44 px glyph circle, label title).
  compact,

  /// A list or pane (64 px circle, heading title).
  regular,

  /// A whole page or a large pane (88 px circle, title-size title).
  page,
}

/// Designed empty state (review L3): the glyph in a tinted circle, a title,
/// a one-line body and an optional action, centred. Three sizes.
/// Usage: `BhorEmptyState(icon: BhorIcons.batches, title: '...', message: '...', action: button)`,
/// `BhorEmptyState(size: BhorEmptySize.compact, icon: ..., title: ...)`.
class BhorEmptyState extends StatelessWidget {
  const BhorEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.size = BhorEmptySize.regular,
  });

  final IconData icon;
  final String title;

  /// One short line under the title.
  final String? message;
  final Widget? action;
  final BhorEmptySize size;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final (double circle, double glyph, EdgeInsets pad, TextStyle titleStyle, double gap) = switch (size) {
      BhorEmptySize.compact => (
          44.0,
          22.0,
          const EdgeInsets.symmetric(horizontal: BhorSpace.s16, vertical: BhorSpace.s16),
          b.type.bodyStrong,
          BhorSpace.s8,
        ),
      BhorEmptySize.regular => (
          64.0,
          28.0,
          const EdgeInsets.symmetric(horizontal: BhorSpace.s24, vertical: BhorSpace.s32),
          b.type.heading,
          BhorSpace.s16,
        ),
      BhorEmptySize.page => (
          88.0,
          40.0,
          const EdgeInsets.symmetric(horizontal: BhorSpace.s32, vertical: BhorSpace.s40 + BhorSpace.s8),
          b.type.title,
          BhorSpace.s20,
        ),
    };
    return Padding(
      padding: pad,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: circle,
            height: circle,
            decoration: BoxDecoration(color: c.accentTint, shape: BoxShape.circle),
            child: Icon(icon, size: glyph, color: c.accent),
          ),
          SizedBox(height: gap),
          Semantics(header: true, child: Text(title, textAlign: TextAlign.center, style: titleStyle)),
          if (message != null) ...<Widget>[
            const SizedBox(height: BhorSpace.s4),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: size == BhorEmptySize.page ? 440 : 360),
              child: Text(
                message!,
                textAlign: TextAlign.center,
                style: (size == BhorEmptySize.compact ? b.type.meta : b.type.body).copyWith(color: c.text2),
              ),
            ),
          ],
          if (action != null) ...<Widget>[SizedBox(height: gap), action!],
        ],
      ),
    );
  }
}

/// Dashboard masonry: content-sized cards in 1 / 2 / 3 columns by the
/// available width (never equal-height rows, so no hollow or clipped cards;
/// review T1 / L4). Each child goes to the currently shortest column, in
/// order. Put it in a scroll view; it sizes itself to its content.
/// Usage: `BhorMasonry(children: [todayCard, paymentsCard, backupCard])`.
class BhorMasonry extends MultiChildRenderObjectWidget {
  const BhorMasonry({
    super.key,
    required super.children,
    this.gap = BhorSpace.s16,
    this.minColumnWidth = 340,
    this.maxColumns = 3,
  });

  /// Space between columns and between cards.
  final double gap;

  /// A column is never narrower than this (fewer columns instead).
  final double minColumnWidth;
  final int maxColumns;

  /// Columns for [width]: as many as fit at [minColumnWidth], 1..[maxColumns].
  static int columnsFor(double width, {double minColumnWidth = 340, int maxColumns = 3, double gap = BhorSpace.s16}) {
    if (!width.isFinite || width <= 0) return 1;
    final int n = ((width + gap) / (minColumnWidth + gap)).floor();
    return n.clamp(1, math.max(1, maxColumns)).toInt();
  }

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMasonry(gap: gap, minColumnWidth: minColumnWidth, maxColumns: maxColumns);

  @override
  void updateRenderObject(BuildContext context, _RenderMasonry renderObject) {
    renderObject
      ..gap = gap
      ..minColumnWidth = minColumnWidth
      ..maxColumns = maxColumns;
  }
}

class _MasonryParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderMasonry extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, _MasonryParentData>, RenderBoxContainerDefaultsMixin<RenderBox, _MasonryParentData> {
  _RenderMasonry({required double gap, required double minColumnWidth, required int maxColumns})
      : _gap = gap,
        _minColumnWidth = minColumnWidth,
        _maxColumns = maxColumns;

  double _gap;
  double get gap => _gap;
  set gap(double v) {
    if (v == _gap) return;
    _gap = v;
    markNeedsLayout();
  }

  double _minColumnWidth;
  double get minColumnWidth => _minColumnWidth;
  set minColumnWidth(double v) {
    if (v == _minColumnWidth) return;
    _minColumnWidth = v;
    markNeedsLayout();
  }

  int _maxColumns;
  int get maxColumns => _maxColumns;
  set maxColumns(int v) {
    if (v == _maxColumns) return;
    _maxColumns = v;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _MasonryParentData) child.parentData = _MasonryParentData();
  }

  /// Lays the children out (or measures them for a dry layout) and returns
  /// the size; [place] receives each child's offset on a real layout.
  Size _layout(BoxConstraints constraints, {required bool dry}) {
    final double width = constraints.maxWidth.isFinite ? constraints.maxWidth : minColumnWidth;
    final int n = BhorMasonry.columnsFor(width, minColumnWidth: minColumnWidth, maxColumns: maxColumns, gap: gap);
    final double colW = math.max(0, (width - gap * (n - 1)) / n);
    final List<double> heights = List<double>.filled(n, 0);
    final BoxConstraints childBox = BoxConstraints.tightFor(width: colW);
    bool any = false;
    RenderBox? child = firstChild;
    while (child != null) {
      final _MasonryParentData pd = child.parentData! as _MasonryParentData;
      final Size size;
      if (dry) {
        size = child.getDryLayout(childBox);
      } else {
        child.layout(childBox, parentUsesSize: true);
        size = child.size;
      }
      int col = 0;
      for (int i = 1; i < n; i++) {
        if (heights[i] < heights[col] - 0.5) col = i;
      }
      if (!dry) pd.offset = Offset(col * (colW + gap), heights[col]);
      heights[col] += size.height + gap;
      any = true;
      child = pd.nextSibling;
    }
    final double tallest = any ? heights.reduce(math.max) - gap : 0;
    return constraints.constrain(Size(width, math.max(0, tallest)));
  }

  @override
  void performLayout() {
    size = _layout(constraints, dry: false);
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) => _layout(constraints, dry: true);

  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) => minColumnWidth;

  @override
  double computeMinIntrinsicHeight(double width) => _layout(BoxConstraints(maxWidth: width), dry: true).height;

  @override
  double computeMaxIntrinsicHeight(double width) => computeMinIntrinsicHeight(width);

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
