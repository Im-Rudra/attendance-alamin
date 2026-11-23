// Enrollment ⋮ › "Change join date" (item 6) and "Change fee for this
// student" (item 4). Both are side-panel forms with the unsaved-changes
// guard. The join date never moves the first billable month; a fee change
// applies from the chosen month on, earlier months keep their fee.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/error_text.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/providers/dues_providers.dart';
import 'package:attendance_alamin/app/widgets/chip_wrap.dart';
import 'package:attendance_alamin/app/widgets/digits_formatter.dart';
import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/core/validation/validators.dart';
import 'package:attendance_alamin/data/repositories/people_providers.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/enrollment.dart';
import 'package:attendance_alamin/features/students/controllers/student_actions.dart';
import 'package:attendance_alamin/features/students/widgets/student_fields.dart';

/// "Change join date"; toasts when saved.
Future<void> openChangeJoinDate(BuildContext context, Enrollment enrollment) async {
  final l10n = context.l10n;
  final ValueNotifier<bool> dirty = ValueNotifier<bool>(false);
  final bool? done = await showBhorPanel<bool>(
    context,
    kind: BhorPanelKind.form,
    title: l10n.stuChangeJoinDate,
    width: 440,
    dirty: dirty,
    builder: (BuildContext ctx) => ChangeJoinDateBody(enrollment: enrollment, dirty: dirty),
  );
  if (done == true && context.mounted) BhorToast.show(context, message: l10n.stuJoinDateSaved);
}

class ChangeJoinDateBody extends ConsumerStatefulWidget {
  const ChangeJoinDateBody({super.key, required this.enrollment, this.dirty});

  final Enrollment enrollment;
  final ValueNotifier<bool>? dirty;

  @override
  ConsumerState<ChangeJoinDateBody> createState() => _ChangeJoinDateBodyState();
}

class _ChangeJoinDateBodyState extends ConsumerState<ChangeJoinDateBody> {
  late LocalDate _date = widget.enrollment.joinDate;
  bool _busy = false;
  String? _error;

  void _set(LocalDate d) {
    setState(() {
      _date = d;
      _error = null;
    });
    widget.dirty?.value = d != widget.enrollment.joinDate;
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final LocalDate? end = widget.enrollment.endDate;
    if (end != null && _date.isAfter(end)) {
      setState(() => _error = l10n.stuJoinAfterEnd(context.fmt.date(end)));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(enrollmentsRepositoryProvider)
          .updateJoinDate(widget.enrollment.id, DateTime(_date.year, _date.month, _date.day));
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ValidationException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.field == 'overlap' ? l10n.stuJoinOverlap : errorText(l10n, e);
      });
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
    final BhorThemeData b = context.bhor;
    final Enrollment e = widget.enrollment;
    final LocalDate today = ref.watch(todayProvider);
    final LocalDate? end = e.endDate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        JoinDateField(
          value: _date,
          onChanged: _set,
          lastDate: end != null && end.isBefore(today) ? end : null,
        ),
        const SizedBox(height: BhorSpace.s12),
        Text(
          l10n.stuJoinDateKeepsFee(context.fmt.monthYear(e.startMonth)),
          key: const ValueKey<String>('stu-join-keeps-fee'),
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
          key: const ValueKey<String>('stu-join-save'),
          label: l10n.commonSave,
          expand: true,
          onPressed: (_busy || _date == e.joinDate) ? null : _save,
        ),
      ],
    );
  }
}

/// "Change fee for this student"; toasts when saved.
Future<void> openChangeStudentFee(BuildContext context, Enrollment enrollment) async {
  final l10n = context.l10n;
  final ValueNotifier<bool> dirty = ValueNotifier<bool>(false);
  final bool? done = await showBhorPanel<bool>(
    context,
    kind: BhorPanelKind.form,
    title: l10n.stuChangeFee,
    width: 460,
    dirty: dirty,
    builder: (BuildContext ctx) => ChangeStudentFeeBody(enrollment: enrollment, dirty: dirty),
  );
  if (done == true && context.mounted) BhorToast.show(context, message: l10n.stuFeeChanged);
}

class ChangeStudentFeeBody extends ConsumerStatefulWidget {
  const ChangeStudentFeeBody({super.key, required this.enrollment, this.dirty});

  final Enrollment enrollment;
  final ValueNotifier<bool>? dirty;

