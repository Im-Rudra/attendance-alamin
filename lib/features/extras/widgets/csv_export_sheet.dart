// The CSV export sheet (F23): pick what to export for a month and save it or
// share it. Three files - students, payments, attendance - each with its own
// save and share button. The files carry a UTF-8 BOM so Excel shows Bangla.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/data/backup/backup_files.dart';
import 'package:attendance_alamin/data/backup/backup_providers.dart';
import 'package:attendance_alamin/data/repositories/people_providers.dart';
import 'package:attendance_alamin/data/repositories/structure_providers.dart';
import 'package:attendance_alamin/features/extras/controllers/csv_export.dart';
import 'package:attendance_alamin/features/settings/settings_entry.dart';

/// Opens the sheet for [month].
Future<void> openCsvExportSheet(BuildContext context, {required YearMonth month}) {
  return showBhorPanel<void>(
    context,
    title: context.l10n.extraCsvTitle,
    kind: BhorPanelKind.confirm,
    scroll: false,
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
        if (saved && mounted) BhorToast.show(context, message: l10n.extraCsvSaved, tone: BhorTone.ok);
      }
    } on Object {
      if (mounted) BhorToast.show(context, message: l10n.extraCsvFailed, tone: BhorTone.danger);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final BhorThemeData b = context.bhor;
    final List<({CsvKind kind, IconData icon, String title, String hint})> rows =
        <({CsvKind kind, IconData icon, String title, String hint})>[
      (
        kind: CsvKind.students,
        icon: BhorIcons.batches,
        title: l10n.extraCsvStudents,
        hint: l10n.extraCsvStudentsHint,
      ),
      (
        kind: CsvKind.payments,
        icon: BhorIcons.takeMoney,
        title: l10n.extraCsvPayments,
        hint: l10n.extraCsvPaymentsHint,
      ),
      (
        kind: CsvKind.attendance,
        icon: BhorIcons.checkCircle,
        title: l10n.extraCsvAttendance,
        hint: l10n.extraCsvAttendanceHint,
      ),
    ];
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              BhorIconButton(
                key: const ValueKey<String>('csv-prev-month'),
                icon: BhorIcons.chevronLeft,
                semanticLabel: fmt.monthYear(_month.addMonths(-1)),
                onPressed: () => setState(() => _month = _month.addMonths(-1)),
              ),
              Expanded(
                child: Text(
                  l10n.extraCsvMonthLine(fmt.monthYear(_month)),
                  key: const ValueKey<String>('csv-month'),
                  textAlign: TextAlign.center,
                  style: b.type.heading,
                ),
              ),
              BhorIconButton(
                key: const ValueKey<String>('csv-next-month'),
                icon: BhorIcons.chevronRight,
                semanticLabel: fmt.monthYear(_month.addMonths(1)),
                onPressed: () => setState(() => _month = _month.addMonths(1)),
              ),
            ],
          ),
          const SizedBox(height: BhorSpace.s8),
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
            const SizedBox(height: BhorSpace.s8),
          ],
          const SizedBox(height: BhorSpace.s4),
          Text(l10n.extraCsvPrivacy, style: b.type.meta),
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
    final BhorThemeData b = context.bhor;
    return BhorCard(
      padding: const EdgeInsets.all(BhorSpace.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: b.colors.accent),
              const SizedBox(width: BhorSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: b.type.bodyStrong),
                    Text(hint, style: b.type.meta),
                  ],
                ),
              ),
              if (busy) const BhorSpinner(size: 24),
            ],
          ),
          const SizedBox(height: BhorSpace.s8),
          Wrap(
            spacing: BhorSpace.s8,
            runSpacing: BhorSpace.s8,
            children: <Widget>[
              BhorButton(
                key: ValueKey<String>('csv-save-${kind.name}'),
                icon: BhorIcons.backupDown,
                label: saveLabel,
                onPressed: enabled ? onSave : null,
              ),
              BhorButton(
                key: ValueKey<String>('csv-share-${kind.name}'),
                variant: BhorButtonVariant.secondary,
                icon: BhorIcons.share,
                label: shareLabel,
                onPressed: enabled ? onShare : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
