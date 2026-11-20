// Building blocks of the import review screen (UX 2f, Product 4 "Change
// summary screen"): backup info, headline, the Added/Updated/Deleted table,
// deletions (red, first), samples, explanations and the bottom action bar.

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/core/time/center_time.dart';
import 'package:attendance_alamin/domain/sync/sync_models.dart';
import 'package:attendance_alamin/features/backup/controllers/backup_state.dart';
import 'package:attendance_alamin/features/backup/controllers/backup_text.dart';
import 'package:attendance_alamin/features/backup/controllers/merge_clashes.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

/// Entities in display order; deletions are listed in this order too.
const List<SummaryEntity> kReviewEntities = SummaryEntity.values;

int _keptTotal(ChangeSummary s) {
  int n = 0;
  for (final EntityChange e in s.entities.values) {
    n += e.keptLocal;
  }
  return n;
}

/// Backup info: when, which device, which app version, how much is inside.
class ReviewInfoCard extends StatelessWidget {
  const ReviewInfoCard({super.key, required this.snapshot, required this.center});

  final Snapshot snapshot;
  final CenterTime center;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final AppFormat fmt = context.fmt;
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final String device =
        snapshot.deviceName.trim().isEmpty ? l10n.backupReviewUnknownDevice : snapshot.deviceName.trim();
    int count(String table) => snapshot.counts[table] ?? 0;
    final TextStyle? line = tt.bodyLarge?.copyWith(color: tokens.textPrimary);
    return GlassCard(
      key: const Key('review-info'),
      dense: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.inventory_2_outlined, color: tokens.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(l10n.backupReviewInfoTitle, style: tt.titleMedium?.copyWith(color: tokens.textPrimary)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(l10n.backupReviewCreated(backupWhenText(l10n, fmt, center, snapshot.createdAtMs)), style: line),
          const SizedBox(height: 2),
          Text(l10n.backupReviewDevice(device), style: line),
          const SizedBox(height: 2),
          Text(
            l10n.backupReviewVersion(snapshot.appVersion.isEmpty ? '-' : snapshot.appVersion),
            style: tt.bodyMedium?.copyWith(color: tokens.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.backupReviewTotals(
              fmt.number(count('subjects')),
              fmt.number(count('batches')),
              fmt.number(count('students')),
              fmt.number(count('payments')),
            ),
            key: const Key('review-totals'),
            style: tt.bodyMedium?.copyWith(color: tokens.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// A neutral (info-coloured) note card with an icon.
class ReviewNote extends StatelessWidget {
  const ReviewNote({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    return Semantics(
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.infoContainer,
          borderRadius: BorderRadius.circular(AuroraMetrics.radiusDenseList),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, color: tokens.info),
              const SizedBox(width: 12),
              Expanded(
                child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: tokens.textPrimary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "এই ব্যাকআপে N টি পরিবর্তন আছে" (24 sp), or the nothing-to-do sentence.
class ReviewHeadline extends StatelessWidget {
  const ReviewHeadline({super.key, required this.changes});

  final int changes;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.aurora;
    final String text =
        changes == 0 ? l10n.backupHeadlineNone : l10n.backupHeadline(context.fmt.number(changes));
    return Semantics(
      header: true,
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          text,
          key: const Key('review-headline'),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: tokens.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

/// One row per entity: new / changed / removed counts, and what is kept.
class ChangeTable extends StatelessWidget {
  const ChangeTable({super.key, required this.summary, this.fill = false});

  final ChangeSummary summary;

  /// Stretch to the pane's height (desktop column).
  final bool fill;

  static const double _colWidth = 60;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final AppFormat fmt = context.fmt;
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;

    Widget head(String text, {Color? color}) => SizedBox(
          width: _colWidth,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(text, style: tt.labelMedium?.copyWith(color: color ?? tokens.textSecondary)),
          ),
        );
    Widget cell(int n, {Color? color}) => SizedBox(
          width: _colWidth,
          child: Text(
            fmt.number(n),
            textAlign: TextAlign.center,
            style: tt.titleMedium?.copyWith(
              color: n == 0 ? tokens.textDisabled : (color ?? tokens.textPrimary),
              fontWeight: n == 0 ? FontWeight.w400 : FontWeight.w600,
            ),
          ),
        );

    final List<Widget> rows = <Widget>[];
    for (final SummaryEntity e in kReviewEntities) {
      final EntityChange c = summary.entities[e] ?? const EntityChange();
      rows.add(
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              key: Key('review-row-${e.name}'),
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        entityLabel(l10n, e),
                        style: tt.bodyLarge?.copyWith(color: tokens.textPrimary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (c.keptLocal > 0)
                        Text(
                          l10n.backupKeptShort(fmt.number(c.keptLocal)),
                          style: tt.labelSmall?.copyWith(color: tokens.textSecondary),
                        ),
                    ],
                  ),
                ),
                cell(c.added),
                cell(c.updated),
                cell(c.deleted, color: tokens.error),
              ],
            ),
          ),
        ),
      );
    }

    final int kept = _keptTotal(summary);
    final Widget table = Column(
      mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Spacer(),
            head(l10n.backupColAdded),
            head(l10n.backupColUpdated),
            head(l10n.backupColDeleted, color: tokens.error),
          ],
        ),
        Divider(height: 8, color: tokens.track),
        for (int i = 0; i < rows.length; i++) ...<Widget>[
          if (i > 0) Divider(height: 1, color: tokens.track),
          rows[i],
        ],
        if (fill) const Spacer(),
        if (kept > 0) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            l10n.backupKeptTotal(fmt.number(kept)),
            key: const Key('review-kept'),
            style: tt.bodyMedium?.copyWith(color: tokens.textSecondary),
          ),
        ],
      ],
    );
    return GlassCard(key: const Key('review-table'), dense: true, child: table);
  }
}

