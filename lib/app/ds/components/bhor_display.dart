// Display components (docs/council/13-fluid-ui-spec.md): BhorTag (pill),
// BhorCard (+ hero, the only gradient), BhorList (surface card r20 with a
// line edge holding rows), BhorListRow (inset hairline, soft hover/press),
// BhorSectionHeader, BhorAvatar (circle), BhorProgress (animated fill),
// BhorSkeleton (shimmer sweep), BhorEmptyState.

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/foundation/bhor_icons.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_interaction.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_theme.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_tokens.dart';
import 'package:attendance_alamin/app/theme/tokens.dart' show SeverityLevel;

enum BhorTone { neutral, accent, ok, danger, late, absent, warn, overdue }

/// Status tag: a pill. Never colour alone: always a word.
/// Usage: `BhorTag(label: 'পরিশোধিত', tone: BhorTone.ok)` or
/// `BhorTag.severity(level: SeverityLevel.urgent, label: 'জরুরি')`.
class BhorTag extends StatelessWidget {
  const BhorTag({super.key, required this.label, this.tone = BhorTone.neutral, this.icon})
      : severity = null;

  /// Dues severity tag (honey to rose; overdue is solid raspberry, white text).
  const BhorTag.severity({super.key, required SeverityLevel level, required this.label, this.icon})
      : severity = level,
        tone = BhorTone.neutral;

  final String label;
  final BhorTone tone;
  final SeverityLevel? severity;
  final IconData? icon;

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
        severity != null ? (c.sevFill[severity!.index], c.sevText[severity!.index]) : colorsOf(c, tone);
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
/// Tappable when [onTap] is set (hover edge, press scale).
/// Usage: `BhorCard(child: ...)`, `BhorCard.hero(child: ...)`.
class BhorCard extends StatelessWidget {
  const BhorCard({super.key, required this.child, this.padding, this.onTap, this.semanticLabel})
      : hero = false;

  const BhorCard.hero({super.key, required this.child, this.padding, this.onTap, this.semanticLabel})
      : hero = true;

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final double radius = hero ? BhorRadius.hero : BhorRadius.card;
    Widget box(BhorStates s) => AnimatedContainer(
          duration: BhorMotion.of(context, BhorMotion.fast),
          curve: BhorMotion.ease,
          padding: padding ?? EdgeInsets.all(hero ? BhorSpace.s20 : BhorSpace.s16),
          decoration: BoxDecoration(
            color: hero ? null : c.surface,
            gradient: hero ? c.heroGradient : null,
            borderRadius: BorderRadius.circular(radius),
            border: hero ? null : Border.all(color: s.hovered ? c.accentLine : c.line),
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
    if (onTap == null) return box(const BhorStates());
    return BhorPressable(
      onTap: onTap,
      semanticLabel: semanticLabel,
      radius: radius,
      pressScale: 0.985,
      builder: (BuildContext context, BhorStates s) => box(s),
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
/// desktop); hover / press paint the soft fill. Money goes in [trailing]
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
                          Text(title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: b.type.bodyStrong.copyWith(color: selected ? c.accent : c.text)),
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

/// Calm empty state: icon tile, title, message and an optional action.
/// Usage: `BhorEmptyState(icon: BhorIcons.batches, title: '...', message: '...', action: button)`.
class BhorEmptyState extends StatelessWidget {
  const BhorEmptyState({super.key, required this.icon, required this.title, this.message, this.action});

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s24, vertical: BhorSpace.s32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: c.accentTint,
              borderRadius: BorderRadius.circular(BhorRadius.card),
            ),
            child: Icon(icon, size: BhorIconSize.nav + 4, color: c.accent),
          ),
          const SizedBox(height: BhorSpace.s16),
          Semantics(header: true, child: Text(title, textAlign: TextAlign.center, style: b.type.heading)),
          if (message != null) ...<Widget>[
            const SizedBox(height: BhorSpace.s4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(message!, textAlign: TextAlign.center, style: b.type.body.copyWith(color: c.text2)),
            ),
          ],
          if (action != null) ...<Widget>[const SizedBox(height: BhorSpace.s16), action!],
        ],
      ),
    );
  }
}
