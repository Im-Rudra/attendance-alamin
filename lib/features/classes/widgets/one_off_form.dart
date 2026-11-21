// The form shared by the reschedule and extra-class sheets (UX 2g): batch
// (extra only), date, start time, duration, a LIVE clash card with free-time
// suggestions, and a save button that stays disabled with its reason.

import 'dart:math' as math;

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/error_text.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/providers/schedule_providers.dart';
import 'package:attendance_alamin/core/errors/error_codes.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/data/repositories/people_providers.dart';
import 'package:attendance_alamin/data/repositories/schedule_repository.dart';
import 'package:attendance_alamin/data/repositories/structure_providers.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';
import 'package:attendance_alamin/features/classes/controllers/class_controller.dart';
import 'package:attendance_alamin/features/classes/widgets/clash_panel.dart';
import 'package:attendance_alamin/features/classes/widgets/sheet_frame.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

enum OneOffMode { reschedule, extra }

/// Sheet content for [OneOffMode.reschedule] (needs [occ]) and
/// [OneOffMode.extra] (optional [batchId], [date], [startMin] pre-fills). Pops
/// `true` (reschedule) or the new occurrence id (extra) once saved.
class OneOffForm extends ConsumerStatefulWidget {
  const OneOffForm({super.key, required this.mode, this.occ, this.batchId, this.date, this.startMin})
      : assert(mode == OneOffMode.extra || occ != null);

  final OneOffMode mode;
  final String? occ;
  final String? batchId;
  final LocalDate? date;
  final int? startMin;

  @override
  ConsumerState<OneOffForm> createState() => _OneOffFormState();
}

class _OneOffFormState extends ConsumerState<OneOffForm> {
  static const List<int> _durations = <int>[30, 45, 60, 90, 120];

  bool _inited = false;
  String? _batchId;
  LocalDate _date = const LocalDate(2000, 1, 1);
  int _start = 0;
  int _dur = 60;
  bool _durTouched = false;

  late LocalDate _initDate;
  late int _initStart;

  SlotCheckResult? _clash;
  int _gen = 0;
  bool _saving = false;
  String? _error;

  /// Reschedule only: the class already has a saved roll call (QA-04), so it
  /// may move to today or earlier but never to a future date.
  bool _held = false;

  bool get _isExtra => widget.mode == OneOffMode.extra;

