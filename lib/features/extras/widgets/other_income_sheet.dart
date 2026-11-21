// The other-income sheet (F22): a one-off payment with a label (admission,
// exam, notes...). Record only: no dues, no warnings. It appears in the
// collection summary's "অন্যান্য" line (read from the same repository) and can
// be shared as a receipt.

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/error_text.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/services/share_service.dart';
import 'package:attendance_alamin/app/widgets/digits_formatter.dart';
import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/errors/error_codes.dart';
import 'package:attendance_alamin/core/settings/setting_keys.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/validation/validators.dart';
import 'package:attendance_alamin/data/repositories/people_providers.dart';
import 'package:attendance_alamin/data/repositories/settings_providers.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/other_income.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/features/extras/controllers/other_income_text.dart';
import 'package:attendance_alamin/features/settings/settings_entry.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

/// What the sheet returns when it saved.
class SavedOtherIncome {
  const SavedOtherIncome({required this.id, required this.income, required this.share});

  final String id;
  final OtherIncome income;

  /// "Save & send receipt" was used.
  final bool share;
}

/// Opens the sheet; true when an income was saved. Shows the "recorded"
/// snackbar (with undo) on the caller's screen.
Future<bool> openOtherIncomeSheet(BuildContext context, {String? studentId}) async {
  final ProviderContainer container = ProviderScope.containerOf(context);
  final SavedOtherIncome? saved = await showBhorSheet<SavedOtherIncome>(
    context,
    title: context.l10n.extraIncomeTitle,
    // Root navigator: above the bottom navigation, never behind it (C15).
    builder: (BuildContext ctx) => OtherIncomeForm(
      studentId: studentId,
      onClose: () => Navigator.of(ctx).pop(),
      onSaved: (SavedOtherIncome s) => Navigator.of(ctx).pop(s),
    ),
  );
  if (saved == null || !context.mounted) return saved != null;
  final l10n = context.l10n;
  final String message = l10n.extraIncomeSaved(context.fmt.money(saved.income.amount), saved.income.label);
  BhorToast.show(
    context,
    message: message,
    tone: BhorTone.ok,
    actionLabel: l10n.commonUndo,
    onAction: () => container.read(otherIncomeRepositoryProvider).softDelete(saved.id),
    duration: const Duration(seconds: 8),
    bottomOffset: context.bhorIsWide ? 0 : 64,
  );
  if (saved.share) {
    final String text = await _receiptText(context, container, saved.income);
    if (context.mounted) await ShareService.shareText(context, text);
  }
  return true;
}

Future<String> _receiptText(BuildContext context, ProviderContainer container, OtherIncome income) async {
  final l10n = context.l10n;
  final fmt = context.fmt;
  final String center = (await container.read(settingsRepositoryProvider).get(SettingKeys.centerName));
  String? student;
  if (income.studentId != null) {
    student = (await container.read(studentsRepositoryProvider).getById(income.studentId!))?.name;
  }
  return otherIncomeReceiptText(
    l10n: l10n,
    fmt: fmt,
    income: income,
    methodLabel: paymentMethodLabel(l10n, income.method),
    centerName: center,
    studentName: student,
  );
}

class OtherIncomeForm extends ConsumerStatefulWidget {
  const OtherIncomeForm({super.key, this.studentId, required this.onClose, required this.onSaved});

  final String? studentId;
  final VoidCallback onClose;
  final ValueChanged<SavedOtherIncome> onSaved;

  @override
  ConsumerState<OtherIncomeForm> createState() => _OtherIncomeFormState();
}

class _OtherIncomeFormState extends ConsumerState<OtherIncomeForm> {
  final TextEditingController _label = TextEditingController();
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _note = TextEditingController();
  PaymentMethod? _method;
  LocalDate? _date;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _label.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  int? get _amountValue {
    try {
      final int v = Validators.amount(_amount.text);
      return v > 0 ? v : null;
    } on Object {
      return null;
    }
  }

  /// Inline message when the typed amount is above the maximum (QA-13).
  String? _amountError(AppLocalizations l10n) {
    if (_amount.text.trim().isEmpty) return null;
    try {
      Validators.amount(_amount.text);
    } on ValidationException catch (e) {
      if (e.code == ErrorCodes.amountTooLarge) return errorText(l10n, e);
    } on Object {
      return null;
    }
    return null;
  }

  bool get _labelOk => _label.text.trim().isNotEmpty;
  bool get _canSave => !_busy && _labelOk && _amountValue != null;

  Future<void> _pickDate(LocalDate today, LocalDate current) async {
    final DateTime last = DateTime(today.year, today.month, today.day);
    DateTime first = DateTime(today.year - 2, 1, 1);
    final DateTime initial = DateTime(current.year, current.month, current.day);
    if (initial.isBefore(first)) first = initial;
    final DateTime? picked = await showBhorDatePicker(
      context,
      initialDate: initial.isAfter(last) ? last : initial,
      firstDate: first,
      lastDate: last,
      weekStart: ref.read(weekStartProvider).value ?? DateTime.saturday,
      today: last,
    );
    if (picked == null || !mounted) return;
    setState(() => _date = LocalDate(picked.year, picked.month, picked.day));
  }

