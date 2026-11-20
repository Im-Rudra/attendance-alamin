// Students tab (UX 3, 3b). Phones and mediums: search + filter chips + rows.
// Wide windows (>= 840): list || profile through PaneSplit, and on large
// windows the data table (sticky header, UX 3b columns) || a 420 profile pane.
// `/students/:studentId` passes [selectedId].

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/pane_split.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/features/students/controllers/student_nav.dart';
import 'package:attendance_alamin/features/students/ui/student_profile_screen.dart';
import 'package:attendance_alamin/features/students/widgets/student_keys.dart';
import 'package:attendance_alamin/features/students/widgets/students_list_pane.dart';
import 'package:attendance_alamin/features/students/widgets/students_overview.dart';

class StudentsScreen extends StatelessWidget {
  const StudentsScreen({super.key, this.selectedId});

  /// Student shown in the detail pane on wide windows.
  final String? selectedId;

  /// Content width from which the list becomes the data table.
  static const double tableMinWidth = 1000;

  /// Width of the profile pane next to the table.
  static const double tableProfileWidth = 420;

  @override
  Widget build(BuildContext context) {
    final String? id = selectedId;
    return StudentKeys(
      onNew: () => stuPush(context, Routes.studentNew),
      onEscape: id == null ? null : () => stuGo(context, Routes.students),
      child: _build(context, id),
    );
  }

  Widget _build(BuildContext context, String? id) {
    final bool wide = WindowClass.of(context).isWide;
    if (!wide) return _ListScaffold(selectedId: id, table: false);
    final Widget detail =
        id == null ? const StudentsOverview() : StudentProfileScreen(studentId: id);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        if (c.maxWidth >= tableMinWidth) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(child: _ListScaffold(selectedId: id, table: true)),
              SizedBox(width: 1, child: ColoredBox(color: context.aurora.hairline)),
              SizedBox(
                width: tableProfileWidth,
                child: PaneScope(child: detail),
              ),
            ],
          );
        }
        return PaneSplit(
          screen: 'students',
          list: _ListScaffold(selectedId: id, table: false),
          preferList: id == null,
          detail: detail,
        );
      },
    );
  }
}

class _ListScaffold extends StatelessWidget {
  const _ListScaffold({required this.selectedId, required this.table});

  final String? selectedId;
  final bool table;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final double g = WindowClass.of(context).gutter;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !PaneScope.isEmbedded(context),
        title: Semantics(header: true, child: Text(l10n.navStudents)),
        actions: <Widget>[
          if (table)
            FilledButton.icon(
              key: const ValueKey<String>('stu-new-button'),
              onPressed: () => stuPush(context, Routes.studentNew),
              icon: const Icon(Icons.person_add_alt_1),
              label: Text(l10n.stuNewStudent),
            ),
          IconButton(
            tooltip: l10n.commonSearch,
            icon: const Icon(Icons.manage_search),
            onPressed: () => stuPush(context, Routes.search),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: table
          ? null
          : FloatingActionButton.extended(
              key: const ValueKey<String>('stu-fab-new'),
              onPressed: () => stuPush(context, Routes.studentNew),
              icon: const Icon(Icons.person_add_alt_1),
              label: Text(l10n.stuNewStudent),
            ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(g, 4, g, g),
          child: StudentsListPane(selectedId: selectedId, table: table),
        ),
      ),
    );
  }
}