/// Deletions listed by name, in red, always first.
class DeletionsCard extends StatelessWidget {
  const DeletionsCard({super.key, required this.summary, required this.names});

  final ChangeSummary summary;
  final SnapshotNames names;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final AppFormat fmt = context.fmt;
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final Color on = tokens.onErrorContainer;

    final List<String> lines = <String>[];
    int total = 0;
    for (final SummaryEntity e in kReviewEntities) {
      final EntityChange? c = summary.entities[e];
      if (c == null || c.deleted == 0) continue;
      total += c.deleted;
      final String label = entityLabel(l10n, e);
      for (final RowMap sample in c.deletedSamples) {
        lines.add(l10n.backupDeletionLine(label, sampleText(l10n, fmt, names, sample)));
      }
      final int more = c.deleted - c.deletedSamples.length;
      if (more > 0) lines.add(l10n.backupDeletionLine(label, l10n.backupMore(fmt.number(more))));
    }
    if (total == 0) return const SizedBox.shrink();

    return Semantics(
      container: true,
      child: DecoratedBox(
        key: const Key('review-deletions'),
        decoration: BoxDecoration(
          color: tokens.errorContainer,
          borderRadius: BorderRadius.circular(AuroraMetrics.radiusDenseList),
          border: Border.all(color: tokens.errorContainerBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.warning_amber_rounded, color: on),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        l10n.backupDeletionsTitle(fmt.number(total)),
                        style: tt.titleMedium?.copyWith(color: on),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final String line in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(line, style: tt.bodyLarge?.copyWith(color: on)),
                ),
              const SizedBox(height: 4),
              Text(l10n.backupDeletionsNote, style: tt.bodySmall?.copyWith(color: on)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Time clashes the merge would create, in red (after the deletions).
class ClashesCard extends StatelessWidget {
  const ClashesCard({super.key, required this.clashes, required this.nameOf});

  final List<MergeClash> clashes;
  final String? Function(String batchId) nameOf;

  static const int _maxLines = 5;

  @override
  Widget build(BuildContext context) {
    if (clashes.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final AppFormat fmt = context.fmt;
    String name(String id) => nameOf(id) ?? l10n.backupSampleUnnamed;
    final List<String> lines = <String>[
      for (final MergeClash c in clashes.take(_maxLines))
        l10n.backupClashLine(
          fmt.weekdayName(c.weekday),
          fmt.timeRange(c.startMin, c.endMin),
          name(c.batchAId),
          name(c.batchBId),
        ),
    ];
    return KeyedSubtree(
      key: const Key('review-clashes'),
      child: ConflictCard(lines: lines, moreCount: clashes.length > _maxLines ? clashes.length - _maxLines : 0),
    );
  }
}

/// Up to 3 samples per non-empty bucket (new, changed), with "+N আরও".
class SamplesCard extends StatelessWidget {
  const SamplesCard({super.key, required this.summary, required this.names});

  final ChangeSummary summary;
  final SnapshotNames names;

  static bool hasAny(ChangeSummary s) =>
      s.entities.values.any((EntityChange c) => c.added > 0 || c.updated > 0);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final AppFormat fmt = context.fmt;
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;

    Widget bucket(String label, List<RowMap> samples, int count) {
      final int more = count - samples.length;
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 64,
              child: Text(label, style: tt.labelMedium?.copyWith(color: tokens.accent)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (final RowMap s in samples)
                    Text(sampleText(l10n, fmt, names, s), style: tt.bodyMedium?.copyWith(color: tokens.textPrimary)),
                  if (more > 0)
                    Text(l10n.backupMore(fmt.number(more)), style: tt.bodySmall?.copyWith(color: tokens.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final List<Widget> blocks = <Widget>[];
    for (final SummaryEntity e in kReviewEntities) {
      final EntityChange? c = summary.entities[e];
      if (c == null || (c.added == 0 && c.updated == 0)) continue;
      blocks.add(
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(entityLabel(l10n, e), style: tt.titleSmall?.copyWith(color: tokens.textPrimary)),
              if (c.added > 0) bucket(l10n.backupColAdded, c.addedSamples, c.added),
              if (c.updated > 0) bucket(l10n.backupColUpdated, c.updatedSamples, c.updated),
            ],
          ),
        ),
      );
    }
    if (blocks.isEmpty) return const SizedBox.shrink();
    return GlassCard(
      key: const Key('review-samples'),
      dense: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(l10n.backupSamplesTitle, style: tt.titleMedium?.copyWith(color: tokens.textPrimary)),
          ),
          ...blocks,
        ],
      ),
    );
  }
}

/// What applying does, in four plain sentences.
class ExplainCard extends StatelessWidget {
  const ExplainCard({super.key, this.fill = false});

  final bool fill;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final List<(IconData, String)> items = <(IconData, String)>[
      (Icons.touch_app_outlined, l10n.backupExplainNothing),
      (Icons.history, l10n.backupExplainSafety),
      (Icons.update, l10n.backupExplainNewer),
      (Icons.shield_outlined, l10n.backupExplainAbsent),
    ];
    return GlassCard(
      key: const Key('review-explain'),
      dense: true,
      child: Column(
        mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(l10n.backupExplainTitle, style: tt.titleMedium?.copyWith(color: tokens.textPrimary)),
          ),
          const SizedBox(height: 8),
          for (final (IconData, String) item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(item.$1, size: 20, color: tokens.accent),
                  const SizedBox(width: 12),
                  Expanded(child: Text(item.$2, style: tt.bodyMedium?.copyWith(color: tokens.textPrimary))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A centred card with an icon, an optional title, a message and buttons.
class ReviewNotice extends StatelessWidget {
  const ReviewNotice({
    super.key,
    required this.icon,
    required this.message,
    this.title,
    this.error = false,
    this.actions = const <Widget>[],
  });

  final IconData icon;
  final String? title;
  final String message;
  final bool error;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                ExcludeSemantics(
                  child: Icon(icon, size: 56, color: error ? tokens.error : tokens.accent),
                ),
                const SizedBox(height: 12),
                if (title != null) ...<Widget>[
                  Semantics(
                    header: true,
                    liveRegion: true,
                    child: Text(
                      title!,
                      textAlign: TextAlign.center,
                      style: tt.headlineSmall?.copyWith(color: tokens.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: tt.bodyLarge?.copyWith(color: tokens.textSecondary),
                ),
                for (final Widget a in actions) ...<Widget>[const SizedBox(height: 12), a],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom bar: cancel (or OK) on the start side, the apply button beside it
/// with the reason when it is disabled.
class ReviewActionBar extends StatelessWidget {
  const ReviewActionBar({
    super.key,
    required this.secondaryLabel,
    required this.onSecondary,
    required this.primaryLabel,
    required this.onPrimary,
    this.disabledReason,
    this.busy = false,
  });

  final String secondaryLabel;
  final VoidCallback? onSecondary;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String? disabledReason;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surfaceDense,
        border: Border(top: BorderSide(color: tokens.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      TextButton(
                        key: const Key('review-secondary'),
                        onPressed: onSecondary,
                        style: TextButton.styleFrom(minimumSize: const Size(72, 56)),
                        child: Text(secondaryLabel),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          key: const Key('review-apply'),
                          onPressed: onPrimary,
                          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                          child: busy
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                    const SizedBox(width: 12),
                                    Flexible(child: Text(primaryLabel)),
                                  ],
                                )
                              : Text(primaryLabel, textAlign: TextAlign.center),
                        ),
                      ),
                    ],
                  ),
                  if (onPrimary == null && !busy && disabledReason != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      disabledReason!,
                      key: const Key('review-disabled-reason'),
                      textAlign: TextAlign.center,
                      style: tt.labelMedium?.copyWith(color: tokens.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "{n}টি পরিবর্তন প্রয়োগ হয়েছে" with the way back.
class ReviewResult extends StatelessWidget {
  const ReviewResult({
    super.key,
    required this.state,
    required this.onUndo,
    required this.onDone,
    this.busy = false,
  });

  final ImportState state;
  final VoidCallback? onUndo;
  final VoidCallback onDone;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final AppFormat fmt = context.fmt;
    final tokens = context.aurora;
    return ReviewNotice(
      icon: Icons.check_circle_outline,
      title: l10n.backupDoneTitle(fmt.number(state.changes)),
      message: l10n.backupDoneSafety,
      actions: <Widget>[
        if (state.overfilled > 0)
          ReviewNote(
            icon: Icons.info_outline,
            text: l10n.backupOverfilled(fmt.number(state.overfilled)),
          ),
        OutlinedButton.icon(
          key: const Key('review-undo'),
          onPressed: busy ? null : onUndo,
          icon: const Icon(Icons.undo),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            foregroundColor: tokens.textPrimary,
          ),
          label: Text(l10n.backupUndo),
        ),
        FilledButton(
          key: const Key('review-done'),
          onPressed: busy ? null : onDone,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          child: Text(l10n.commonOk),
        ),
      ],
    );
  }
}

/// The apply-button label for [changes] (the count is part of the label).
String applyLabel(AppLocalizations l10n, AppFormat fmt, int changes) =>
    changes == 0 ? l10n.backupApply : l10n.backupApplyN(fmt.number(changes));
