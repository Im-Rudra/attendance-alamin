// The roll call itself (UX 2b): loads one class (or the ad-hoc class of a day
// without one), its roster and any saved marks / unsaved draft, and lets the
// teacher mark everyone in a few taps. One column on phones; 2-4 column-major
// columns plus a summary pane on wide windows, with the desktop keys.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/l10n/error_text.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/providers/schedule_providers.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/stub_screen.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/data/repositories/attendance_repository.dart';
import 'package:attendance_alamin/data/repositories/local_meta_repository.dart';
import 'package:attendance_alamin/data/repositories/people_providers.dart';
import 'package:attendance_alamin/data/repositories/schedule_repository.dart';
import 'package:attendance_alamin/data/repositories/settings_providers.dart';
import 'package:attendance_alamin/data/repositories/structure_providers.dart';
import 'package:attendance_alamin/domain/models/attendance.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';
import 'package:attendance_alamin/features/attendance/controllers/roll_call_controller.dart';
import 'package:attendance_alamin/features/attendance/controllers/roll_models.dart';
import 'package:attendance_alamin/features/attendance/widgets/roll_header.dart';
import 'package:attendance_alamin/features/attendance/widgets/roll_row.dart';
import 'package:attendance_alamin/features/attendance/widgets/roll_skeleton.dart';
import 'package:attendance_alamin/features/schedule/schedule_entry.dart';
import 'package:attendance_alamin/features/students/students_entry.dart';

enum _LeaveChoice { save, discard }

class RollEditor extends ConsumerStatefulWidget {
  const RollEditor({
    super.key,
    required this.batchId,
    required this.date,
    required this.occ,
    required this.choices,
    required this.onDate,
    required this.onPick,
    this.returnTo,
  });

  /// Where "Done" goes back to (the screen the teacher came from), if known.
  final String? returnTo;

  final String batchId;
  final LocalDate date;

  /// The class being taken; null = no class that day (ad-hoc extra class).
  final String? occ;

  /// Every class of the batch on [date] (chips when 2+).
  final List<SessionChoice> choices;
  final ValueChanged<LocalDate> onDate;
  final ValueChanged<String> onPick;

  @override
  ConsumerState<RollEditor> createState() => _RollEditorState();
}

class _RollEditorState extends ConsumerState<RollEditor> {
  RollCallController? _c;
  RollTarget? _target;
  List<BatchSchedule> _schedules = const <BatchSchedule>[];
  Map<String, int> _rollOf = const <String, int>{};
  bool _notFound = false;
  Object? _loadError;

  SlotCheckResult? _clash;
  bool _checking = false;
  int _checkSeq = 0;

  final TextEditingController _search = TextEditingController();
  final FocusNode _focus = FocusNode(debugLabel: 'roll-call');
  final ScrollController _scroll = ScrollController();
  final Map<String, GlobalKey> _rowKeys = <String, GlobalKey>{};
  int _cursor = -1;
  String _digits = '';
  bool _leaving = false;

  /// The "everyone is present" hint of a fresh roll call. Decided once on load
  /// and kept for the whole visit, so the roster never jumps under a tap.
  bool _showHint = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _c?.dispose();
    _search.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ---- loading ---------------------------------------------------------

