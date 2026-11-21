// Small Bhor compositions shared by the attendance widgets: the status tag of
// an attendance mark, the sticky save bar of the roll call and the red
// "clashing class" card (the library has no equivalents; docs/council/11).

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/widgets/theme_mapping.dart';
import 'package:attendance_alamin/domain/models/enums.dart';

/// Tag tone of an attendance status.
BhorTone attendanceTone(AttendanceStatus s) => switch (s) {
      AttendanceStatus.present => BhorTone.ok,
      AttendanceStatus.absent => BhorTone.absent,
      AttendanceStatus.late => BhorTone.late,
      AttendanceStatus.leave => BhorTone.neutral,
    };

/// A status as a tag: icon + word (never colour alone). [short] uses the
/// one-letter form.
Widget attendanceTag(BuildContext context, AttendanceStatus s, {bool short = false}) {
  final l10n = context.l10n;
  return BhorTag(
    label: short ? s.shortLabel(l10n) : s.label(l10n),
    tone: attendanceTone(s),
    icon: s.icon,
  );
}

/// The bar pinned under the roll call: optional live counts, the save button
/// and, when it is disabled, the reason.
class RollSaveBar extends StatelessWidget {
  const RollSaveBar({
    super.key,
    required this.label,
    this.onPressed,
    this.disabledReason,
    this.summary,
  });

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;

  /// Shown under a disabled button so the teacher knows what is missing.
  final String? disabledReason;

  /// Live counts, e.g. "28 present, 2 absent".
  final String? summary;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: b.colors.surface,
        border: Border(top: BorderSide(color: b.colors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(BhorSpace.s16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (summary != null) ...<Widget>[
                Semantics(
                  liveRegion: true,
                  child: Text(summary!, textAlign: TextAlign.center, style: b.type.meta),
                ),
                const SizedBox(height: BhorSpace.s8),
              ],
              BhorButton(
                label: label,
                expand: true,
                onPressed: onPressed,
                disabledReason: disabledReason,
              ),
              if (onPressed == null && disabledReason != null) ...<Widget>[
                const SizedBox(height: BhorSpace.s8),
                Text(disabledReason!, textAlign: TextAlign.center, style: b.type.meta),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One fix offered by [RollClashCard].
class RollClashFix {
  const RollClashFix({required this.label, required this.onTap, this.primary = false});

  final String label;
  final VoidCallback onTap;
  final bool primary;
}

/// The clashing classes of an ad-hoc class time with 1-2 fix buttons. A live
/// region, so it is announced when it appears.
class RollClashCard extends StatelessWidget {
  const RollClashCard({super.key, required this.lines, this.moreCount = 0, this.fixes = const <RollClashFix>[]});

  final List<String> lines;
  final int moreCount;
  final List<RollClashFix> fixes;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final l10n = context.l10n;
    final Color on = b.colors.danger;
    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: b.colors.dangerBg,
          borderRadius: BorderRadius.circular(BhorRadius.card),
          border: Border.all(color: on.withValues(alpha: 0.35)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(BhorSpace.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.warning_amber_rounded, color: on, size: 24),
                  const SizedBox(width: BhorSpace.s8),
                  Expanded(child: Text(l10n.uiConflictTitle, style: b.type.heading.copyWith(color: on))),
                ],
              ),
              const SizedBox(height: BhorSpace.s8),
              for (final String line in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: BhorSpace.s4),
                  child: Text(line, style: b.type.body.copyWith(color: on)),
                ),
              if (moreCount > 0)
                Text(l10n.uiConflictMore(context.fmt.number(moreCount)), style: b.type.label.copyWith(color: on)),
              if (fixes.isNotEmpty) ...<Widget>[
                const SizedBox(height: BhorSpace.s8),
                Wrap(
                  spacing: BhorSpace.s8,
                  runSpacing: BhorSpace.s8,
                  children: <Widget>[
                    for (final RollClashFix f in fixes)
                      BhorButton(
                        label: f.label,
                        variant: f.primary ? BhorButtonVariant.danger : BhorButtonVariant.secondary,
                        onPressed: f.onTap,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
