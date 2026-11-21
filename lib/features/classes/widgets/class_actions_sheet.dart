// Per-date actions of one class (UX 2g): "à¦¶à§à¦§à§ {date}" with change time,
// cancel (undo snackbar + guardians' notice), roll call and restore.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/error_text.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/providers/schedule_providers.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/services/share_service.dart';
import 'package:attendance_alamin/app/widgets/state_pill.dart' show ClassState;
import 'package:attendance_alamin/core/errors/error_codes.dart';
import 'package:attendance_alamin/core/settings/setting_keys.dart';
import 'package:attendance_alamin/data/repositories/schedule_repository.dart';
import 'package:attendance_alamin/data/repositories/settings_providers.dart';
import 'package:attendance_alamin/data/repositories/structure_providers.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';
import 'package:attendance_alamin/features/classes/controllers/class_controller.dart';
import 'package:attendance_alamin/features/classes/widgets/reschedule_sheet.dart';
import 'package:attendance_alamin/features/classes/widgets/sheet_frame.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

/// Opens the actions of [occ]; carries out what the sheet asks for afterwards
/// (reschedule sheet, roll call, the undo snackbar of a cancel).
Future<void> showClassActionsSheet(BuildContext context, {required String occ, String? returnTo}) async {
  final ProviderContainer container = ProviderScope.containerOf(context);
  final AppLocalizations l10n = context.l10n;
  final ClassSheetResult? result = await showClassSheet<ClassSheetResult>(
    context,
    (BuildContext ctx) => ClassActionsSheet(occ: occ),
    kind: BhorPanelKind.list,
    width: 440,
  );
  if (result == null || !context.mounted) return;
  switch (result) {
    case RescheduleRequested():
      await showRescheduleSheet(context, occ: occ);
    case RollCallRequested():
      GoRouter.maybeOf(context)?.push<void>(Routes.rollCall(occ), extra: returnTo);
    case final CancelDone done:
      if (!BhorToast.canShowIn(context)) return;
      _showCancelToast(
        context: context,
        repo: container.read(scheduleRepositoryProvider),
        l10n: l10n,
        done: done,
      );
  }
}

void _showCancelToast({
  required BuildContext context,
  required ScheduleRepository repo,
  required AppLocalizations l10n,
  required CancelDone done,
}) {
  final String? notice = done.guardianMessage;
  final String text = done.removedExtra ? l10n.clsExtraRemovedSnack : l10n.clsCancelledSnack;

  Future<void> undo() async {
    String message = l10n.clsRestoredSnack;
    try {
      await repo.restore(done.occ);
    } catch (e) {
      message = errorText(l10n, e);
    }
    if (context.mounted) BhorToast.show(context, message: message);
  }

  if (notice == null) {
    BhorToast.show(
      context,
      message: text,
      duration: const Duration(seconds: 8),
      actionLabel: l10n.commonUndo,
      onAction: () => unawaited(undo()),
    );
    return;
  }
  BhorToast.show(
    context,
    message: text,
    duration: const Duration(seconds: 8),
    actions: <BhorToastAction>[
      BhorToastAction(
        label: l10n.clsNotifyGuardians,
        onPressed: () {
          if (context.mounted) ShareService.shareText(context, notice);
        },
      ),
      BhorToastAction(label: l10n.commonUndo, onPressed: () => unawaited(undo())),
    ],
  );
}

/// The sheet body (public so the screen matrix can render it directly).
class ClassActionsSheet extends ConsumerStatefulWidget {
  const ClassActionsSheet({super.key, required this.occ});

  final String occ;

  @override
  ConsumerState<ClassActionsSheet> createState() => _ClassActionsSheetState();
}

class _ClassActionsSheetState extends ConsumerState<ClassActionsSheet> {
  bool _busy = false;
  String? _error;
  SlotCheckResult? _restoreClash;

