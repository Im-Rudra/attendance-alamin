// HolidayScreen (F28, "ছুটি ঘোষণা"): cancel every batch's classes for a date
// range in one action - Eid, exams, a strike. A live preview says how many
// classes and batches it touches, a confirm dialog repeats the number, and the
// snackbar offers undo. A second mode brings a range back later. Reminders
// replan on their own: the reminder service listens to the schedules.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/l10n/error_text.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/providers/schedule_providers.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/core/time/date_range.dart';
import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/data/repositories/schedule_repository.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';
import 'package:attendance_alamin/data/repositories/structure_providers.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';
import 'package:attendance_alamin/features/extras/controllers/holiday_logic.dart';

enum _HolidayMode { cancel, restore }

class HolidayScreen extends ConsumerStatefulWidget {
  const HolidayScreen({super.key});

  @override
  ConsumerState<HolidayScreen> createState() => _HolidayScreenState();
}

class _HolidayScreenState extends ConsumerState<HolidayScreen> {
  _HolidayMode _mode = _HolidayMode.cancel;
  LocalDate? _from;
  LocalDate? _to;
  final TextEditingController _reason = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  LocalDate _fromOr(LocalDate today) => _from ?? today;
  LocalDate _toOr(LocalDate today) => _to ?? _fromOr(today);

