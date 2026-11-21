// BulkAddScreen (F20): a repeating mini form (name, guardian phone) with
// "Save & next". Built for the setup evening: type a name, Tab, type the
// phone, Enter - it saves, enrols the student in the batch and the cursor is
// back in the name field. A phone that already belongs to someone only asks
// once (siblings share a guardian number).

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/error_text.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/data/repositories/people_providers.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/features/extras/controllers/bulk_add_service.dart';
import 'package:attendance_alamin/features/extras/controllers/extra_providers.dart';
import 'package:attendance_alamin/features/extras/widgets/csv_import_flow.dart';

class BulkAddScreen extends ConsumerStatefulWidget {
  const BulkAddScreen({super.key, required this.batchId});

  final String batchId;

  @override
  ConsumerState<BulkAddScreen> createState() => _BulkAddScreenState();
}

class _BulkAddScreenState extends ConsumerState<BulkAddScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();

  /// Newest first.
  final List<BulkAdded> _added = <BulkAdded>[];
  bool _busy = false;
  String? _error;

  /// Set when the typed phone belongs to someone; the next save adds anyway.
  Student? _phoneOwner;
  String? _confirmedPhone;
  String? _removedNote;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  bool get _canSave => !_busy && _name.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (!_canSave) return;
    final l10n = context.l10n;
    final String name = _name.text;
    final String phone = _phone.text;
    // Clear now, not after the save: whatever is typed while the save runs
    // belongs to the next student and must not be wiped.
    _name.clear();
    _phone.clear();
    setState(() {
      _busy = true;
      _error = null;
      _removedNote = null;
    });
    try {
      final students = ref.read(studentsRepositoryProvider);
      final String phoneKey = phone.trim();
      if (phoneKey.isNotEmpty && _confirmedPhone != phoneKey) {
        final Student? owner = await phoneOwner(students, phone);
        if (!mounted) return;
        if (owner != null) {
          _restore(name, phone);
          setState(() {
            _busy = false;
            _phoneOwner = owner;
            _confirmedPhone = phoneKey;
          });
          return;
        }
      }
      final BulkAdded added = await bulkAddStudent(
        students: students,
        enrollments: ref.read(enrollmentsRepositoryProvider),
        batchId: widget.batchId,
        name: name,
        guardianPhone: phone,
        today: ref.read(todayProvider),
      );
      if (!mounted) return;
      setState(() {
        _added.insert(0, added);
        _busy = false;
        _phoneOwner = null;
        _confirmedPhone = null;
      });
      _nameFocus.requestFocus();
    } on Object catch (e) {
      if (!mounted) return;
      _restore(name, phone);
      setState(() {
        _busy = false;
        _error = errorText(l10n, e);
      });
    }
  }

  /// Puts a row that was not saved back, unless the teacher already started
  /// typing the next one.
  void _restore(String name, String phone) {
    if (_name.text.isEmpty && _phone.text.isEmpty) {
      _name.text = name;
      _phone.text = phone;
    }
  }

  Future<void> _removeLast() async {
    if (_added.isEmpty || _busy) return;
    final BulkAdded last = _added.first;
    setState(() => _busy = true);
    try {
      await ref.read(studentsRepositoryProvider).softDelete(last.id);
      if (!mounted) return;
      setState(() {
        _added.removeAt(0);
        _busy = false;
        _removedNote = context.l10n.extraBulkRemoved(last.name);
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = errorText(context.l10n, e);
      });
    }
  }

  Future<void> _importCsv() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await startCsvStudentImport(
        context,
        ref,
        batchId: widget.batchId,
        onAdded: (List<BulkAdded> added) {
          if (!mounted) return;
          setState(() {
            _added.insertAll(0, added.reversed);
            _error = null;
            _removedNote = null;
          });
        },
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.batch(widget.batchId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final AsyncValue<Batch?> batch = ref.watch(extraBatchProvider(widget.batchId));
    final double g = WindowClass.of(context).gutter;
    final bool wide = WindowClass.of(context).isWide;

    Widget body;
    if (batch.hasError) {
      body = BhorEmptyState(icon: BhorIcons.warning, title: l10n.commonLoadingFailed);
    } else if (!batch.hasValue) {
      body = const Center(child: BhorSpinner());
    } else if (batch.value == null) {
      body = BhorEmptyState(icon: BhorIcons.delete, title: l10n.extraBulkBatchMissing);
    } else {
      final Widget form = _form(context, batch.value!);
      final Widget list = _addedList(context, scrollable: wide);
      body = wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(flex: 5, child: SingleChildScrollView(child: form)),
                SizedBox(width: g),
                Expanded(flex: 4, child: list),
              ],
            )
          : ListView(children: <Widget>[form, const SizedBox(height: BhorSpace.s12), list]);
    }

    final bool ready = batch.value != null;
    return BhorScaffold(
      header: BhorHeader(
        title: l10n.extraBulkTitle,
        large: true,
        showBack: true,
        onBack: _close,
        actions: <Widget>[
          BhorButton(
            key: const ValueKey<String>('bulk-finish'),
            variant: BhorButtonVariant.ghost,
            label: l10n.extraBulkFinish,
            onPressed: _close,
          ),
          const SizedBox(width: BhorSpace.s8),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(g, 4, g, g),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: body,
          ),
        ),
      ),
      bottomNav: ready
          ? BhorActionBar(
              buttonKey: const ValueKey<String>('bulk-save'),
              label: _phoneOwner != null ? l10n.extraBulkSaveAnyway : l10n.extraBulkSaveNext,
              onPressed: _canSave ? _save : null,
              disabledReason: _name.text.trim().isEmpty ? l10n.extraBulkDisabledName : null,
              summary: l10n.extraBulkAddedCount(context.fmt.digits(_added.length.toString())),
            )
          : null,
    );
  }

  Widget _form(BuildContext context, Batch batch) {
    final l10n = context.l10n;
    final BhorThemeData b = context.bhor;
    return BhorCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.extraBulkIntoBatch(batch.name),
            style: b.type.bodyStrong.copyWith(color: b.colors.accent),
          ),
          const SizedBox(height: BhorSpace.s4),
          Text(
            l10n.onbBillingStartNote(context.fmt.monthYear(ref.watch(todayProvider).yearMonth)),
            key: const ValueKey<String>('bulk-billing-note'),
            style: b.type.body.copyWith(color: b.colors.text2),
          ),
          const SizedBox(height: BhorSpace.s12),
          BhorTextField(
            key: const ValueKey<String>('bulk-name'),
            textCapitalization: TextCapitalization.words,
            controller: _name,
            focusNode: _nameFocus,
            autofocus: true,
            textInputAction: TextInputAction.next,
            label: l10n.extraBulkNameLabel,
            onChanged: (_) => setState(() => _removedNote = null),
            onSubmitted: (_) => _phoneFocus.requestFocus(),
          ),
          const SizedBox(height: BhorSpace.s12),
          BhorTextField(
            key: const ValueKey<String>('bulk-phone'),
            controller: _phone,
            focusNode: _phoneFocus,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            tabular: true,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'[0-9০-৯+\-\s]')),
            ],
            label: l10n.extraBulkPhoneLabel,
            onChanged: (_) => setState(() {
              _phoneOwner = null;
              _confirmedPhone = null;
              _error = null;
            }),
            onSubmitted: (_) => _save(),
          ),
          if (_phoneOwner != null) ...<Widget>[
            const SizedBox(height: BhorSpace.s12),
            _Note(
              key: const ValueKey<String>('bulk-duplicate'),
              icon: BhorIcons.info,
              text: l10n.extraBulkDuplicate(_phoneOwner!.name),
              fill: b.colors.accentTint,
              color: b.colors.accent,
            ),
          ],
          if (_error != null) ...<Widget>[
            const SizedBox(height: BhorSpace.s12),
            _Note(
              key: const ValueKey<String>('bulk-error'),
              icon: BhorIcons.warning,
              text: _error!,
              fill: b.colors.dangerBg,
              color: b.colors.danger,
            ),
          ],
          if (_removedNote != null) ...<Widget>[
            const SizedBox(height: BhorSpace.s12),
            Text(_removedNote!, style: b.type.meta),
          ],
          const SizedBox(height: BhorSpace.s12),
          Text(l10n.extraBulkHint, style: b.type.meta),
          const SizedBox(height: BhorSpace.s12),
          CsvImportButton(onPressed: _busy ? null : _importCsv),
        ],
      ),
    );
  }

  Widget _addedList(BuildContext context, {required bool scrollable}) {
    final l10n = context.l10n;
    final BhorThemeData b = context.bhor;
    if (_added.isEmpty) return const SizedBox.shrink();
    // A phone shows the newest rows only; the counter in the action bar has
    // the full number.
    final List<BulkAdded> shown = scrollable || _added.length <= 30 ? _added : _added.sublist(0, 30);
    final List<Widget> rows = <Widget>[
      for (int i = 0; i < shown.length; i++)
        BhorListRow(
          key: ValueKey<String>('bulk-added-${shown[i].id}'),
          leading: BhorAvatar(name: shown[i].name, size: 32),
          title: shown[i].name,
          subtitle: shown[i].guardianPhone == null ? null : context.fmt.digits(shown[i].guardianPhone!),
          divider: i < shown.length - 1,
          trailing: Text(l10n.extraBulkRoll(context.fmt.digits(shown[i].roll)), style: b.type.meta),
        ),
    ];
    final Widget header = Padding(
      padding: const EdgeInsets.only(left: BhorSpace.s16, right: BhorSpace.s8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Semantics(
              header: true,
              child: Text(l10n.extraBulkAddedTitle, style: b.type.heading),
            ),
          ),
          BhorButton(
            key: const ValueKey<String>('bulk-undo-last'),
            variant: BhorButtonVariant.ghost,
            icon: BhorIcons.undo,
            label: l10n.extraBulkUndoLast,
            onPressed: _busy ? null : _removeLast,
          ),
        ],
      ),
    );
    if (!scrollable) return BhorList(header: header, children: rows);
    return BhorCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          header,
          Expanded(child: ListView(padding: EdgeInsets.zero, children: rows)),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({super.key, required this.icon, required this.text, required this.fill, required this.color});

  final IconData icon;
  final String text;
  final Color fill;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(BhorRadius.control)),
        child: Padding(
          padding: const EdgeInsets.all(BhorSpace.s12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, size: 20, color: color),
              const SizedBox(width: BhorSpace.s8),
              Expanded(child: Text(text, style: context.bhor.type.body.copyWith(color: color))),
            ],
          ),
        ),
      ),
    );
  }
}
