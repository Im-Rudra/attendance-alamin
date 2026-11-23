// The selection bar of the students list (item 10) and its bulk actions:
// enrol in a batch · mark as left · share fee reminders (one message per
// guardian, the dues reminder text) · copy phone numbers · export CSV ·
// clear. There is deliberately no bulk delete.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/providers/schedule_providers.dart';
import 'package:attendance_alamin/app/services/share_service.dart';
import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/data/backup/backup_providers.dart';
import 'package:attendance_alamin/data/repositories/people_providers.dart';
import 'package:attendance_alamin/data/repositories/settings_providers.dart';
import 'package:attendance_alamin/data/repositories/structure_providers.dart';
import 'package:attendance_alamin/domain/dues/dues_engine.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/enrollment.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/domain/models/subject.dart';
import 'package:attendance_alamin/features/batches/widgets/batch_format.dart';
import 'package:attendance_alamin/features/dues/controllers/dues_state.dart';
import 'package:attendance_alamin/features/dues/controllers/reminder_actions.dart';
import 'package:attendance_alamin/features/extras/controllers/csv_export.dart';
import 'package:attendance_alamin/features/students/controllers/student_actions.dart';
import 'package:attendance_alamin/features/students/controllers/student_form_model.dart';
import 'package:attendance_alamin/features/students/controllers/student_providers.dart';
import 'package:attendance_alamin/features/students/controllers/student_selection.dart';
import 'package:attendance_alamin/features/students/widgets/student_fields.dart';

/// Below this width the bar shows the count, one "Actions" menu and ✕.
const double kSelectionBarCompactWidth = 560;

/// "{n} selected" and the bulk actions, pinned under the list.
class StudentSelectionBar extends ConsumerWidget {
  const StudentSelectionBar({super.key, required this.students, required this.onClear});

  /// The selected students that are listed, in list order.
  final List<Student> students;
  final VoidCallback onClear;

