// Public surface of the batches feature (plan section 1 #32). Signatures are
// frozen; other features (more, search, today) call these.

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/error_text.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/data/repositories/batches_repository.dart';
import 'package:attendance_alamin/data/repositories/structure_providers.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/enrollment.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';
import 'package:attendance_alamin/features/batches/controllers/batch_providers.dart';
import 'package:attendance_alamin/features/batches/widgets/archive_dialogs.dart';

void _toast(BuildContext context, String message) {
  BhorToast.show(context, message: message);
}

/// Finish-batch dialog (asks the finish day and the last billable month);
/// true when finished.
Future<bool> showArchiveBatchDialog(BuildContext context, {required String batchId}) async {
  final ProviderContainer container = ProviderScope.containerOf(context, listen: false);
  final BatchesRepository repo = container.read(batchesRepositoryProvider);
  final Batch? batch = await repo.getById(batchId);
  if (batch == null || batch.archived || !context.mounted) return false;
  final LocalDate today = container.read(todayProvider);
  // Up to two years back, but never before the batch existed.
  LocalDate earliest = today.addDays(-730);
  if (batch.createdOn.isAfter(earliest)) earliest = batch.createdOn;
  if (earliest.isAfter(today)) earliest = today;
  final FinishChoice? choice = await showArchiveBatchPanel(
    context,
    batchName: batch.name,
    today: today,
    earliest: earliest,
    weekStart: container.read(weekStartProvider).value ?? DateTime.saturday,
  );
  if (choice == null || !context.mounted) return false;
  final l10n = context.l10n;
  try {
    await repo.archive(batchId, on: choice.on, lastBillableMonth: choice.lastBillableMonth);
  } on Object catch (e) {
    if (context.mounted) _toast(context, errorText(l10n, e));
    return false;
  }
  if (context.mounted) _toast(context, l10n.batchArchivedToast);
  return true;
}

/// One printable line per clash group: "Subject · Batch · every Sunday · time".
Future<List<String>> _clashLines(
  BuildContext context,
  ProviderContainer container,
  SlotCheckResult preview,
) async {
  final l10n = context.l10n;
  final AppFormat fmt = context.fmt;
  final BatchesRepository batches = container.read(batchesRepositoryProvider);
  final Map<String, String> subjectNames = <String, String>{
    for (final s in await container.read(batchSubjectsProvider.future)) s.id: s.name,
  };
  final List<String> lines = <String>[];
  for (final ClashGroup g in preview.groups) {
    final Batch? other = await batches.getById(g.batchId);
    final String when = g.everyWeek
        ? l10n.batchClashEvery(fmt.weekdayName(g.weekday))
        : (g.date == null ? '' : fmt.dateShort(g.date!));
    lines.add(l10n.batchClashLine(
      subjectNames[other?.subjectId] ?? '',
      other?.name ?? '',
      when,
      fmt.timeRange(g.startMin, g.endMin),
    ));
  }
  return lines;
}

/// Reopen flow (restart day, clash check, gap-waive prompt); true when reopened.
Future<bool> showUnarchiveBatchFlow(BuildContext context, {required String batchId}) async {
  final ProviderContainer container = ProviderScope.containerOf(context, listen: false);
  final BatchesRepository repo = container.read(batchesRepositoryProvider);
  final Batch? batch = await repo.getById(batchId);
  if (batch == null || !batch.archived || !context.mounted) return false;
  final LocalDate today = container.read(todayProvider);

  final SlotCheckResult preview = await repo.previewUnarchive(batchId);
  final List<Enrollment> enrollments =
      await container.read(batchEnrollmentsProvider(batchId).future);
  if (!context.mounted) return false;
  List<String> clashLines = const <String>[];
  if (!preview.ok) {
    try {
      clashLines = await _clashLines(context, container, preview);
    } on Object catch (e, st) {
      debugPrint('unarchive clash lines failed: $e $st');
      return false;
    }
  }
  if (!context.mounted) return false;

  // From the day after it was finished (a batch finished today reopens today).
  LocalDate earliest = (batch.archivedOn ?? today).addDays(1);
  if (earliest.isAfter(today)) earliest = today;
  final UnarchiveChoice? choice = await showUnarchiveBatchPanel(
    context,
    batchName: batch.name,
    clashLines: clashLines,
    gapFor: (LocalDate on) => gapMonthsOnUnarchive(enrollments, on.yearMonth),
    today: today,
    earliest: earliest,
    weekStart: container.read(weekStartProvider).value ?? DateTime.saturday,
  );
  if (choice == null || !context.mounted) return false;

  final l10n = context.l10n;
  final GoRouter? router = GoRouter.maybeOf(context);
  try {
    await repo.unarchive(
      batchId,
      acceptClashes: choice.acceptClashes,
      waiveGap: choice.waiveGap,
      on: choice.on,
    );
  } on Object catch (e) {
    if (context.mounted) _toast(context, errorText(l10n, e));
    return false;
  }
  if (context.mounted) _toast(context, l10n.batchUnarchivedToast);
  // Scenario 21: unarchiving with clashes goes straight to fixing the slots.
  if (choice.acceptClashes) router?.push(Routes.batchSlots(batchId));
  return true;
}
