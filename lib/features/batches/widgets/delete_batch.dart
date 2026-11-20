// Delete behind the secondary menu, with the impact numbers (Product 3.8).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/l10n/error_text.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/data/repositories/batches_repository.dart';
import 'package:attendance_alamin/data/repositories/structure_providers.dart';
import 'package:attendance_alamin/domain/models/batch.dart';

/// Asks with the numbers that go with the batch, then soft-deletes it. True
/// when deleted.
Future<bool> confirmDeleteBatch(BuildContext context, {required String batchId}) async {
  final ProviderContainer container = ProviderScope.containerOf(context, listen: false);
  final BatchesRepository repo = container.read(batchesRepositoryProvider);
  final Batch? batch = await repo.getById(batchId);
  if (batch == null || !context.mounted) return false;
  final DeleteImpact impact = await repo.deleteImpact(batchId);
  if (!context.mounted) return false;
  final l10n = context.l10n;
  final fmt = context.fmt;
  final bool ok = await showConfirmDialog(
    context,
    title: l10n.batchDeleteTitle(batch.name),
    body:
        '${l10n.batchDeleteBody(fmt.number(impact.students), fmt.number(impact.sessions), fmt.number(impact.payments))}\n\n${l10n.batchDeleteHint}',
    confirmLabel: l10n.batchDeleteConfirm,
    destructive: true,
  );
  if (!ok || !context.mounted) return false;
  try {
    await repo.softDelete(batchId);
  } on Object catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(errorText(l10n, e))));
    }
    return false;
  }
  if (context.mounted) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(l10n.batchDeletedToast)));
  }
  return true;
}
