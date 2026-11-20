// Backup review (UX 2f, Product 4): the full-screen change summary shown after
// a backup file was picked, then the result with the way back. Phone: one
// column. Desktop: the numbers (info, headline, table) on one side, the named
// details (deletions, clashes, samples, explanations) on the other.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/l10n/error_text.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/data/infra_providers.dart';
import 'package:attendance_alamin/domain/sync/sync_models.dart';
import 'package:attendance_alamin/features/backup/controllers/backup_state.dart';
import 'package:attendance_alamin/features/backup/widgets/review_parts.dart';
import 'package:attendance_alamin/features/reminders/reminders_entry.dart';

class BackupReviewScreen extends ConsumerWidget {
  const BackupReviewScreen({super.key});

  void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.moreBackup);
    }
  }

  Future<void> _apply(BuildContext context, WidgetRef ref) async {
    await ref.read(importControllerProvider.notifier).apply();
    if (!context.mounted) return;
    if (ref.read(importControllerProvider).phase == ImportPhase.applied) {
      requestRemindersReplan(context);
    }
  }

  Future<void> _undo(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool ok = await ref.read(importControllerProvider.notifier).undo();
    if (!context.mounted) return;
    if (ok) {
      requestRemindersReplan(context);
      messenger.showSnackBar(SnackBar(content: Text(l10n.backupUndone)));
      _close(context);
    } else {
      final String? code = ref.read(importControllerProvider).errorCode;
      if (code != null) {
        messenger.showSnackBar(SnackBar(content: Text(errorTextForCode(l10n, code))));
      }
    }
  }

  Future<void> _pickOther(WidgetRef ref) =>
      ref.read(importControllerProvider.notifier).pickAndPreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final AppFormat fmt = context.fmt;
    final ImportState s = ref.watch(importControllerProvider);
    final bool busy = s.phase == ImportPhase.applying || s.phase == ImportPhase.loading;

    final Widget body;
    Widget? bottom;
    switch (s.phase) {
      case ImportPhase.idle:
        body = ReviewNotice(
          icon: Icons.upload_file_outlined,
          message: l10n.backupReviewEmpty,
          actions: <Widget>[
            FilledButton(
              key: const Key('review-pick'),
              onPressed: () => _pickOther(ref),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
              child: Text(l10n.backupPickFile),
            ),
          ],
        );
      case ImportPhase.loading:
        body = Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(l10n.backupLoading, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        );
      case ImportPhase.failed:
        body = ReviewNotice(
          icon: Icons.error_outline,
          error: true,
          title: l10n.backupFailedTitle,
          message: errorTextForCode(l10n, s.errorCode ?? 'unknown'),
          actions: <Widget>[
            FilledButton(
              key: const Key('review-pick-other'),
              onPressed: () => _pickOther(ref),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
              child: Text(l10n.backupPickOther),
            ),
          ],
        );
      case ImportPhase.applied:
        body = ReviewResult(
          state: s,
          onUndo: () => _undo(context, ref),
          onDone: () => _close(context),
        );
      case ImportPhase.ready:
      case ImportPhase.applying:
        final ChangeSummary summary = s.summary ?? const ChangeSummary();
        final int changes = summary.totalChanges;
        body = _ReadyBody(state: s, summary: summary);
        final bool applying = s.phase == ImportPhase.applying;
        bottom = ReviewActionBar(
          secondaryLabel: changes == 0 ? l10n.commonOk : l10n.commonCancel,
          onSecondary: applying ? null : () => _close(context),
          primaryLabel: applying ? l10n.backupApplying : applyLabel(l10n, fmt, changes),
          onPrimary: changes == 0 || applying ? null : () => _apply(context, ref),
          disabledReason: changes == 0 ? l10n.backupApplyDisabledNone : null,
          busy: applying,
        );
    }

    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: l10n.commonClose,
            icon: const Icon(Icons.close),
            onPressed: busy ? null : () => _close(context),
          ),
          title: Semantics(header: true, child: Text(l10n.shellTitleBackupReview)),
        ),
        body: SafeArea(top: false, bottom: bottom == null, child: body),
        bottomNavigationBar: bottom,
      ),
    );
  }
}

class _ReadyBody extends ConsumerWidget {
  const _ReadyBody({required this.state, required this.summary});

  final ImportState state;
  final ChangeSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final double g = WindowClass.of(context).gutter;
    final Snapshot? snapshot = state.snapshot;
    final int changes = summary.totalChanges;
    final center = ref.watch(centerTimeProvider);

    final Widget? error = state.errorCode == null
        ? null
        : ReviewError(text: errorTextForCode(l10n, state.errorCode!));
    final Widget? info = snapshot == null ? null : ReviewInfoCard(snapshot: snapshot, center: center);
    final Widget? older = state.older ? ReviewNote(icon: Icons.history_toggle_off, text: l10n.backupOlderBanner) : null;
    final Widget headline = ReviewHeadline(changes: changes);
    final bool hasDeletions = summary.entities.values.any((EntityChange c) => c.deleted > 0);
    final Widget? deletions =
        hasDeletions ? DeletionsCard(summary: summary, names: state.names) : null;
    final Widget? clashes = state.clashes.isEmpty
        ? null
        : ClashesCard(clashes: state.clashes, nameOf: state.batchName);
    final Widget? samples =
        SamplesCard.hasAny(summary) ? SamplesCard(summary: summary, names: state.names) : null;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final bool wide = c.maxWidth >= WindowClass.expandedMin && c.hasBoundedHeight;
        if (!wide) {
          final List<Widget> items = <Widget>[
            ?error,
            ?info,
            ?older,
            headline,
            ?deletions,
            ?clashes,
            ChangeTable(summary: summary),
            ?samples,
            const ExplainCard(),
          ];
          return ListView(
            padding: EdgeInsets.fromLTRB(g, 8, g, g),
            children: <Widget>[
              for (int i = 0; i < items.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(height: 12),
                items[i],
              ],
            ],
          );
        }
        return Padding(
          padding: EdgeInsets.fromLTRB(g, 8, g, g),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                flex: 5,
                child: _FillColumn(
                  children: <Widget>[?error, ?info, ?older, headline],
                  last: ChangeTable(summary: summary, fill: true),
                ),
              ),
              SizedBox(width: g),
              Expanded(
                flex: 6,
                child: _FillColumn(
                  children: <Widget>[?deletions, ?clashes, ?samples],
                  last: const ExplainCard(fill: true),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A scrollable column whose last card stretches to fill the pane's height,
/// so a short column never leaves a blank area.
class _FillColumn extends StatelessWidget {
  const _FillColumn({required this.children, required this.last});

  final List<Widget> children;
  final Widget last;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (final Widget w in children) ...<Widget>[w, const SizedBox(height: 12)],
                  Expanded(child: last),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// An error line above the review (an apply that failed).
class ReviewError extends StatelessWidget {
  const ReviewError({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        key: const Key('review-error'),
        decoration: BoxDecoration(
          color: tokens.errorContainer,
          borderRadius: BorderRadius.circular(AuroraMetrics.radiusDenseList),
          border: Border.all(color: tokens.errorContainerBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              Icon(Icons.error_outline, color: tokens.onErrorContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: tokens.onErrorContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
