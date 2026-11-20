// The CSV export sheet (F23): pick what to export for a month and save it or
// share it. Three files - students, payments, attendance - each with its own
// save and share button. The files carry a UTF-8 BOM so Excel shows Bangla.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/data/backup/backup_files.dart';
import 'package:attendance_alamin/data/backup/backup_providers.dart';
import 'package:attendance_alamin/data/repositories/people_providers.dart';
import 'package:attendance_alamin/data/repositories/structure_providers.dart';
import 'package:attendance_alamin/features/extras/controllers/csv_export.dart';
import 'package:attendance_alamin/features/settings/settings_entry.dart';

/// Opens the sheet for [month].
Future<void> openCsvExportSheet(BuildContext context, {required YearMonth month}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (BuildContext ctx) => CsvExportSheet(initialMonth: month),
  );
}

class CsvExportSheet extends ConsumerStatefulWidget {
  const CsvExportSheet({super.key, required this.initialMonth, this.files});

  final YearMonth initialMonth;

  /// Test seam; defaults to `backupFilesProvider`.
  final BackupFiles? files;

  @override
  ConsumerState<CsvExportSheet> createState() => _CsvExportSheetState();
}

class _CsvExportSheetState extends ConsumerState<CsvExportSheet> {
  late YearMonth _month = widget.initialMonth;
  CsvKind? _busy;

  Future<void> _run(CsvKind kind, {required bool share}) async {
    if (_busy != null) return;
    final l10n = context.l10n;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final BackupFiles files = widget.files ?? ref.read(backupFilesProvider);
    setState(() => _busy = kind);
    try {
      final CsvFile file = await loadCsvFile(
        kind: kind,
        month: _month,
        l10n: l10n,
        students: ref.read(studentsRepositoryProvider),
        enrollments: ref.read(enrollmentsRepositoryProvider),
        batches: ref.read(batchesRepositoryProvider),
        payments: ref.read(paymentsRepositoryProvider),
        otherIncome: ref.read(otherIncomeRepositoryProvider),
        attendance: ref.read(attendanceRepositoryProvider),
        methodLabel: (m) => paymentMethodLabel(l10n, m),
      );
      if (share) {
        await files.share(file.bytes, fileName: file.fileName);
      } else {
        final bool saved = await files.save(file.bytes, fileName: file.fileName);
        if (saved) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(l10n.extraCsvSaved)));
        }
      }
    } on Object {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.extraCsvFailed)));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final List<({CsvKind kind, IconData icon, String title, String hint})> rows =
        <({CsvKind kind, IconData icon, String title, String hint})>[
      (
        kind: CsvKind.students,
        icon: Icons.groups_outlined,
        title: l10n.extraCsvStudents,
        hint: l10n.extraCsvStudentsHint,
      ),
      (
        kind: CsvKind.payments,
        icon: Icons.payments_outlined,
        title: l10n.extraCsvPayments,
        hint: l10n.extraCsvPaymentsHint,
      ),
      (
        kind: CsvKind.attendance,
        icon: Icons.fact_check_outlined,
        title: l10n.extraCsvAttendance,
        hint: l10n.extraCsvAttendanceHint,
      ),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(header: true, child: Text(l10n.extraCsvTitle, style: tt.titleLarge)),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              IconButton(
                key: const ValueKey<String>('csv-prev-month'),
                tooltip: fmt.monthYear(_month.addMonths(-1)),
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() => _month = _month.addMonths(-1)),
              ),
              Expanded(
                child: Text(
                  l10n.extraCsvMonthLine(fmt.monthYear(_month)),
                  key: const ValueKey<String>('csv-month'),
                  textAlign: TextAlign.center,
                  style: tt.titleMedium,
                ),
              ),
              IconButton(
                key: const ValueKey<String>('csv-next-month'),
                tooltip: fmt.monthYear(_month.addMonths(1)),
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(() => _month = _month.addMonths(1)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final r in rows) ...<Widget>[
            _CsvRow(
              kind: r.kind,
              icon: r.icon,
              title: r.title,
              hint: r.hint,
              busy: _busy == r.kind,
              enabled: _busy == null,
              saveLabel: l10n.extraCsvSave,
              shareLabel: l10n.extraCsvShare,
              onSave: () => _run(r.kind, share: false),
              onShare: () => _run(r.kind, share: true),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 4),
          Text(l10n.extraCsvPrivacy, style: tt.bodySmall?.copyWith(color: tokens.textSecondary)),
        ],
      ),
    );
  }
}

class _CsvRow extends StatelessWidget {
  const _CsvRow({
    required this.kind,
    required this.icon,
    required this.title,
    required this.hint,
    required this.busy,
    required this.enabled,
    required this.saveLabel,
    required this.shareLabel,
    required this.onSave,
    required this.onShare,
  });

  final CsvKind kind;
  final IconData icon;
  final String title;
  final String hint;
  final bool busy;
  final bool enabled;
  final String saveLabel;
  final String shareLabel;
  final VoidCallback onSave;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surfaceDense,
        border: Border.all(color: tokens.hairline),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, color: tokens.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title, style: tt.titleSmall),
                      Text(hint, style: tt.bodySmall?.copyWith(color: tokens.textSecondary)),
                    ],
                  ),
                ),
                if (busy)
                  const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.icon(
                  key: ValueKey<String>('csv-save-${kind.name}'),
                  onPressed: enabled ? onSave : null,
                  style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                  icon: const Icon(Icons.save_alt, size: 18),
                  label: Text(saveLabel),
                ),
                OutlinedButton.icon(
                  key: ValueKey<String>('csv-share-${kind.name}'),
                  onPressed: enabled ? onShare : null,
                  style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: Text(shareLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