  static const Key barKey = ValueKey<String>('stu-selection-bar');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final BhorThemeData b = context.bhor;
    final List<_BulkAction> actions = <_BulkAction>[
      _BulkAction('enroll', BhorIcons.add, l10n.stuBulkEnroll, () => bulkEnroll(context, students)),
      _BulkAction('remind', BhorIcons.remind, l10n.stuBulkRemind, () => bulkRemind(context, students)),
      _BulkAction('phones', BhorIcons.copy, l10n.stuBulkCopyPhones, () => bulkCopyPhones(context, students)),
      _BulkAction('csv', BhorIcons.backupDown, l10n.stuBulkExport, () => bulkExportCsv(context, students)),
      _BulkAction('left', BhorIcons.leftStudents, l10n.stuBulkLeft, () => bulkMarkLeft(context, students),
          destructive: true),
    ];
    final Widget count = Semantics(
      liveRegion: true,
      child: Text(
        l10n.stuSelectedCount(context.fmt.number(students.length)),
        key: const ValueKey<String>('stu-selected-count'),
        style: b.type.bodyStrong,
      ),
    );
    return BhorCard(
      key: barKey,
      padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s12, vertical: BhorSpace.s8),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints box) {
          if (box.maxWidth < kSelectionBarCompactWidth) {
            return Row(
              children: <Widget>[
                Expanded(child: count),
                Builder(
                  builder: (BuildContext btn) => BhorButton(
                    key: const ValueKey<String>('stu-bulk-menu'),
                    label: l10n.stuBulkActions,
                    trailingIcon: BhorIcons.chevronDown,
                    size: BhorButtonSize.sm,
                    variant: BhorButtonVariant.secondary,
                    onPressed: () => showBhorMenu(
                      context,
                      anchor: btn,
                      items: <BhorMenuItem>[
                        for (final _BulkAction a in actions)
                          BhorMenuItem(
                            key: ValueKey<String>('stu-bulk-item-${a.id}'),
                            icon: a.icon,
                            label: a.label,
                            destructive: a.destructive,
                            onTap: a.run,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: BhorSpace.s4),
                BhorIconButton(
                  key: const ValueKey<String>('stu-bulk-clear'),
                  icon: BhorIcons.close,
                  semanticLabel: l10n.stuBulkClear,
                  onPressed: onClear,
                ),
              ],
            );
          }
          return Wrap(
            spacing: BhorSpace.s8,
            runSpacing: BhorSpace.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Padding(
                padding: const EdgeInsetsDirectional.only(end: BhorSpace.s8),
                child: count,
              ),
              for (final _BulkAction a in actions)
                BhorButton(
                  key: ValueKey<String>('stu-bulk-${a.id}'),
                  label: a.label,
                  icon: a.icon,
                  size: BhorButtonSize.sm,
                  variant: BhorButtonVariant.secondary,
                  onPressed: a.run,
                ),
              BhorButton(
                key: const ValueKey<String>('stu-bulk-clear'),
                label: l10n.stuBulkClear,
                icon: BhorIcons.close,
                size: BhorButtonSize.sm,
                variant: BhorButtonVariant.ghost,
                onPressed: onClear,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BulkAction {
  const _BulkAction(this.id, this.icon, this.label, this.run, {this.destructive = false});

  final String id;
  final IconData icon;
  final String label;
  final VoidCallback run;
  final bool destructive;
}

void _toast(BuildContext anchor, String message, {BhorTone tone = BhorTone.neutral}) {
  if (anchor.mounted) BhorToast.show(anchor, message: message, tone: tone);
}

// ---- copy phone numbers ------------------------------------------------------

/// Copies the distinct guardian / student numbers, one per line.
Future<void> bulkCopyPhones(BuildContext context, List<Student> students) async {
  final l10n = context.l10n;
  final BuildContext anchor = BhorToast.anchorOf(context);
  final List<String> numbers = phoneNumbersOf(students);
  if (numbers.isEmpty) {
    _toast(anchor, l10n.stuBulkNoPhones, tone: BhorTone.warn);
    return;
  }
  final String copied = l10n.stuBulkPhonesCopied(context.fmt.number(numbers.length));
  try {
    await Clipboard.setData(ClipboardData(text: numbers.join('\n')));
  } catch (_) {
    // The toast below is the feedback either way.
  }
  _toast(anchor, copied, tone: BhorTone.ok);
}

// ---- export CSV ----------------------------------------------------------------

/// The students CSV of the Extras export, limited to [students].
Future<void> bulkExportCsv(BuildContext context, List<Student> students) async {
  final l10n = context.l10n;
  final BuildContext anchor = BhorToast.anchorOf(context);
  final ProviderContainer c = ProviderScope.containerOf(context, listen: false);
  try {
    final List<Enrollment> enrollments = await c.read(enrollmentsRepositoryProvider).watchAll().first;
    final List<Batch> batches = await c.read(batchesRepositoryProvider).watchAll(includeArchived: true).first;
    final CsvFile file = buildStudentsCsv(
      l10n: l10n,
      month: c.read(todayProvider).yearMonth,
      students: students,
      enrollments: enrollments,
      batches: batches,
    );
    final bool saved = await c.read(backupFilesProvider).save(file.bytes, fileName: file.fileName);
    if (saved) _toast(anchor, l10n.extraCsvSaved, tone: BhorTone.ok);
  } on Object {
    _toast(anchor, l10n.extraCsvFailed, tone: BhorTone.danger);
  }
}

// ---- share fee reminders -------------------------------------------------------

/// One reminder per guardian (siblings sharing a number get one message with
/// each child's reminder), shared one after the other like the Fees
/// walk-through. Students with nothing due are left out.
Future<void> bulkRemind(BuildContext context, List<Student> students) async {
  final l10n = context.l10n;
  final BuildContext anchor = BhorToast.anchorOf(context);
  final ProviderContainer c = ProviderScope.containerOf(context, listen: false);
  final Lang lang = context.lang;
  final List<GuardianReminder> messages = <GuardianReminder>[];
  try {
    for (final List<Student> group in groupByGuardian(students)) {
      final List<String> texts = <String>[];
      final List<Student> owing = <Student>[];
      for (final Student s in group) {
        final String? text = await composeReminder(
          c,
          lang: lang,
          studentId: s.id,
          centerFallback: l10n.duesCenterFallback,
        );
        if (text == null) continue;
        texts.add(text);
        owing.add(s);
      }
      if (texts.isEmpty) continue;
      messages.add(GuardianReminder(students: owing, number: owing.first.callNumber, text: texts.join('\n\n')));
    }
  } on Object {
    _toast(anchor, l10n.duesReminderFailed, tone: BhorTone.danger);
    return;
  }
  if (messages.isEmpty) {
    _toast(anchor, l10n.stuBulkRemindNone);
    return;
  }
  if (!context.mounted) return;
  await showBhorPanel<void>(
    context,
    kind: BhorPanelKind.confirm,
    title: l10n.stuBulkRemindTitle,
    builder: (BuildContext ctx) => BulkReminderPanel(messages: messages),
  );
}

/// The message for one guardian.
class GuardianReminder {
  const GuardianReminder({required this.students, required this.number, required this.text});

  final List<Student> students;
  final String? number;
  final String text;
}

class BulkReminderPanel extends ConsumerStatefulWidget {
  const BulkReminderPanel({super.key, required this.messages});

  final List<GuardianReminder> messages;

  @override
  ConsumerState<BulkReminderPanel> createState() => _BulkReminderPanelState();
}

class _BulkReminderPanelState extends ConsumerState<BulkReminderPanel> {
  int _index = 0;
  int _sent = 0;
  bool _busy = false;

  Future<void> _share(GuardianReminder m) async {
    setState(() => _busy = true);
    final String? n = m.number;
    await ShareService.shareText(context, m.text, hasPhone: n != null && n.trim().isNotEmpty);
    final meta = ref.read(localMetaRepositoryProvider);
    final LocalDate today = ref.read(todayProvider);
    for (final Student s in m.students) {
      await markReminded(meta, today, s.id);
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _sent++;
      _index++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final BhorThemeData b = context.bhor;
    final int total = widget.messages.length;
    if (_index >= total) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Icon(BhorIcons.checkCircleFill, size: 56, color: b.colors.accent),
          const SizedBox(height: BhorSpace.s12),
          Text(
            l10n.stuBulkRemindDone(fmt.number(_sent)),
            key: const ValueKey<String>('stu-remind-done'),
            textAlign: TextAlign.center,
            style: b.type.heading,
          ),
          const SizedBox(height: BhorSpace.s16),
          BhorButton(label: l10n.commonDone, onPressed: () => Navigator.of(context).pop()),
        ],
      );
    }
    final GuardianReminder m = widget.messages[_index];
    final String? number = m.number;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          l10n.stuBulkRemindProgress(fmt.number(_index + 1), fmt.number(total)),
          key: const ValueKey<String>('stu-remind-progress'),
          style: b.type.label.copyWith(color: b.colors.text2),
        ),
        const SizedBox(height: BhorSpace.s4),
        Text(m.students.map((Student s) => s.name).join(', '), style: b.type.heading),
        Text(
          number == null || number.trim().isEmpty ? l10n.stuBulkRemindNoPhone : fmt.digits(number),
          style: b.type.body.copyWith(color: b.colors.text2),
        ),
        const SizedBox(height: BhorSpace.s12),
        DecoratedBox(
          decoration: BoxDecoration(
            color: b.colors.soft,
            borderRadius: BorderRadius.circular(BhorRadius.control),
          ),
          child: Padding(
            padding: const EdgeInsets.all(BhorSpace.s12),
            child: Text(m.text, style: b.type.body),
          ),
        ),
        const SizedBox(height: BhorSpace.s16),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: BhorSpace.s8,
          runSpacing: BhorSpace.s8,
          children: <Widget>[
            BhorButton(
              key: const ValueKey<String>('stu-remind-skip'),
              label: l10n.stuBulkRemindSkip,
              variant: BhorButtonVariant.ghost,
              onPressed: _busy ? null : () => setState(() => _index++),
            ),
            BhorButton(
              key: const ValueKey<String>('stu-remind-share'),
              label: l10n.stuBulkRemindShare,
              icon: BhorIcons.share,
              onPressed: _busy ? null : () => _share(m),
            ),
          ],
        ),
      ],
    );
  }
}

// ---- enrol in a batch ----------------------------------------------------------

/// Enrols the selected active students in one batch (join date, fee start and
/// an optional special fee shared by all). Students already in that batch,
/// or who left, are skipped.
Future<void> bulkEnroll(BuildContext context, List<Student> students) async {
  final l10n = context.l10n;
  final BuildContext anchor = BhorToast.anchorOf(context);
  final ProviderContainer c = ProviderScope.containerOf(context, listen: false);
  final ValueNotifier<bool> dirty = ValueNotifier<bool>(false);
  final ({int enrolled, int skipped})? result = await showBhorPanel<({int enrolled, int skipped})>(
    context,
    kind: BhorPanelKind.form,
    title: l10n.stuBulkEnrollTitle(context.fmt.number(students.length)),
    dirty: dirty,
    builder: (BuildContext ctx) => BulkEnrollPanel(students: students, dirty: dirty),
  );
  if (result == null) return;
  if (result.enrolled > 0) c.read(stuSelectionProvider.notifier).clear();
  if (!anchor.mounted) return;
  final String done = l10n.stuBulkEnrolled(anchor.fmt.number(result.enrolled));
  _toast(
    anchor,
    result.skipped == 0 ? done : '$done · ${l10n.stuBulkSkipped(anchor.fmt.number(result.skipped))}',
    tone: result.enrolled > 0 ? BhorTone.ok : BhorTone.warn,
  );
}

class BulkEnrollPanel extends ConsumerStatefulWidget {
  const BulkEnrollPanel({super.key, required this.students, this.dirty});

  final List<Student> students;
  final ValueNotifier<bool>? dirty;

  @override
  ConsumerState<BulkEnrollPanel> createState() => _BulkEnrollPanelState();
}

class _BulkEnrollPanelState extends ConsumerState<BulkEnrollPanel> {
  final EnrollChoice _choice = EnrollChoice();
  bool _busy = false;

  void _syncDirty() {
    final ValueNotifier<bool>? n = widget.dirty;
    if (n != null && n.value != _choice.isDirty) n.value = _choice.isDirty;
  }

  @override
  void initState() {
    super.initState();
    _choice.changes.addListener(_syncDirty);
  }

  @override
  void dispose() {
    _choice.changes.removeListener(_syncDirty);
    _choice.dispose();
    super.dispose();
  }

  /// Active students not already (openly) in [batchId].
  List<Student> _toEnroll(String batchId, List<Enrollment> all) {
    final Set<String> inBatch = <String>{
      for (final Enrollment e in all)
        if (e.batchId == batchId && e.endDate == null) e.studentId,
    };
    return <Student>[
      for (final Student s in widget.students)
        if (s.status == StudentStatus.active && !inBatch.contains(s.id)) s,
    ];
  }

  Future<void> _run(String batchId, List<Student> targets, LocalDate today, int cutoff) async {
    final ({bool ok, int? amount}) fee = _choice.parseFee(context.l10n);
    if (!fee.ok) return;
    setState(() => _busy = true);
    final repo = ref.read(enrollmentsRepositoryProvider);
    final LocalDate join = _choice.joinFor(today);
    var enrolled = 0;
    for (final Student s in targets) {
      try {
        await repo.enroll(
          studentId: s.id,
          batchId: batchId,
          joinDate: join,
          startMonth: _choice.startFor(join, cutoff),
          feeOverride: fee.amount,
        );
        enrolled++;
      } on AppException {
        // Counted as skipped below (e.g. enrolled meanwhile).
      }
    }
    if (!mounted) return;
    Navigator.of(context).pop((enrolled: enrolled, skipped: widget.students.length - enrolled));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final BhorThemeData b = context.bhor;
    final LocalDate today = ref.watch(todayProvider);
    final int cutoff = ref.watch(stuCutoffProvider).value ?? 15;
    final List<Subject> subjects = ref.watch(stuSubjectsProvider).value ?? const <Subject>[];
    final List<Enrollment> all = ref.watch(allEnrollmentsProvider).value ?? const <Enrollment>[];
    final List<Batch> batches = <Batch>[
      for (final Batch bt in ref.watch(stuBatchesProvider).value ?? const <Batch>[])
        if (!bt.archived) bt,
    ]..sort((Batch x, Batch y) => x.sortOrder.compareTo(y.sortOrder));
    String labelOf(Batch bt) {
      for (final Subject s in subjects) {
        if (s.id == bt.subjectId) return batchLabel(l10n, s.name, bt.name);
      }
      return bt.name;
    }

    return ListenableBuilder(
      listenable: _choice,
      builder: (BuildContext context, Widget? _) {
        final String? batchId = batches.any((Batch bt) => bt.id == _choice.batchId) ? _choice.batchId : null;
        final List<Student> targets = batchId == null ? const <Student>[] : _toEnroll(batchId, all);
        final int skipped = widget.students.length - targets.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              widget.students.map((Student s) => s.name).join(', '),
              style: b.type.body.copyWith(color: b.colors.text2),
            ),
            const SizedBox(height: BhorSpace.s12),
            if (batches.isEmpty)
              Text(l10n.stuNoBatchesToJoin, style: b.type.body)
            else
              BhorSelect<String>(
                key: const ValueKey<String>('stu-bulk-enroll-batch'),
                label: l10n.stuBatchOptional,
                value: batchId,
                hint: l10n.stuPickBatchFirst,
                options: <BhorOption<String>>[
                  for (final Batch bt in batches) BhorOption<String>(bt.id, labelOf(bt)),
                ],
                onChanged: _choice.setBatch,
              ),
            if (batchId != null) ...<Widget>[
              const SizedBox(height: BhorSpace.s16),
              StartMonthFeeFields(choice: _choice, join: today, cutoff: cutoff),
              if (skipped > 0) ...<Widget>[
                const SizedBox(height: BhorSpace.s12),
                Text(
                  l10n.stuBulkSkipped(context.fmt.number(skipped)),
                  key: const ValueKey<String>('stu-bulk-enroll-skipped'),
                  style: b.type.body.copyWith(color: b.colors.text2),
                ),
              ],
            ],
            const SizedBox(height: BhorSpace.s16),
            BhorButton(
              key: const ValueKey<String>('stu-bulk-enroll-confirm'),
              label: l10n.stuBulkEnrollConfirm(context.fmt.number(targets.length)),
              expand: true,
              onPressed: (_busy || batchId == null || targets.isEmpty)
                  ? null
                  : () => _run(batchId, targets, today, cutoff),
            ),
          ],
        );
      },
    );
  }
}

