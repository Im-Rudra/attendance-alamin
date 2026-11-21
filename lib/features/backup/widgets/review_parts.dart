// Building blocks of the import review screen (UX 2f, Product 4 "Change
// summary screen"): backup info, headline, the Added/Updated/Deleted table,
// deletions (red, first), samples, explanations and the bottom action bar.

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/core/time/center_time.dart';
import 'package:attendance_alamin/domain/sync/sync_models.dart';
import 'package:attendance_alamin/features/backup/controllers/backup_state.dart';
import 'package:attendance_alamin/features/backup/controllers/backup_text.dart';
import 'package:attendance_alamin/features/backup/controllers/merge_clashes.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

/// Entities in display order; deletions are listed in this order too.
const List<SummaryEntity> kReviewEntities = SummaryEntity.values;

/// Records of this device that are newer than the backup and are kept.
int keptTotal(ChangeSummary s) {
  int n = 0;
  for (final EntityChange e in s.entities.values) {
    n += e.keptLocal;
  }
  return n;
}

/// A hairline between table rows.
class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) => Container(height: 1, color: context.bhor.colors.line);
}

/// A red card: an icon and title, lines, an optional footer. [boxKey] sits on
/// the coloured box itself.
class ReviewDangerCard extends StatelessWidget {
  const ReviewDangerCard({
    super.key,
    this.boxKey,
    required this.title,
    required this.lines,
    this.footer,
    this.footerStyle,
    this.icon = BhorIcons.warning,
  });

  final Key? boxKey;
  final String title;
  final List<String> lines;
  final String? footer;
  final TextStyle? footerStyle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final Color on = b.colors.warn;
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        key: boxKey,
        decoration: BoxDecoration(
          color: b.colors.warnBg,
          borderRadius: BorderRadius.circular(BhorRadius.card),
        ),
        child: Padding(
          padding: const EdgeInsets.all(BhorSpace.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(icon, color: on),
                  const SizedBox(width: BhorSpace.s8),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(title, style: b.type.heading.copyWith(color: on)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: BhorSpace.s8),
              for (final String line in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: BhorSpace.s4),
                  child: Text(line, style: b.type.body.copyWith(color: on)),
                ),
              if (footer != null) ...<Widget>[
                const SizedBox(height: BhorSpace.s4),
                Text(footer!, style: footerStyle ?? b.type.meta.copyWith(color: on)),
              ],
            ],
          ),
        ),
      ),
    );
  }
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
    final BhorThemeData b = context.bhor;
    final String device =
        snapshot.deviceName.trim().isEmpty ? l10n.backupReviewUnknownDevice : snapshot.deviceName.trim();
    int count(String table) => snapshot.counts[table] ?? 0;
    final TextStyle line = b.type.body;
    return BhorCard(
      key: const Key('review-info'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(BhorIcons.archive, color: b.colors.accent),
              const SizedBox(width: BhorSpace.s12),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(l10n.backupReviewInfoTitle, style: b.type.heading),
                ),
              ),
            ],
          ),
          const SizedBox(height: BhorSpace.s8),
          Text(l10n.backupReviewCreated(backupWhenText(l10n, fmt, center, snapshot.createdAtMs)), style: line),
          const SizedBox(height: 2),
          Text(l10n.backupReviewDevice(device), style: line),
          const SizedBox(height: 2),
          Text(
            l10n.backupReviewVersion(snapshot.appVersion.isEmpty ? '-' : snapshot.appVersion),
            style: b.type.meta,
          ),
          const SizedBox(height: BhorSpace.s8),
          Text(
            l10n.backupReviewTotals(
              fmt.number(count('subjects')),
              fmt.number(count('batches')),
              fmt.number(count('students')),
              fmt.number(count('payments')),
            ),
            key: const Key('review-totals'),
            style: b.type.meta,
          ),
        ],
      ),
    );
  }
}

/// A neutral (accent-tinted) note card with an icon.
class ReviewNote extends StatelessWidget {
  const ReviewNote({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    return Semantics(
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: b.colors.accentTint,
          borderRadius: BorderRadius.circular(BhorRadius.card),
        ),
        child: Padding(
          padding: const EdgeInsets.all(BhorSpace.s12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, color: b.colors.accent),
              const SizedBox(width: BhorSpace.s12),
              Expanded(child: Text(text, style: b.type.body)),
            ],
          ),
        ),
      ),
    );
  }
}

