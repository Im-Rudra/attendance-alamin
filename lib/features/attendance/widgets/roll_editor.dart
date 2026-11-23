// The roll call itself (UX 2b): loads one class (or the ad-hoc class of a day
// without one), its roster and any saved marks / unsaved draft, and lets the
// teacher mark everyone in a few taps. Phones: one column with the pinned
// save bar. Wide windows: a BhorFocusPage inside the shell (slim top bar with
// the date switcher and actions, one centred column of rows, a sticky bottom
// bar with the live counts and Save) and the desktop keys.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/error_text.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/providers/schedule_providers.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/stub_screen.dart';
import 'package:attendance_alamin/app/shell/templates/templates.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/app/widgets/theme_mapping.dart';
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
import 'package:attendance_alamin/domain/models/enrollment.dart';
import 'package:attendance_alamin/features/attendance/controllers/late_joiners.dart';
import 'package:attendance_alamin/features/attendance/controllers/roll_call_controller.dart';
import 'package:attendance_alamin/features/attendance/controllers/roll_models.dart';
import 'package:attendance_alamin/features/attendance/widgets/late_joiners_ui.dart';
import 'package:attendance_alamin/features/attendance/widgets/roll_header.dart';
import 'package:attendance_alamin/features/attendance/widgets/roll_parts.dart';
import 'package:attendance_alamin/features/attendance/widgets/roll_row.dart';
import 'package:attendance_alamin/features/attendance/widgets/roll_skeleton.dart';
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

class _RollEditorState extends ConsumerState<RollEditor> with SingleTickerProviderStateMixin {
  RollCallController? _c;
  RollTarget? _target;
  List<BatchSchedule> _schedules = const <BatchSchedule>[];
  Map<String, int> _rollOf = const <String, int>{};

  /// Students who joined after this date (footer line; see late_joiners.dart).
  List<LateJoiner> _late = const <LateJoiner>[];
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

  /// The cursor was last moved with the keyboard: only then is its outline
  /// drawn (a mouse click never leaves a focus ring behind, review R3).
  bool _kbCursor = false;
  String _digits = '';
  bool _leaving = false;

