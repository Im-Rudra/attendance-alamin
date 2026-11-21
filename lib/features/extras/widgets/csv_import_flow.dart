// Add students from a CSV file (shared by onboarding and the bulk-add
// screen): pick the file, show a preview sheet (problem rows flagged and
// skipped), save everything in one go with a progress bar, then report the
// count in a snackbar.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
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
    return OutlinedButton.icon(
      key: const ValueKey<String>('csv-import-button'),
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      icon: const Icon(Icons.upload_file_outlined),
      label: Text(context.l10n.extraImportButton),
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
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  void say(String text) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), persist: false));

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

  final CsvImportResult? result = await showModalBottomSheet<CsvImportResult>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 560),
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

  String _problemText(AppLocalizations l10n, CsvProblem p) => switch (p) {
        CsvProblem.emptyName => l10n.extraImportProblemName,
        CsvProblem.badPhone => l10n.extraImportProblemPhone,
        CsvProblem.duplicate => l10n.extraImportProblemDuplicate,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final int okCount = _ok.length;
    final int skipped = widget.rows.length - okCount;
    final double maxH = MediaQuery.sizeOf(context).height * 0.9;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(
                l10n.extraImportFound(fmt.number(widget.rows.length)),
                key: const ValueKey<String>('csv-found'),
                style: tt.titleLarge,
              ),
            ),
            if (skipped > 0) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                l10n.extraImportSkipped(fmt.number(skipped)),
                key: const ValueKey<String>('csv-skipped'),
                style: tt.bodyMedium?.copyWith(color: tokens.onErrorContainer),
              ),
            ],
            const SizedBox(height: 4),
            Text(l10n.extraImportHint, style: tt.bodySmall?.copyWith(color: tokens.textSecondary)),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.rows.length,
                itemBuilder: (BuildContext _, int i) {
                  final CsvStudentRow r = widget.rows[i];
                  final CsvProblem? p = r.problem;
                  final String detail = <String>[
                    if (r.roll != null) l10n.extraBulkRoll(fmt.digits(r.roll!)),
                    if (r.phone != null) fmt.digits(r.phone!),
                  ].join('  ·  ');
                  return ListTile(
                    key: ValueKey<String>('csv-row-$i'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      p == null ? Icons.check_circle_outline : Icons.block,
                      color: p == null ? tokens.accent : tokens.onErrorContainer,
                    ),
                    title: Text(
                      r.name.isEmpty ? '—' : r.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: p == null ? null : TextStyle(color: tokens.textSecondary),
                    ),
                    subtitle: p != null
                        ? Text(
                            _problemText(l10n, p),
                            style: TextStyle(color: tokens.onErrorContainer),
                          )
                        : (detail.isEmpty ? null : Text(detail)),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            if (_saving) ...<Widget>[
              LinearProgressIndicator(
                key: const ValueKey<String>('csv-progress'),
                value: okCount == 0 ? null : _done / okCount,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.extraImportSaving(fmt.number(_done), fmt.number(okCount)),
                style: tt.bodyMedium?.copyWith(color: tokens.textSecondary),
              ),
            ] else ...<Widget>[
              FilledButton(
                key: const ValueKey<String>('csv-add-all'),
                onPressed: okCount == 0 ? null : _save,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                child: Text(l10n.extraImportAddAll(fmt.number(okCount))),
              ),
              const SizedBox(height: 4),
              TextButton(
                key: const ValueKey<String>('csv-cancel'),
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: Text(l10n.commonCancel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
