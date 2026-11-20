// "ছেড়ে যাওয়া শিক্ষার্থী" (More > Students who left): who left and when, what
// they still owe (grey), and a rejoin button.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/features/students/controllers/student_nav.dart';
import 'package:attendance_alamin/features/students/controllers/student_providers.dart';
import 'package:attendance_alamin/features/students/widgets/rejoin_flow.dart';
import 'package:attendance_alamin/features/students/widgets/student_avatar.dart';

class LeftStudentsScreen extends ConsumerWidget {
  const LeftStudentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tokens = context.aurora;
    final fmt = context.fmt;
    final TextTheme tt = Theme.of(context).textTheme;
    final double g = WindowClass.of(context).gutter;
    final AsyncValue<List<StudentRow>> async = ref.watch(stuRowsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Semantics(header: true, child: Text(l10n.shellTitleLeft)),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(g, 4, g, g),
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object e, StackTrace st) => EmptyState(
                icon: Icons.error_outline, message: l10n.commonLoadingFailed),
            data: (List<StudentRow> all) {
              final List<StudentRow> rows = <StudentRow>[
                for (final StudentRow r in all)
                  if (r.student.status == StudentStatus.left) r,
              ];
              if (rows.isEmpty) {
                return GlassCard(
                  dense: true,
                  padding: EdgeInsets.zero,
                  child: EmptyState(
                    icon: Icons.person_off_outlined,
                    message: l10n.stuLeftEmpty,
                  ),
                );
              }
              return GlassCard(
                dense: true,
                padding: EdgeInsets.zero,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: rows.length,
                  separatorBuilder: (BuildContext c, int i) =>
                      Divider(height: 1, thickness: 1, color: tokens.track),
                  itemBuilder: (BuildContext c, int i) {
                    final StudentRow r = rows[i];
                    final Student s = r.student;
                    final int owed = r.dues?.totalOutstanding ?? 0;
                    return InkWell(
                      onTap: () => stuGo(context, Routes.student(s.id)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                StudentAvatar(student: s, size: 40),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(s.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: tt.titleMedium),
                                      Text(
                                        <String>[
                                          if (s.leftDate != null)
                                            l10n.stuLeftOn(
                                                fmt.date(s.leftDate!)),
                                          if (owed > 0)
                                            l10n.stuDuesGrey(fmt.money(owed)),
                                        ].join(' · '),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: tt.labelMedium?.copyWith(
                                            color: tokens.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: OutlinedButton.icon(
                                key: ValueKey<String>('stu-left-rejoin-${s.id}'),
                                icon: const Icon(Icons.person_add_alt_1_outlined),
                                label: Text(l10n.stuRejoin),
                                onPressed: () => runRejoinFlow(context, ref, s),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