// ---- mark as left --------------------------------------------------------------

/// Marks the selected active students as left on one date; every open
/// enrollment gets the usual last billable month for that date.
Future<void> bulkMarkLeft(BuildContext context, List<Student> students) async {
  final l10n = context.l10n;
  final BuildContext anchor = BhorToast.anchorOf(context);
  final ProviderContainer c = ProviderScope.containerOf(context, listen: false);
  final List<Student> active = <Student>[
    for (final Student s in students)
      if (s.status == StudentStatus.active) s,
  ];
  if (active.isEmpty) {
    _toast(anchor, l10n.stuBulkNoneActive);
    return;
  }
  final ValueNotifier<bool> dirty = ValueNotifier<bool>(false);
  final int? done = await showBhorPanel<int>(
    context,
    kind: BhorPanelKind.form,
    title: l10n.stuBulkLeftTitle(context.fmt.number(active.length)),
    width: 460,
    dirty: dirty,
    builder: (BuildContext ctx) => BulkLeavePanel(students: active, dirty: dirty),
  );
  if (done == null) return;
  c.read(stuSelectionProvider.notifier).clear();
  if (anchor.mounted) _toast(anchor, l10n.stuBulkLeftDone(anchor.fmt.number(done)), tone: BhorTone.ok);
}