  @override
  ConsumerState<ChangeStudentFeeBody> createState() => _ChangeStudentFeeBodyState();
}

class _ChangeStudentFeeBodyState extends ConsumerState<ChangeStudentFeeBody> {
  final TextEditingController _amount = TextEditingController();
  late YearMonth _from;
  late YearMonth _initialFrom;
  String _initialText = '';
  bool _busy = false;
  String? _amountError;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Opens on this month (never before the first billable month) with the
    // special fee in force now, if any. The card that opened the panel
    // already watches these dues, so they are loaded.
    final YearMonth current = ref.read(todayProvider).yearMonth;
    final YearMonth start = widget.enrollment.startMonth;
    _from = current.isBefore(start) ? start : current;
    _initialFrom = _from;
    final EnrollmentTerms? terms = ref.read(enrollmentDuesProvider(widget.enrollment.id)).value?.terms;
    final int? special = terms == null ? null : specialFeeAt(terms.overrides, current);
    _initialText = special == null ? '' : special.toString();
    _amount.text = _initialText;
    _amount.addListener(_syncDirty);
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _syncDirty() {
    final ValueNotifier<bool>? n = widget.dirty;
    if (n == null) return;
    final bool d = _amount.text.trim() != _initialText || _from != _initialFrom;
    if (n.value != d) n.value = d;
  }

  void _pick(YearMonth m) {
    setState(() => _from = m);
    _syncDirty();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final YearMonth from = _from;
    int? amount;
    final String raw = _amount.text.trim();
    if (raw.isNotEmpty) {
      try {
        amount = Validators.amount(raw);
      } on ValidationException catch (e) {
        setState(() => _amountError = errorText(l10n, e));
        return;
      }
    }
    setState(() {
      _busy = true;
      _amountError = null;
      _error = null;
    });
    try {
      await ref.read(enrollmentsRepositoryProvider).setOverride(widget.enrollment.id, amount, from: from);
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
    final YearMonth current = ref.watch(todayProvider).yearMonth;
    final EnrollmentTerms? terms = ref.watch(enrollmentDuesProvider(widget.enrollment.id)).value?.terms;
    final YearMonth from = _from;
    final int? batchFee = terms == null ? null : batchFeeAt(terms.batchFees, from);
    final ({List<YearMonth> quick, List<YearMonth> older}) months =
        feeChangeMonths(current, widget.enrollment.startMonth);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        BhorTextField(
          key: const ValueKey<String>('stu-fee-amount'),
          controller: _amount,
          localDigits: true,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[DigitsFormatter(fmt)],
          onChanged: (_) {
            if (_amountError != null) setState(() => _amountError = null);
          },
          label: l10n.stuChangeFeeAmount,
          helper: batchFee == null ? l10n.stuFeeOverrideHint : l10n.stuChangeFeeHint(fmt.money(batchFee)),
          error: _amountError,
        ),
        const SizedBox(height: BhorSpace.s16),
        Text(l10n.stuChangeFeeFrom, style: b.type.heading),
        const SizedBox(height: BhorSpace.s8),
        ChipWrap(
          children: <Widget>[
            for (final YearMonth m in months.quick)
              BhorChip(
                key: ValueKey<String>('stu-fee-from-${m.toInt()}'),
                label: fmt.monthYear(m),
                selected: m == from,
                onSelected: (_) => _pick(m),
              ),
          ],
        ),
        if (months.older.isNotEmpty) ...<Widget>[
          const SizedBox(height: BhorSpace.s12),
          BhorSelect<YearMonth>(
            key: const ValueKey<String>('stu-fee-from-earlier'),
            value: months.older.contains(from) ? from : null,
            hint: l10n.stuFeeEarlierMonth,
            options: <BhorOption<YearMonth>>[
              for (final YearMonth m in months.older) BhorOption<YearMonth>(m, fmt.monthYear(m)),
            ],
            onChanged: _pick,
          ),
        ],
        const SizedBox(height: BhorSpace.s8),
        Text(l10n.stuChangeFeeNote, style: b.type.label.copyWith(color: b.colors.text2)),
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
          key: const ValueKey<String>('stu-fee-save'),
          label: l10n.commonSave,
          expand: true,
          onPressed: _busy ? null : _save,
        ),
      ],
    );
  }
}
