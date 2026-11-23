// Rejoin (Product 3.2, item 11): "Back from" (default today, as early as the
// day after leaving) and, when months between the last billable month and
// that day would become owed, "মাঝের N মাস মাফ করবেন?" (waive is the default).

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/error_text.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/data/repositories/people_providers.dart';
import 'package:attendance_alamin/domain/models/enrollment.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/features/students/controllers/student_actions.dart';
import 'package:attendance_alamin/features/students/widgets/student_fields.dart';

/// True when the student is active again.
Future<bool> runRejoinFlow(
    BuildContext context, WidgetRef ref, Student student) async {
  final l10n = context.l10n;
  final List<Enrollment> enrollments = await ref
      .read(enrollmentsRepositoryProvider)
      .watchForStudent(student.id)
      .first;
  if (!context.mounted) return false;
  final ValueNotifier<bool> dirty = ValueNotifier<bool>(false);
  final bool? done = await showBhorPanel<bool>(
    context,
    kind: BhorPanelKind.form,
    title: l10n.stuRejoinTitle,
    width: 460,
    dirty: dirty,
    builder: (BuildContext ctx) => RejoinPanel(student: student, enrollments: enrollments, dirty: dirty),
  );
  if (done != true) return false;
  if (context.mounted) BhorToast.show(context, message: l10n.stuRejoined(student.name));
  return true;
}

class RejoinPanel extends ConsumerStatefulWidget {
  const RejoinPanel({super.key, required this.student, required this.enrollments, this.dirty});

  final Student student;
  final List<Enrollment> enrollments;
  final ValueNotifier<bool>? dirty;

  @override
  ConsumerState<RejoinPanel> createState() => _RejoinPanelState();
}

class _RejoinPanelState extends ConsumerState<RejoinPanel> {
  LocalDate? _date;
  bool _waive = true;
  bool _busy = false;
  String? _error;

  void _syncDirty(LocalDate today) {
    widget.dirty?.value = (_date != null && _date != today) || !_waive;
  }

  Future<void> _confirm(LocalDate back, int gap) async {
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(studentsRepositoryProvider)
          .rejoin(widget.student.id, waiveGap: gap > 0 && _waive, on: back);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = errorText(l10n, e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final BhorThemeData b = context.bhor;
    final LocalDate today = ref.watch(todayProvider);
    final LocalDate first = rejoinFirstDay(widget.student, today);
    LocalDate back = _date ?? today;
    if (back.isBefore(first)) back = first;
    if (back.isAfter(today)) back = today;
    final int gap = rejoinGapMonths(widget.student, widget.enrollments, back);
    final LocalDate? left = widget.student.leftDate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(widget.student.name, style: b.type.heading),
        if (left != null)
          Text(l10n.stuRejoinLeftOn(fmt.date(left)), style: b.type.body.copyWith(color: b.colors.text2)),
        const SizedBox(height: BhorSpace.s12),
        DateField(
          key: const ValueKey<String>('stu-rejoin-date'),
          label: l10n.stuRejoinBackFrom,
          value: back,
          firstDate: first,
          lastDate: today,
          onChanged: (LocalDate d) {
            setState(() => _date = d);
            _syncDirty(today);
          },
        ),
        if (gap > 0) ...<Widget>[
          const SizedBox(height: BhorSpace.s16),
          Semantics(
            liveRegion: true,
            child: Text(
              gap == 1 ? l10n.stuRejoinGapBodyOne(fmt.number(gap)) : l10n.stuRejoinGapBody(fmt.number(gap)),
              style: b.type.heading,
            ),
          ),
          const SizedBox(height: BhorSpace.s8),
          BhorRadioCard<bool>(
            key: const ValueKey<String>('stu-rejoin-waive'),
            value: true,
            groupValue: _waive,
            onChanged: (bool v) {
              setState(() => _waive = v);
              _syncDirty(today);
            },
            title: l10n.stuRejoinWaive,
          ),
          const SizedBox(height: BhorSpace.s8),
          BhorRadioCard<bool>(
            key: const ValueKey<String>('stu-rejoin-keep'),
            value: false,
            groupValue: _waive,
            onChanged: (bool v) {
              setState(() => _waive = v);
              _syncDirty(today);
            },
            title: l10n.stuRejoinKeepDues,
          ),
        ],
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
          key: const ValueKey<String>('stu-rejoin-confirm'),
          label: l10n.stuRejoin,
          expand: true,
          onPressed: _busy ? null : () => _confirm(back, gap),
        ),
      ],
    );
  }
}