  Future<void> _cancel(OccurrenceInfo info) async {
    final AppLocalizations l10n = context.l10n;
    final fmt = context.fmt;
    final ScheduleRepository repo = ref.read(scheduleRepositoryProvider);
    final today = ref.read(todayProvider);
    final List<BatchSchedule> schedules = ref.read(schedulesProvider).value ?? const <BatchSchedule>[];
    final bool isExtra = info.occurrence!.kind == OccurrenceKind.extra;
    setState(() {
      _busy = true;
      _error = null;
    });
    String? message;
    if (!isExtra) {
      String center = '';
      try {
        center = await ref.read(settingsRepositoryProvider).get(SettingKeys.centerName);
      } catch (_) {
        center = '';
      }
      message = buildCancelMessage(
        l10n: l10n,
        fmt: fmt,
        info: info,
        today: today,
        schedules: schedules,
        center: center,
      );
    }
    try {
      await repo.cancel(widget.occ);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = errorText(l10n, e);
      });
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(CancelDone(occ: widget.occ, removedExtra: isExtra, guardianMessage: message));
  }

  Future<void> _restore() async {
    final AppLocalizations l10n = context.l10n;
    final ScheduleRepository repo = ref.read(scheduleRepositoryProvider);
    setState(() {
      _busy = true;
      _error = null;
      _restoreClash = null;
    });
    try {
      await repo.restore(widget.occ);
    } on ScheduleClashException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _restoreClash = e.result;
      });
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = errorText(l10n, e);
      });
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final BhorThemeData b = context.bhor;
    final AsyncValue<OccurrenceInfo?> async = ref.watch(occInfoProvider(widget.occ));

    if (async.hasError) {
      return SheetFrame(title: l10n.clsRescheduleTitle, child: Text(errorText(l10n, async.error!)));
    }
    if (!async.hasValue) {
      return const SizedBox(height: 160, child: Center(child: BhorSpinner(size: 28)));
    }
    final OccurrenceInfo? info = async.value;
    final Occurrence? o = info?.occurrence;
    if (info == null || o == null) {
      return SheetFrame(
        title: l10n.clsRescheduleTitle,
        child: Text(errorTextForCode(l10n, ErrorCodes.notFound)),
      );
    }

    final bool cancelled = info.cancelled;
    final bool moved = o.kind == OccurrenceKind.rescheduled;
    final bool extra = o.kind == OccurrenceKind.extra;
    final bool future = o.date.isAfter(ref.watch(todayProvider));

    // How many classes of this batch fall on that date (cancelled ones too):
    // with 2+ the title names the time, so the sessions are never confused.
    final DayPlan? plan = ref.watch(dayPlanProvider(o.date)).value;
    int sameBatch = 1;
    if (plan != null) {
      sameBatch = plan.classes.where((DayClass c) => c.batch.id == info.batch.id).length;
    }
    final String dateText = fmt.weekdayDate(o.date);
    final String title = sameBatch >= 2
        ? l10n.clsSheetTitleAt(dateText, fmt.time(o.startMin))
        : l10n.clsSheetTitle(dateText);

    ClassState? state;
    if (cancelled) {
      state = ClassState.cancelled;
    } else if (moved) {
      state = ClassState.moved;
    } else if (extra) {
      state = ClassState.extra;
    }

    final List<Widget> actions = <Widget>[
      if (!cancelled)
        _ActionTile(
          icon: BhorIcons.clock,
          label: l10n.clsActionReschedule,
          onTap: _busy ? null : () => Navigator.of(context).pop(const RescheduleRequested()),
        ),
      if (!cancelled)
        _ActionTile(
          icon: extra ? BhorIcons.delete : BhorIcons.holiday,
          label: extra ? l10n.clsActionRemoveExtra : l10n.clsActionCancel,
          destructive: true,
          onTap: _busy ? null : () => _cancel(info),
        ),
      // Product 3.6: no roll call for a future date (QA-15); the tile stays
      // visible, disabled, with the reason.
      if (!cancelled && future)
        _ActionTile(
          icon: BhorIcons.rollCall,
          label: l10n.clsActionRollCall,
          reason: errorTextForCode(l10n, ErrorCodes.rollCallFutureDate),
          onTap: null,
        ),
      if (!cancelled && !future)
        _ActionTile(
          icon: BhorIcons.rollCall,
          label: l10n.clsActionRollCall,
          onTap: _busy ? null : () => Navigator.of(context).pop(const RollCallRequested()),
        ),
      if (cancelled)
        _ActionTile(
          icon: BhorIcons.undo,
          label: l10n.clsActionRestoreCancelled,
          onTap: _busy ? null : _restore,
        ),
      if (moved && !cancelled)
        _ActionTile(
          icon: BhorIcons.clock,
          label: l10n.clsActionRestoreMoved,
          onTap: _busy ? null : _restore,
        ),
    ];

    return SheetFrame(
      title: title,
      subtitle: l10n.clsClassLabel(info.subjectName, info.batch.name),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: BhorSpace.s12,
            runSpacing: BhorSpace.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(fmt.timeRange(o.startMin, o.endMin), style: b.type.heading),
              if (state != null) _classStateTag(context, state),
              if (moved && o.originalStartMin != null)
                Text(l10n.clsMovedFrom(fmt.time(o.originalStartMin!)), style: b.type.meta),
            ],
          ),
          const SizedBox(height: BhorSpace.s12),
          if (_restoreClash != null) ...<Widget>[
            BhorClashCard(
              lines: <String>[
                for (final ClashGroup g in _restoreClash!.groups.take(3))
                  clashLine(
                    l10n: l10n,
                    fmt: fmt,
                    group: g,
                    byBatch: <String, BatchSchedule>{
                      for (final BatchSchedule s
                          in ref.watch(schedulesProvider).value ?? const <BatchSchedule>[])
                        s.batch.id: s,
                    },
                  ),
              ],
            ),
            const SizedBox(height: BhorSpace.s12),
          ],
          if (_error != null) ...<Widget>[
            Text(_error!, style: b.type.body.copyWith(color: b.colors.danger)),
            const SizedBox(height: BhorSpace.s12),
          ],
          ...actions,
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.reason,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool destructive;

  /// Why the action is unavailable (shown under the label when disabled).
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final Color color = onTap == null ? c.text3 : (destructive ? c.danger : c.text);
    return BhorPressable(
      onTap: onTap,
      semanticLabel: reason == null ? label : '$label. $reason',
      excludeChildSemantics: true,
      radius: BhorRadius.control,
      scaleOnPress: false,
      builder: (BuildContext context, BhorStates s) => Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.all(BhorSpace.s8),
        decoration: BoxDecoration(
          color: s.hovered ? c.surface2 : null,
          borderRadius: BorderRadius.circular(BhorRadius.control),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, color: color),
            const SizedBox(width: BhorSpace.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(label, style: b.type.body.copyWith(color: color)),
                  if (reason != null) Text(reason!, style: b.type.meta),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Class state as a Bhor tag (icon + word, never colour alone).
Widget _classStateTag(BuildContext context, ClassState state) {
  final l10n = context.l10n;
  switch (state) {
    case ClassState.now:
      return BhorTag(label: l10n.uiClassNow, tone: BhorTone.accent, icon: BhorIcons.clock);
    case ClassState.moved:
      return BhorTag(label: l10n.uiClassMoved, tone: BhorTone.late, icon: BhorIcons.refresh);
    case ClassState.cancelled:
      return BhorTag(label: l10n.uiClassCancelled, tone: BhorTone.danger, icon: BhorIcons.absent);
    case ClassState.extra:
      return BhorTag(label: l10n.uiClassExtra, tone: BhorTone.neutral, icon: BhorIcons.add);
  }
}