  Future<void> _pick({required bool start, required LocalDate today}) async {
    final LocalDate current = start ? _fromOr(today) : _toOr(today);
    final DateTime first = _dt(today.addDays(-60));
    final DateTime last = _dt(today.addDays(400));
    DateTime initial = _dt(current);
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    final DateTime? picked = await showAppDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked == null || !mounted) return;
    final LocalDate d = LocalDate(picked.year, picked.month, picked.day);
    setState(() {
      _error = null;
      if (start) {
        _from = d;
        // Keep the range valid while the start moves forward.
        if (_toOr(today).isBefore(d)) _to = d;
      } else {
        _to = d;
      }
    });
  }

  DateTime _dt(LocalDate d) => DateTime(d.year, d.month, d.day);

  Future<void> _run(DateRange range, HolidayPreview preview) async {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(scheduleRepositoryProvider);
    if (_mode == _HolidayMode.cancel) {
      final bool ok = await showConfirmDialog(
        context,
        title: l10n.extraHolidayConfirmTitle(
          fmt.digits(range.length.toString()),
          fmt.digits(preview.classes.toString()),
        ),
        body: l10n.extraHolidayConfirmBody,
        confirmLabel: l10n.extraHolidayCancelButton(fmt.digits(preview.classes.toString())),
        destructive: true,
      );
      if (!ok || !mounted) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_mode == _HolidayMode.cancel) {
        final String reason = _reason.text.trim();
        final int n = await repo.cancelRange(range, note: reason.isEmpty ? null : reason);
        if (!mounted) return;
        setState(() => _busy = false);
        _snack(
          messenger,
          l10n.extraHolidayDone(fmt.digits(n.toString())),
          l10n.commonUndo,
          () => _undoCancel(messenger, range, l10n, fmt, repo),
        );
      } else {
        final int n = await repo.undoCancelRange(range);
        if (!mounted) return;
        setState(() => _busy = false);
        _snack(messenger, l10n.extraHolidayRestored(fmt.digits(n.toString())), null, null);
      }
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = errorText(l10n, e);
      });
    }
  }

  /// Runs from the snackbar, possibly after the teacher left the screen, so it
  /// only uses what was captured up front.
  Future<void> _undoCancel(
    ScaffoldMessengerState messenger,
    DateRange range,
    AppLocalizations l10n,
    AppFormat fmt,
    ScheduleRepository repo,
  ) async {
    try {
      final int n = await repo.undoCancelRange(range);
      _snack(messenger, l10n.extraHolidayRestored(fmt.digits(n.toString())), null, null);
    } on Object catch (e) {
      _snack(messenger, errorText(l10n, e), null, null);
    }
  }

  void _snack(ScaffoldMessengerState m, String message, String? actionLabel, VoidCallback? onAction) {
    m
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 8),
        // Auto-dismiss even with an action (Flutter keeps action snackbars
        // otherwise).
        persist: false,
        action: actionLabel == null ? null : SnackBarAction(label: actionLabel, onPressed: onAction!),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final LocalDate today = ref.watch(todayProvider);
    final AsyncValue<List<BatchSchedule>> schedules = ref.watch(schedulesProvider);
    final double g = WindowClass.of(context).gutter;

    final LocalDate from = _fromOr(today);
    final LocalDate to = _toOr(today);
    final DateRange range = DateRange(from, to);
    final bool rangeOk = !range.isEmpty;
    final List<BatchSchedule>? data = schedules.value;
    final HolidayPreview preview = data == null || !rangeOk
        ? const HolidayPreview()
        : (_mode == _HolidayMode.cancel ? previewCancel(data, range) : previewRestore(data, range));
    final bool cancelMode = _mode == _HolidayMode.cancel;
    final String count = fmt.digits(preview.classes.toString());

    final String previewText = !rangeOk
        ? l10n.extraHolidayRangeInvalid
        : preview.isEmpty
            ? (cancelMode ? l10n.extraHolidayPreviewNone : l10n.extraHolidayRestoreNone)
            : (cancelMode
                ? l10n.extraHolidayPreview(count, fmt.digits(preview.batches.toString()))
                : l10n.extraHolidayRestorePreview(count));

    final Widget form = GlassCard(
      dense: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l10n.extraHolidayIntro, style: tt.bodyMedium?.copyWith(color: tokens.textSecondary)),
          const SizedBox(height: 16),
          SegmentedChoice<_HolidayMode>(
            options: _HolidayMode.values,
            selected: _mode,
            onChanged: (_HolidayMode m) => setState(() {
              _mode = m;
              _error = null;
            }),
            labelOf: (_HolidayMode m) =>
                m == _HolidayMode.cancel ? l10n.extraHolidayModeCancel : l10n.extraHolidayModeRestore,
          ),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (BuildContext context, BoxConstraints c) {
            final Widget a = _DateTile(
              key: const ValueKey<String>('holiday-from'),
              label: l10n.extraHolidayFrom,
              value: fmt.date(from),
              onTap: () => _pick(start: true, today: today),
            );
            final Widget b = _DateTile(
              key: const ValueKey<String>('holiday-to'),
              label: l10n.extraHolidayTo,
              value: fmt.date(to),
              onTap: () => _pick(start: false, today: today),
            );
            if (c.maxWidth >= 420) {
              return Row(children: <Widget>[Expanded(child: a), const SizedBox(width: 12), Expanded(child: b)]);
            }
            return Column(children: <Widget>[a, const SizedBox(height: 12), b]);
          }),
          if (rangeOk) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              l10n.extraHolidayDays(fmt.digits(range.length.toString())),
              style: tt.labelMedium?.copyWith(color: tokens.textSecondary),
            ),
          ],
          if (cancelMode) ...<Widget>[
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey<String>('holiday-reason'),
              controller: _reason,
              maxLength: 60,
              decoration: InputDecoration(labelText: l10n.extraHolidayReason),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: <Widget>[
                for (final String r in <String>[
                  l10n.extraHolidayReasonEid,
                  l10n.extraHolidayReasonExam,
                  l10n.extraHolidayReasonHartal,
                ])
                  ActionChip(
                    label: Text(r),
                    onPressed: () => setState(() => _reason.text = r),
                  ),
              ],
            ),
          ],
        ],
      ),
    );

    final Widget previewCard = GlassCard(
      dense: true,
      child: Semantics(
        liveRegion: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  !rangeOk ? Icons.error_outline : (cancelMode ? Icons.event_busy_outlined : Icons.event_available_outlined),
                  color: !rangeOk ? tokens.error : tokens.accent,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    previewText,
                    key: const ValueKey<String>('holiday-preview'),
                    style: tt.titleSmall,
                  ),
                ),
              ],
            ),
            if (!cancelMode) ...<Widget>[
              const SizedBox(height: 8),
              Text(l10n.extraHolidayRestoreWarn, style: tt.bodySmall?.copyWith(color: tokens.textSecondary)),
            ],
            if (_error != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(_error!, style: tt.bodyMedium?.copyWith(color: tokens.error)),
            ],
          ],
        ),
      ),
    );

    final bool canRun = rangeOk && !preview.isEmpty && !_busy && data != null;
    return Scaffold(
      appBar: AppBar(title: Semantics(header: true, child: Text(l10n.shellTitleHolidays))),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(g, 4, g, g),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[form, const SizedBox(height: 12), previewCard],
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: StickyActionBar(
        label: cancelMode ? l10n.extraHolidayCancelButton(count) : l10n.extraHolidayRestoreButton(count),
        onPressed: canRun ? () => _run(range, preview) : null,
        disabledReason: rangeOk && preview.isEmpty ? previewText : null,
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({super.key, required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '$label, $value',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: tokens.hairline),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(label, style: tt.labelSmall?.copyWith(color: tokens.textSecondary)),
                    Text(value, style: tt.bodyLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Icon(Icons.calendar_today_outlined, size: 18, color: tokens.accent),
            ],
          ),
        ),
      ),
    );
  }
}
