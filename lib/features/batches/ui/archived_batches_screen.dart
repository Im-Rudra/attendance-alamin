// More › সংরক্ষণাগার: archived batches with a one-tap unarchive (scenario 21).

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/async_combine.dart';
import 'package:attendance_alamin/app/providers/schedule_providers.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/enrollment.dart';
import 'package:attendance_alamin/domain/models/subject.dart';
import 'package:attendance_alamin/features/batches/batches_entry.dart';
import 'package:attendance_alamin/features/batches/controllers/batch_providers.dart';
import 'package:attendance_alamin/features/batches/widgets/batch_format.dart';

class _ArchivedRow {
  const _ArchivedRow(this.batch, this.subjectName, this.students);

  final Batch batch;
  final String subjectName;
  final int students;
}

final _archivedRowsProvider = Provider<AsyncValue<List<_ArchivedRow>>>((ref) {
  return combine3(
    ref.watch(batchEveryBatchProvider),
    ref.watch(batchSubjectsProvider),
    ref.watch(allEnrollmentsProvider),
    (List<Batch> batches, List<Subject> subjects, List<Enrollment> enrollments) {
      final Map<String, String> names = <String, String>{for (final s in subjects) s.id: s.name};
      final List<_ArchivedRow> rows = <_ArchivedRow>[
        for (final Batch b in batches)
          if (b.archived)
            _ArchivedRow(
              b,
              names[b.subjectId] ?? '',
              enrollments.where((Enrollment e) => e.batchId == b.id && e.endDate == null).length,
            ),
      ];
      return rows;
    },
  );
});

class ArchivedBatchesScreen extends ConsumerWidget {
  const ArchivedBatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final double g = WindowClass.of(context).gutter;
    final Widget body = ref.watch(_archivedRowsProvider).when(
          loading: () => const Center(child: BhorSpinner()),
          error: (Object e, StackTrace s) => BhorEmptyState(
            icon: BhorIcons.warning,
            title: l10n.commonLoadingFailed,
            action: BhorButton(
              label: l10n.commonRetry,
              variant: BhorButtonVariant.secondary,
              onPressed: () => ref.invalidate(_archivedRowsProvider),
            ),
          ),
          data: (List<_ArchivedRow> rows) {
            if (rows.isEmpty) {
              return BhorCard(
                padding: EdgeInsets.zero,
                child: BhorEmptyState(icon: BhorIcons.archive, title: l10n.batchArchivedEmpty),
              );
            }
            return LayoutBuilder(
              builder: (BuildContext context, BoxConstraints c) {
                final int cols = c.maxWidth >= 720 ? 2 : 1;
                const double gap = 12;
                final double w = (c.maxWidth - gap * (cols - 1)) / cols;
                return SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 120),
                  child: Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: <Widget>[
                      for (final _ArchivedRow r in rows) SizedBox(width: w, child: _ArchivedCard(row: r)),
                    ],
                  ),
                );
              },
            );
          },
        );
    return BhorScaffold(
      header: BhorHeader(title: l10n.shellTitleArchived),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Padding(padding: EdgeInsets.fromLTRB(g, BhorSpace.s4, g, g), child: body),
        ),
      ),
    );
  }
}

class _ArchivedCard extends StatelessWidget {
  const _ArchivedCard({required this.row});

  final _ArchivedRow row;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData th = context.bhor;
    final l10n = context.l10n;
    final fmt = context.fmt;
    final Batch b = row.batch;
    return BhorCard(
      onTap: () => openPath(context, Routes.batch(b.id)),
      semanticLabel: b.name,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(b.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: th.type.heading),
          Text(
            row.subjectName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: th.type.body.copyWith(color: th.colors.text2),
          ),
          const SizedBox(height: BhorSpace.s8),
          Wrap(
            spacing: BhorSpace.s12,
            runSpacing: BhorSpace.s4,
            children: <Widget>[
              Text(l10n.batchStudentCount(fmt.number(row.students)), style: th.type.label),
              if (b.archivedOn != null)
                Text(
                  l10n.batchArchivedOn(fmt.date(b.archivedOn!)),
                  style: th.type.label.copyWith(color: th.colors.text2),
                ),
            ],
          ),
          const SizedBox(height: BhorSpace.s8),
          BhorButton(
            label: l10n.batchMenuUnarchive,
            icon: BhorIcons.archive,
            variant: BhorButtonVariant.secondary,
            onPressed: () => showUnarchiveBatchFlow(context, batchId: b.id),
          ),
        ],
      ),
    );
  }
}
