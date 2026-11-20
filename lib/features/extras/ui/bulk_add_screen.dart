// BulkAddScreen (F20): a repeating mini form (name, guardian phone) with
// "Save & next". Built for the setup evening: type a name, Tab, type the
// phone, Enter - it saves, enrols the student in the batch and the cursor is
// back in the name field. A phone that already belongs to someone only asks
// once (siblings share a guardian number).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/l10n/error_text.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/data/repositories/people_providers.dart';
import 'package:attendance_alamin/data/repositories/settings_providers.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/features/extras/controllers/bulk_add_service.dart';
import 'package:attendance_alamin/features/extras/controllers/extra_providers.dart';

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
        settings: ref.read(settingsRepositoryProvider),
        batchId: widget.batchId,
        name: name,
        guardianPhone: phone,
        today: ref.read(todayProvider),
      );
      if (!mounted) return;
      _name.clear();
      _phone.clear();
      setState(() {
        _added.insert(0, added);
        _busy = false;
        _phoneOwner = null;
        _confirmedPhone = null;
      });
      _nameFocus.requestFocus();
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = errorText(l10n, e);
      });
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
      body = EmptyState(icon: Icons.error_outline, message: l10n.commonLoadingFailed);
    } else if (!batch.hasValue) {
      body = const Center(child: CircularProgressIndicator());
    } else if (batch.value == null) {
      body = EmptyState(icon: Icons.layers_clear_outlined, message: l10n.extraBulkBatchMissing);
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
          : ListView(children: <Widget>[form, const SizedBox(height: 12), list]);
    }

    final bool ready = batch.value != null;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.commonClose,
          icon: const Icon(Icons.close),
          onPressed: _close,
        ),
        title: Semantics(header: true, child: Text(l10n.extraBulkTitle)),
        actions: <Widget>[
          TextButton(
            key: const ValueKey<String>('bulk-finish'),
            onPressed: _close,
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            child: Text(l10n.extraBulkFinish),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(g, 4, g, g),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: body,
            ),
          ),
        ),
      ),
      bottomNavigationBar: ready
          ? StickyActionBar(
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
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    return GlassCard(
      dense: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.extraBulkIntoBatch(batch.name),
            style: tt.titleSmall?.copyWith(color: tokens.accent),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey<String>('bulk-name'),
            controller: _name,
            focusNode: _nameFocus,
            autofocus: true,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: l10n.extraBulkNameLabel),
            onChanged: (_) => setState(() => _removedNote = null),
            onSubmitted: (_) => _phoneFocus.requestFocus(),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey<String>('bulk-phone'),
            controller: _phone,
            focusNode: _phoneFocus,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'[0-9০-৯+\-\s]')),
            ],
            decoration: InputDecoration(labelText: l10n.extraBulkPhoneLabel),
            onChanged: (_) => setState(() {
              _phoneOwner = null;
              _confirmedPhone = null;
              _error = null;
            }),
            onSubmitted: (_) => _save(),
          ),
          if (_phoneOwner != null) ...<Widget>[
            const SizedBox(height: 12),
            _Note(
              key: const ValueKey<String>('bulk-duplicate'),
              icon: Icons.info_outline,
              text: l10n.extraBulkDuplicate(_phoneOwner!.name),
              fill: tokens.infoContainer,
              color: tokens.info,
            ),
          ],
          if (_error != null) ...<Widget>[
            const SizedBox(height: 12),
            _Note(
              key: const ValueKey<String>('bulk-error'),
              icon: Icons.error_outline,
              text: _error!,
              fill: tokens.errorContainer,
              color: tokens.onErrorContainer,
            ),
          ],
          if (_removedNote != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(_removedNote!, style: tt.bodySmall?.copyWith(color: tokens.textSecondary)),
          ],
          const SizedBox(height: 12),
          Text(l10n.extraBulkHint, style: tt.bodySmall?.copyWith(color: tokens.textSecondary)),
        ],
      ),
    );
  }

  Widget _addedList(BuildContext context, {required bool scrollable}) {
    final l10n = context.l10n;
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    if (_added.isEmpty) return const SizedBox.shrink();
    // A phone shows the newest rows only; the counter in the action bar has
    // the full number.
    final List<BulkAdded> shown = scrollable || _added.length <= 30 ? _added : _added.sublist(0, 30);
    final List<Widget> rows = <Widget>[
      for (final BulkAdded a in shown)
        ListTile(
          key: ValueKey<String>('bulk-added-${a.id}'),
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: InitialsAvatar(name: a.name),
          title: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: a.guardianPhone == null ? null : Text(context.fmt.digits(a.guardianPhone!)),
          trailing: Text(
            l10n.extraBulkRoll(context.fmt.digits(a.roll)),
            style: tt.labelMedium?.copyWith(color: tokens.textSecondary),
          ),
        ),
    ];
    final Widget header = Row(
      children: <Widget>[
        Expanded(
          child: Semantics(
            header: true,
            child: Text(l10n.extraBulkAddedTitle, style: tt.titleSmall),
          ),
        ),
        TextButton.icon(
          key: const ValueKey<String>('bulk-undo-last'),
          onPressed: _busy ? null : _removeLast,
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          icon: const Icon(Icons.undo, size: 18),
          label: Text(l10n.extraBulkUndoLast),
        ),
      ],
    );
    return GlassCard(
      dense: true,
      child: scrollable
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                header,
                Expanded(child: ListView(children: rows)),
              ],
            )
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[header, ...rows]),
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
        decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color))),
            ],
          ),
        ),
      ),
    );
  }
}
