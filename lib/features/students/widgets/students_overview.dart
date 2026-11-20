// Detail pane when no student is selected (UX 3b rule 4): roster stats and the
// five biggest dues, never a blank pane.

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
    for (final StudentRow r in rows ?? const <StudentRow>[]) {
      if (r.student.status == StudentStatus.left) {
        left++;
      } else {
        active++;
        if (r.student.admissionDate.yearMonth == today.yearMonth) fresh++;
        if (r.dues != null && r.dues!.totalOutstanding > 0) owing.add(r);
      }
    }
    owing.sort((StudentRow a, StudentRow b) =>
        b.dues!.totalOutstanding.compareTo(a.dues!.totalOutstanding));
    final List<StudentRow> top = owing.take(5).toList();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !PaneScope.isEmbedded(context),
        title: Semantics(header: true, child: Text(l10n.shellTitleOverview)),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(gutter, 4, gutter, gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: StatTile(
                      label: l10n.stuStatActive, value: fmt.number(active)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatTile(
                      label: l10n.stuStatNew, value: fmt.number(fresh)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatTile(
                      label: l10n.stuStatLeft, value: fmt.number(left)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SectionHeader(title: l10n.stuTopDues),
            GlassCard(
              dense: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: top.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(l10n.stuNoOneOwes,
                          style: tt.bodyLarge
                              ?.copyWith(color: tokens.textSecondary)),
                    )
                  : Column(
                      children: <Widget>[
                        for (final StudentRow r in top)
                          InkWell(
                            onTap: () => stuGo(context, Routes.student(r.id)),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 48),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                child: Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(r.student.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: tt.titleMedium),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(fmt.money(r.dues!.totalOutstanding),
                                        style: tt.titleSmall),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
