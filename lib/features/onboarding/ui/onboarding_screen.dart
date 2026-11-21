// First-run onboarding (UX 2a): four short steps from a cold start to a usable
// app, with no instructions needed.
//   1 language (+ theme, optional center name)   2 first subject / batch / times
//   3 quick-add students                          4 class-reminder priming
// Every step can be left and come back to without losing what was typed; the
// batch is saved when step 2 is finished and each student is saved the moment
// "save and add next" is pressed, so nothing typed is ever thrown away.
// The last step sets `onboardingDone`, shows the one-time coach mark and lands
// on Today.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/l10n/error_text.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/validation/validators.dart';
import 'package:attendance_alamin/domain/models/drafts.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';
import 'package:attendance_alamin/features/extras/controllers/bulk_add_service.dart';
import 'package:attendance_alamin/features/extras/widgets/csv_import_flow.dart';
import 'package:attendance_alamin/features/onboarding/controllers/onboarding_service.dart';
import 'package:attendance_alamin/features/onboarding/widgets/batch_step.dart';
import 'package:attendance_alamin/features/onboarding/widgets/coach_mark.dart';
import 'package:attendance_alamin/features/onboarding/widgets/context_pane.dart';
import 'package:attendance_alamin/features/onboarding/widgets/language_step.dart';
import 'package:attendance_alamin/features/onboarding/widgets/onb_common.dart';
import 'package:attendance_alamin/features/onboarding/widgets/reminder_step.dart';
import 'package:attendance_alamin/features/onboarding/widgets/students_step.dart';
import 'package:attendance_alamin/features/reminders/reminders_entry.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const String _dash = ' — ';

  int _step = 0;

  final TextEditingController _center = TextEditingController();
  final TextEditingController _subject = TextEditingController();
  final TextEditingController _batchName = TextEditingController();
  final TextEditingController _fee = TextEditingController();
  final TextEditingController _studentName = TextEditingController();
  final TextEditingController _studentPhone = TextEditingController();
  final FocusNode _nameFocus = FocusNode();

  BillingType _billing = BillingType.prepaid;
  late List<SlotDraft> _slots;
  SlotCheckResult _check = const SlotCheckResult();
  String? _classLabel;
  bool _batchNameSeeded = false;

  /// The last name this screen wrote into the batch name field; once the field
  /// differs the teacher has typed their own and it is never overwritten.
  String? _autoBatchName;

  String? _batchId;
  ({String subject, String batch})? _created;
  final List<SavedStudent> _students = <SavedStudent>[];
  String? _lastAdded;

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Today's weekday at the next full hour (07:00-20:00, else 16:00), one hour
    // long (UX 2a).
    final LocalDate today = ref.read(todayProvider);
    final int now = ref.read(nowMinutesProvider);
    final int start = defaultSlotStartMin(now);
    _slots = <SlotDraft>[SlotDraft(weekday: today.isoWeekday, startMin: start, endMin: start + 60)];
    for (final TextEditingController c in <TextEditingController>[_subject, _batchName, _fee]) {
      c.addListener(_formChanged);
    }
  }

  @override
  void dispose() {
    _center.dispose();
    _subject.dispose();
    _batchName.dispose();
    _fee.dispose();
    _studentName.dispose();
    _studentPhone.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _formChanged() {
    if (!mounted) return;
    setState(() {
      _error = null;
      final String? c = _classLabel;
      if (c != null && !_subject.text.contains(c)) _classLabel = null;
    });
  }

  /// A callback from the slot editor may arrive while it builds.
  void _defer(VoidCallback f) {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(f);
      });
    } else {
      setState(f);
    }
  }

  // ---- navigation -------------------------------------------------------

  void _go(int step) {
    if (step == 1 && !_batchNameSeeded) {
      _batchNameSeeded = true;
      _setAutoBatchName();
    }
    setState(() {
      _step = step;
      _error = null;
    });
  }

  /// "বিকাল ৪টার ব্যাচ": the default batch name from the first class time.
  String _timeBatchName(int startMin) {
    final String t = context.fmt.time(startMin);
    final String hourOnly = t.replaceFirst(RegExp(r':(00|০০)'), '');
    return context.l10n.onbBatchTimeName(hourOnly);
  }

  void _setAutoBatchName() {
    if (_slots.isEmpty) return;
    final String? last = _autoBatchName;
    if (last != null && _batchName.text != last) return; // typed by the teacher
    final String next = _timeBatchName(_slots.first.startMin);
    _autoBatchName = next;
    _batchName.text = next;
  }

  void _back() {
    if (_busy || _step == 0) return;
    _go(_step - 1);
  }

  // ---- step 1: language and center name ---------------------------------

  Future<void> _afterLanguage() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final l10n = context.l10n;
    try {
      await ref.read(onboardingServiceProvider).saveCenterName(_center.text);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = errorText(l10n, e);
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    _go(1);
  }

  // ---- step 2: first batch ----------------------------------------------

  String _composeSubject(String base, String? cls) {
    if (cls == null) return base;
    return base.isEmpty ? cls : '$base$_dash$cls';
  }

  String _baseOfSubject() {
    String t = _subject.text.trim();
    final String? old = _classLabel;
    if (old != null) {
      if (t.endsWith('$_dash$old')) {
        t = t.substring(0, t.length - old.length - _dash.length).trim();
      } else if (t == old) {
        t = '';
      }
    }
    return t;
  }

  void _onSubjectChip(String s) {
    _subject.text = _composeSubject(s, _classLabel);
  }

  void _onClassChip(String c) {
    final String base = _baseOfSubject();
    final String? next = _classLabel == c ? null : c;
    setState(() => _classLabel = next);
    _subject.text = _composeSubject(base, next);
  }

  String? _batchReason() {
    final l10n = context.l10n;
    if (_subject.text.trim().isEmpty) return l10n.batchReasonSubject;
    if (_batchName.text.trim().isEmpty) return l10n.batchReasonName;
    try {
      Validators.amount(_fee.text);
    } on ValidationException {
      return l10n.batchReasonFee;
    }
    if (_slots.isEmpty) return l10n.batchReasonSlots;
    if (!_check.ok) return l10n.batchReasonClash;
    return null;
  }

  Future<void> _createBatch() async {
    if (_busy || _batchReason() != null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final l10n = context.l10n;
    final String subject = _subject.text.trim();
    final String batch = _batchName.text.trim();
    try {
      final String id = await ref.read(onboardingServiceProvider).createBatch(
            subject: subject,
            batchName: batch,
            fee: _fee.text,
            billing: _billing,
            slots: _slots,
          );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _batchId = id;
        _created = (subject: subject, batch: batch);
      });
      _go(2);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = errorText(l10n, e);
        });
      }
    }
  }

  // ---- step 3: students -------------------------------------------------

  /// Saves the typed student. With [requireName] an empty name is an error
  /// (the button); without it nothing typed means nothing to save (Next).
  /// Returns false when something went wrong and the teacher must look.
  Future<bool> _addStudent({required bool requireName}) async {
    if (_busy) return false;
    final l10n = context.l10n;
    final bool empty = _studentName.text.trim().isEmpty;
    if (empty && !requireName && _studentPhone.text.trim().isEmpty) return true;
    // Clear the fields now, before the save: anything typed while it runs is
    // the next student and must survive.
    final String typedName = _studentName.text;
    final String typedPhone = _studentPhone.text;
    _studentName.clear();
    _studentPhone.clear();
    setState(() {
      _busy = true;
      _error = null;
    });
    _nameFocus.requestFocus();
    try {
      final SavedStudent s = await ref.read(onboardingServiceProvider).addStudent(
            name: typedName,
            guardianPhone: typedPhone,
            batchId: _batchId,
          );
      if (!mounted) return true;
      setState(() {
        _busy = false;
        _students.add(s);
        _lastAdded = s.name;
      });
      _nameFocus.requestFocus();
      return true;
    } on Object catch (e) {
      if (mounted) {
        if (_studentName.text.isEmpty && _studentPhone.text.isEmpty) {
          _studentName.text = typedName;
          _studentPhone.text = typedPhone;
        }
        setState(() {
          _busy = false;
          _error = errorText(l10n, e);
        });
        if (e is AppException) _nameFocus.requestFocus();
      }
      return false;
    }
  }

  Future<void> _importCsv() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await startCsvStudentImport(
        context,
        ref,
        batchId: _batchId,
        onAdded: (List<BulkAdded> added) {
          if (!mounted) return;
          setState(() {
            for (final BulkAdded a in added) {
              _students.add(SavedStudent(id: a.id, name: a.name, roll: a.roll, guardianPhone: a.guardianPhone));
            }
            if (added.isNotEmpty) _lastAdded = added.last.name;
          });
        },
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _afterStudents() async {
    if (!await _addStudent(requireName: false)) return;
    if (!mounted) return;
    _go(3);
  }

  // ---- step 4: reminders and finish -------------------------------------

  Future<void> _finish({required bool remind}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final l10n = context.l10n;
    try {
      if (remind) {
        try {
          await showReminderPriming(context);
        } on Object {
          // A refused or failed permission never blocks the first start.
        }
        if (!mounted) return;
      }
      await ref.read(onboardingServiceProvider).markDone();
      if (!mounted) return;
      if (_batchId != null) await showRollCallCoach(context);
      if (!mounted) return;
      GoRouter.maybeOf(context)?.go(Routes.today);
    } on Object catch (e) {
      if (mounted) setState(() => _error = errorText(l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---- build ------------------------------------------------------------

  Widget _stepBody() {
    switch (_step) {
      case 0:
        return LanguageStep(center: _center, onSubmit: _afterLanguage);
      case 1:
        return BatchStep(
          subject: _subject,
          name: _batchName,
          fee: _fee,
          billing: _billing,
          onBilling: (BillingType t) => setState(() => _billing = t),
          slots: _slots,
          onSlots: (List<SlotDraft> s) => _defer(() {
            _slots = s;
            if (_batchNameSeeded) _setAutoBatchName();
          }),
          onCheck: (SlotCheckResult r) => _defer(() => _check = r),
          classLabel: _classLabel,
          onSubjectChip: _onSubjectChip,
          onClassChip: _onClassChip,
          created: _created,
          error: _error,
        );
      case 2:
        return StudentsStep(
          name: _studentName,
          phone: _studentPhone,
          nameFocus: _nameFocus,
          onAdd: () => _addStudent(requireName: true),
          onImportCsv: _importCsv,
          saved: _students,
          batchName: _created?.batch,
          billingMonth: context.fmt.monthYear(ref.read(todayProvider).yearMonth),
          busy: _busy,
          error: _error,
          lastAdded: _lastAdded,
        );
      default:
        return ReminderStep(error: _error);
    }
  }

  Widget _actionBar() {
    final l10n = context.l10n;
    switch (_step) {
      case 0:
        return OnbActionBar(
          label: l10n.commonNext,
          onPressed: _busy ? null : _afterLanguage,
        );
      case 1:
        if (_created != null) {
          return OnbActionBar(label: l10n.commonNext, onPressed: () => _go(2));
        }
        final String? reason = _batchReason();
        return OnbActionBar(
          label: l10n.onbCreateBatch,
          onPressed: reason == null && !_busy ? _createBatch : null,
          disabledReason: reason,
        );
      case 2:
        return OnbActionBar(
          label: l10n.commonNext,
          onPressed: _busy ? null : _afterStudents,
          secondaryLabel: _students.isEmpty ? l10n.onbStudentsLater : null,
          onSecondary: _busy ? null : () => _go(3),
        );
      default:
        return OnbActionBar(
          label: _busy ? l10n.onbFinishing : l10n.onbRemindYes,
          onPressed: _busy ? null : () => _finish(remind: true),
          secondaryLabel: l10n.onbRemindNo,
          onSecondary: _busy ? null : () => _finish(remind: false),
        );
    }
  }

  Widget _topBar() {
    final l10n = context.l10n;
    final bool canSkip = _step == 1 && _created == null;
    return SizedBox(
      height: 56,
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 64,
            child: _step == 0
                ? null
                : IconButton(
                    key: const Key('onb-back'),
                    tooltip: l10n.commonBack,
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _busy ? null : _back,
                  ),
          ),
          Expanded(child: Center(child: OnbProgressDots(step: _step))),
          SizedBox(
            width: 96,
            child: canSkip
                ? TextButton(
                    key: const Key('onb-skip'),
                    onPressed: _busy ? null : () => _go(2),
                    child: Text(l10n.onbSkip),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _scrollBody(double gutter) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          key: ValueKey<int>(_step),
          padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 24),
          child: _stepBody(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool wide = WindowClass.of(context).isWide;
    final tokens = context.aurora;
    final Widget content;
    if (wide) {
      content = LayoutBuilder(
        builder: (BuildContext context, BoxConstraints box) {
          final double h = math.min(math.max(box.maxHeight - 48, 320), 780);
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: SizedBox(
                  height: h,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      SizedBox(width: 360, child: OnbContextPane(step: _step)),
                      const SizedBox(width: 24),
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: tokens.surfaceDense,
                            borderRadius: BorderRadius.circular(AuroraMetrics.radiusHero),
                            border: Border.all(color: tokens.hairline),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AuroraMetrics.radiusHero),
                            child: Column(
                              children: <Widget>[
                                _topBar(),
                                Expanded(child: _scrollBody(24)),
                                _actionBar(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    } else {
      content = Column(
        children: <Widget>[
          _topBar(),
          Expanded(child: _scrollBody(16)),
          _actionBar(),
        ],
      );
    }

    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        body: SafeArea(child: content),
      ),
    );
  }
}
