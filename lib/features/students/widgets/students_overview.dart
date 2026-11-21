// Detail pane when no student is selected (UX 3b rule 4): roster stats, the
// five biggest dues, students per batch and the newest students. On a wide
// pane the cards sit in two columns so the pane never has a blank half.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/pane_split.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/features/batches/widgets/batch_table.dart';
import 'package:attendance_alamin/features/students/controllers/student_nav.dart';
import 'package:attendance_alamin/features/students/controllers/student_providers.dart';

class StudentsOverview extends ConsumerWidget {
  const StudentsOverview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final BhorThemeData th = context.bhor;
    final fmt = context.fmt;
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

    Widget listCard(List<Widget> rowsList) => BhorCard(
          padding: EdgeInsets.zero,
          child: Column(children: rowsList),
        );

    Widget nameRow(StudentRow r, Widget trailing, {required bool last}) => BhorListRow(
          title: r.student.name,
          divider: !last,
          onTap: () => stuGo(context, Routes.student(r.id)),
          trailing: trailing,
        );

    final Widget topDues = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        BhorSectionHeader(title: l10n.stuTopDues),
        if (top.isEmpty)
          BhorCard(
            child: Text(l10n.stuNoOneOwes, style: th.type.body.copyWith(color: th.colors.text2)),
          )
        else
          listCard(<Widget>[
            for (int i = 0; i < top.length; i++)
              nameRow(
                top[i],
                BhorMoney(top[i].dues!.totalOutstanding, style: th.type.bodyStrong),
                last: i == top.length - 1,
              ),
          ]),
      ],
    );

    final Widget byBatch = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        BhorSectionHeader(title: l10n.stuOverviewByBatch),
        if (batchIds.isEmpty)
          BhorCard(
            child: Text(l10n.stuNoOneOwes, style: th.type.body.copyWith(color: th.colors.text2)),
          )
        else
          BatchBarList(
            entries: <BatchBarEntry>[
              for (final String id in batchIds.take(6))
                BatchBarEntry(
                  label: batchNames[id]!,
                  value: perBatch[id]!,
                  valueText: fmt.number(perBatch[id]!),
                  onTap: () => stuGo(context, Routes.batch(id)),
                ),
            ],
          ),
      ],
    );

    final Widget recentCard = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        BhorSectionHeader(title: l10n.stuOverviewRecent),
        listCard(<Widget>[
          for (int i = 0; i < recent.length; i++)
            nameRow(
              recent[i],
              Text(
                fmt.dateShort(recent[i].student.admissionDate),
                style: th.type.label.copyWith(color: th.colors.text2),
              ),
              last: i == recent.length - 1,
            ),
        ]),
      ],
    );

    final Widget stats = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: BhorCard(child: BhorStatText(label: l10n.stuStatActive, value: fmt.number(active)))),
        const SizedBox(width: BhorSpace.s12),
        Expanded(child: BhorCard(child: BhorStatText(label: l10n.stuStatNew, value: fmt.number(fresh)))),
        const SizedBox(width: BhorSpace.s12),
        Expanded(child: BhorCard(child: BhorStatText(label: l10n.stuStatLeft, value: fmt.number(left)))),
      ],
    );

    final Widget rightColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        byBatch,
        if (recent.isNotEmpty) ...<Widget>[const SizedBox(height: BhorSpace.s12), recentCard],
      ],
    );

    return BhorScaffold(
      header: BhorHeader(
        title: l10n.shellTitleOverview,
        showBack: PaneScope.isEmbedded(context) ? false : null,
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints c) {
          final bool twoCol = c.maxWidth >= 600;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(gutter, BhorSpace.s4, gutter, gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                stats,
                const SizedBox(height: BhorSpace.s12),
                if (twoCol)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(child: topDues),
                      const SizedBox(width: BhorSpace.s12),
                      Expanded(child: rightColumn),
                    ],
                  )
                else ...<Widget>[
                  topDues,
                  const SizedBox(height: BhorSpace.s12),
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
