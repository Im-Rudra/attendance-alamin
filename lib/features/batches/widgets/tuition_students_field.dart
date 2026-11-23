// "Students" of a new private tuition (item 1): pick existing students from a
// searchable list and/or add new ones by name + guardian phone, right inside
// the tuition form. Nothing is written until the form saves.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/error_text.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/widgets/digits_formatter.dart';
import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/validation/validators.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/features/batches/controllers/batch_providers.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

/// One student typed in the tuition form (created on save).
class NewTuitionStudent {
  NewTuitionStudent(this.key);

  /// Stable widget key (rows can be removed from the middle).
  final int key;
  final TextEditingController name = TextEditingController();
  final TextEditingController phone = TextEditingController();

  void dispose() {
    name.dispose();
    phone.dispose();
  }
}

/// The students picked / typed for a new tuition.
class TuitionStudentsDraft extends ChangeNotifier {
  final List<String> picked = <String>[];
  final List<NewTuitionStudent> added = <NewTuitionStudent>[];
  int _next = 0;

  bool get isEmpty => picked.isEmpty && added.isEmpty;

  void pick(String id) {
    if (picked.contains(id)) return;
    picked.add(id);
    notifyListeners();
  }

  void unpick(String id) {
    if (picked.remove(id)) notifyListeners();
  }

  void addNew() {
    final NewTuitionStudent row = NewTuitionStudent(_next++);
    row.name.addListener(notifyListeners);
    row.phone.addListener(notifyListeners);
    added.add(row);
    notifyListeners();
  }

  void removeNew(NewTuitionStudent row) {
    if (!added.remove(row)) return;
    notifyListeners();
    // Disposed after the frame that drops its fields.
    WidgetsBinding.instance.addPostFrameCallback((_) => row.dispose());
  }

  /// The guardian phone's error, or null (blank is fine).
  static String? phoneError(AppLocalizations l10n, NewTuitionStudent row) {
    if (row.phone.text.trim().isEmpty) return null;
    try {
      Validators.phone(row.phone.text);
      return null;
    } on ValidationException catch (e) {
      return errorText(l10n, e);
    }
  }

  /// Why the form cannot save these students yet, or null.
  String? reason(AppLocalizations l10n) {
    for (final NewTuitionStudent r in added) {
      if (r.name.text.trim().isEmpty) return l10n.batchReasonStudentName;
    }
    for (final NewTuitionStudent r in added) {
      if (phoneError(l10n, r) != null) return l10n.batchReasonStudentPhone;
    }
    return null;
  }

  @override
  void dispose() {
    for (final NewTuitionStudent r in added) {
      r.dispose();
    }
    super.dispose();
  }
}

class TuitionStudentsField extends ConsumerWidget {
  const TuitionStudentsField({super.key, required this.draft});

  final TuitionStudentsDraft draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final BhorThemeData th = context.bhor;
    final List<Student> all = <Student>[
      for (final Student s in ref.watch(batchAllStudentsProvider).value ?? const <Student>[])
        if (s.status == StudentStatus.active) s,
    ]..sort((Student a, Student b) => a.name.compareTo(b.name));
    final Map<String, Student> byId = <String, Student>{for (final Student s in all) s.id: s};

    return ListenableBuilder(
      listenable: draft,
      builder: (BuildContext context, Widget? _) {
        final List<Student> pickable = <Student>[
          for (final Student s in all)
            if (!draft.picked.contains(s.id)) s,
        ];
        String? sub(Student s) {
          final String phone = (s.guardianPhone ?? s.phone ?? '').trim();
          final String roll = (s.roll ?? '').trim();
          final List<String> parts = <String>[
            if (roll.isNotEmpty) l10n.stuRollLine(fmt.digits(roll)),
            if (phone.isNotEmpty) fmt.digits(phone),
          ];
          return parts.isEmpty ? null : parts.join(' · ');
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Semantics(header: true, child: Text(l10n.batchTuitionStudents, style: th.type.heading)),
            const SizedBox(height: BhorSpace.s4),
            Text(l10n.batchTuitionStudentsHelp, style: th.type.meta),
            const SizedBox(height: BhorSpace.s8),
            if (draft.picked.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: BhorSpace.s8),
                child: BhorCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      for (int i = 0; i < draft.picked.length; i++)
                        BhorListRow(
                          key: ValueKey<String>('tuition-picked-${draft.picked[i]}'),
                          title: byId[draft.picked[i]]?.name ?? '',
                          subtitle: byId[draft.picked[i]] == null ? null : sub(byId[draft.picked[i]]!),
                          divider: i < draft.picked.length - 1,
                          trailing: BhorIconButton(
                            semanticLabel: l10n.batchTuitionRemoveStudent(byId[draft.picked[i]]?.name ?? ''),
                            icon: BhorIcons.close,
                            onPressed: () => draft.unpick(draft.picked[i]),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            for (final NewTuitionStudent row in draft.added)
              Padding(
                key: ValueKey<int>(row.key),
                padding: const EdgeInsets.only(bottom: BhorSpace.s8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          BhorTextField(
                            key: ValueKey<String>('tuition-new-name-${row.key}'),
                            controller: row.name,
                            label: l10n.batchTuitionNewName,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            autofocus: true,
                          ),
                          const SizedBox(height: BhorSpace.s8),
                          BhorTextField(
                            key: ValueKey<String>('tuition-new-phone-${row.key}'),
                            controller: row.phone,
                            label: l10n.batchTuitionNewPhone,
                            keyboardType: TextInputType.phone,
                            inputFormatters: <TextInputFormatter>[DigitsFormatter(context.fmt, maxLength: 20, phone: true)],
                            error: TuitionStudentsDraft.phoneError(l10n, row),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: BhorSpace.s4),
                    Padding(
                      padding: const EdgeInsets.only(top: BhorSpace.s8),
                      child: BhorIconButton(
                        semanticLabel: l10n.batchTuitionRemoveStudent(row.name.text.trim()),
                        icon: BhorIcons.close,
                        onPressed: () => draft.removeNew(row),
                      ),
                    ),
                  ],
                ),
              ),
            if (pickable.isNotEmpty) ...<Widget>[
              BhorSelect<String>(
                key: const ValueKey<String>('tuition-pick-student'),
                label: l10n.batchTuitionPickStudent,
                hint: l10n.stuPickHint,
                value: null,
                searchable: true,
                searchHint: l10n.batchTuitionPickHint,
                options: <BhorOption<String>>[
                  for (final Student s in pickable)
                    BhorOption<String>(
                      s.id,
                      sub(s) == null ? s.name : '${s.name} · ${sub(s)}',
                      searchText: '${s.roll ?? ''} ${s.phone ?? ''} ${s.guardianPhone ?? ''}',
                    ),
                ],
                onChanged: draft.pick,
              ),
              const SizedBox(height: BhorSpace.s8),
            ],
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: BhorButton(
                key: const ValueKey<String>('tuition-add-new-student'),
                icon: BhorIcons.add,
                label: l10n.batchTuitionAddNew,
                variant: BhorButtonVariant.secondary,
                size: BhorButtonSize.sm,
                onPressed: draft.addNew,
              ),
            ),
          ],
        );
      },
    );
  }
}