  @override
  void initState() {
    super.initState();
    if (_isExtra) {
      final LocalDate today = ref.read(todayProvider);
      final int now = ref.read(nowMinutesProvider);
      _batchId = widget.batchId;
      _date = widget.date ?? today;
      _start = widget.startMin ?? math.max(360, math.min(1260, ((now + 29) ~/ 30) * 30));
      _initDate = _date;
      _initStart = _start;
      _inited = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _recheck());
    }
  }

  /// The chosen batch; the only live batch when there is just one.
  String? _effectiveBatch(List<BatchSchedule> live) {
    if (_batchId != null) return _batchId;
    if (_isExtra && live.length == 1) return live.first.batch.id;
    return null;
  }

  List<BatchSchedule> _liveBatches() {
    final List<BatchSchedule> all = ref.read(schedulesProvider).value ?? const <BatchSchedule>[];
    return <BatchSchedule>[for (final BatchSchedule s in all) if (!s.batch.archived) s];
  }

  Future<void> _loadHeld() async {
    final String? occ = widget.occ;
    if (_isExtra || occ == null) return;
    try {
      final Object? session = await ref.read(attendanceRepositoryProvider).getSession(occ);
      if (session != null && mounted) setState(() => _held = true);
    } catch (_) {
      // The repository re-checks on save.
    }
  }

  Future<void> _recheck() async {
    if (!mounted || !_inited) return;
    final String? batch = _isExtra ? _effectiveBatch(_liveBatches()) : _batchId;
    if (batch == null) {
      if (_clash != null) setState(() => _clash = null);
      return;
    }
    final int gen = ++_gen;
    try {
      final SlotCheckResult r = await ref.read(scheduleRepositoryProvider).checkSingle(
            batchId: batch,
            date: _date,
            startMin: _start,
            endMin: _start + _dur,
            replacingOcc: _isExtra ? null : widget.occ,
          );
      if (!mounted || gen != _gen) return;
      setState(() => _clash = r.ok ? null : r);
    } catch (_) {
      // The save itself re-checks; a failed live check must not block the form.
    }
  }

  void _setStart(int start) {
    final int s = math.max(0, math.min(start, 1440 - _dur));
    setState(() {
      _start = s;
      _error = null;
    });
    _recheck();
  }

  void _setDuration(int d) {
    setState(() {
      _dur = d;
      _durTouched = true;
      _start = math.max(0, math.min(_start, 1440 - d));
      _error = null;
    });
    _recheck();
  }

  Future<void> _pickDate() async {
    final LocalDate today = ref.read(todayProvider);
    final LocalDate lo = (_initDate.isBefore(today) ? _initDate : today).addDays(-365);
    final LocalDate hi = (_initDate.isAfter(today) ? _initDate : today).addDays(730);
    final int weekStart = ref.read(weekStartProvider).value ?? DateTime.saturday;
    final DateTime? picked = await showBhorDatePicker(
      context,
      initialDate: DateTime(_date.year, _date.month, _date.day),
      firstDate: DateTime(lo.year, lo.month, lo.day),
      lastDate: DateTime(hi.year, hi.month, hi.day),
      weekStart: weekStart,
      today: DateTime(today.year, today.month, today.day),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _date = LocalDate(picked.year, picked.month, picked.day);
      _error = null;
    });
    _recheck();
  }

  Future<void> _pickTime() async {
    final int? m = await showBhorTimePicker(context, initial: _start);
    if (m == null || !mounted) return;
    _setStart(m);
  }

  void _chooseBatch(BatchSchedule s) {
    setState(() {
      _batchId = s.batch.id;
      _error = null;
      if (!_durTouched && s.slots.isNotEmpty) _dur = s.slots.first.durationMin;
      _start = math.max(0, math.min(_start, 1440 - _dur));
    });
    _recheck();
  }

  bool get _changed => _date != _initDate || _start != _initStart;

  Future<void> _save(String batchId) async {
    final AppLocalizations l10n = context.l10n;
    final ScheduleRepository repo = ref.read(scheduleRepositoryProvider);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_isExtra) {
        final String id = await repo.addExtra(
          batchId: batchId,
          date: _date,
          startMin: _start,
          endMin: _start + _dur,
        );
        if (!mounted) return;
        Navigator.of(context).pop(id);
      } else {
        await repo.reschedule(widget.occ!, newDate: _date, startMin: _start, endMin: _start + _dur);
        if (!mounted) return;
        Navigator.of(context).pop(true);
      }
    } on ScheduleClashException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _clash = e.result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = errorText(l10n, e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final BhorThemeData b = context.bhor;

    // A schedule change (another save, an undo) re-runs the live check.
    ref.listen<AsyncValue<List<BatchSchedule>>>(schedulesProvider, (_, _) => _recheck());

    final List<BatchSchedule> live = _liveBatches();
    String? batchId;
    String classLabel = '';
    if (_isExtra) {
      batchId = _effectiveBatch(live);
    } else {
      final AsyncValue<OccurrenceInfo?> info = ref.watch(occInfoProvider(widget.occ!));
      if (info.hasError) {
        return SheetFrame(title: l10n.clsRescheduleTitle, child: Text(errorText(l10n, info.error!)));
      }
      if (!info.hasValue) {
        return const SizedBox(height: 160, child: Center(child: BhorSpinner(size: 28)));
      }
      final OccurrenceInfo? i = info.value;
      final Occurrence? o = i?.occurrence;
      if (i == null || o == null) {
        return SheetFrame(title: l10n.clsRescheduleTitle, child: Text(l10n.commonLoadingFailed));
      }
      if (!_inited) {
        _inited = true;
        _batchId = i.batch.id;
        _date = o.date;
        _start = o.startMin;
        _dur = o.endMin - o.startMin;
        _initDate = _date;
        _initStart = _start;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _recheck();
          _loadHeld();
        });
      }
      batchId = _batchId;
      classLabel = l10n.clsClassLabel(i.subjectName, i.batch.name);
    }

    // Other classes of the chosen batch on that date (extra sheet note).
    String? sameDayNote;
    if (_isExtra && batchId != null) {
      final DayPlan? plan = ref.watch(dayPlanProvider(_date)).value;
      if (plan != null) {
        final List<DayClass> others = <DayClass>[
          for (final DayClass c in plan.classes)
            if (c.batch.id == batchId && !c.cancelled) c,
        ];
        if (others.isNotEmpty) {
          sameDayNote = l10n.clsSameDayNote(
            fmt.digits('${others.length}'),
            others.map((DayClass c) => fmt.timeRange(c.startMin, c.endMin)).join(', '),
          );
        }
      }
    }

    final List<int> durations = <int>[
      if (!_durations.contains(_dur)) _dur,
      ..._durations,
    ]..sort();

    final bool clash = _clash != null && !_clash!.ok;
    final LocalDate today = ref.watch(todayProvider);
    String? reason;
    if (batchId == null) {
      reason = l10n.clsReasonNoBatch;
    } else if (_held && _date.isAfter(today)) {
      reason = errorTextForCode(l10n, ErrorCodes.heldClassToFuture);
    } else if (clash) {
      reason = l10n.clsReasonClash;
    } else if (!_isExtra && !_changed) {
      reason = l10n.clsReasonUnchanged;
    }
    final String? target = batchId;
    final bool canSave = reason == null && !_saving && target != null;

    return SheetFrame(
      title: _isExtra ? l10n.clsExtraTitle : l10n.clsRescheduleTitle,
      subtitle: _isExtra ? null : classLabel,
      footer: ClassSaveBar(
        label: _isExtra ? l10n.clsAddExtra : l10n.clsSaveReschedule,
        onPressed: canSave ? () => _save(target) : null,
        disabledReason: reason,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_isExtra) ...<Widget>[
            _Label(l10n.clsFieldBatch),
            if (live.isEmpty)
              Text(l10n.clsNoBatches, style: b.type.meta)
            else
              Wrap(
                spacing: BhorSpace.s8,
                runSpacing: BhorSpace.s8,
                children: <Widget>[
                  for (final BatchSchedule s in live)
                    BhorChip(
                      label: l10n.clsClassLabel(s.subjectName, s.batch.name),
                      selected: s.batch.id == batchId,
                      onSelected: (_) => _chooseBatch(s),
                    ),
                ],
              ),
            const SizedBox(height: BhorSpace.s12),
          ],
          FieldRow(
            label: l10n.clsFieldDate,
            value: fmt.weekdayDate(_date),
            icon: Icons.calendar_today_outlined,
            onTap: _pickDate,
          ),
          const SizedBox(height: BhorSpace.s12),
          FieldRow(
            label: l10n.clsFieldTime,
            value: fmt.timeRange(_start, _start + _dur),
            onTap: _pickTime,
            leading: BhorIconButton(
              semanticLabel: l10n.clsEarlier,
              icon: Icons.remove,
              onPressed: _start - 15 >= 0 ? () => _setStart(_start - 15) : null,
            ),
            trailing: BhorIconButton(
              semanticLabel: l10n.clsLater,
              icon: Icons.add,
              onPressed: _start + _dur + 15 <= 1440 ? () => _setStart(_start + 15) : null,
            ),
          ),
          const SizedBox(height: BhorSpace.s12),
          _Label(l10n.clsFieldDuration),
          Wrap(
            spacing: BhorSpace.s8,
            runSpacing: BhorSpace.s8,
            children: <Widget>[
              for (final int d in durations)
                BhorChip(
                  label: durationText(l10n, fmt, d),
                  selected: d == _dur,
                  onSelected: (_) => _setDuration(d),
                ),
            ],
          ),
          if (sameDayNote != null) ...<Widget>[
            const SizedBox(height: BhorSpace.s12),
            Text(sameDayNote, style: b.type.meta),
          ],
          if (clash) ...<Widget>[
            const SizedBox(height: BhorSpace.s12),
            ClashPanel(result: _clash!, durationMin: _dur, onPickStart: _setStart),
          ],
          if (_error != null) ...<Widget>[
            const SizedBox(height: BhorSpace.s12),
            Text(_error!, style: b.type.body.copyWith(color: b.colors.danger)),
          ],
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: BhorSpace.s4),
        child: Text(text, style: context.bhor.type.label.copyWith(color: context.bhor.colors.text2)),
      );
}