  Future<void> _save({required bool share}) async {
    if (!_canSave) return;
    final l10n = context.l10n;
    final LocalDate today = ref.read(todayProvider);
    final List<PaymentMethod> visible = ref.read(paymentMethodsConfigProvider).visible;
    final PaymentMethod method = _method ?? (visible.isEmpty ? PaymentMethod.cash : visible.first);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final String note = _note.text.trim();
      final OtherIncome draft = OtherIncome(
        id: '',
        studentId: widget.studentId,
        label: Validators.name(_label.text),
        amount: Validators.amount(_amount.text),
        paidOn: _date ?? today,
        method: method,
        note: note.isEmpty ? null : note,
      );
      final String id = await ref.read(otherIncomeRepositoryProvider).add(draft);
      if (!mounted) return;
      widget.onSaved(SavedOtherIncome(
        id: id,
        share: share,
        income: OtherIncome(
          id: id,
          studentId: draft.studentId,
          label: draft.label,
          amount: draft.amount,
          paidOn: draft.paidOn,
          method: draft.method,
          note: draft.note,
        ),
      ));
    } on Object catch (e) {
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
    final LocalDate date = _date ?? today;
    final List<PaymentMethod> methods = ref.watch(paymentMethodsConfigProvider).visible;
    final PaymentMethod method = _method ?? (methods.isEmpty ? PaymentMethod.cash : methods.first);
    final AsyncValue<Student?> student =
        widget.studentId == null ? const AsyncData<Student?>(null) : ref.watch(_studentProvider(widget.studentId!));

    String? reason;
    if (!_labelOk) {
      reason = l10n.extraIncomeDisabledLabel;
    } else if (_amountValue == null) {
      reason = l10n.payDisabledAmount;
    }
    final List<String> quickLabels = <String>[
      l10n.extraIncomeAdmission,
      l10n.extraIncomeExam,
      l10n.extraIncomeNotes,
    ];

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l10n.extraIncomeHelp, style: b.type.body.copyWith(color: b.colors.text2)),
          if (student.value != null) ...<Widget>[
            const SizedBox(height: BhorSpace.s8),
            Text(l10n.extraIncomeFromStudent(student.value!.name), style: b.type.bodyStrong),
          ],
          const SizedBox(height: BhorSpace.s16),
          BhorTextField(
            key: const ValueKey<String>('income-label'),
            controller: _label,
            textInputAction: TextInputAction.next,
            label: l10n.extraIncomeLabelField,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: BhorSpace.s8),
          Wrap(
            spacing: BhorSpace.s8,
            runSpacing: BhorSpace.s4,
            children: <Widget>[
              for (int i = 0; i < quickLabels.length; i++)
                BhorChip(
                  key: ValueKey<String>('income-quick-$i'),
                  label: quickLabels[i],
                  selected: _label.text == quickLabels[i],
                  onSelected: (bool _) => setState(() => _label.text = quickLabels[i]),
                ),
            ],
          ),
          const SizedBox(height: BhorSpace.s16),
          BhorTextField(
            key: const ValueKey<String>('income-amount'),
            controller: _amount,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[DigitsFormatter(fmt)],
            tabular: true,
            label: l10n.payAmountLabel,
            prefix: Text('৳', style: b.type.body.copyWith(color: b.colors.text2)),
            error: _amountError(l10n),
            helper: _amountValue == null ? null : fmt.money(_amountValue!),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: BhorSpace.s16),
          Text(l10n.payMethodLabel, style: b.type.label),
          const SizedBox(height: BhorSpace.s8),
          Wrap(
            spacing: BhorSpace.s8,
            runSpacing: BhorSpace.s4,
            children: <Widget>[
              for (final PaymentMethod m in methods)
                BhorChip(
                  key: ValueKey<String>('income-method-${m.code}'),
                  label: paymentMethodLabel(l10n, m),
                  selected: m == method,
                  onSelected: (bool _) => setState(() => _method = m),
                ),
            ],
          ),
          const SizedBox(height: BhorSpace.s16),
          BhorButton(
            key: const ValueKey<String>('income-date'),
            variant: BhorButtonVariant.secondary,
            icon: Icons.calendar_today_outlined,
            label: '${l10n.payDateLabel}: ${fmt.date(date)}',
            expand: true,
            onPressed: () => _pickDate(today, date),
          ),
          const SizedBox(height: BhorSpace.s16),
          BhorTextField(
            key: const ValueKey<String>('income-note'),
            controller: _note,
            label: l10n.payNoteLabel,
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: BhorSpace.s12),
            Text(_error!, style: b.type.body.copyWith(color: b.colors.danger)),
          ],
          const SizedBox(height: BhorSpace.s20),
          BhorButton(
            key: const ValueKey<String>('income-save'),
            label: l10n.commonSave,
            expand: true,
            onPressed: _canSave ? () => _save(share: false) : null,
          ),
          const SizedBox(height: BhorSpace.s8),
          BhorButton(
            key: const ValueKey<String>('income-save-send'),
            variant: BhorButtonVariant.secondary,
            label: l10n.extraIncomeSaveSend,
            expand: true,
            onPressed: _canSave ? () => _save(share: true) : null,
          ),
          if (reason != null) ...<Widget>[
            const SizedBox(height: BhorSpace.s8),
            Text(reason, textAlign: TextAlign.center, style: b.type.meta),
          ],
        ],
      ),
    );
  }
}

final _studentProvider =
    StreamProvider.autoDispose.family<Student?, String>(
        (Ref ref, String id) => ref.watch(studentsRepositoryProvider).watchById(id));