  Future<void> _load() async {
    try {
      final ScheduleRepository scheduleRepo = ref.read(scheduleRepositoryProvider);
      final AttendanceRepository attendance = ref.read(attendanceRepositoryProvider);
      final String? occ = widget.occ;
      // Everything the first frame needs is asked at once (one worker round
      // trip each on web), not one await after the other.
      final String draftGuess = occ ?? 'adhoc.${widget.batchId}.${widget.date.toCompact()}';
      final Future<List<BatchSchedule>> schedulesF = ref.read(schedulesProvider.future);
      final Future<OccurrenceInfo?> infoF = occ == null ? Future<OccurrenceInfo?>.value() : scheduleRepo.resolve(occ);
      final Future<(AttendanceSession, List<AttendanceRecord>)?> savedF =
          occ == null ? Future<(AttendanceSession, List<AttendanceRecord>)?>.value() : attendance.getSession(occ);
      final Future<List<Student>> rosterF = ref.read(enrollmentsRepositoryProvider).rosterOn(widget.batchId, widget.date);
      final Future<String?> draftF = ref.read(localMetaRepositoryProvider).getRaw(LocalMetaKeys.rollCallDraft(draftGuess));
      final loaded = await (schedulesF, infoF, savedF, rosterF, draftF).wait;
      final List<BatchSchedule> schedules = loaded.$1;
      final OccurrenceInfo? info = loaded.$2;
      final (AttendanceSession, List<AttendanceRecord>)? saved = loaded.$3;
      final List<Student> firstRoster = loaded.$4;
      final String? firstDraft = loaded.$5;
      if (!mounted) return;
      BatchSchedule? bs;
      for (final BatchSchedule s in schedules) {
        if (s.batch.id == widget.batchId) bs = s;
      }
      if (bs == null) {
        setState(() => _notFound = true);
        return;
      }
      Occurrence? occurrence;
      var cancelled = false;
      if (occ != null) {
        occurrence = info?.occurrence;
        cancelled = info?.cancelled ?? false;
        if (occurrence == null && saved != null) {
          final AttendanceSession s = saved.$1;
          occurrence = Occurrence(
            occ: s.occ,
            batchId: s.batchId,
            date: s.date,
            startMin: s.startMin,
            endMin: s.endMin,
            kind: s.slotId != null ? OccurrenceKind.regular : OccurrenceKind.extra,
            slotId: s.slotId,
            exceptionId: s.exceptionId,
            originalDate: s.originalDate,
          );
        }
        if (!mounted) return;
        if (occurrence == null) {
          setState(() => _notFound = true);
          return;
        }
      }
      final LocalDate date = occurrence?.date ?? widget.date;
      final List<Student> roster = date == widget.date
          ? firstRoster
          : await ref.read(enrollmentsRepositoryProvider).rosterOn(widget.batchId, date);
      final String draftOcc = occurrence?.occ ?? 'adhoc.${widget.batchId}.${date.toCompact()}';
      String? rawDraft;
      if (saved == null) {
        rawDraft = draftOcc == draftGuess
            ? firstDraft
            : await ref.read(localMetaRepositoryProvider).getRaw(LocalMetaKeys.rollCallDraft(draftOcc));
      }
      if (!mounted) return;

      final ({int start, int end}) times = commonSlotTimes(bs.slots);
      final RollTarget target = RollTarget(
        batch: bs.batch,
        subjectName: bs.subjectName,
        date: date,
        startMin: occurrence?.startMin ?? times.start,
        endMin: occurrence?.endMin ?? times.end,
        occurrence: occurrence,
        cancelled: cancelled,
      );

      final Map<String, AttendanceStatus> initial = <String, AttendanceStatus>{};
      String? note = saved?.$1.note;
      if (saved != null) {
        for (final AttendanceRecord r in saved.$2) {
          initial[r.studentId] = r.status;
        }
      }
      var restored = false;
      final RollDraft? draft = RollDraftCodec.decode(rawDraft);
      if (draft != null) {
        restored = true;
        for (final Student s in roster) {
          final AttendanceStatus? d = draft.statuses[s.id];
          if (d != null) initial[s.id] = d;
        }
        note = draft.note;
      }

      final LocalDate today = ref.read(todayProvider);
      final bool readOnly = bs.batch.archived || date.isAfter(today);
      final Map<String, int> rolls = <String, int>{};
      for (var i = 0; i < roster.length; i++) {
        rolls[roster[i].id] = int.tryParse(roster[i].roll ?? '') ?? (i + 1);
      }

      final RollCallController controller = RollCallController(
        students: roster,
        initial: initial,
        persist: _persist,
        writeDraft: (String? json) =>
            ref.read(localMetaRepositoryProvider).setRaw(LocalMetaKeys.rollCallDraft(draftOcc), json),
        saved: saved != null,
        note: note,
        restoredFromDraft: restored,
        readOnly: readOnly,
      );
      setState(() {
        _schedules = schedules;
        _target = target;
        _rollOf = rolls;
        _c = controller;
        _showHint = saved == null && !readOnly && roster.isNotEmpty;
      });
      if (target.adHoc && !readOnly) unawaited(_recheck());
    } on Object catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  Future<void> _persist(Map<String, AttendanceStatus> statuses, String? note) async {
    final RollTarget t = _target!;
    final AttendanceRepository attendance = ref.read(attendanceRepositoryProvider);
    final Occurrence? o = t.occurrence;
    RollTarget next = t;
    if (o == null) {
      final String occ = await attendance.saveAdHocRollCall(
        batchId: t.batch.id,
        date: t.date,
        startMin: t.startMin,
        endMin: t.endMin,
        statuses: statuses,
      );
      final Occurrence created = Occurrence(
        occ: occ,
        batchId: t.batch.id,
        date: t.date,
        startMin: t.startMin,
        endMin: t.endMin,
        kind: OccurrenceKind.extra,
        exceptionId: occ.startsWith('x.') ? occ.substring(2) : null,
      );
      next = t.copyWith(occurrence: created);
      if (note != null) {
        await attendance.saveRollCall(occurrence: created, statuses: statuses, note: note);
      }
    } else {
      await attendance.saveRollCall(
        occurrence: o,
        statuses: statuses,
        note: note,
        removeCancel: t.cancelled,
      );
      if (t.cancelled) next = t.copyWith(cancelled: false);
    }
    if (mounted) {
      setState(() => _target = next);
    } else {
      _target = next;
    }
  }

  // ---- ad-hoc class time -----------------------------------------------

  Future<void> _recheck() async {
    final RollTarget? t = _target;
    if (t == null || !t.adHoc) return;
    final int seq = ++_checkSeq;
    if (t.endMin <= t.startMin) {
      setState(() {
        _clash = null;
        _checking = false;
      });
      return;
    }
    setState(() => _checking = true);
    SlotCheckResult? result;
    try {
      result = await ref.read(scheduleRepositoryProvider).checkSingle(
            batchId: t.batch.id,
            date: t.date,
            startMin: t.startMin,
            endMin: t.endMin,
          );
    } on Object {
      result = null;
    }
    if (!mounted || seq != _checkSeq) return;
    setState(() {
      _clash = result;
      _checking = false;
    });
  }

  Future<void> _pickTime({required bool start}) async {
    final RollTarget? t = _target;
    if (t == null) return;
    final l10n = context.l10n;
    final int? m = await showTimePickerSheet(
      context,
      initialMin: start ? t.startMin : t.endMin,
      title: start ? l10n.rollPickStart : l10n.rollPickEnd,
    );
    if (m == null || !mounted) return;
    if (start) {
      final int duration = t.endMin - t.startMin;
      final int keep = duration > 0 ? duration : 60;
      _setTimes(m, (m + keep).clamp(m + 5, 1440).toInt());
    } else {
      _setTimes(t.startMin, m);
    }
  }

  void _setTimes(int startMin, int endMin) {
    final RollTarget? t = _target;
    if (t == null) return;
    setState(() => _target = t.copyWith(startMin: startMin, endMin: endMin));
    unawaited(_recheck());
  }

  // ---- saving / leaving ------------------------------------------------

  bool _canSave(RollTarget t, RollCallController c) {
    if (c.readOnly || c.students.isEmpty) return false;
    if (t.adHoc) {
      if (t.endMin <= t.startMin || _checking) return false;
      if (_clash != null && !_clash!.ok) return false;
    }
    return true;
  }

  Future<void> _save() async {
    final RollCallController? c = _c;
    final RollTarget? t = _target;
    if (c == null || t == null) return;
    if (c.readOnly) {
      _finish();
      return;
    }
    if (c.saved && !c.dirty && !c.saving) {
      _finish();
      return;
    }
    if (!_canSave(t, c)) return;
    final l10n = context.l10n;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final AttendanceRepository attendance = ref.read(attendanceRepositoryProvider);
    final ScheduleRepository scheduleRepo = ref.read(scheduleRepositoryProvider);
    final bool wasSaved = c.saved;
    final bool wasAdHoc = t.adHoc;
    final bool wasCancelled = t.cancelled;
    final bool ok = await c.save();
    if (!mounted || !ok) return;
    if (!wasSaved) {
      final String? occ = _target?.occurrence?.occ;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 8),
            // A snackbar with an action would otherwise never time out.
            persist: false,
            content: Text(l10n.rollSavedSnack),
            action: occ == null
                ? null
                : SnackBarAction(
                    label: l10n.commonUndo,
                    onPressed: () async {
                      try {
                        await attendance.deleteSession(occ);
                        if (wasAdHoc) {
                          await scheduleRepo.deleteExtra(occ);
                        } else if (wasCancelled) {
                          await scheduleRepo.cancel(occ);
                        }
                      } on Object {
                        // The roll call stays as saved; nothing else to do.
                      }
                    },
                  ),
          ),
        );
    }
    _finish();
  }

  void _finish() {
    if (_leaving) return;
    setState(() => _leaving = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _close();
    });
  }

  void _close() {
    final GoRouter? router = GoRouter.maybeOf(context);
    if (router == null) {
      Navigator.of(context).maybePop();
    } else if (widget.returnTo != null) {
      router.go(widget.returnTo!);
    } else if (router.canPop()) {
      router.pop();
    } else {
      router.go(Routes.today);
    }
  }

  Future<void> _confirmLeave() async {
    final RollCallController? c = _c;
    if (c == null) return;
    final l10n = context.l10n;
    final _LeaveChoice? choice = await showDialog<_LeaveChoice>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(l10n.rollLeaveTitle),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_LeaveChoice.discard),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            child: Text(l10n.rollLeaveDiscard),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(_LeaveChoice.save),
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            child: Text(l10n.rollLeaveSave),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case _LeaveChoice.save:
        await _save();
      case _LeaveChoice.discard:
        c.discardDraft();
        _finish();
    }
  }

  Future<void> _deleteSession() async {
    final RollTarget? t = _target;
    final String? occ = t?.occurrence?.occ;
    if (occ == null) return;
    final l10n = context.l10n;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final AttendanceRepository attendance = ref.read(attendanceRepositoryProvider);
    final bool yes = await showConfirmDialog(
      context,
      title: l10n.rollDeleteTitle,
      body: l10n.rollDeleteBody,
      confirmLabel: l10n.rollDeleteConfirm,
      destructive: true,
    );
    if (!yes || !mounted) return;
    try {
      await attendance.deleteSession(occ);
    } on Object catch (e) {
      if (mounted) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(errorText(l10n, e))));
      }
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.rollDeletedSnack)));
    if (mounted) _finish();
  }

  Future<void> _editNote() async {
    final RollCallController? c = _c;
    if (c == null || c.readOnly) return;
    final String? value = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => _NoteDialog(initial: c.note ?? ''),
    );
    if (value == null || !mounted) return;
    c.setNote(value);
  }

  Future<void> _rowMenu(RollCallController c, Student s) async {
    if (c.readOnly) return;
    final RollMenuChoice? choice = await showRollStatusSheet(
      context,
      name: s.name,
      current: c.statusOf(s.id),
    );
    if (choice == null || !mounted) return;
    if (choice.note) {
      await _editNote();
    } else {
      final AttendanceStatus? status = choice.status;
      if (status != null) c.setStatus(s.id, status);
    }
  }

  // ---- keyboard --------------------------------------------------------

  List<Student> _visible(RollCallController c) {
    final String q = AppFormat.toAsciiDigits(_search.text.trim()).toLowerCase();
    if (q.isEmpty) return c.students;
    return <Student>[
      for (final Student s in c.students)
        if (s.name.toLowerCase().contains(q) || (s.roll ?? '').toLowerCase().contains(q)) s,
    ];
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final RollCallController? c = _c;
    if (c == null) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final HardwareKeyboard kb = HardwareKeyboard.instance;
    final bool ctrl = kb.isControlPressed || kb.isMetaPressed;
    final bool alt = kb.isAltPressed;
    final LogicalKeyboardKey k = event.logicalKey;

    final BuildContext? focusCtx = FocusManager.instance.primaryFocus?.context;
    final bool typing = focusCtx != null &&
        (focusCtx.widget is EditableText || focusCtx.findAncestorWidgetOfExactType<EditableText>() != null);

    if (ctrl && k == LogicalKeyboardKey.keyS) {
      unawaited(_save());
      return KeyEventResult.handled;
    }
    if (ctrl && k == LogicalKeyboardKey.keyZ && !typing) {
      c.undo();
      return KeyEventResult.handled;
    }
    if (alt && k == LogicalKeyboardKey.arrowLeft) {
      widget.onDate(widget.date.addDays(-1));
      return KeyEventResult.handled;
    }
    if (alt && k == LogicalKeyboardKey.arrowRight) {
      if (widget.date.isBefore(ref.read(todayProvider))) widget.onDate(widget.date.addDays(1));
      return KeyEventResult.handled;
    }
    if (typing || ctrl || alt) return KeyEventResult.ignored;

    final List<Student> rows = _visible(c);
    if (rows.isEmpty) return KeyEventResult.ignored;
    if (k == LogicalKeyboardKey.arrowDown || k == LogicalKeyboardKey.keyJ) {
      _moveCursor(rows, (_cursor + 1).clamp(0, rows.length - 1).toInt());
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.keyK) {
      _moveCursor(rows, (_cursor - 1).clamp(0, rows.length - 1).toInt());
      return KeyEventResult.handled;
    }
    final String? digit = event.character;
    if (digit != null && digit.length == 1 && RegExp(r'[0-9]').hasMatch(digit)) {
      _jumpToRoll(rows, digit);
      return KeyEventResult.handled;
    }
    if (_cursor < 0 || _cursor >= rows.length) return KeyEventResult.ignored;
    final Student s = rows[_cursor];
    if (k == LogicalKeyboardKey.space) {
      c.toggle(s.id);
    } else if (k == LogicalKeyboardKey.keyP) {
      c.setStatus(s.id, AttendanceStatus.present);
    } else if (k == LogicalKeyboardKey.keyA) {
      c.setStatus(s.id, AttendanceStatus.absent);
    } else if (k == LogicalKeyboardKey.keyL) {
      c.setStatus(s.id, AttendanceStatus.late);
    } else if (k == LogicalKeyboardKey.keyE) {
      c.setStatus(s.id, AttendanceStatus.leave);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  void _jumpToRoll(List<Student> rows, String digit) {
    String buffer = _digits + digit;
    int find(String b) {
      for (var i = 0; i < rows.length; i++) {
        final int roll = _rollOf[rows[i].id] ?? (i + 1);
        if ('$roll'.startsWith(b)) return i;
      }
      return -1;
    }

    var at = find(buffer);
    if (at < 0) {
      buffer = digit;
      at = find(buffer);
    }
    _digits = buffer;
    if (at >= 0) _moveCursor(rows, at);
  }

  void _moveCursor(List<Student> rows, int index) {
    setState(() => _cursor = index);
    final BuildContext? ctx = _rowKeys[rows[index].id]?.currentContext;
    if (ctx != null) {
      unawaited(Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 120)));
    }
  }

  // ---- build -----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final RollCallController? c = _c;
    final RollTarget? t = _target;
    if (_notFound) {
      return StubScreen(
        name: l10n.shellTitleRollCall,
        icon: Icons.fact_check_outlined,
        fullScreen: true,
        message: l10n.rollNotFound,
      );
    }
    if (_loadError != null) {
      return StubScreen(
        name: l10n.shellTitleRollCall,
        icon: Icons.fact_check_outlined,
        fullScreen: true,
        message: errorText(l10n, _loadError!),
      );
    }
    if (c == null || t == null) {
      return StubScreen(
        name: l10n.shellTitleRollCall,
        icon: Icons.fact_check_outlined,
        fullScreen: true,
        body: const RollSkeleton(),
      );
    }
    final LocalDate today = ref.watch(todayProvider);
    final WindowClass wc = WindowClass.of(context);
    return ListenableBuilder(
      listenable: c,
      builder: (BuildContext context, Widget? _) => _loaded(context, c, t, today, wc),
    );
  }

  int _columns(WindowClass wc) => switch (wc) {
        WindowClass.compact => 1,
        WindowClass.medium || WindowClass.expanded => 2,
        WindowClass.large => 3,
        WindowClass.extraLarge => 4,
      };

  Widget _loaded(BuildContext context, RollCallController c, RollTarget initialTarget, LocalDate today, WindowClass wc) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final tokens = context.aurora;
    final RollTarget t = _target ?? initialTarget;
    final bool wide = wc.isWide;
    final bool dense = wc.usesRail;
    final double gutter = wc.gutter;
    final bool future = widget.date.isAfter(today);
    final bool past = widget.date.isBefore(today);
    final bool archived = t.batch.archived;
    final RollCounts k = c.counts;
    final String countsText = k.leave > 0
        ? l10n.rollCountsWithLeave(fmt.number(k.present), fmt.number(k.absent), fmt.number(k.late), fmt.number(k.leave))
        : l10n.rollCounts(fmt.number(k.present), fmt.number(k.absent), fmt.number(k.late));
    final bool canSave = c.readOnly || _canSave(t, c);

    String? reason;
    if (!c.readOnly && !canSave) {
      if (c.students.isEmpty) {
        reason = l10n.rollReasonNoStudents;
      } else if (t.adHoc && t.endMin <= t.startMin) {
        reason = l10n.rollReasonTime;
      } else if (t.adHoc && _checking) {
        reason = l10n.rollReasonChecking;
      } else if (t.adHoc) {
        reason = l10n.rollReasonClash;
      }
    }
    final String saveLabel = (c.saved || c.readOnly) ? l10n.rollDone : l10n.rollSaveButton(fmt.number(c.students.length));
    final Widget bar = StickyActionBar(
      label: saveLabel,
      onPressed: canSave ? () => unawaited(_save()) : null,
      disabledReason: reason,
      summary: wide ? null : countsText,
    );

    final Widget stateLine = _StateLine(saved: c.saved, saving: c.saving);

    final List<Student> rows = _visible(c);
    final List<Widget> header = <Widget>[
      RollDateHeader(
        date: widget.date,
        startMin: t.startMin,
        endMin: t.endMin,
        canGoNext: past,
        onPrev: () => widget.onDate(widget.date.addDays(-1)),
        onNext: () => widget.onDate(widget.date.addDays(1)),
        choices: widget.choices,
        selectedOcc: widget.occ,
        onPick: widget.onPick,
      ),
      if (archived) _gap(RollBanner(icon: Icons.inventory_2_outlined, text: l10n.rollBannerArchived)),
      if (future)
        _gap(RollBanner(icon: Icons.event_busy, text: l10n.rollBannerFuture, tone: RollBannerTone.warning))
      else if (past)
        _gap(RollBanner(icon: Icons.history, text: l10n.rollBannerPast)),
      if (t.cancelled) _gap(RollBanner(icon: Icons.block, text: l10n.rollBannerCancelled)),
      if (t.adHoc && !c.readOnly) ...<Widget>[
        _gap(RollBanner(icon: Icons.add_circle_outline, text: l10n.rollBannerAdHoc)),
        _gap(AdHocTimeCard(
          startMin: t.startMin,
          endMin: t.endMin,
          enabled: !c.saving,
          onStart: () => unawaited(_pickTime(start: true)),
          onEnd: () => unawaited(_pickTime(start: false)),
        )),
        if (_clash != null && !_clash!.ok) _gap(_clashCard(t, _clash!)),
      ],
      if (c.restoredFromDraft && !c.saved) _gap(RollBanner(icon: Icons.restore, text: l10n.rollBannerDraft)),
      if (c.error != null) _gap(_errorCard(c)),
      if (c.note != null)
        _gap(RollBanner(icon: Icons.edit_note, text: l10n.rollNoteLabel(c.note!))),
      if (_showHint && !c.readOnly && c.students.isNotEmpty)
        _gap(RollBanner(icon: Icons.info_outline, text: l10n.rollHintAllPresent)),
      if (c.students.isNotEmpty && !c.readOnly) _gap(_actionsRow(c)),
    ];

    final Widget roster;
    if (c.students.isEmpty) {
      roster = Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: EmptyState(
          icon: Icons.groups_outlined,
          message: l10n.rollEmptyBatch,
          actionLabel: (archived || c.readOnly) ? null : l10n.rollAddStudent,
          onAction: (archived || c.readOnly)
              ? null
              : () async {
                  await showAddStudentToBatchSheet(context, batchId: t.batch.id);
                  if (!mounted) return;
                  _reloadRoster();
                },
          fill: false,
        ),
      );
    } else if (rows.isEmpty) {
      roster = Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text(l10n.rollNoMatch, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: tokens.textSecondary))),
      );
    } else {
      roster = _Roster(
        rows: rows,
        columns: wide || wc == WindowClass.medium ? _columns(wc) : 1,
        gap: 8,
        builder: (int i) => _row(context, c, rows[i], i, dense: dense, keyed: wide || wc == WindowClass.medium),
      );
    }

    final Widget title = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l10n.rollTitle(t.subjectName, t.batch.name),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        stateLine,
      ],
    );

    final PopupMenuButton<String> menu = PopupMenuButton<String>(
      tooltip: l10n.commonMore,
      onSelected: (String v) {
        if (v == 'note') unawaited(_editNote());
        if (v == 'delete') unawaited(_deleteSession());
      },
      itemBuilder: (BuildContext ctx) => <PopupMenuEntry<String>>[
        if (!c.readOnly) PopupMenuItem<String>(value: 'note', child: Text(l10n.rollMenuNote)),
        if (!c.readOnly && c.saved && !t.adHoc)
          PopupMenuItem<String>(value: 'delete', child: Text(l10n.rollMenuDelete)),
      ],
    );
    final bool hasMenu = !c.readOnly;

    final Widget body;
    if (wide) {
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              controller: _scroll,
              padding: EdgeInsets.fromLTRB(gutter, 4, gutter, gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[...header, const SizedBox(height: 12), roster],
              ),
            ),
          ),
          SizedBox(
            width: 300,
            child: DecoratedBox(
              decoration: BoxDecoration(border: Border(left: BorderSide(color: tokens.hairline))),
              child: Column(
                children: <Widget>[
                  Expanded(
                    child: RollSummaryPane(
                      counts: k,
                      state: stateLine,
                      note: c.note,
                      onNote: c.readOnly ? null : () => unawaited(_editNote()),
                    ),
                  ),
                  bar,
                ],
              ),
            ),
          ),
        ],
      );
    } else {
      final bool twoCol = wc == WindowClass.medium;
      body = Column(
        children: <Widget>[
          Expanded(
            child: CustomScrollView(
              controller: _scroll,
              slivers: <Widget>[
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(gutter, 4, gutter, 12),
                  sliver: SliverToBoxAdapter(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: header),
                  ),
                ),
                if (twoCol || c.students.isEmpty || rows.isEmpty)
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(gutter, 0, gutter, gutter),
                    sliver: SliverToBoxAdapter(child: roster),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(gutter, 0, gutter, gutter),
                    sliver: SliverList.separated(
                      itemCount: rows.length,
                      separatorBuilder: (BuildContext _, int __) => const SizedBox(height: 8),
                      itemBuilder: (BuildContext ctx, int i) => _row(ctx, c, rows[i], i, dense: false, keyed: false),
                    ),
                  ),
              ],
            ),
          ),
          bar,
        ],
      );
    }

    return PopScope(
      canPop: _leaving || !c.dirty,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) unawaited(_confirmLeave());
      },
      child: Focus(
        focusNode: _focus,
        autofocus: wide,
        onKeyEvent: _onKey,
        child: IgnorePointer(
          ignoring: _leaving && GoRouter.maybeOf(context) != null,
          child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: l10n.commonClose,
              icon: const Icon(Icons.close),
              onPressed: _close,
            ),
            title: Semantics(header: true, child: title),
            actions: <Widget>[
              if (!c.readOnly)
                IconButton(
                  tooltip: l10n.commonUndo,
                  icon: const Icon(Icons.undo),
                  onPressed: c.canUndo ? c.undo : null,
                ),
              if (hasMenu) menu,
            ],
          ),
          body: SafeArea(top: false, child: body),
        ),
        ),
      ),
    );
  }

  Widget _gap(Widget child) => Padding(padding: const EdgeInsets.only(top: 8), child: child);

  void _reloadRoster() {
    final RollCallController? old = _c;
    setState(() {
      _c = null;
      _target = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => old?.dispose());
    unawaited(_load());
  }

  Widget _row(BuildContext context, RollCallController c, Student s, int index, {required bool dense, required bool keyed}) {
    final int roll = _rollOf[s.id] ?? (index + 1);
    final Widget row = RollRow(
      name: s.name,
      roll: roll,
      status: c.statusOf(s.id),
      dense: dense,
      enabled: !c.readOnly,
      focused: dense && _cursor == index,
      onToggle: () {
        setState(() => _cursor = index);
        HapticFeedback.selectionClick();
        c.toggle(s.id);
      },
      onLate: () {
        setState(() => _cursor = index);
        HapticFeedback.selectionClick();
        c.toggleLate(s.id);
      },
      onMenu: () => unawaited(_rowMenu(c, s)),
    );
    if (!keyed) return row;
    return KeyedSubtree(key: _rowKeys.putIfAbsent(s.id, () => GlobalKey()), child: row);
  }

  Widget _actionsRow(RollCallController c) {
    final l10n = context.l10n;
    final bool wide = WindowClass.of(context).isWide;
    final Widget buttons = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        OutlinedButton.icon(
          onPressed: () => c.markAll(AttendanceStatus.present),
          icon: Icon(AttendanceStatus.present.icon),
          label: Text(l10n.rollAllPresent),
          style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
        ),
        OutlinedButton.icon(
          onPressed: () => c.markAll(AttendanceStatus.absent),
          icon: Icon(AttendanceStatus.absent.icon),
          label: Text(l10n.rollAllAbsent),
          style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
        ),
      ],
    );
    final Widget search = TextField(
      controller: _search,
      textInputAction: TextInputAction.search,
      onChanged: (String _) => setState(() => _cursor = -1),
      decoration: InputDecoration(
        hintText: l10n.rollSearchHint,
        prefixIcon: const Icon(Icons.search),
        isDense: true,
      ),
    );
    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Flexible(flex: 3, child: buttons),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: search),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[buttons, const SizedBox(height: 8), search],
    );
  }

  Widget _errorCard(RollCallController c) {
    final l10n = context.l10n;
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.errorContainer,
          borderRadius: BorderRadius.circular(AuroraMetrics.radiusDenseList),
          border: Border.all(color: tokens.errorContainerBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              Icon(Icons.error_outline, color: tokens.onErrorContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  errorText(l10n, c.error!),
                  style: tt.bodyMedium?.copyWith(color: tokens.onErrorContainer),
                ),
              ),
              TextButton(
                onPressed: () => unawaited(_save()),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48), foregroundColor: tokens.onErrorContainer),
                child: Text(l10n.commonRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _clashCard(RollTarget t, SlotCheckResult r) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final Map<String, BatchSchedule> byBatch = <String, BatchSchedule>{
      for (final BatchSchedule s in _schedules) s.batch.id: s,
    };
    final List<String> lines = <String>[
      for (final ClashGroup g in r.groups.take(3))
        l10n.rollClashLine(
          '${byBatch[g.batchId]?.subjectName ?? ''} · ${byBatch[g.batchId]?.batch.name ?? ''}',
          fmt.timeRange(g.startMin, g.endMin),
        ),
    ];
    final int duration = t.endMin - t.startMin;
    final FreeSuggestion? s = r.suggestion;
    final List<ConflictFix> fixes = <ConflictFix>[];
    if (s != null) {
      final int? primary = s.primaryStartMin;
      if (primary != null) {
        fixes.add(ConflictFix(
          label: l10n.rollFixUse(fmt.timeRange(primary, primary + duration)),
          onTap: () => _setTimes(primary, primary + duration),
          primary: true,
        ));
      }
    }
    return ConflictCard(
      lines: lines,
      moreCount: r.groups.length > 3 ? r.groups.length - 3 : 0,
      fixes: fixes,
    );
  }
}