  /// The save button is showing its "done" check (success moment).
  bool _celebrate = false;
  late final AnimationController _hold =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 520));

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
    _hold.dispose();
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
        rolls[roster[i].id] = int.tryParse(AppFormat.toAsciiDigits(roster[i].roll ?? '')) ?? (i + 1);
      }
      final List<LateJoiner> lateJoiners =
          (bs.batch.archived || date.isAfter(today)) ? const <LateJoiner>[] : await _loadLateJoiners(date);
      if (!mounted) return;

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
        _late = lateJoiners;
        _c = controller;
        _showHint = saved == null && !readOnly && roster.isNotEmpty;
      });
      if (target.adHoc && !readOnly) unawaited(_recheck());
    } on Object catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  /// Open enrolments of this batch that start after [date]. A failure here
  /// only hides the footer line; it never stops the roll call from loading.
  Future<List<LateJoiner>> _loadLateJoiners(LocalDate date) async {
    try {
      final List<Enrollment> all =
          await ref.read(enrollmentsRepositoryProvider).watchForBatch(widget.batchId).first;
      final Map<String, Student> byId = <String, Student>{};
      for (final Enrollment e in all) {
        if (e.endDate != null || !e.joinDate.isAfter(date)) continue;
        final Student? s = await ref.read(studentsRepositoryProvider).getById(e.studentId);
        if (s != null) byId[s.id] = s;
      }
      return lateJoinersOf(date: date, enrollments: all, studentsById: byId);
    } on Object {
      return const <LateJoiner>[];
    }
  }

  /// "Show" of the late-joiners footer: who joined after this date. "Add" on
  /// a row asks once, moves that join date to this day and reloads the roster
  /// so the student can be marked.
  Future<void> _showLateJoiners(BuildContext anchor) async {
    final LocalDate date = _target?.date ?? widget.date;
    final List<LateJoiner> shown = _late;
    final LateJoiner? picked = await showBhorPanel<LateJoiner>(
      context,
      kind: BhorPanelKind.list,
      anchor: anchor,
      title: context.l10n.rollLateTitle(context.fmt.number(shown.length)),
      width: 400,
      builder: (BuildContext ctx) => LateJoinersList(
        joiners: shown,
        date: date,
        onAdd: (LateJoiner j) => Navigator.of(ctx).pop(j),
      ),
    );
    if (picked == null || !mounted) return;
    await _moveLateJoiner(picked, date);
  }

  Future<void> _moveLateJoiner(LateJoiner j, LocalDate date) async {
    final l10n = context.l10n;
    final bool ok = await showBhorConfirm(
      context,
      title: l10n.rollLateMoveTitle(j.student.name, context.fmt.date(date)),
      message: l10n.rollLateMoveBody,
      confirmLabel: l10n.rollLateMoveConfirm,
    );
    if (!ok || !mounted) return;
    try {
      await ref
          .read(enrollmentsRepositoryProvider)
          .updateJoinDate(j.enrollmentId, DateTime(date.year, date.month, date.day));
    } on Object catch (e) {
      if (mounted) BhorToast.show(context, message: errorText(l10n, e), tone: BhorTone.danger);
      return;
    }
    if (!mounted) return;
    // Marks not saved yet live in the roll-call draft (written on every
    // change) and come back with the reloaded roster.
    _reloadRoster();
  }

  /// Date button of the header: the calendar hangs from it, 2 years back to
  /// today (same range as "Another date"). Goes through the same day change
  /// as the arrows, so drafts and the unsaved-marks handling are unchanged.
  Future<void> _pickDate(BuildContext anchor) async {
    final LocalDate today = ref.read(todayProvider);
    final int weekStart = ref.read(weekStartProvider).value ?? DateTime.saturday;
    final DateTime first = DateTime(today.year - 2, today.month, today.day);
    final DateTime last = DateTime(today.year, today.month, today.day);
    DateTime initial = DateTime(widget.date.year, widget.date.month, widget.date.day);
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    final DateTime? picked = await showBhorDatePicker(
      context,
      anchor: anchor,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      weekStart: weekStart,
      today: last,
    );
    if (picked == null || !mounted) return;
    final LocalDate d = LocalDate(picked.year, picked.month, picked.day);
    if (d != widget.date) widget.onDate(d);
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

  Future<void> _pickTime({required bool start, BuildContext? anchor}) async {
    final RollTarget? t = _target;
    if (t == null) return;
    final int? m = await showBhorTimePicker(
      context,
      anchor: anchor,
      initial: start ? t.startMin : t.endMin,
      title: start ? context.l10n.rollAdHocStart : context.l10n.rollAdHocEnd,
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
    final AttendanceRepository attendance = ref.read(attendanceRepositoryProvider);
    final ScheduleRepository scheduleRepo = ref.read(scheduleRepositoryProvider);
    final bool wasSaved = c.saved;
    final bool wasAdHoc = t.adHoc;
    final bool wasCancelled = t.cancelled;
    final bool ok = await c.save();
    if (!mounted || !ok) return;
    if (!wasSaved) {
      final String? occ = _target?.occurrence?.occ;
      BhorToast.show(
        context,
        message: l10n.rollSavedSnack,
        duration: const Duration(seconds: 8),
        actionLabel: occ == null ? null : l10n.commonUndo,
        onAction: occ == null
            ? null
            : () async {
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
      );
    }
    // Success moment: the button morphs to a check, a short hold, then close.
    if (!BhorMotion.reduced(context)) {
      setState(() => _celebrate = true);
      await _hold.forward(from: 0);
      if (!mounted) return;
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
    // Title then the two answers: no empty body band (review b277 X6).
    final _LeaveChoice? choice = await showBhorConfirmChoice<_LeaveChoice>(
      context,
      title: l10n.rollLeaveTitle,
      primaryLabel: l10n.rollLeaveSave,
      primaryValue: _LeaveChoice.save,
      secondaryLabel: l10n.rollLeaveDiscard,
      secondaryValue: _LeaveChoice.discard,
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
    final AttendanceRepository attendance = ref.read(attendanceRepositoryProvider);
    final bool yes = await showBhorConfirm(
      context,
      title: l10n.rollDeleteTitle,
      message: l10n.rollDeleteBody,
      confirmLabel: l10n.rollDeleteConfirm,
      destructive: true,
    );
    if (!yes || !mounted) return;
    try {
      await attendance.deleteSession(occ);
    } on Object catch (e) {
      if (mounted) {
        BhorToast.show(context, message: errorText(l10n, e), tone: BhorTone.danger);
      }
      return;
    }
    if (!mounted) return;
    BhorToast.show(context, message: l10n.rollDeletedSnack);
    _finish();
  }

  /// The class note: a small form anchored to the control that opened it
  /// ([anchor]: the note button, the more button or a row's dots), a small
  /// dialog when there is none, a sheet on phones (review b277 X3). Save
  /// stays disabled until the text changed; closing with changes asks first.
  Future<void> _editNote([BuildContext? anchor]) async {
    final RollCallController? c = _c;
    if (c == null || c.readOnly) return;
    final String initial = c.note ?? '';
    final TextEditingController text = TextEditingController(text: initial);
    final ValueNotifier<bool> dirty = ValueNotifier<bool>(false);
    void sync() => dirty.value = text.text.trim() != initial.trim();
    text.addListener(sync);
    final BuildContext? at = (anchor != null && anchor.mounted) ? anchor : null;
    final String? value = await showBhorPanel<String>(
      context,
      kind: BhorPanelKind.picker,
      anchor: at,
      title: context.l10n.rollNoteTitle,
      width: 380,
      dirty: dirty,
      builder: (BuildContext ctx) => RollNoteField(controller: text),
      footer: (BuildContext ctx) => ValueListenableBuilder<bool>(
        valueListenable: dirty,
        builder: (BuildContext bc, bool changed, Widget? _) => BhorButton(
          key: const ValueKey<String>('roll-note-save'),
          label: ctx.l10n.commonSave,
          expand: true,
          onPressed: changed ? () => Navigator.of(ctx).pop(text.text) : null,
        ),
      ),
    );
    // Not disposed here: the popover may still be fading out with the field.
    text.removeListener(sync);
    if (value == null || !mounted) return;
    c.setNote(value);
  }

  Future<void> _rowMenu(RollCallController c, Student s, BuildContext anchor, Set<AttendanceStatus> onRow) async {
    if (c.readOnly) return;
    if (context.bhorIsWide) {
      // Desktop: an anchored menu at the dots button (one click per status).
      // Wide rows show every status as a button already: the menu then only
      // holds what the row does not (review b277 X5).
      final l10n = context.l10n;
      await showBhorMenu(
        context,
        anchor: anchor,
        items: <BhorMenuItem>[
          for (final AttendanceStatus st in AttendanceStatus.values)
            if (!onRow.contains(st))
              BhorMenuItem(
                key: Key('roll-menu-${st.name}'),
                icon: statusIcon(st),
                label: st.label(l10n),
                onTap: () {
                  if (mounted) c.setStatus(s.id, st);
                },
              ),
          BhorMenuItem(
            key: const Key('roll-menu-note'),
            icon: BhorIcons.notes,
            label: l10n.rollMenuNote,
            onTap: () => unawaited(_editNote(anchor)),
          ),
        ],
      );
      return;
    }
    final RollMenuChoice? choice = await showRollStatusSheet(
      context,
      name: s.name,
      current: c.statusOf(s.id),
      anchor: anchor,
    );
    if (choice == null || !mounted) return;
    if (choice.note) {
      if (anchor.mounted) {
        await _editNote(anchor);
      } else {
        await _editNote();
      }
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
    setState(() {
      _cursor = index;
      _kbCursor = true;
    });
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
        icon: BhorIcons.rollCall,
        fullScreen: true,
        message: l10n.rollNotFound,
      );
    }
    if (_loadError != null) {
      return StubScreen(
        name: l10n.shellTitleRollCall,
        icon: BhorIcons.rollCall,
        fullScreen: true,
        message: errorText(l10n, _loadError!),
      );
    }
    if (c == null || t == null) {
      return StubScreen(
        name: l10n.shellTitleRollCall,
        icon: BhorIcons.rollCall,
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

  Widget _loaded(BuildContext context, RollCallController c, RollTarget initialTarget, LocalDate today, WindowClass wc) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final BhorThemeData b = context.bhor;
    final RollTarget t = _target ?? initialTarget;
    final bool wide = wc.isWide;
    final bool dense = wide || wc.usesRail;
    final double gutter = wc.gutter;
    final bool future = widget.date.isAfter(today);
    final bool past = widget.date.isBefore(today);
    final bool archived = t.batch.archived;
    final RollCounts k = c.counts;
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
    final VoidCallback? onSave = canSave ? () => unawaited(_save()) : null;
    final Widget bar = BhorActionBar(
      label: saveLabel,
      onPressed: onSave,
      loading: c.saving && !c.saved,
      done: _celebrate,
      disabledReason: reason,
    );

    final Widget stateLine = _StateLine(saved: c.saved, saving: c.saving);

    final List<Student> rows = _visible(c);

    // Every quiet note of the screen is ONE compact line (review R2); only
    // the warnings stand apart.
    final List<String> info = <String>[
      if (archived) l10n.rollBannerArchived,
      if (!future && past) l10n.rollBannerPast,
      if (t.cancelled) l10n.rollBannerCancelled,
      if (t.adHoc && !c.readOnly) l10n.rollBannerAdHoc,
      if (c.restoredFromDraft && !c.saved) l10n.rollBannerDraft,
      if (c.note != null) l10n.rollNoteLabel(c.note!),
      if (_showHint && !c.readOnly && c.students.isNotEmpty) l10n.rollHintAllPresent,
    ];
    final List<Widget> header = <Widget>[
      if (!wide)
        RollDateHeader(
          date: widget.date,
          startMin: t.startMin,
          endMin: t.endMin,
          canGoNext: past,
          onPrev: () => widget.onDate(widget.date.addDays(-1)),
          onNext: () => widget.onDate(widget.date.addDays(1)),
          onPickDate: _pickDate,
          choices: widget.choices,
          selectedOcc: widget.occ,
          onPick: widget.onPick,
        )
      else if (widget.choices.length > 1)
        RollSessionChips(choices: widget.choices, selectedOcc: widget.occ, onPick: widget.onPick, start: true),
      if (future)
        _gap(RollBanner(icon: BhorIcons.holiday, text: l10n.rollBannerFuture, tone: RollBannerTone.warning)),
      if (info.isNotEmpty) _gap(RollNotice(lines: info)),
      if (t.adHoc && !c.readOnly) ...<Widget>[
        _gap(AdHocTimeCard(
          startMin: t.startMin,
          endMin: t.endMin,
          enabled: !c.saving,
          onStart: (BuildContext bc) => unawaited(_pickTime(start: true, anchor: bc)),
          onEnd: (BuildContext bc) => unawaited(_pickTime(start: false, anchor: bc)),
        )),
        if (_clash != null && !_clash!.ok) _gap(_clashCard(t, _clash!)),
      ],
      if (c.error != null) _gap(_errorCard(c)),
      if (!wide && c.students.isNotEmpty) _gap(RollCountTags(counts: k)),
      if (c.students.isNotEmpty && !c.readOnly) _gap(_actionsRow(c)),
    ];

    Widget roster;
    if (c.students.isEmpty) {
      roster = Padding(
        padding: const EdgeInsets.symmetric(vertical: BhorSpace.s24),
        child: BhorEmptyState(
          icon: BhorIcons.batches,
          title: l10n.rollEmptyBatch,
          action: (archived || c.readOnly)
              ? null
              : BhorButton(
                  label: l10n.rollAddStudent,
                  onPressed: () async {
                    await showAddStudentToBatchSheet(context, batchId: t.batch.id);
                    if (!mounted) return;
                    _reloadRoster();
                  },
                ),
        ),
      );
    } else if (rows.isEmpty) {
      roster = Padding(
        padding: const EdgeInsets.symmetric(vertical: BhorSpace.s24),
        child: Center(child: Text(l10n.rollNoMatch, style: b.type.body.copyWith(color: b.colors.text2))),
      );
    } else {
      // Pointer taps never draw the keyboard outline (review R3).
      final bool keyboard = _kbCursor;
      // One comfortable column on wide windows: the rows stay readable and the
      // toggle sits near the name (a second column only fits at very wide
      // content, and the page is capped at 880 anyway).
      roster = _Roster(
        rows: rows,
        columns: 1,
        gap: BhorSpace.s8,
        builder: (int i) {
          final bool keyed = wide || wc == WindowClass.medium;
          final Widget row = _row(context, c, rows[i], i, dense: dense, keyed: keyed, keyboard: keyboard);
          return keyed ? row : BhorStagger(index: i, child: row);
        },
      );
    }

    // Phones show icon-only toggles: a one-line legend says what they mean.
    if (!dense && rows.isNotEmpty && !c.readOnly) {
      roster = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[const RollLegend(), roster],
      );
    }

    // Students who joined after this date are not on its roster: one quiet
    // line says so, "Show" lists them.
    if (_late.isNotEmpty) {
      roster = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          roster,
          LateJoinersFooter(
            count: _late.length,
            onShow: (BuildContext bc) => unawaited(_showLateJoiners(bc)),
          ),
        ],
      );
    }

    final bool canDelete = !c.readOnly && c.saved && !t.adHoc;
    final Widget content;
    if (wide) {
      final Widget actions = Builder(
        builder: (BuildContext bc) => Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (!c.readOnly)
              BhorIconButton(
                semanticLabel: l10n.commonUndo,
                icon: BhorIcons.undo,
                onPressed: c.canUndo ? c.undo : null,
              ),
            if (!c.readOnly)
              Builder(
                builder: (BuildContext nc) => BhorIconButton(
                  semanticLabel: l10n.rollMenuNote,
                  icon: BhorIcons.notes,
                  onPressed: () => unawaited(_editNote(nc)),
                ),
              ),
            Builder(
              builder: (BuildContext hc) => BhorIconButton(
                semanticLabel: l10n.rollShortcutsTitle,
                icon: BhorIcons.info,
                onPressed: () => unawaited(_showShortcuts(hc)),
              ),
            ),
            if (canDelete)
              Builder(
                builder: (BuildContext mc) => BhorIconButton(
                  semanticLabel: l10n.commonMore,
                  icon: BhorIcons.overflowVertical,
                  onPressed: () => unawaited(_openMenu(c, t, mc)),
                ),
              ),
          ],
        ),
      );
      content = BhorFocusPage(
        title: l10n.rollTitle(t.subjectName, t.batch.name),
        titleWidget: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(
                l10n.rollTitle(t.subjectName, t.batch.name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: b.type.title,
              ),
            ),
            RollDateHeader(
              date: widget.date,
              startMin: t.startMin,
              endMin: t.endMin,
              canGoNext: past,
              onPrev: () => widget.onDate(widget.date.addDays(-1)),
              onNext: () => widget.onDate(widget.date.addDays(1)),
              onPickDate: _pickDate,
              choices: widget.choices,
              selectedOcc: widget.occ,
              onPick: widget.onPick,
              start: true,
              showChips: false,
            ),
          ],
        ),
        actions: <Widget>[actions],
        onBack: _goBack,
        summary: c.students.isEmpty
            ? stateLine
            : Wrap(
                spacing: BhorSpace.s12,
                runSpacing: BhorSpace.s4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[RollCountTags(counts: k), stateLine],
              ),
        primary: BhorButton(
          label: saveLabel,
          onPressed: onSave,
          loading: c.saving && !c.saved,
          done: _celebrate,
          disabledReason: reason,
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[...header, const SizedBox(height: BhorSpace.s12), roster],
        ),
      );
    } else {
      final Widget title = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.rollTitle(t.subjectName, t.batch.name),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: b.type.title,
          ),
          stateLine,
        ],
      );
      // The menu only earns its place when it has more than the note: a saved
      // roll call can also be deleted. Otherwise "note" is a direct button.
      final Widget menu = canDelete
          ? Builder(
              builder: (BuildContext bc) => BhorIconButton(
                semanticLabel: l10n.commonMore,
                icon: BhorIcons.overflowVertical,
                onPressed: () => unawaited(_openMenu(c, t, bc)),
              ),
            )
          : Builder(
              builder: (BuildContext nc) => BhorIconButton(
                semanticLabel: l10n.rollMenuNote,
                icon: BhorIcons.notes,
                onPressed: () => unawaited(_editNote(nc)),
              ),
            );
      content = BhorScaffold(
        header: BhorHeader(
          divider: true,
          leading: BhorIconButton(
            semanticLabel: l10n.commonClose,
            icon: BhorIcons.back,
            variant: BhorButtonVariant.secondary,
            size: BhorButtonSize.sm,
            color: context.bhor.colors.text,
            onPressed: _close,
          ),
          titleWidget: Semantics(header: true, child: title),
          actions: <Widget>[
            if (!c.readOnly)
              BhorIconButton(
                semanticLabel: l10n.commonUndo,
                icon: BhorIcons.undo,
                onPressed: c.canUndo ? c.undo : null,
              ),
            if (!c.readOnly) menu,
          ],
        ),
        body: BhorStaggerScope(
          child: Column(
            children: <Widget>[
              Expanded(
                child: CustomScrollView(
                  controller: _scroll,
                  slivers: <Widget>[
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(gutter, BhorSpace.s4, gutter, BhorSpace.s12),
                      sliver: SliverToBoxAdapter(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: header),
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(gutter, 0, gutter, gutter),
                      sliver: SliverToBoxAdapter(child: roster),
                    ),
                  ],
                ),
              ),
              bar,
            ],
          ),
        ),
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
          child: content,
        ),
      ),
    );
  }

  /// Back / Esc: leaving with unsaved marks asks first, otherwise it goes
  /// straight back to where the teacher came from.
  void _goBack() {
    final RollCallController? c = _c;
    if (c != null && c.dirty && !_leaving) {
      unawaited(_confirmLeave());
    } else {
      _close();
    }
  }

  /// The keyboard help: a small popover hanging from its button.
  Future<void> _showShortcuts(BuildContext anchor) => showBhorPanel<void>(
        context,
        kind: BhorPanelKind.list,
        anchor: anchor,
        title: context.l10n.rollShortcutsTitle,
        width: 360,
        builder: (BuildContext ctx) => const RollShortcutList(),
      );

  /// The "more" menu: edit the class note, delete a saved roll call.
  Future<void> _openMenu(RollCallController c, RollTarget t, BuildContext anchor) async {
    final l10n = context.l10n;
    final bool canDelete = !c.readOnly && c.saved && !t.adHoc;
    await showBhorMenu(
      context,
      anchor: anchor,
      items: <BhorMenuItem>[
        BhorMenuItem(
          icon: BhorIcons.notes,
          label: l10n.rollMenuNote,
          onTap: () => unawaited(_editNote(anchor)),
        ),
        if (canDelete)
          BhorMenuItem(
            icon: BhorIcons.delete,
            label: l10n.rollMenuDelete,
            destructive: true,
            onTap: () => unawaited(_deleteSession()),
          ),
      ],
    );
  }

  Widget _gap(Widget child) => Padding(padding: const EdgeInsets.only(top: BhorSpace.s8), child: child);

  void _reloadRoster() {
    final RollCallController? old = _c;
    setState(() {
      _c = null;
      _target = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => old?.dispose());
    unawaited(_load());
  }

  Widget _row(BuildContext context, RollCallController c, Student s, int index,
      {required bool dense, required bool keyed, required bool keyboard}) {
    final int roll = _rollOf[s.id] ?? (index + 1);
    final Widget row = RollRow(
      name: s.name,
      roll: roll,
      status: c.statusOf(s.id),
      dense: dense,
      enabled: !c.readOnly,
      focused: dense && keyboard && _cursor == index,
      onToggle: () {
        setState(() {
          _cursor = index;
          _kbCursor = false;
        });
        HapticFeedback.selectionClick();
        c.toggle(s.id);
      },
      onSet: (AttendanceStatus next) {
        setState(() {
          _cursor = index;
          _kbCursor = false;
        });
        c.setStatus(s.id, next);
      },
      onMenu: (BuildContext rowContext, Set<AttendanceStatus> onRow) => unawaited(_rowMenu(c, s, rowContext, onRow)),
    );
    if (!keyed) return row;
    return KeyedSubtree(key: _rowKeys.putIfAbsent(s.id, () => GlobalKey()), child: row);
  }

  Widget _actionsRow(RollCallController c) {
    final l10n = context.l10n;
    final bool wide = WindowClass.of(context).isWide;
    final Widget buttons = Wrap(
      spacing: BhorSpace.s8,
      runSpacing: BhorSpace.s8,
      children: <Widget>[
        BhorButton(
          label: l10n.rollAllPresent,
          icon: BhorIcons.present,
          variant: BhorButtonVariant.secondary,
          onPressed: () => c.markAll(AttendanceStatus.present),
        ),
        BhorButton(
          label: l10n.rollAllAbsent,
          icon: BhorIcons.absent,
          variant: BhorButtonVariant.secondary,
          onPressed: () => c.markAll(AttendanceStatus.absent),
        ),
      ],
    );
    final Widget search = BhorTextField(
      controller: _search,
      textInputAction: TextInputAction.search,
      onChanged: (String _) => setState(() => _cursor = -1),
      hint: l10n.rollSearchHint,
      prefix: const Icon(BhorIcons.search),
    );
    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Flexible(flex: 3, child: buttons),
          const SizedBox(width: BhorSpace.s12),
          Expanded(flex: 2, child: search),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[buttons, const SizedBox(height: BhorSpace.s8), search],
    );
  }

  Widget _errorCard(RollCallController c) {
    final l10n = context.l10n;
    final BhorThemeData b = context.bhor;
    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: b.colors.dangerBg,
          borderRadius: BorderRadius.circular(BhorRadius.card),
          border: Border.all(color: b.colors.danger.withValues(alpha: 0.35)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(BhorSpace.s12),
          child: Row(
            children: <Widget>[
              Icon(BhorIcons.warning, color: b.colors.danger),
              const SizedBox(width: BhorSpace.s8),
              Expanded(
                child: Text(
                  errorText(l10n, c.error!),
                  style: b.type.body.copyWith(color: b.colors.danger),
                ),
              ),
              BhorButton(
                label: l10n.commonRetry,
                variant: BhorButtonVariant.ghost,
                onPressed: () => unawaited(_save()),
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
    final List<BhorClashFix> fixes = <BhorClashFix>[];
    if (s != null) {
      final int? primary = s.primaryStartMin;
      if (primary != null) {
        fixes.add(BhorClashFix(
          label: l10n.rollFixUse(fmt.timeRange(primary, primary + duration)),
          onTap: () => _setTimes(primary, primary + duration),
          primary: true,
        ));
      }
    }
    return BhorClashCard(
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
    final BhorThemeData b = context.bhor;
    final String text = saving ? l10n.rollStateSaving : (saved ? l10n.rollStateSaved : l10n.rollStateUnsaved);
    final IconData icon = saving ? BhorIcons.refresh : (saved ? BhorIcons.check : BhorIcons.edit);
    return Semantics(
      liveRegion: true,
      container: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: b.colors.text2),
          const SizedBox(width: BhorSpace.s4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: b.type.caption,
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
    final BhorColors c = context.bhor.colors;
    // One surface list per column: rows are separated by inset hairlines,
    // never by individual outlined cards.
    Widget group(int from, int to) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(BhorRadius.card),
          border: Border.all(color: c.line),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(BhorRadius.card - 1),
          child: Column(
            children: <Widget>[
              for (var i = from; i < to; i++) ...<Widget>[
                if (i > from)
                  Padding(
                    padding: const EdgeInsets.only(left: BhorSpace.s16),
                    child: SizedBox(height: 1, width: double.infinity, child: ColoredBox(color: c.line)),
                  ),
                builder(i),
              ],
            ],
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (var col = 0; col < cols; col++) ...<Widget>[
          if (col > 0) SizedBox(width: gap + BhorSpace.s4),
          Expanded(
            child: col * perCol < n ? group(col * perCol, n < (col + 1) * perCol ? n : (col + 1) * perCol) : const SizedBox.shrink(),
          ),
        ],
      ],
    );
  }
}
