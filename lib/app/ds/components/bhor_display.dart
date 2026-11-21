// Display components: BhorTag, BhorCard (+ hero), BhorListRow,
// BhorSectionHeader, BhorAvatar, BhorProgress, BhorSkeleton, BhorEmptyState.

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/foundation/bhor_interaction.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_theme.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_tokens.dart';
import 'package:attendance_alamin/app/theme/tokens.dart' show SeverityLevel;

enum BhorTone { neutral, accent, ok, danger, late, absent }

/// Compact status tag (radius 6). Never colour alone: always a word.
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

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final (Color bg, Color fg) = severity != null
        ? (c.sevFill[severity!.index], c.sevText[severity!.index])
        : switch (tone) {
            BhorTone.neutral => (c.surface2, c.text2),
            BhorTone.accent => (c.accentTint, c.accent),
            BhorTone.ok => (c.okBg, c.ok),
            BhorTone.danger => (c.dangerBg, c.danger),
            BhorTone.late => (c.lateBg, c.lateText),
            BhorTone.absent => (c.absent, c.onAbsent),
          };
    return Semantics(
      container: true,
      label: label,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(BhorRadius.tag)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 13, color: fg),
              const SizedBox(width: 3),
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

/// Surface card with a hairline border (radius 16); `hero` paints the
/// signature gradient (radius 18, white text). Tappable when [onTap] is set.
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
          duration: BhorMotion.fast,
          padding: padding ?? const EdgeInsets.all(BhorSpace.s16),
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
      builder: (BuildContext context, BhorStates s) => box(s),
    );
  }
}

/// Dense row with a hairline divider (48 tall on phones, 44 on desktop).
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

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final double minH = context.bhorIsWide ? BhorSize.control : BhorSize.phoneRow;
    Widget row(BhorStates s) => Container(
          constraints: BoxConstraints(minHeight: minH),
          padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s16, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? c.accentTint : (s.hovered || s.pressed ? c.surface2 : null),
            border: divider ? Border(bottom: BorderSide(color: c.line)) : null,
          ),
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
              radius: 8,
              builder: (BuildContext context, BhorStates s) => ConstrainedBox(
                constraints: const BoxConstraints(minHeight: BhorSize.minTap),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s8),
                  child: Center(
                    widthFactor: 1,
                    child: Text(actionLabel!,
                        style: b.type.label.copyWith(
                          color: c.accent,
                          decoration: s.hovered ? TextDecoration.underline : TextDecoration.none,
                          decorationColor: c.accent,
                        )),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Rounded-square initials avatar (radius 9).
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
    final BorderRadius r = BorderRadius.circular(BhorRadius.avatar * size / 36);
    return Semantics(
      label: name,
      image: image != null,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: c.accentTint,
          borderRadius: r,
          border: Border.all(color: c.accentLine, width: 0.5),
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

/// Thin progress bar (0..1).
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
    return Semantics(
      label: semanticLabel,
      value: '${(v * 100).round()}%',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: SizedBox(
          height: height,
          child: Stack(
            children: <Widget>[
              Positioned.fill(child: ColoredBox(color: c.surface2)),
              AnimatedFractionallySizedBox(
                duration: BhorMotion.slow,
                curve: BhorMotion.curve,
                alignment: Alignment.centerLeft,
                widthFactor: v,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color ?? c.accent,
                    borderRadius: BorderRadius.circular(height / 2),
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

/// Loading placeholder block with a soft pulse (still when animations are off).
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
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
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
    return ExcludeSemantics(
      child: FadeTransition(
        opacity: Tween<double>(begin: 1, end: 0.55).animate(_c),
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(widget.radius)),
        ),
      ),
    );
  }
}

/// Calm empty state: icon tile, title, message and an optional action.
/// Usage: `BhorEmptyState(icon: Icons.groups, title: '...', message: '...', action: button)`.
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
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: c.accentTint,
              borderRadius: BorderRadius.circular(BhorRadius.card),
            ),
            child: Icon(icon, size: 28, color: c.accent),
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
