// The other-income sheet (F22): a one-off payment with a label (admission,
// exam, notes...). Record only: no dues, no warnings. It appears in the
// collection summary's "অন্যান্য" line (read from the same repository) and can
// be shared as a receipt.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/widgets/chip_wrap.dart';
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
import 'package:attendance_alamin/data/repositories/place_providers.dart';
import 'package:attendance_alamin/data/repositories/settings_providers.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/other_income.dart';
import 'package:attendance_alamin/domain/models/place.dart';
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
  // A side panel on desktop, a sheet on phones (F7). The footer holds the
  // save buttons (the form publishes their state); closing asks first once
  // something was typed. A save plays the success moment. The notifiers are
  // not disposed: the exit animation still listens to them.
  final ValueNotifier<OtherIncomeBarSpec?> bar = ValueNotifier<OtherIncomeBarSpec?>(null);
  final ValueNotifier<bool> dirty = ValueNotifier<bool>(false);
  final SavedOtherIncome? saved = await showBhorPanel<SavedOtherIncome>(
    context,
    title: context.l10n.extraIncomeTitle,
    kind: BhorPanelKind.form,
    scroll: false,
    dirty: dirty,
    footer: (BuildContext ctx) => OtherIncomeBar(sink: bar),
    builder: (BuildContext ctx) => OtherIncomeForm(
      studentId: studentId,
      barSink: bar,
      dirtySink: dirty,
      onClose: () => Navigator.of(ctx).pop(),
      onSaved: (SavedOtherIncome s) => unawaited(showBhorSuccess<SavedOtherIncome>(ctx, result: s)),
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
  String center = await container.read(settingsRepositoryProvider).get(SettingKeys.centerName);
  // Income of another place carries that place's name (the main place is
  // the centre settings).
  final String? placeId = income.placeId;
  if (placeId != null && placeId != kDefaultPlaceId) {
    final Place? place = await container.read(placesRepositoryProvider).getById(placeId);
    if (place != null && place.name.trim().isNotEmpty) center = place.name;
  }
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
  const OtherIncomeForm({
    super.key,
    this.studentId,
    required this.onClose,
    required this.onSaved,
    this.barSink,
    this.dirtySink,
  });

  final String? studentId;

  /// When set, the save buttons are drawn by the container's footer
  /// ([OtherIncomeBar]); the form publishes their state here.
  final ValueNotifier<OtherIncomeBarSpec?>? barSink;

  /// Set to true once the teacher typed or changed something.
  final ValueNotifier<bool>? dirtySink;
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

  /// The place it belongs to; null = general. Starts at the place the lists
  /// are filtered to (only asked with 2+ places).
  late String? _placeId = ref.read(placeFilterProvider);
  bool _busy = false;
  bool _touched = false;
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

  Future<void> _pickDate(LocalDate today, LocalDate current, BuildContext anchor) async {
    final DateTime last = DateTime(today.year, today.month, today.day);
    DateTime first = DateTime(today.year - 2, 1, 1);
    final DateTime initial = DateTime(current.year, current.month, current.day);
    if (initial.isBefore(first)) first = initial;
    final DateTime? picked = await showBhorDatePicker(
      context,
      anchor: anchor,
      initialDate: initial.isAfter(last) ? last : initial,
      firstDate: first,
      lastDate: last,
      weekStart: ref.read(weekStartProvider).value ?? DateTime.saturday,
      today: last,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _touched = true;
      _date = LocalDate(picked.year, picked.month, picked.day);
    });
  }

  bool get _dirty => _label.text.isNotEmpty || _amount.text.isNotEmpty || _note.text.isNotEmpty || _touched;

  void _publish(OtherIncomeBarSpec spec) {
    final ValueNotifier<OtherIncomeBarSpec?>? bar = widget.barSink;
    final ValueNotifier<bool>? d = widget.dirtySink;
    if (bar == null && d == null) return;
    final bool dirty = _dirty;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (bar != null && bar.value != spec) bar.value = spec;
      if (d != null && d.value != dirty) d.value = dirty;
    });
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
        placeId: _placeId,
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
          placeId: draft.placeId,
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

  /// "Place": General (no place) or one of the active places.
  Widget _placeSelect(AppLocalizations l10n, BhorThemeData b) {
    final List<Place> places = ref.watch(placesProvider).value ?? const <Place>[];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        BhorSelect<String>(
          key: const ValueKey<String>('income-place'),
          label: l10n.placeField,
          value: _placeId ?? '',
          searchable: true,
          options: <BhorOption<String>>[
            BhorOption<String>('', l10n.placeGeneral),
            for (final Place p in places) BhorOption<String>(p.id, p.name, icon: BhorIcons.explore),
          ],
          onChanged: (String id) => setState(() {
            _touched = true;
            _placeId = id.isEmpty ? null : id;
          }),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(l10n.placeIncomeHelp, style: b.type.meta),
        ),
      ],
    );
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
    final OtherIncomeBarSpec spec = (
      canSave: _canSave,
      busy: _busy,
      reason: reason,
      save: _save,
    );
    _publish(spec);
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
            textCapitalization: TextCapitalization.sentences,
            controller: _label,
            textInputAction: TextInputAction.next,
            label: l10n.extraIncomeLabelField,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: BhorSpace.s8),
          ChipWrap(
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
            localDigits: true,
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
          ChipWrap(
            spacing: BhorSpace.s8,
            runSpacing: BhorSpace.s4,
            children: <Widget>[
              for (final PaymentMethod m in methods)
                BhorChip(
                  key: ValueKey<String>('income-method-${m.code}'),
                  label: paymentMethodLabel(l10n, m),
                  selected: m == method,
                  onSelected: (bool _) => setState(() {
                    _touched = true;
                    _method = m;
                  }),
                ),
            ],
          ),
          if (ref.watch(hasManyPlacesProvider)) ...<Widget>[
            const SizedBox(height: BhorSpace.s16),
            _placeSelect(l10n, b),
          ],
          const SizedBox(height: BhorSpace.s16),
          BhorPickerField(
            key: const ValueKey<String>('income-date'),
            label: l10n.payDateLabel,
            value: date == today ? l10n.payDateToday(fmt.date(date)) : fmt.date(date),
            icon: BhorIcons.calendar,
            semanticLabel: l10n.payDateEdit,
            onTap: (BuildContext fieldContext) => _pickDate(today, date, fieldContext),
          ),
          const SizedBox(height: BhorSpace.s16),
          BhorTextField(
            key: const ValueKey<String>('income-note'),
            controller: _note,
            label: l10n.payNoteLabel,
            onChanged: (_) => setState(() {}),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: BhorSpace.s12),
            Text(_error!, style: b.type.body.copyWith(color: b.colors.danger)),
          ],
          if (widget.barSink == null) ...<Widget>[
            const SizedBox(height: BhorSpace.s20),
            OtherIncomeButtons(spec: spec),
          ],
        ],
      ),
    );
  }
}

