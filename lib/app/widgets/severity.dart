// Payment-warning widgets (UX 5): badge, row edge bar, 10-segment bar.
// Never colour alone: every badge carries an icon and a word.

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/theme_mapping.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';

class SeverityBadge extends StatelessWidget {
  const SeverityBadge({
    super.key,
    required this.level,
    this.dayInDue,
    this.monthCount = 1,
    this.partialRemaining,
    this.compact = false,
  });

  final DueLevel level;

  /// 1..10 inside the window; shown as "7 days". Null hides the count.
  final int? dayInDue;

  /// More than 1 adds "3 months due".
  final int monthCount;

  /// Remaining taka of a partly paid month; adds "Partial, X left".
  final int? partialRemaining;

  /// 24dp tall, label only (plus day count).
  final bool compact;

  /// The text the badge shows (and announces).
  String labelText(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final List<String> parts = <String>[level.label(l10n)];
    if (dayInDue != null && level != DueLevel.upcoming) {
      parts.add(l10n.uiDayCount(fmt.number(dayInDue!)));
    }
    if (!compact) {
      if (monthCount > 1) parts.add(l10n.uiMonthsDue(fmt.number(monthCount)));
      if (partialRemaining != null) parts.add(l10n.uiPartialLeft(fmt.money(partialRemaining!)));
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final sev = context.severity;
    final SeverityLevel s = level.severityLevel;
    final bool solid = level == DueLevel.overdue;
    final Color fill = sev.badgeFill(s);
    final Color text = sev.badgeText(s);
    final Color? border = sev.badgeBorder(s);
    final TextStyle? base = Theme.of(context).textTheme.labelMedium;
    final String label = labelText(context);
    final double h = compact ? 24 : 28;
    return Semantics(
      container: true,
      label: label,
      excludeSemantics: true,
      child: Container(
        constraints: BoxConstraints(minHeight: h),
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: 2),
        decoration: ShapeDecoration(
          color: fill,
          shape: StadiumBorder(
            side: border == null
                ? BorderSide.none
                : BorderSide(color: border, width: sev.badgeBorderWidth(s)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(level.icon, size: compact ? 14 : 16, color: text),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: base?.copyWith(
                  color: text,
                  fontWeight: solid ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 4dp leading edge bar of a dues row. Decorative: excluded from semantics.
class LevelEdgeBar extends StatelessWidget {
  const LevelEdgeBar({super.key, required this.level});

  /// Null draws nothing visible (keeps rows aligned).
  final DueLevel? level;

  @override
  Widget build(BuildContext context) {
    final DueLevel? l = level;
    return ExcludeSemantics(
      child: SizedBox(
        width: 4,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: l == null ? Colors.transparent : context.severity.hue(l.severityLevel),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

/// 10 segments (day 1..10 since due). Passed days are filled in their level
/// hue, future days use `track`, today's segment is ringed. Beyond day 10
/// ([todayDay] null) every segment is filled. A solid overdue badge sits at the
/// right end when [overdueCount] > 0.
class EscalationBar extends StatelessWidget {
  const EscalationBar({super.key, required this.todayDay, this.overdueCount = 0});

  /// 1..10, or null when the oldest unpaid fee is beyond day 10.
  final int? todayDay;
  final int overdueCount;

  static const int segments = 10;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final sev = context.severity;
    final l10n = context.l10n;
    final fmt = context.fmt;
    final int? today = todayDay;
    final TextStyle? cap =
        Theme.of(context).textTheme.labelMedium?.copyWith(color: tokens.textSecondary);

    final Widget bar = Row(
      children: <Widget>[
        for (int d = 1; d <= segments; d++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: d == 1 ? 0 : 3),
              child: _Segment(
                key: ValueKey<String>('escalation-segment-$d'),
                color: (today == null || d <= today) ? sev.segment(d) : tokens.track,
                ringed: today == d,
                ring: tokens.textPrimary,
              ),
            ),
          ),
      ],
    );

    final Widget scale;
    if (today == null) {
      scale = Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(fmt.number(1), style: cap),
          Text(fmt.number(segments), style: cap),
        ],
      );
    } else {
      final double x = -1 + 2 * (today - 0.5) / segments;
      scale = Stack(
        alignment: Alignment.center,
        children: <Widget>[
          if (today > 2) Align(alignment: Alignment.centerLeft, child: Text(fmt.number(1), style: cap)),
          if (today < 9)
            Align(alignment: Alignment.centerRight, child: Text(fmt.number(segments), style: cap)),
          Align(
            alignment: Alignment(x, 0),
            child: Text(
              l10n.uiEscalationToday(fmt.number(today)),
              style: cap?.copyWith(color: tokens.textPrimary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    }

    final String semantic =
        today == null ? l10n.uiEscalationBeyond : l10n.a11yEscalationDay(fmt.number(today));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Semantics(
                container: true,
                label: semantic,
                excludeSemantics: true,
                child: SizedBox(height: 22, child: bar),
              ),
            ),
            if (overdueCount > 0) ...<Widget>[
              const SizedBox(width: 12),
              _OverdueCountBadge(count: overdueCount),
            ],
          ],
        ),
        const SizedBox(height: 4),
        ExcludeSemantics(child: SizedBox(height: 22, child: scale)),
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({super.key, required this.color, required this.ringed, required this.ring});

  final Color color;
  final bool ringed;
  final Color ring;

  @override
  Widget build(BuildContext context) {
    // Every segment has the same 22dp outer box so the row never jumps; the
    // ringed one draws a 2px ring with a 2px gap around its 14dp fill.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: ringed ? Border.all(color: ring, width: 2) : null,
      ),
      child: Padding(
        padding: EdgeInsets.all(ringed ? 2 : 0),
        child: Center(
          child: SizedBox(
            height: 14,
            child: DecoratedBox(
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }
}

class _OverdueCountBadge extends StatelessWidget {
  const _OverdueCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final sev = context.severity;
    const SeverityLevel s = SeverityLevel.overdue;
    final Color? border = sev.badgeBorder(s);
    final String label = context.l10n.uiOverdueCount(context.fmt.number(count));
    return Semantics(
      container: true,
      label: label,
      excludeSemantics: true,
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: ShapeDecoration(
          color: sev.badgeFill(s),
          shape: StadiumBorder(
            side: border == null
                ? BorderSide.none
                : BorderSide(color: border, width: sev.badgeBorderWidth(s)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(DueLevel.overdue.icon, size: 16, color: sev.badgeText(s)),
            const SizedBox(width: 4),
            Text(
              label,
              maxLines: 1,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: sev.badgeText(s),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
