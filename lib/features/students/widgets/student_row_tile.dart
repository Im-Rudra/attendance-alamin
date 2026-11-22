// One student in the list (phone / medium / list pane), the dues badge shared
// with the data table, and the desktop right-click menu.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/widgets/theme_mapping.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/features/payments/payments_entry.dart';
import 'package:attendance_alamin/features/students/controllers/student_nav.dart';
import 'package:attendance_alamin/features/students/controllers/student_providers.dart';
import 'package:attendance_alamin/features/students/students_entry.dart';
import 'package:attendance_alamin/features/students/widgets/student_avatar.dart';

/// The worst-level badge of a student's open dues (grey money for a student who
/// left, nothing when nothing is open).
class StudentDuesBadge extends StatelessWidget {
  const StudentDuesBadge({super.key, required this.dues, this.compact = true});

  final StudentDues? dues;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final StudentDues? d = dues;
    if (d == null) return const SizedBox.shrink();
    final DueLevel? worst = d.worst;
    if (worst == null) {
      return Text(
        context.l10n.stuDuesGrey(context.fmt.money(d.totalOutstanding)),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.bhor.type.label.copyWith(color: context.bhor.colors.text2),
      );
    }
    final l10n = context.l10n;
    final fmt = context.fmt;
    final List<String> parts = <String>[worst.label(l10n)];
    if (d.worstDay != null && worst != DueLevel.upcoming) {
      parts.add(l10n.uiDayCount(fmt.number(d.worstDay!)));
    }
    if (!compact && d.openDueMonths > 1) parts.add(l10n.uiMonthsDue(fmt.number(d.openDueMonths)));
    return BhorTag.severity(level: worst.severityLevel, label: parts.join(' · '), icon: worst.icon);
  }
}

/// One student in the list. The subtitle (roll, "subject · batch" labels) wraps
/// onto further lines rather than being clipped, so it is drawn here instead of
/// by [BhorListRow], whose subtitle is a single ellipsized line.
class StudentRowTile extends StatelessWidget {
  const StudentRowTile({
    super.key,
    required this.row,
    required this.selected,
    required this.onTap,
    this.last = false,
  });

  final StudentRow row;
  final bool selected;
  final VoidCallback onTap;

  /// The last row of a list draws no divider.
  final bool last;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final Student s = row.student;
    final String? roll = s.roll;
    final bool left = s.status == StudentStatus.left;
    final String rollText = roll == null || roll.isEmpty ? '' : context.fmt.digits(roll);
    final String subtitle = <String>[
      if (rollText.isNotEmpty) rollText,
      left
          ? (s.leftDate == null
              ? l10n.stuStatusLeft
              : l10n.stuLeftOn(context.fmt.date(s.leftDate!)))
          : row.batchesText(l10n),
    ].where((String t) => t.isNotEmpty).join(' · ');
    final double minH = context.bhorIsWide ? BhorSize.minTap : BhorSize.phoneRow;
    final Widget? trailing = row.dues == null
        ? null
        : ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 170),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerEnd,
              child: StudentDuesBadge(dues: row.dues),
            ),
          );
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapUp: (TapUpDetails d) => showStudentContextMenu(context, d.globalPosition, row),
      child: BhorPressable(
        onTap: onTap,
        selected: selected,
        semanticLabel: subtitle.isEmpty ? s.name : '${s.name}, $subtitle',
        scaleOnPress: false,
        radius: 0,
        builder: (BuildContext context, BhorStates st) => AnimatedContainer(
          duration: BhorMotion.of(context, BhorMotion.instant),
          constraints: BoxConstraints(minHeight: minH),
          color: selected ? c.accentTint : (st.hovered || st.pressed ? c.soft : c.soft.withValues(alpha: 0)),
          child: Stack(
            alignment: AlignmentDirectional.centerStart,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s16, vertical: 8),
                child: Row(
                  children: <Widget>[
                    StudentAvatar(student: s, size: 40),
                    const SizedBox(width: BhorSpace.s12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(s.name, style: b.type.bodyStrong),
                          if (subtitle.isNotEmpty) Text(subtitle, style: b.type.meta),
                        ],
                      ),
                    ),
                    if (trailing != null) ...<Widget>[const SizedBox(width: BhorSpace.s12), trailing],
                  ],
                ),
              ),
              if (!last)
                PositionedDirectional(
                  start: BhorSpace.s16 + 36 + BhorSpace.s12,
                  end: 0,
                  bottom: 0,
                  height: 1,
                  child: ColoredBox(color: c.line),
                ),
              Positioned.fill(child: BhorSelectionBar(selected: selected, inset: BhorSpace.s8)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Desktop right-click menu on a student (UX 3b): open · collect · copy
/// number · enrol in another batch · mark left. One menu component with icons
/// (G8); "mark left" is the destructive item.
Future<void> showStudentContextMenu(
  BuildContext context,
  Offset position,
  StudentRow row,
) {
  final l10n = context.l10n;
  final Student s = row.student;
  final String? number = s.callNumber;
  final bool active = s.status == StudentStatus.active;
  return showBhorMenu(
    context,
    items: <BhorMenuItem>[
      BhorMenuItem(
        icon: BhorIcons.students,
        label: l10n.stuMenuOpen,
        onTap: () => stuGo(context, Routes.student(s.id)),
      ),
      BhorMenuItem(
        icon: BhorIcons.takeMoney,
        label: l10n.stuCollect,
        onTap: () => showCollectPaymentSheet(context, studentId: s.id),
      ),
      if (number != null)
        BhorMenuItem(
          icon: BhorIcons.copy,
          label: l10n.commonCopyNumber,
          onTap: () async {
            final String copied = l10n.commonCopied;
            await Clipboard.setData(ClipboardData(text: number));
            if (context.mounted) BhorToast.show(context, message: copied);
          },
        ),
      if (active)
        BhorMenuItem(
          icon: BhorIcons.add,
          label: l10n.stuEnrollOther,
          onTap: () => showEnrollSheet(context, studentId: s.id),
        ),
      if (active)
        BhorMenuItem(
          icon: BhorIcons.leftStudents,
          label: l10n.stuMenuLeft,
          destructive: true,
          onTap: () => showMarkLeftDialog(context, studentId: s.id),
        ),
    ],
  );
}
