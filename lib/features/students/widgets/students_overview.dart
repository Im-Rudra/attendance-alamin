// Detail pane when no student is selected (UX 3b rule 4): roster stats, the
// five biggest dues, students per batch and the newest students. On a wide
// pane the cards sit in two columns so the pane never has a blank half.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/pane_split.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/features/students/controllers/student_nav.dart';
import 'package:attendance_alamin/features/students/controllers/student_providers.dart';

class StudentsOverview extends ConsumerWidget {
  const StudentsOverview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tokens = context.aurora;
    final fmt = context.fmt;
    final TextTheme tt = Theme.of(context).textTheme;
    final double gutter = WindowClass.of(context).gutter;
    final LocalDate today = ref.watch(todayProvider);
    final List<StudentRow>? rows = ref.watch(stuRowsProvider).value;

    int active = 0, fresh = 0, left = 0;
    final List<StudentRow> owing = <StudentRow>[];
    final List<StudentRow> activeRows = <StudentRow>[];
    final Map<String, int> perBatch = <String, int>{};
    final Map<String, String> batchNames = <String, String>{};
    for (final StudentRow r in rows ?? const <StudentRow>[]) {
      if (r.student.status == StudentStatus.left) {
        left++;
      } else {
        active++;
        activeRows.add(r);
        if (r.student.admissionDate.yearMonth == today.yearMonth) fresh++;
        if (r.dues != null && r.dues!.totalOutstanding > 0) owing.add(r);
        for (final Batch b in r.batches) {
          perBatch[b.id] = (perBatch[b.id] ?? 0) + 1;
          batchNames[b.id] = b.name;
        }
      }
    }
    owing.sort((StudentRow a, StudentRow b) =>
        b.dues!.totalOutstanding.compareTo(a.dues!.totalOutstanding));
    final List<StudentRow> top = owing.take(5).toList();

    // Students per batch and the newest students balance the pane (QA-09).
    final List<String> batchIds = perBatch.keys.toList()
      ..sort((String a, String b) {
        final int c = perBatch[b]!.compareTo(perBatch[a]!);
        return c != 0 ? c : batchNames[a]!.compareTo(batchNames[b]!);
      });
    activeRows.sort((StudentRow a, StudentRow b) =>
        b.student.admissionDate.compareTo(a.student.admissionDate));
    final List<StudentRow> recent = activeRows.take(5).toList();

    Widget nameRow(StudentRow r, Widget trailing) => InkWell(
          onTap: () => stuGo(context, Routes.student(r.id)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(r.student.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.titleMedium),
                  ),
                  const SizedBox(width: 8),
                  trailing,
                ],
              ),
            ),
          ),
        );

    final Widget topDues = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeader(title: l10n.stuTopDues),
        GlassCard(
          dense: true,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: top.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l10n.stuNoOneOwes,
                      style: tt.bodyLarge?.copyWith(color: tokens.textSecondary)),
                )
              : Column(
                  children: <Widget>[
                    for (final StudentRow r in top)
                      nameRow(
                        r,
                        MoneyText(fmt.money(r.dues!.totalOutstanding), style: tt.titleSmall),
                      ),
                  ],
                ),
        ),
      ],
    );

    final Widget byBatch = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeader(title: l10n.stuOverviewByBatch),
        BarListCard(
          entries: <BarEntry>[
            for (final String id in batchIds.take(6))
              BarEntry(
                label: batchNames[id]!,
                value: perBatch[id]!,
                valueText: fmt.number(perBatch[id]!),
                onTap: () => stuGo(context, Routes.batch(id)),
              ),
          ],
          emptyText: l10n.stuNoOneOwes,
        ),
      ],
    );

    final Widget recentCard = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeader(title: l10n.stuOverviewRecent),
        GlassCard(
          dense: true,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: <Widget>[
              for (final StudentRow r in recent)
                nameRow(
                  r,
                  Text(
                    fmt.dateShort(r.student.admissionDate),
                    style: tt.labelMedium?.copyWith(color: tokens.textSecondary),
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    final Widget stats = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: StatTile(label: l10n.stuStatActive, value: fmt.number(active))),
        const SizedBox(width: 12),
        Expanded(child: StatTile(label: l10n.stuStatNew, value: fmt.number(fresh))),
        const SizedBox(width: 12),
        Expanded(child: StatTile(label: l10n.stuStatLeft, value: fmt.number(left))),
      ],
    );

    final Widget rightColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        byBatch,
        if (recent.isNotEmpty) ...<Widget>[const SizedBox(height: 12), recentCard],
      ],
    );

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !PaneScope.isEmbedded(context),
        title: Semantics(header: true, child: Text(l10n.shellTitleOverview)),
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints c) {
          final bool twoCol = c.maxWidth >= 600;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(gutter, 4, gutter, gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                stats,
                const SizedBox(height: 12),
                if (twoCol)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(child: topDues),
                      const SizedBox(width: 12),
                      Expanded(child: rightColumn),
                    ],
                  )
                else ...<Widget>[
                  topDues,
                  const SizedBox(height: 12),
                  rightColumn,
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