/// "এই ব্যাকআপে N টি পরিবর্তন আছে" (24 sp), or the nothing-to-do sentence.
/// With no changes but [kept] newer local records (QA-08) it says that
/// nothing will change and those records are kept, never "the same".
class ReviewHeadline extends StatelessWidget {
  const ReviewHeadline({super.key, required this.changes, this.kept = 0});

  final int changes;

  /// Records of this device that are newer than the backup (kept as they are).
  final int kept;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final String text = changes > 0
        ? l10n.backupHeadline(context.fmt.number(changes))
        : kept > 0
            ? l10n.backupHeadlineKeptOnly(context.fmt.number(kept))
            : l10n.backupHeadlineNone;
    return Semantics(
      header: true,
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: BhorSpace.s4),
        child: Text(
          text,
          key: const Key('review-headline'),
          style: context.bhor.type.display,
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
    final BhorThemeData b = context.bhor;

    Widget head(String text, {Color? color}) => SizedBox(
          width: _colWidth,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(text, style: b.type.label.copyWith(color: color ?? b.colors.text2)),
          ),
        );
    Widget cell(int n, {Color? color}) => SizedBox(
          width: _colWidth,
          child: Text(
            fmt.number(n),
            textAlign: TextAlign.center,
            style: BhorType.tabular(
              b.type.heading.copyWith(
                color: n == 0 ? b.colors.text3 : (color ?? b.colors.text),
                fontWeight: n == 0 ? FontWeight.w400 : FontWeight.w600,
              ),
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
            padding: const EdgeInsets.symmetric(vertical: BhorSpace.s4),
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
                        style: b.type.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (c.keptLocal > 0)
                        Text(l10n.backupKeptShort(fmt.number(c.keptLocal)), style: b.type.caption),
                    ],
                  ),
                ),
                cell(c.added),
                cell(c.updated),
                cell(c.deleted, color: b.colors.danger),
              ],
            ),
          ),
        ),
      );
    }

    final int kept = keptTotal(summary);
    final Widget table = Column(
      mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Spacer(),
            head(l10n.backupColAdded),
            head(l10n.backupColUpdated),
            head(l10n.backupColDeleted, color: b.colors.danger),
          ],
        ),
        const SizedBox(height: BhorSpace.s4),
        const _Hairline(),
        for (int i = 0; i < rows.length; i++) ...<Widget>[
          if (i > 0) const _Hairline(),
          rows[i],
        ],
        if (fill) const Spacer(),
        if (kept > 0) ...<Widget>[
          const SizedBox(height: BhorSpace.s8),
          Text(l10n.backupKeptTotal(fmt.number(kept)), key: const Key('review-kept'), style: b.type.meta),
        ],
      ],
    );
    return BhorCard(key: const Key('review-table'), child: table);
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

    return ReviewDangerCard(
      boxKey: const Key('review-deletions'),
      title: l10n.backupDeletionsTitle(fmt.number(total)),
      lines: lines,
      footer: l10n.backupDeletionsNote,
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
    final int more = clashes.length > _maxLines ? clashes.length - _maxLines : 0;
    return KeyedSubtree(
      key: const Key('review-clashes'),
      child: ReviewDangerCard(
        title: l10n.uiConflictTitle,
        lines: lines,
        footer: more > 0 ? l10n.uiConflictMore(fmt.number(more)) : null,
      ),
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
    final BhorThemeData b = context.bhor;

    Widget bucket(String label, List<RowMap> samples, int count) {
      final int more = count - samples.length;
      return Padding(
        padding: const EdgeInsets.only(top: BhorSpace.s4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 64,
              child: Text(label, style: b.type.label.copyWith(color: b.colors.accent)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (final RowMap s in samples) Text(sampleText(l10n, fmt, names, s), style: b.type.body),
                  if (more > 0) Text(l10n.backupMore(fmt.number(more)), style: b.type.meta),
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
          padding: const EdgeInsets.only(top: BhorSpace.s8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(entityLabel(l10n, e), style: b.type.bodyStrong),
              if (c.added > 0) bucket(l10n.backupColAdded, c.addedSamples, c.added),
              if (c.updated > 0) bucket(l10n.backupColUpdated, c.updatedSamples, c.updated),
            ],
          ),
        ),
      );
    }
    if (blocks.isEmpty) return const SizedBox.shrink();
    return BhorCard(
      key: const Key('review-samples'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(l10n.backupSamplesTitle, style: b.type.heading),
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
    final BhorThemeData b = context.bhor;
    final List<(IconData, String)> items = <(IconData, String)>[
      (BhorIcons.check, l10n.backupExplainNothing),
      (BhorIcons.clock, l10n.backupExplainSafety),
      (BhorIcons.refresh, l10n.backupExplainNewer),
      (BhorIcons.info, l10n.backupExplainAbsent),
    ];
    return BhorCard(
      key: const Key('review-explain'),
      child: Column(
        mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(l10n.backupExplainTitle, style: b.type.heading),
          ),
          const SizedBox(height: BhorSpace.s8),
          for (final (IconData, String) item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(item.$1, size: 20, color: b.colors.accent),
                  const SizedBox(width: BhorSpace.s12),
                  Expanded(child: Text(item.$2, style: b.type.body)),
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
    final BhorThemeData b = context.bhor;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(BhorSpace.s16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: BhorCard(
            padding: const EdgeInsets.all(BhorSpace.s24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                ExcludeSemantics(
                  child: Icon(icon, size: 56, color: error ? b.colors.danger : b.colors.accent),
                ),
                const SizedBox(height: BhorSpace.s12),
                if (title != null) ...<Widget>[
                  Semantics(
                    header: true,
                    liveRegion: true,
                    child: Text(title!, textAlign: TextAlign.center, style: b.type.title),
                  ),
                  const SizedBox(height: BhorSpace.s8),
                ],
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: b.type.body.copyWith(color: b.colors.text2),
                ),
                for (final Widget a in actions) ...<Widget>[const SizedBox(height: BhorSpace.s12), a],
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
    final BhorThemeData b = context.bhor;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: b.colors.surface,
        border: Border(top: BorderSide(color: b.colors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(BhorSpace.s16, BhorSpace.s12, BhorSpace.s16, BhorSpace.s12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      BhorButton(
                        key: const Key('review-secondary'),
                        variant: BhorButtonVariant.ghost,
                        label: secondaryLabel,
                        onPressed: onSecondary,
                      ),
                      const SizedBox(width: BhorSpace.s8),
                      Expanded(
                        child: BhorButton(
                          key: const Key('review-apply'),
                          label: primaryLabel,
                          loading: busy,
                          expand: true,
                          onPressed: onPrimary,
                        ),
                      ),
                    ],
                  ),
                  if (onPrimary == null && !busy && disabledReason != null) ...<Widget>[
                    const SizedBox(height: BhorSpace.s8),
                    Text(
                      disabledReason!,
                      key: const Key('review-disabled-reason'),
                      textAlign: TextAlign.center,
                      style: b.type.meta,
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
    return ReviewNotice(
      icon: BhorIcons.checkCircle,
      title: l10n.backupDoneTitle(fmt.number(state.changes)),
      message: l10n.backupDoneSafety,
      actions: <Widget>[
        if (state.overfilled > 0)
          ReviewNote(
            icon: BhorIcons.info,
            text: l10n.backupOverfilled(fmt.number(state.overfilled)),
          ),
        BhorButton(
          key: const Key('review-undo'),
          variant: BhorButtonVariant.secondary,
          icon: BhorIcons.undo,
          label: l10n.backupUndo,
          expand: true,
          onPressed: busy ? null : onUndo,
        ),
        BhorButton(
          key: const Key('review-done'),
          label: l10n.commonOk,
          expand: true,
          onPressed: busy ? null : onDone,
        ),
      ],
    );
  }
}

/// The apply-button label for [changes] (the count is part of the label).
String applyLabel(AppLocalizations l10n, AppFormat fmt, int changes) =>
    changes == 0 ? l10n.backupApply : l10n.backupApplyN(fmt.number(changes));
