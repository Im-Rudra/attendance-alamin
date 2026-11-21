// Add students from a CSV file (shared by onboarding and the bulk-add
// screen): pick the file, show a preview sheet (problem rows flagged and
// skipped), save everything in one go with a progress bar, then report the
// count in a toast.

import 'dart:typed_data';

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/data/repositories/people_providers.dart';
import 'package:attendance_alamin/features/extras/controllers/bulk_add_service.dart';
import 'package:attendance_alamin/features/extras/controllers/csv_import_service.dart';
import 'package:attendance_alamin/features/extras/csv_student_parser.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

/// The secondary "Add from CSV file" button under a manual form.
class CsvImportButton extends StatelessWidget {
  const CsvImportButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return BhorButton(
      key: const ValueKey<String>('csv-import-button'),
      variant: BhorButtonVariant.secondary,
      icon: Icons.upload_file_outlined,
      label: context.l10n.extraImportButton,
      expand: true,
      onPressed: onPressed,
    );
  }
}

/// Runs the whole flow. [onAdded] receives the students that were saved.
/// [batchId] null means "no batch" (onboarding with the batch step skipped).
Future<void> startCsvStudentImport(
  BuildContext context,
  WidgetRef ref, {
  required String? batchId,
  required void Function(List<BulkAdded> added) onAdded,
}) async {
  final AppLocalizations l10n = context.l10n;
  void say(String text) {
    if (context.mounted) BhorToast.show(context, message: text);
  }

  List<CsvStudentRow> rows;
  try {
    final Uint8List? bytes = await ref.read(csvFilePickerProvider)();
    if (bytes == null) return;
    rows = parseStudentCsvBytes(bytes);
    rows = await flagExistingDuplicates(ref.read(studentsRepositoryProvider), rows);
  } on Object {
    say(l10n.extraImportReadFailed);
    return;
  }
  if (rows.isEmpty) {
    say(l10n.extraImportNone);
    return;
  }
  if (!context.mounted) return;

  final CsvImportResult? result = await showBhorSheet<CsvImportResult>(
    context,
    dismissible: false,
    builder: (BuildContext ctx) => CsvPreviewSheet(
      rows: rows,
      save: (List<CsvStudentRow> r, void Function(int) progress) => importStudentRows(
        students: ref.read(studentsRepositoryProvider),
        enrollments: ref.read(enrollmentsRepositoryProvider),
        batchId: batchId,
        rows: r,
        today: ref.read(todayProvider),
        onProgress: progress,
      ),
    ),
  );
  if (result == null) return;
  onAdded(result.added);
  say(result.failed == 0
      ? l10n.extraImportDone(context.fmt.number(result.added.length))
      : l10n.extraImportDonePartial(context.fmt.number(result.added.length), context.fmt.number(result.failed)));
}

typedef CsvSave = Future<CsvImportResult> Function(List<CsvStudentRow> rows, void Function(int done) progress);

class CsvPreviewSheet extends StatefulWidget {
  const CsvPreviewSheet({super.key, required this.rows, required this.save});

  final List<CsvStudentRow> rows;
  final CsvSave save;

  @override
  State<CsvPreviewSheet> createState() => _CsvPreviewSheetState();
}

class _CsvPreviewSheetState extends State<CsvPreviewSheet> {
  bool _saving = false;
  int _done = 0;

  List<CsvStudentRow> get _ok => <CsvStudentRow>[
        for (final CsvStudentRow r in widget.rows)
          if (r.ok) r,
      ];

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _done = 0;
    });
    final CsvImportResult result = await widget.save(widget.rows, (int d) {
      if (mounted) setState(() => _done = d);
    });
    if (mounted) Navigator.of(context).pop(result);
  }

  String _noteText(AppLocalizations l10n, CsvNote n) => switch (n) {
        CsvNote.samePhone => l10n.extraImportNoteSamePhone,
        CsvNote.sameName => l10n.extraImportNoteSameName,
      };

  String _problemText(AppLocalizations l10n, CsvProblem p) => switch (p) {
        CsvProblem.emptyName => l10n.extraImportProblemName,
        CsvProblem.badPhone => l10n.extraImportProblemPhone,
        CsvProblem.duplicate => l10n.extraImportProblemDuplicate,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final BhorThemeData b = context.bhor;
    final int okCount = _ok.length;
    final int skipped = widget.rows.length - okCount;
    final double maxH = MediaQuery.sizeOf(context).height * 0.8;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              l10n.extraImportFound(fmt.number(widget.rows.length)),
              key: const ValueKey<String>('csv-found'),
              style: b.type.title,
            ),
          ),
          if (skipped > 0) ...<Widget>[
            const SizedBox(height: BhorSpace.s4),
            Text(
              l10n.extraImportSkipped(fmt.number(skipped)),
              key: const ValueKey<String>('csv-skipped'),
              style: b.type.body.copyWith(color: b.colors.danger),
            ),
          ],
          const SizedBox(height: BhorSpace.s4),
          Text(l10n.extraImportHint, style: b.type.meta),
          const SizedBox(height: BhorSpace.s8),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: widget.rows.length,
              itemBuilder: (BuildContext _, int i) {
                final CsvStudentRow r = widget.rows[i];
                final CsvProblem? p = r.problem;
                final String detail = <String>[
                  if (r.roll != null) l10n.extraBulkRoll(fmt.digits(r.roll!)),
                  if (r.phone != null) fmt.digits(r.phone!),
                ].join('  ·  ');
                return Padding(
                  key: ValueKey<String>('csv-row-$i'),
                  padding: const EdgeInsets.symmetric(vertical: BhorSpace.s8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        p == null ? Icons.check_circle_outline : Icons.block,
                        color: p == null ? b.colors.accent : b.colors.danger,
                      ),
                      const SizedBox(width: BhorSpace.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              r.name.isEmpty ? '—' : r.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: p == null ? b.type.bodyStrong : b.type.bodyStrong.copyWith(color: b.colors.text2),
                            ),
                            if (p != null)
                              Text(_problemText(l10n, p), style: b.type.meta.copyWith(color: b.colors.danger))
                            else ...<Widget>[
                              if (detail.isNotEmpty) Text(detail, style: b.type.meta),
                              if (r.note != null)
                                Text(
                                  _noteText(l10n, r.note!),
                                  key: ValueKey<String>('csv-note-$i'),
                                  style: b.type.meta,
                                ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: BhorSpace.s12),
          if (_saving) ...<Widget>[
            BhorProgress(
              key: const ValueKey<String>('csv-progress'),
              value: okCount == 0 ? 0 : _done / okCount,
            ),
            const SizedBox(height: BhorSpace.s8),
            Text(
              l10n.extraImportSaving(fmt.number(_done), fmt.number(okCount)),
              style: b.type.body.copyWith(color: b.colors.text2),
            ),
          ] else ...<Widget>[
            BhorButton(
              key: const ValueKey<String>('csv-add-all'),
              label: l10n.extraImportAddAll(fmt.number(okCount)),
              expand: true,
              onPressed: okCount == 0 ? null : _save,
            ),
            const SizedBox(height: BhorSpace.s4),
            BhorButton(
              key: const ValueKey<String>('csv-cancel'),
              variant: BhorButtonVariant.ghost,
              label: l10n.commonCancel,
              expand: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ],
      ),
    );
  }
}
