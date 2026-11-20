// One roll-call row (UX 2b): the whole row toggles present/absent, a trailing
// 48dp button toggles late, long-press / right-click / the options button
// open the status sheet (excused, note). Absent is the solid slate slab.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/dashed_border.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/domain/models/enums.dart';

class RollRow extends StatelessWidget {
  const RollRow({
    super.key,
    required this.name,
    required this.roll,
    required this.status,
    this.dense = false,
    this.enabled = true,
    this.focused = false,
    this.onToggle,
    this.onLate,
    this.onMenu,
  });

  final String name;
  final int roll;
  final AttendanceStatus status;

  /// Desktop strip (52dp) instead of the phone card (64dp).
  final bool dense;

  /// False for a future date or an archived batch: nothing reacts.
  final bool enabled;

  /// The keyboard cursor is on this row.
  final bool focused;
  final VoidCallback? onToggle;
  final VoidCallback? onLate;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final att = context.attendance;
    final l10n = context.l10n;
    final fmt = context.fmt;
    final TextTheme tt = Theme.of(context).textTheme;
    final AttendanceKind kind = status.kind;
    final Color fill = att.fill(kind);
    final Color text = att.text(kind);
    final Color? border = att.border(kind);
    final bool isLate = status == AttendanceStatus.late;
    final bool leave = status == AttendanceStatus.leave;
    final String statusText = status.label(l10n);
    final String rollText = fmt.number(roll);
    final BorderRadius br = BorderRadius.circular(AuroraMetrics.radiusDenseList);
    final VoidCallback? tap = enabled ? onToggle : null;
    final VoidCallback? lateTap = enabled ? onLate : null;
    final VoidCallback? menu = enabled ? onMenu : null;
    final String hint = status == AttendanceStatus.absent ? l10n.a11yHintMarkPresent : l10n.a11yHintMarkAbsent;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final bool shortLabel = dense && c.maxWidth < 300;
        final bool menuButton = dense && c.maxWidth >= 360 && menu != null;
        final Widget label = Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(status.icon, color: text, size: 20),
            const SizedBox(width: 4),
            Text(
              shortLabel ? status.shortLabel(l10n) : statusText,
              maxLines: 1,
              style: tt.labelMedium?.copyWith(color: text),
            ),
          ],
        );

        final Widget info = dense
            ? Row(
                children: <Widget>[
                  SizedBox(
                    width: 28,
                    child: Text(rollText, maxLines: 1, style: tt.bodyMedium?.copyWith(color: text)),
                  ),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleSmall?.copyWith(color: text),
                    ),
                  ),
                  const SizedBox(width: 8),
                  label,
                ],
              )
            : Row(
                children: <Widget>[
                  InitialsAvatar(name: name),
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
                        Text(rollText, style: tt.bodyMedium?.copyWith(color: text)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  label,
                ],
              );

        final double box = dense ? 52 : 64;
        final Widget main = Semantics(
          container: true,
          button: tap != null,
          label: l10n.a11yStudentRollRow(name, rollText, statusText),
          hint: tap == null ? null : hint,
          excludeSemantics: true,
          onTap: tap,
          onLongPress: menu,
          customSemanticsActions: menu == null
              ? null
              : <CustomSemanticsAction, VoidCallback>{
                  CustomSemanticsAction(label: l10n.rollRowMenu): menu,
                },
          child: InkWell(
            canRequestFocus: false,
            onTap: tap,
            onLongPress: menu,
            onSecondaryTap: menu,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: dense ? 10 : 12, vertical: dense ? 4 : 8),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box - (dense ? 8 : 16)),
                child: Align(alignment: AlignmentDirectional.centerStart, child: info),
              ),
            ),
          ),
        );

        final Widget lateButton = Semantics(
          container: true,
          button: true,
          toggled: isLate,
          label: l10n.uiMarkLate,
          excludeSemantics: true,
          onTap: lateTap,
          child: SizedBox(
            width: dense ? 60 : 64,
            height: box,
            child: Center(
              child: Material(
                color: isLate ? att.fill(AttendanceKind.late) : tokens.surfaceDense,
                shape: StadiumBorder(
                  side: BorderSide(color: isLate ? att.text(AttendanceKind.late) : tokens.hairline),
                ),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: lateTap,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          l10n.uiAttLate,
                          maxLines: 1,
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
        );

        final BorderSide side = focused
            ? BorderSide(color: tokens.accent, width: 2)
            : (border == null || leave ? BorderSide.none : BorderSide(color: border));
        Widget card = Material(
          color: fill,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: br, side: side),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box),
            child: Row(
              children: <Widget>[
                Expanded(child: main),
                if (menuButton)
                  IconButton(
                    tooltip: l10n.rollRowMenu,
                    icon: Icon(Icons.more_vert, color: text),
                    onPressed: menu,
                  ),
                lateButton,
              ],
            ),
          ),
        );
        if (leave && border != null && !focused) {
          card = DashedBorder(color: border, radius: AuroraMetrics.radiusDenseList, child: card);
        }
        return card;
      },
    );
  }
}

/// What the status sheet returns: a new status, or "edit the class note".
class RollMenuChoice {
  const RollMenuChoice.status(AttendanceStatus this.status) : note = false;
  const RollMenuChoice.note()
      : status = null,
        note = true;

  final AttendanceStatus? status;
  final bool note;
}

Future<RollMenuChoice?> showRollStatusSheet(
  BuildContext context, {
  required String name,
  required AttendanceStatus current,
}) {
  return showModalBottomSheet<RollMenuChoice>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (BuildContext ctx) => RollStatusSheet(name: name, current: current),
  );
}

/// The sheet body (public so the screen matrix can render it directly).
class RollStatusSheet extends StatelessWidget {
  const RollStatusSheet({super.key, required this.name, required this.current});

  final String name;
  final AttendanceStatus current;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.aurora;
    final att = context.attendance;
    final TextTheme tt = Theme.of(context).textTheme;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Semantics(
              header: true,
              child: Text(
                l10n.rollStatusSheetTitle(name),
                style: tt.titleLarge?.copyWith(color: tokens.textPrimary),
              ),
            ),
          ),
          for (final AttendanceStatus s in AttendanceStatus.values)
            ListTile(
              minTileHeight: 56,
              leading: Icon(s.icon, color: att.text(s.kind)),
              title: Text(s.label(l10n)),
              trailing: s == current ? Icon(Icons.check, color: tokens.accent) : null,
              onTap: () => Navigator.of(context).pop(RollMenuChoice.status(s)),
            ),
          const Divider(height: 1),
          ListTile(
            minTileHeight: 56,
            leading: const Icon(Icons.edit_note),
            title: Text(l10n.rollMenuNote),
            onTap: () => Navigator.of(context).pop(const RollMenuChoice.note()),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