class BulkLeavePanel extends ConsumerStatefulWidget {
  const BulkLeavePanel({super.key, required this.students, this.dirty});

  /// Active students only.
  final List<Student> students;
  final ValueNotifier<bool>? dirty;

  @override
  ConsumerState<BulkLeavePanel> createState() => _BulkLeavePanelState();
}

class _BulkLeavePanelState extends ConsumerState<BulkLeavePanel> {
  LocalDate? _date;
  bool _busy = false;
  String? _error;

  Future<void> _run(LocalDate on) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = ref.read(studentsRepositoryProvider);
    var done = 0;
    try {
      for (final Student s in widget.students) {
        await repo.markLeft(s.id, on: on, lastBillableByEnrollment: const {});
        done++;
      }
    } on AppException {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = context.l10n.stuBulkLeftFailed(context.fmt.number(done));
      });
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(done);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final BhorThemeData b = context.bhor;
    final LocalDate today = ref.watch(todayProvider);
    final LocalDate on = _date ?? today;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          widget.students.map((Student s) => s.name).join(', '),
          style: b.type.body.copyWith(color: b.colors.text2),
        ),
        const SizedBox(height: BhorSpace.s12),
        DateField(
          key: const ValueKey<String>('stu-bulk-left-date'),
          label: l10n.stuLeftDate,
          value: on,
          lastDate: today,
          onChanged: (LocalDate d) {
            setState(() => _date = d);
            widget.dirty?.value = d != today;
          },
        ),
        const SizedBox(height: BhorSpace.s12),
        Text(
          l10n.stuBulkLeftBody(fmt.monthYear(DuesEngine.defaultLastBillableMonth(on))),
          style: b.type.body.copyWith(color: b.colors.text2),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: BhorSpace.s8),
            child: Semantics(
              liveRegion: true,
              child: Text(_error!, style: b.type.body.copyWith(color: b.colors.danger)),
            ),
          ),
        const SizedBox(height: BhorSpace.s16),
        BhorButton(
          key: const ValueKey<String>('stu-bulk-left-confirm'),
          label: l10n.stuBulkLeftConfirm(fmt.number(widget.students.length)),
          variant: BhorButtonVariant.danger,
          expand: true,
          onPressed: _busy ? null : () => _run(on),
        ),
      ],
    );
  }
}
