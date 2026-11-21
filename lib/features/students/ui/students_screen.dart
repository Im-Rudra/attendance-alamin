// Students tab (UX 3, 3b). Phones and mediums: search + filter chips + rows.
// Wide windows (>= 840): list || profile through PaneSplit. On large windows
// (>= 1200) the list pane takes all the width beside a 420 profile and becomes
// the data table (sticky header, UX 3b columns).
// `/students/:studentId` passes [selectedId].

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/pane_split.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/features/students/controllers/student_nav.dart';
import 'package:attendance_alamin/features/students/ui/student_form_screen.dart';
import 'package:attendance_alamin/features/students/ui/student_profile_screen.dart';
import 'package:attendance_alamin/features/students/widgets/student_keys.dart';
import 'package:attendance_alamin/features/students/widgets/students_list_pane.dart';
import 'package:attendance_alamin/features/students/widgets/students_overview.dart';

class StudentsScreen extends StatelessWidget {
  const StudentsScreen({super.key, this.selectedId});

  /// Student shown in the detail pane on wide windows.
  final String? selectedId;

  /// Width of the profile pane next to the table.
  static const double tableProfileWidth = 420;

  /// The list pane shows the table from this width (on large windows).
  static const double tableMinPaneWidth = 480;

  @override
  Widget build(BuildContext context) {
    final String? id = selectedId;
    return StudentKeys(
      onNew: () => showStudentFormPanel(context),
      onEscape: id == null ? null : () => stuGo(context, Routes.students),
      child: _build(context, id),
    );
  }

  Widget _build(BuildContext context, String? id) {
    final WindowClass wc = WindowClass.of(context);
    if (!wc.isWide) return _ListScaffold(selectedId: id);
    final bool large = wc.index >= WindowClass.large.index;
    return PaneSplit(
      screen: 'students',
      listMax: large ? double.infinity : 440,
      detailMax: large ? tableProfileWidth : 720,
      list: _ListScaffold(selectedId: id),
      preferList: id == null,
      detail: id == null
          ? const StudentsOverview()
          : BhorPaneSwitcher(paneKey: id, child: StudentProfileScreen(studentId: id)),
    );
  }
}

class _ListScaffold extends StatelessWidget {
  const _ListScaffold({required this.selectedId});

  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final WindowClass wc = WindowClass.of(context);
    final double g = wc.gutter;
    final bool large = wc.index >= WindowClass.large.index;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final bool table = large && c.maxWidth >= StudentsScreen.tableMinPaneWidth;
        return BhorScaffold(
          header: BhorHeader(
            title: l10n.navStudents,
            large: true,
            showBack: PaneScope.isEmbedded(context) ? false : null,
            actions: <Widget>[
              if (table)
                BhorButton(
                  key: const ValueKey<String>('stu-new-button'),
                  onPressed: () => showStudentFormPanel(context),
                  icon: BhorIcons.add,
                  label: l10n.stuNewStudent,
                  size: BhorButtonSize.sm,
                ),
              BhorIconButton(
                semanticLabel: l10n.commonSearch,
                icon: BhorIcons.search,
                onPressed: () => stuPush(context, Routes.search),
              ),
            ],
          ),
          floating: table
              ? null
              : Padding(
                  // Lift the button above the floating nav pill on phones (QA-03).
                  padding: EdgeInsets.only(bottom: wc.usesRail ? 0 : 84),
                  child: BhorButton(
                    key: const ValueKey<String>('stu-fab-new'),
                    onPressed: () => showStudentFormPanel(context),
                    icon: BhorIcons.add,
                    label: l10n.stuNewStudent,
                  ),
                ),
          body: Padding(
            padding: EdgeInsets.fromLTRB(g, BhorSpace.s4, g, g),
            child: StudentsListPane(selectedId: selectedId, table: table),
          ),
        );
      },
    );
  }
}
