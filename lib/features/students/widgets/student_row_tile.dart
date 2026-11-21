// One student in the list (phone / medium / list pane), the dues badge shared
// with the data table, and the desktop right-click menu.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/widgets/theme_mapping.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
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

String batchNames(List<Batch> batches) =>
    batches.map((Batch b) => b.name).join(' · ');

class StudentRowTile extends StatelessWidget {
  const StudentRowTile({
    super.key,
    required this.row,
    required this.selected,
    required this.onTap,
  });

  final StudentRow row;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
          : batchNames(row.batches),
    ].where((String t) => t.isNotEmpty).join(' · ');
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapUp: (TapUpDetails d) => showStudentContextMenu(context, d.globalPosition, row),
      child: BhorListRow(
        selected: selected,
        leading: StudentAvatar(student: s, size: 40),
        title: s.name,
        subtitle: subtitle.isEmpty ? null : subtitle,
        onTap: onTap,
        trailing: row.dues == null
            ? null
            : ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 170),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerEnd,
                  child: StudentDuesBadge(dues: row.dues),
                ),
              ),
      ),
    );
  }
}

enum _MenuAction { open, collect, copy, enroll, left }

/// Desktop right-click menu on a student (UX 3b): open · collect · copy
/// number · enrol in another batch · mark left.
Future<void> showStudentContextMenu(
  BuildContext context,
  Offset position,
  StudentRow row,
) async {
  final l10n = context.l10n;
  final Student s = row.student;
  final String? number = s.callNumber;
  final bool active = s.status == StudentStatus.active;
  final _MenuAction? choice = await showBhorPanel<_MenuAction>(
    context,
    kind: BhorPanelKind.list,
    width: 380,
    title: s.name,
    builder: (BuildContext ctx) {
      final List<(_MenuAction, String)> items = <(_MenuAction, String)>[
        (_MenuAction.open, l10n.stuMenuOpen),
        (_MenuAction.collect, l10n.stuCollect),
        if (number != null) (_MenuAction.copy, l10n.commonCopyNumber),
        if (active) (_MenuAction.enroll, l10n.stuEnrollOther),
        if (active) (_MenuAction.left, l10n.stuMenuLeft),
      ];
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int i = 0; i < items.length; i++)
            BhorListRow(
              title: items[i].$2,
              divider: i != items.length - 1,
              onTap: () => Navigator.of(ctx).pop(items[i].$1),
            ),
        ],
      );
    },
  );
  if (choice == null || !context.mounted) return;
  switch (choice) {
    case _MenuAction.open:
      stuGo(context, Routes.student(s.id));
    case _MenuAction.collect:
      await showCollectPaymentSheet(context, studentId: s.id);
    case _MenuAction.copy:
      final String copied = l10n.commonCopied;
      await Clipboard.setData(ClipboardData(text: number ?? ''));
      if (context.mounted) BhorToast.show(context, message: copied);
    case _MenuAction.enroll:
      await showEnrollSheet(context, studentId: s.id);
    case _MenuAction.left:
      await showMarkLeftDialog(context, studentId: s.id);
  }
}