/// "সংরক্ষিত" with a check icon, "সংরক্ষণ হচ্ছে…" or "এখনো সেভ হয়নি".
class _StateLine extends StatelessWidget {
  const _StateLine({required this.saved, required this.saving});

  final bool saved;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final String text = saving ? l10n.rollStateSaving : (saved ? l10n.rollStateSaved : l10n.rollStateUnsaved);
    final IconData icon = saving ? Icons.sync : (saved ? Icons.check : Icons.edit_outlined);
    return Semantics(
      liveRegion: true,
      container: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: tokens.textSecondary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.labelSmall?.copyWith(color: tokens.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Column-major roster: the first `ceil(n / columns)` rows fill column one, so
/// "down" always means "next roll".
class _Roster extends StatelessWidget {
  const _Roster({
    required this.rows,
    required this.columns,
    required this.gap,
    required this.builder,
  });

  final List<Student> rows;
  final int columns;
  final double gap;
  final Widget Function(int index) builder;

  @override
  Widget build(BuildContext context) {
    final int n = rows.length;
    final int cols = columns < 1 ? 1 : columns;
    final int perCol = (n / cols).ceil();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (var col = 0; col < cols; col++) ...<Widget>[
          if (col > 0) SizedBox(width: gap + 4),
          Expanded(
            child: Column(
              children: <Widget>[
                for (var i = col * perCol; i < n && i < (col + 1) * perCol; i++)
                  Padding(padding: EdgeInsets.only(bottom: gap), child: builder(i)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({required this.initial});

  final String initial;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.rollNoteTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 200,
        minLines: 1,
        maxLines: 4,
        decoration: InputDecoration(hintText: l10n.rollNoteHint),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}
