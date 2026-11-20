// Per-date actions of one class (UX 2g): "শুধু {date}" with change time,
// cancel (undo snackbar + guardians' notice), roll call and restore.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/l10n/error_text.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/providers/schedule_providers.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/services/share_service.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
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
Future<void> showClassActionsSheet(BuildContext context, {required String occ}) async {
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  final ProviderContainer container = ProviderScope.containerOf(context);
  final AppLocalizations l10n = context.l10n;
  final ClassSheetResult? result = await showClassSheet<ClassSheetResult>(
    context,
    (BuildContext ctx) => ClassActionsSheet(occ: occ),
  );
  if (result == null || !context.mounted) return;
  switch (result) {
    case RescheduleRequested():
      await showRescheduleSheet(context, occ: occ);
    case RollCallRequested():
      GoRouter.maybeOf(context)?.push(Routes.rollCall(occ));
    case final CancelDone done:
      if (messenger == null) return;
      _showCancelSnack(
        context: context,
        messenger: messenger,
        repo: container.read(scheduleRepositoryProvider),
        l10n: l10n,
        done: done,
      );
  }
}

void _showCancelSnack({
  required BuildContext context,
  required ScaffoldMessengerState messenger,
  required ScheduleRepository repo,
  required AppLocalizations l10n,
  required CancelDone done,
}) {
  final String? notice = done.guardianMessage;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(done.removedExtra ? l10n.clsExtraRemovedSnack : l10n.clsCancelledSnack),
            if (notice != null)
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  foregroundColor: Theme.of(context).colorScheme.inversePrimary,
                  padding: EdgeInsets.zero,
                ),
                onPressed: () {
                  messenger.hideCurrentSnackBar();
                  if (context.mounted) ShareService.shareText(context, notice);
                },
                child: Text(l10n.clsNotifyGuardians),
              ),
          ],
        ),
        action: SnackBarAction(
          label: l10n.commonUndo,
          onPressed: () async {
            String message = l10n.clsRestoredSnack;
            try {
              await repo.restore(done.occ);
            } catch (e) {
              message = errorText(l10n, e);
            }
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(message)));
          },
        ),
      ),
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
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final AsyncValue<OccurrenceInfo?> async = ref.watch(occInfoProvider(widget.occ));

    if (async.hasError) {
      return SheetFrame(title: l10n.clsRescheduleTitle, child: Text(errorText(l10n, async.error!)));
    }
    if (!async.hasValue) {
      return const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()));
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
          icon: Icons.schedule,
          label: l10n.clsActionReschedule,
          onTap: _busy ? null : () => Navigator.of(context).pop(const RescheduleRequested()),
        ),
      if (!cancelled)
        _ActionTile(
          icon: extra ? Icons.delete_outline : Icons.event_busy_outlined,
          label: extra ? l10n.clsActionRemoveExtra : l10n.clsActionCancel,
          destructive: true,
          onTap: _busy ? null : () => _cancel(info),
        ),
      if (!cancelled)
        _ActionTile(
          icon: Icons.fact_check_outlined,
          label: l10n.clsActionRollCall,
          onTap: _busy ? null : () => Navigator.of(context).pop(const RollCallRequested()),
        ),
      if (cancelled)
        _ActionTile(
          icon: Icons.undo,
          label: l10n.clsActionRestoreCancelled,
          onTap: _busy ? null : _restore,
        ),
      if (moved && !cancelled)
        _ActionTile(
          icon: Icons.history,
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
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                fmt.timeRange(o.startMin, o.endMin),
                style: tt.titleMedium?.copyWith(color: tokens.textPrimary),
              ),
              if (state != null) StatePill(state: state),
              if (moved && o.originalStartMin != null)
                Text(
                  l10n.clsMovedFrom(fmt.time(o.originalStartMin!)),
                  style: tt.bodyMedium?.copyWith(color: tokens.textSecondary),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_restoreClash != null) ...<Widget>[
            ConflictCard(
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
            const SizedBox(height: 12),
          ],
          if (_error != null) ...<Widget>[
            Text(_error!, style: tt.bodyMedium?.copyWith(color: tokens.error)),
            const SizedBox(height: 12),
          ],
          ...actions,
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.label, required this.onTap, this.destructive = false});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final Color color = onTap == null
        ? tokens.textDisabled
        : destructive
            ? tokens.error
            : tokens.textPrimary;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AuroraMetrics.radiusField),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: <Widget>[
                Icon(icon, color: color),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(label, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: color)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
