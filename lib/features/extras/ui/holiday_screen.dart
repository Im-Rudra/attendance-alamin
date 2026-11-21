// HolidayScreen (F28, "ছুটি ঘোষণা"): cancel every batch's classes for a date
// range in one action - Eid, exams, a strike. A live preview says how many
// classes and batches it touches, a confirm dialog repeats the number, and the
// snackbar offers undo. A second mode brings a range back later. Reminders
// replan on their own: the reminder service listens to the schedules.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/widgets/chip_wrap.dart';
import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/error_text.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/providers/schedule_providers.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
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

  Future<void> _pick({required bool start, required LocalDate today, required BuildContext anchor}) async {
    final LocalDate current = start ? _fromOr(today) : _toOr(today);
    final DateTime first = _dt(today.addDays(-60));
    final DateTime last = _dt(today.addDays(400));
    DateTime initial = _dt(current);
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    final DateTime? picked = await showBhorDatePicker(
      context,
      anchor: anchor,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      weekStart: ref.read(weekStartProvider).value ?? DateTime.saturday,
      today: _dt(today),
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
    final BuildContext screen = context;
    final repo = ref.read(scheduleRepositoryProvider);
    if (_mode == _HolidayMode.cancel) {
      final bool ok = await showBhorConfirm(
        context,
        title: l10n.extraHolidayConfirmTitle(
          fmt.digits(range.length.toString()),
          fmt.digits(preview.classes.toString()),
        ),
        message: l10n.extraHolidayConfirmBody,
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
          screen,
          l10n.extraHolidayDone(fmt.digits(n.toString())),
          l10n.commonUndo,
          () => _undoCancel(screen, range, l10n, fmt, repo),
        );
      } else {
        final int n = await repo.undoCancelRange(range);
        if (!mounted) return;
        setState(() => _busy = false);
        _snack(screen, l10n.extraHolidayRestored(fmt.digits(n.toString())), null, null);
      }
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = errorText(l10n, e);
      });
    }
  }

  /// Runs from the toast, possibly after the teacher left the screen, so it
  /// only uses what was captured up front (the follow-up toast needs the
  /// screen to still be there).
  Future<void> _undoCancel(
    BuildContext screen,
    DateRange range,
    AppLocalizations l10n,
    AppFormat fmt,
    ScheduleRepository repo,
  ) async {
    try {
      final int n = await repo.undoCancelRange(range);
      _snack(screen, l10n.extraHolidayRestored(fmt.digits(n.toString())), null, null);
    } on Object catch (e) {
      _snack(screen, errorText(l10n, e), null, null);
    }
  }

  void _snack(BuildContext screen, String message, String? actionLabel, VoidCallback? onAction) {
    if (!screen.mounted) return;
    BhorToast.show(
      screen,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: const Duration(seconds: 8),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final BhorThemeData th = context.bhor;
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

    final Widget form = BhorCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l10n.extraHolidayIntro, style: th.type.body.copyWith(color: th.colors.text2)),
          const SizedBox(height: BhorSpace.s16),
          BhorSegmented<_HolidayMode>(
            segments: <BhorSegment<_HolidayMode>>[
              BhorSegment<_HolidayMode>(_HolidayMode.cancel, l10n.extraHolidayModeCancel),
              BhorSegment<_HolidayMode>(_HolidayMode.restore, l10n.extraHolidayModeRestore),
            ],
            value: _mode,
            onChanged: (_HolidayMode m) => setState(() {
              _mode = m;
              _error = null;
            }),
          ),
          const SizedBox(height: BhorSpace.s16),
          LayoutBuilder(builder: (BuildContext context, BoxConstraints c) {
            final Widget a = Builder(
              builder: (BuildContext bc) => _DateTile(
                key: const ValueKey<String>('holiday-from'),
                label: l10n.extraHolidayFrom,
                value: fmt.date(from),
                onTap: () => _pick(start: true, today: today, anchor: bc),
              ),
            );
            final Widget b = Builder(
              builder: (BuildContext bc) => _DateTile(
                key: const ValueKey<String>('holiday-to'),
                label: l10n.extraHolidayTo,
                value: fmt.date(to),
                onTap: () => _pick(start: false, today: today, anchor: bc),
              ),
            );
            if (c.maxWidth >= 420) {
              return Row(children: <Widget>[
                Expanded(child: a),
                const SizedBox(width: BhorSpace.s12),
                Expanded(child: b),
              ]);
            }
            return Column(children: <Widget>[a, const SizedBox(height: BhorSpace.s12), b]);
          }),
          if (rangeOk) ...<Widget>[
            const SizedBox(height: BhorSpace.s8),
            Text(l10n.extraHolidayDays(fmt.digits(range.length.toString())), style: th.type.meta),
          ],
          if (cancelMode) ...<Widget>[
            const SizedBox(height: BhorSpace.s16),
            BhorTextField(
              key: const ValueKey<String>('holiday-reason'),
              controller: _reason,
              maxLength: 60,
              label: l10n.extraHolidayReason,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: BhorSpace.s4),
            ChipWrap(
              spacing: BhorSpace.s8,
              runSpacing: BhorSpace.s4,
              children: <Widget>[
                for (final String r in <String>[
                  l10n.extraHolidayReasonEid,
                  l10n.extraHolidayReasonExam,
                  l10n.extraHolidayReasonHartal,
                ])
                  BhorChip(
                    label: r,
                    selected: _reason.text == r,
                    onSelected: (bool _) => setState(() => _reason.text = r),
                  ),
              ],
            ),
          ],
        ],
      ),
    );

    final Widget previewCard = BhorCard(
      child: Semantics(
        liveRegion: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  !rangeOk ? BhorIcons.warning : (cancelMode ? BhorIcons.holiday : BhorIcons.calendar),
                  color: !rangeOk ? th.colors.warn : th.colors.accent,
                ),
                const SizedBox(width: BhorSpace.s12),
                Expanded(
                  child: Text(
                    previewText,
                    key: const ValueKey<String>('holiday-preview'),
                    style: th.type.bodyStrong,
                  ),
                ),
              ],
            ),
            if (!cancelMode) ...<Widget>[
              const SizedBox(height: BhorSpace.s8),
              Text(l10n.extraHolidayRestoreWarn, style: th.type.meta),
            ],
            if (_error != null) ...<Widget>[
              const SizedBox(height: BhorSpace.s8),
              Text(_error!, style: th.type.body.copyWith(color: th.colors.danger)),
            ],
          ],
        ),
      ),
    );

    final bool canRun = rangeOk && !preview.isEmpty && !_busy && data != null;
    final bool wide = WindowClass.of(context).isWide;
    final Widget bar = BhorActionBar(
      buttonKey: const ValueKey<String>('holiday-run'),
      label: cancelMode ? l10n.extraHolidayCancelButton(count) : l10n.extraHolidayRestoreButton(count),
      onPressed: canRun ? () => _run(range, preview) : null,
      disabledReason: rangeOk && preview.isEmpty ? previewText : null,
    );
    final Widget content = SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[form, const SizedBox(height: BhorSpace.s12), previewCard],
      ),
    );
    return BhorScaffold(
      header: BhorHeader(title: l10n.shellTitleHolidays, large: true),
      // Wide windows: a centred 560 dialog-style panel with the button inside
      // it; phones keep the full-width bar.
      body: wide
          ? Padding(
              padding: EdgeInsets.fromLTRB(g, BhorSpace.s16, g, g),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: th.colors.surface,
                      borderRadius: BorderRadius.circular(BhorRadius.card),
                      border: Border.all(color: th.colors.line),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(BhorRadius.card),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Flexible(
                            child: Padding(padding: const EdgeInsets.all(BhorSpace.s16), child: content),
                          ),
                          bar,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
          : Padding(
              padding: EdgeInsets.fromLTRB(g, 4, g, g),
              child: Center(
                child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: content),
              ),
            ),
      bottomNav: wide ? null : bar,
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
    final BhorThemeData b = context.bhor;
    return BhorPressable(
      onTap: onTap,
      semanticLabel: '$label, $value',
      excludeChildSemantics: true,
      builder: (BuildContext context, BhorStates s) => AnimatedContainer(
        duration: BhorMotion.of(context, BhorMotion.fast),
        curve: BhorMotion.ease,
        constraints: const BoxConstraints(minHeight: BhorSize.field),
        padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s16, vertical: BhorSpace.s8),
        decoration: BoxDecoration(
          color: s.hovered || s.pressed ? b.colors.soft2 : b.colors.soft,
          borderRadius: BorderRadius.circular(BhorRadius.control),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(label, style: b.type.caption),
                  Text(value, style: b.type.body, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(BhorIcons.calendar, size: 18, color: b.colors.accent),
          ],
        ),
      ),
    );
  }
}
