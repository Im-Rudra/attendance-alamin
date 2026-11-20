// Month state chip and the scrollable 12-month strip (UX 5: "Where it shows").

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/dashed_border.dart';
import 'package:attendance_alamin/app/widgets/theme_mapping.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';

class _MonthLook {
  const _MonthLook({
    required this.fill,
    required this.text,
    required this.icon,
    required this.label,
    this.border,
    this.dashed = false,
    this.borderWidth = 1,
  });

  final Color fill;
  final Color text;
  final IconData icon;
  final String label;
  final Color? border;
  final bool dashed;
  final double borderWidth;
}

_MonthLook _lookFor(BuildContext context, MonthDue due) {
  final sev = context.severity;
  final l10n = context.l10n;
  final fmt = context.fmt;
  switch (due.state) {
    case MonthState.paid:
      final bool advance = !due.isDue;
      return _MonthLook(
        fill: sev.paidFill,
        text: sev.paidText,
        icon: advance ? Icons.add_circle : Icons.check_circle,
        label: advance ? l10n.uiStateAdvance : l10n.uiStatePaid,
      );
    case MonthState.waived:
      return _MonthLook(
        fill: sev.waivedFill,
        text: sev.waivedText,
        icon: Icons.do_not_disturb_on,
        label: l10n.uiStateWaived,
        border: sev.waivedBorder,
        dashed: true,
      );
    case MonthState.free:
      return _MonthLook(
        fill: sev.notDueFill,
        text: sev.notDueText,
        icon: Icons.circle_outlined,
        label: l10n.uiStateFree,
      );
    case MonthState.partial:
    case MonthState.unpaid:
      final DueLevel? level = due.level;
      if (level == null || level == DueLevel.upcoming) {
        return _MonthLook(
          fill: sev.notDueFill,
          text: sev.notDueText,
          icon: Icons.schedule,
          label: due.state == MonthState.partial
              ? l10n.uiPartialLeft(fmt.money(due.remaining))
              : l10n.uiLevelUpcoming,
          border: sev.notDueText.withValues(alpha: 0.4),
        );
      }
      final SeverityLevel s = level.severityLevel;
      return _MonthLook(
        fill: sev.badgeFill(s),
        text: sev.badgeText(s),
        icon: level.icon,
        label: due.state == MonthState.partial
            ? l10n.uiPartialLeft(fmt.money(due.remaining))
            : level.label(l10n),
        border: sev.badgeBorder(s),
        borderWidth: sev.badgeBorderWidth(s),
      );
  }
}

/// One month of a student's strip: month name plus state icon and word.
class MonthStateChip extends StatelessWidget {
  const MonthStateChip({super.key, required this.due, this.selected = false, this.onTap});

  final MonthDue due;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final fmt = context.fmt;
    final _MonthLook look = _lookFor(context, due);
    final TextTheme tt = Theme.of(context).textTheme;
    const double radius = AuroraMetrics.radiusChip + 4;

    Widget body = Container(
      constraints: const BoxConstraints(minWidth: 88, minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: look.fill,
        borderRadius: BorderRadius.circular(radius),
        border: (look.border != null && !look.dashed)
            ? Border.all(color: look.border!, width: look.borderWidth)
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            fmt.monthShort(due.month.month),
            style: tt.labelMedium?.copyWith(color: look.text, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(look.icon, size: 14, color: look.text),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  look.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.labelSmall?.copyWith(color: look.text),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (look.dashed && look.border != null) {
      body = DashedBorder(color: look.border!, radius: radius, child: body);
    }
    if (selected) {
      body = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius + 3),
          border: Border.all(color: tokens.accent, width: 2),
        ),
        child: Padding(padding: const EdgeInsets.all(2), child: body),
      );
    }
    if (onTap != null) {
      body = Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: body,
        ),
      );
    }
    return Semantics(
      container: true,
      button: onTap != null,
      selected: selected,
      label: context.l10n.a11yMonthChip(fmt.monthYear(due.month), look.label),
      excludeSemantics: true,
      onTap: onTap,
      child: body,
    );
  }
}

/// Horizontally scrollable strip of [MonthStateChip]s.
class MonthStrip extends StatelessWidget {
  const MonthStrip({super.key, required this.months, this.onTap});

  final List<MonthDue> months;
  final ValueChanged<YearMonth>? onTap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < months.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 8),
            MonthStateChip(
              key: ValueKey<int>(months[i].month.toInt()),
              due: months[i],
              onTap: onTap == null ? null : () => onTap!(months[i].month),
            ),
          ],
        ],
      ),
    );
  }
}
