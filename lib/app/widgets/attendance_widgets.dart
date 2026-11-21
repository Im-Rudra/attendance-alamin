// Attendance status chip and the big roll-call toggle row (UX 6, 2b).

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/dashed_border.dart';
import 'package:attendance_alamin/app/widgets/initials_avatar.dart';
import 'package:attendance_alamin/app/widgets/theme_mapping.dart';
import 'package:attendance_alamin/domain/models/enums.dart';

class AttendanceStatusChip extends StatelessWidget {
  const AttendanceStatusChip({super.key, required this.status, this.short = false});

  final AttendanceStatus status;

  /// One or two letters (P / উ) instead of the full word; the icon stays.
  final bool short;

  @override
  Widget build(BuildContext context) {
    final att = context.attendance;
    final l10n = context.l10n;
    final AttendanceKind k = status.kind;
    final Color text = att.text(k);
    final Color? border = att.border(k);
    final bool dashed = status == AttendanceStatus.leave;
    final String label = status.label(l10n);

    Widget chip = Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: att.fill(k),
        borderRadius: BorderRadius.circular(AuroraMetrics.radiusPill),
        border: (border != null && !dashed) ? Border.all(color: border) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(status.icon, size: 16, color: text),
          const SizedBox(width: 4),
          Text(
            short ? status.shortLabel(l10n) : label,
            maxLines: 1,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: text),
          ),
        ],
      ),
    );
    if (dashed && border != null) {
      chip = DashedBorder(color: border, radius: 14, child: chip);
    }
    return Semantics(container: true, label: label, excludeSemantics: true, child: chip);
  }
}

/// One roll-call row: the whole row toggles present/absent, a trailing 48dp
/// button toggles late. Absent is the solid slate slab (UX 6).
class AttendanceToggleRow extends StatelessWidget {
  const AttendanceToggleRow({
    super.key,
    required this.name,
    required this.roll,
    required this.status,
    this.onToggle,
    this.onLateToggle,
  });

  final String name;
  final int roll;

  /// Null = not marked yet.
  final AttendanceStatus? status;
  final VoidCallback? onToggle;
  final VoidCallback? onLateToggle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final att = context.attendance;
    final l10n = context.l10n;
    final fmt = context.fmt;
    final AttendanceStatus? s = status;
    final Color fill = s == null ? tokens.surfaceDense : att.fill(s.kind);
    final Color text = s == null ? tokens.textPrimary : att.text(s.kind);
    final Color? border = s == null ? null : att.border(s.kind);
    final TextTheme tt = Theme.of(context).textTheme;
    final bool isLate = s == AttendanceStatus.late;
    final String statusText = s == null ? '' : s.label(l10n);
    final String hint =
        s == AttendanceStatus.absent ? l10n.a11yHintMarkPresent : l10n.a11yHintMarkAbsent;
    final BorderRadius br = BorderRadius.circular(AuroraMetrics.radiusDenseList);

    return Material(
      color: fill,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: br,
        side: border == null ? BorderSide.none : BorderSide(color: border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Semantics(
                container: true,
                button: onToggle != null,
                label: l10n.a11yStudentRollRow(name, fmt.number(roll), statusText),
                hint: onToggle == null ? null : hint,
                excludeSemantics: true,
                onTap: onToggle,
                child: InkWell(
                  onTap: onToggle,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: <Widget>[
                        InitialsAvatar(name: name, background: text.withValues(alpha: 0.16), foreground: text),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: tt.titleMedium?.copyWith(color: text),
                              ),
                              Text(fmt.number(roll), style: tt.bodyMedium?.copyWith(color: text)),
                            ],
                          ),
                        ),
                        if (s != null) ...<Widget>[
                          const SizedBox(width: 8),
                          Icon(s.icon, color: text, size: 20),
                          const SizedBox(width: 4),
                          Text(statusText, style: tt.labelMedium?.copyWith(color: text)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Semantics(
              container: true,
              button: true,
              toggled: isLate,
              label: l10n.uiMarkLate,
              excludeSemantics: true,
              onTap: onLateToggle,
              child: SizedBox(
                width: 64,
                height: 64,
                child: Center(
                  child: Material(
                    color: isLate ? att.fill(AttendanceKind.late) : tokens.surfaceDense,
                    shape: StadiumBorder(
                      side: BorderSide(
                        color: isLate ? att.text(AttendanceKind.late) : tokens.hairline,
                      ),
                    ),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: onLateToggle,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              l10n.uiAttLate,
                              style: tt.labelMedium?.copyWith(
                                color: isLate ? att.text(AttendanceKind.late) : tokens.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
