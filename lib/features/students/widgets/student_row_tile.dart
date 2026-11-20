// One student in the list (phone / medium / list pane), the dues badge shared
// with the data table, and the desktop right-click menu.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
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
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(color: context.aurora.textSecondary),
      );
    }
    return SeverityBadge(
      level: worst,
      dayInDue: d.worstDay,
      monthCount: d.openDueMonths,
      compact: compact,
    );
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
    final tokens = context.aurora;
    final l10n = context.l10n;
    final TextTheme tt = Theme.of(context).textTheme;
    final Student s = row.student;
    final String? roll = s.roll;
    final bool left = s.status == StudentStatus.left;
    final String subtitle = left
        ? (s.leftDate == null
            ? l10n.stuStatusLeft
            : l10n.stuLeftOn(context.fmt.date(s.leftDate!)))
        : batchNames(row.batches);
    return Semantics(
      container: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onSecondaryTapUp: (TapUpDetails d) =>
            showStudentContextMenu(context, d.globalPosition, row),
        child: Material(
          color: selected ? tokens.accentContainer : Colors.transparent,
          child: InkWell(
            onTap: onTap,
            hoverColor: tokens.track,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: <Widget>[
                    StudentAvatar(student: s, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            roll == null || roll.isEmpty
                                ? s.name
                                : '${context.fmt.digits(roll)} · ${s.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.titleMedium
                                ?.copyWith(color: tokens.textPrimary),
                          ),
                          if (subtitle.isNotEmpty)
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.labelMedium
                                  ?.copyWith(color: tokens.textSecondary),
                            ),
                        ],
                      ),
                    ),
                    if (row.dues != null) ...<Widget>[
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 170),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerEnd,
                          child: StudentDuesBadge(dues: row.dues),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
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
  final RenderObject? overlay =
      Overlay.maybeOf(context)?.context.findRenderObject();
  if (overlay is! RenderBox) return;
  final Student s = row.student;
  final String? number = s.callNumber;
  final bool active = s.status == StudentStatus.active;
  final _MenuAction? choice = await showMenu<_MenuAction>(
    context: context,
    position: RelativeRect.fromRect(
      Rect.fromLTWH(position.dx, position.dy, 0, 0),
      Offset.zero & overlay.size,
    ),
    items: <PopupMenuEntry<_MenuAction>>[
      PopupMenuItem<_MenuAction>(
        value: _MenuAction.open,
        child: Text(l10n.stuMenuOpen),
      ),
      PopupMenuItem<_MenuAction>(
        value: _MenuAction.collect,
        child: Text(l10n.stuCollect),
      ),
      if (number != null)
        PopupMenuItem<_MenuAction>(
          value: _MenuAction.copy,
          child: Text(l10n.commonCopyNumber),
        ),
      if (active)
        PopupMenuItem<_MenuAction>(
          value: _MenuAction.enroll,
          child: Text(l10n.stuEnrollOther),
        ),
      if (active)
        PopupMenuItem<_MenuAction>(
          value: _MenuAction.left,
          child: Text(l10n.stuMenuLeft),
        ),
    ],
  );
  if (choice == null || !context.mounted) return;
  switch (choice) {
    case _MenuAction.open:
      stuGo(context, Routes.student(s.id));
    case _MenuAction.collect:
      await showCollectPaymentSheet(context, studentId: s.id);
    case _MenuAction.copy:
      final ScaffoldMessengerState? messenger =
          ScaffoldMessenger.maybeOf(context);
      final String copied = l10n.commonCopied;
      await Clipboard.setData(ClipboardData(text: number ?? ''));
      messenger?.showSnackBar(SnackBar(content: Text(copied)));
    case _MenuAction.enroll:
      await showEnrollSheet(context, studentId: s.id);
    case _MenuAction.left:
      await showMarkLeftDialog(context, studentId: s.id);
  }
}
