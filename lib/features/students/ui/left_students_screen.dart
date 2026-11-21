// "ছেড়ে যাওয়া শিক্ষার্থী" (More > Students who left): who left and when, what
// they still owe (grey), and a rejoin button.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
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
    final fmt = context.fmt;
    final double g = WindowClass.of(context).gutter;
    final AsyncValue<List<StudentRow>> async = ref.watch(stuRowsProvider);

    return BhorScaffold(
      header: BhorHeader(title: l10n.shellTitleLeft),
      body: Padding(
        padding: EdgeInsets.fromLTRB(g, BhorSpace.s4, g, g),
        child: async.when(
          loading: () => const Center(child: BhorSpinner()),
          error: (Object e, StackTrace st) =>
              BhorEmptyState(icon: BhorIcons.warning, title: l10n.commonLoadingFailed),
          data: (List<StudentRow> all) {
            final List<StudentRow> rows = <StudentRow>[
              for (final StudentRow r in all)
                if (r.student.status == StudentStatus.left) r,
            ];
            if (rows.isEmpty) {
              return BhorCard(
                padding: EdgeInsets.zero,
                child: BhorEmptyState(icon: BhorIcons.leftStudents, title: l10n.stuLeftEmpty),
              );
            }
            return BhorCard(
              padding: EdgeInsets.zero,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: rows.length,
                itemBuilder: (BuildContext c, int i) {
                  final StudentRow r = rows[i];
                  final Student s = r.student;
                  final int owed = r.dues?.totalOutstanding ?? 0;
                  return BhorListRow(
                    leading: StudentAvatar(student: s, size: 40),
                    title: s.name,
                    subtitle: <String>[
                      if (s.leftDate != null) l10n.stuLeftOn(fmt.date(s.leftDate!)),
                      if (owed > 0) l10n.stuDuesGrey(fmt.money(owed)),
                    ].join(' · '),
                    divider: i != rows.length - 1,
                    onTap: () => stuGo(context, Routes.student(s.id)),
                    trailing: BhorButton(
                      key: ValueKey<String>('stu-left-rejoin-${s.id}'),
                      variant: BhorButtonVariant.secondary,
                      size: BhorButtonSize.sm,
                      icon: BhorIcons.add,
                      label: l10n.stuRejoin,
                      onPressed: () => runRejoinFlow(context, ref, s),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
