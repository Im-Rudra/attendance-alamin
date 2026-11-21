// One roll-call row (UX 2b): the whole row toggles present/absent, a trailing
// 48dp button toggles late, long-press / right-click / the options button
// open the status sheet (excused, note). Absent is the solid slate slab.

import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/widgets/theme_mapping.dart';
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
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final l10n = context.l10n;
    final fmt = context.fmt;
    final bool isLate = status == AttendanceStatus.late;
    final String statusText = status.label(l10n);
    final String rollText = fmt.number(roll);
    final VoidCallback? tap = enabled ? onToggle : null;
    final VoidCallback? lateTap = enabled ? onLate : null;
    final VoidCallback? menu = enabled ? onMenu : null;
    final String hint = status == AttendanceStatus.absent ? l10n.a11yHintMarkPresent : l10n.a11yHintMarkAbsent;

    // Fill, text, icon and edge of the row per status (hairline, no shadow).
    final (Color fill, Color text, Color icon, Color edge) = switch (status) {
      AttendanceStatus.present => (c.surface, c.text, c.ok, c.line),
      AttendanceStatus.absent => (c.absent, c.onAbsent, c.onAbsent, c.absent),
      AttendanceStatus.late => (c.lateBg, c.lateText, c.lateText, c.lateText.withValues(alpha: 0.4)),
      AttendanceStatus.leave => (c.surface2, c.text2, c.text2, c.line),
    };

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final bool menuButton = dense && box.maxWidth >= 360 && menu != null;
        final Widget label = Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(status.icon, color: icon, size: 20),
            const SizedBox(width: BhorSpace.s4),
            Text(
              // Always the full word (never "উ/অ/দে"): the name shrinks first.
              statusText,
              maxLines: 1,
              softWrap: false,
              style: b.type.label.copyWith(color: text),
            ),
          ],
        );

        final Widget info = dense
            ? Row(
                children: <Widget>[
                  SizedBox(
                    width: 28,
                    child: Text(rollText, maxLines: 1, style: b.type.body.copyWith(color: text)),
                  ),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: b.type.heading.copyWith(color: text),
                    ),
                  ),
                  const SizedBox(width: BhorSpace.s8),
                  label,
                ],
              )
            : Row(
                children: <Widget>[
                  BhorAvatar(name: name, size: 40),
                  const SizedBox(width: BhorSpace.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: b.type.heading.copyWith(color: text),
                        ),
                        Text(rollText, style: b.type.meta.copyWith(color: text)),
                      ],
                    ),
                  ),
                  const SizedBox(width: BhorSpace.s8),
                  label,
                ],
              );

        final double height = dense ? 52 : 64;
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
          child: Listener(
            onPointerDown: menu == null
                ? null
                : (PointerDownEvent e) {
                    if (e.buttons == kSecondaryButton) menu();
                  },
            child: BhorPressable(
              onTap: tap,
              onLongPress: menu,
              radius: BhorRadius.card,
              scaleOnPress: false,
              showFocusRing: false,
              builder: (BuildContext context, BhorStates s) => Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: dense ? BhorSpace.s12 : BhorSpace.s12,
                  vertical: dense ? BhorSpace.s4 : BhorSpace.s8,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: height - (dense ? 8 : 16)),
                  child: Align(alignment: AlignmentDirectional.centerStart, child: info),
                ),
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
            height: height,
            child: Center(
              child: BhorPressable(
                onTap: lateTap,
                radius: BhorRadius.chip,
                builder: (BuildContext context, BhorStates s) => Container(
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isLate ? c.lateBg : (s.hovered ? c.surface2 : c.surface),
                    borderRadius: BorderRadius.circular(BhorRadius.chip),
                    border: Border.all(color: isLate ? c.lateText : c.line),
                  ),
                  child: Text(
                    l10n.uiAttLate,
                    maxLines: 1,
                    style: b.type.label.copyWith(color: isLate ? c.lateText : c.text),
                  ),
                ),
              ),
            ),
          ),
        );

        return Container(
          constraints: BoxConstraints(minHeight: height),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(BhorRadius.card),
            border: Border.all(color: focused ? c.accent : edge, width: focused ? 2 : 1),
          ),
          child: Row(
            children: <Widget>[
              Expanded(child: main),
              if (menuButton)
                BhorIconButton(
                  semanticLabel: l10n.rollRowMenu,
                  icon: Icons.more_vert,
                  color: text,
                  onPressed: menu,
                ),
              lateButton,
            ],
          ),
        );
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
  return showBhorSheet<RollMenuChoice>(
    context,
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
    final BhorThemeData b = context.bhor;
    final List<AttendanceStatus> all = AttendanceStatus.values;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: BhorSpace.s8),
            child: Semantics(
              header: true,
              child: Text(l10n.rollStatusSheetTitle(name), style: b.type.title),
            ),
          ),
          for (final AttendanceStatus s in all)
            BhorListRow(
              leading: Icon(s.icon, color: _iconColor(b.colors, s)),
              title: s.label(l10n),
              trailing: s == current ? Icon(Icons.check, color: b.colors.accent) : null,
              onTap: () => Navigator.of(context).pop(RollMenuChoice.status(s)),
            ),
          BhorListRow(
            leading: const Icon(Icons.edit_note),
            title: l10n.rollMenuNote,
            divider: false,
            onTap: () => Navigator.of(context).pop(const RollMenuChoice.note()),
          ),
          const SizedBox(height: BhorSpace.s8),
        ],
      ),
    );
  }

  Color _iconColor(BhorColors c, AttendanceStatus s) => switch (s) {
        AttendanceStatus.present => c.ok,
        AttendanceStatus.absent => c.absent,
        AttendanceStatus.late => c.lateText,
        AttendanceStatus.leave => c.text2,
      };
}