/// What the footer of the other-income panel shows (published by the form).
typedef OtherIncomeBarSpec = ({bool canSave, bool busy, String? reason, void Function({required bool share}) save});

/// The footer of the panel: a single primary Save, and "Save & send receipt"
/// as the secondary button.
class OtherIncomeBar extends StatelessWidget {
  const OtherIncomeBar({super.key, required this.sink});

  final ValueListenable<OtherIncomeBarSpec?> sink;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<OtherIncomeBarSpec?>(
        valueListenable: sink,
        builder: (BuildContext context, OtherIncomeBarSpec? spec, Widget? _) => OtherIncomeButtons(spec: spec),
      );
}

/// Save + "Save & send receipt" for [spec] (null: both disabled).
class OtherIncomeButtons extends StatelessWidget {
  const OtherIncomeButtons({super.key, required this.spec});

  final OtherIncomeBarSpec? spec;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final BhorThemeData b = context.bhor;
    final OtherIncomeBarSpec? sp = spec;
    final bool can = sp != null && sp.canSave;
    final Widget save = BhorButton(
      key: const ValueKey<String>('income-save'),
      label: l10n.commonSave,
      expand: true,
      loading: sp?.busy ?? false,
      onPressed: can ? () => sp.save(share: false) : null,
    );
    final Widget send = BhorButton(
      key: const ValueKey<String>('income-save-send'),
      variant: BhorButtonVariant.secondary,
      label: l10n.extraIncomeSaveSend,
      expand: true,
      onPressed: can ? () => sp.save(share: true) : null,
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (c.maxWidth >= 400)
            Row(
              children: <Widget>[
                Expanded(child: send),
                const SizedBox(width: BhorSpace.s8),
                Expanded(child: save),
              ],
            )
          else ...<Widget>[
            save,
            const SizedBox(height: BhorSpace.s8),
            send,
          ],
          if (!can && sp?.reason != null) ...<Widget>[
            const SizedBox(height: BhorSpace.s8),
            Text(sp!.reason!, textAlign: TextAlign.center, style: b.type.meta),
          ],
        ],
      ),
    );
  }
}

final _studentProvider =
    StreamProvider.autoDispose.family<Student?, String>(
        (Ref ref, String id) => ref.watch(studentsRepositoryProvider).watchById(id));
