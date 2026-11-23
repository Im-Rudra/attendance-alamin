// Students tab (UX 3, 3b) on BhorMasterDetailPage. Phones and narrow panes:
// search + filter chips + rows, the profile alone once one is open. A pane
// that holds the list and a profile side by side (>= 801) shows them
// together; when it also leaves the table >= 600 beside the profile (>= 480), the
// list becomes the data table and takes every pixel the profile does not need.
// `/students/:studentId` passes [selectedId]. With nothing selected the
// detail column is the roster overview.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/pane_split.dart';
import 'package:attendance_alamin/app/shell/templates/templates.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/features/students/controllers/student_nav.dart';
import 'package:attendance_alamin/features/students/controllers/student_selection.dart';
import 'package:attendance_alamin/features/students/students_entry.dart';
import 'package:attendance_alamin/features/students/ui/student_profile_screen.dart';
import 'package:attendance_alamin/features/students/widgets/student_keys.dart';
import 'package:attendance_alamin/features/students/widgets/students_list_pane.dart';
import 'package:attendance_alamin/features/students/widgets/students_overview.dart';

class StudentsScreen extends ConsumerWidget {
  const StudentsScreen({super.key, this.selectedId});

  /// Student shown in the detail pane on wide windows.
  final String? selectedId;

  /// The profile column is never narrower than this (nothing clips in Bangla).
  static const double profileMinWidth = 440;

  /// With room for the table the profile gets a share of the pane, between
  /// [profileMinWidth] + 40 and 560, so a wide Name column never starves it.
  static double profileWidthFor(double paneWidth) =>
      (paneWidth * 0.34).clamp(profileMinWidth + 40, 560.0).toDouble();

  /// The list pane shows the table from this width.
  static const double tableMinPaneWidth = 600;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? id = selectedId;
    // Esc clears a multi-selection first, then closes the profile.
    final bool selecting = ref.watch(stuSelectionProvider.select((StudentSelection s) => s.isNotEmpty));
    return StudentKeys(
      onNew: () => openAddStudent(context),
      onEscape: selecting
          ? () => ref.read(stuSelectionProvider.notifier).clear()
          : (id == null ? null : () => stuGo(context, Routes.students)),
      child: _build(context, id),
    );
  }

  Widget _build(BuildContext context, String? id) {
    if (!WindowClass.of(context).isWide) return _ListScaffold(selectedId: id);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final double w = box.maxWidth;
        final bool two = BhorMasterDetailPage.twoPane(w, minDetailWidth: profileMinWidth);
        // The table takes everything the profile leaves.
        final double tableWidth = (w - 1 - profileWidthFor(w)).floorToDouble();
        final bool table = two && tableWidth >= tableMinPaneWidth;
        Widget embed(Widget child) => two ? PaneScope(child: child) : child;
        return BhorMasterDetailPage(
          masterWidth: table ? tableWidth : BhorMasterDetailPage.defaultMasterWidth,
          minDetailWidth: profileMinWidth,
          master: embed(_ListScaffold(selectedId: id, table: table)),
          detail: id == null
              ? null
              : embed(BhorPaneSwitcher(paneKey: id, child: StudentProfileScreen(studentId: id))),
          emptyDetail: embed(const StudentsOverview()),
        );
      },
    );
  }
}

class _ListScaffold extends ConsumerWidget {
  const _ListScaffold({required this.selectedId, this.table = false});

  final String? selectedId;
  final bool table;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final WindowClass wc = WindowClass.of(context);
    final double g = wc.gutter;
    // On phones the selection bar takes the FAB's place above the nav pill.
    final bool selecting = ref.watch(stuSelectionProvider.select((StudentSelection s) => s.isNotEmpty));
    final double pill = wc.usesRail ? 0 : 84;
    return BhorScaffold(
      header: BhorHeader(
        title: l10n.navStudents,
        large: true,
        showBack: PaneScope.isEmbedded(context) ? false : null,
        actions: <Widget>[
          if (wc.isWide)
            BhorButton(
              key: const ValueKey<String>('stu-new-button'),
              onPressed: () => openAddStudent(context),
              icon: BhorIcons.add,
              label: l10n.stuNewStudent,
              size: BhorButtonSize.sm,
            ),
        ],
      ),
      floating: wc.isWide || selecting
          ? null
          : Padding(
              // Lift the button above the floating nav pill on phones (QA-03).
              padding: EdgeInsets.only(bottom: wc.usesRail ? 0 : 84),
              child: BhorButton(
                key: const ValueKey<String>('stu-fab-new'),
                onPressed: () => openAddStudent(context),
                icon: BhorIcons.add,
                label: l10n.stuNewStudent,
              ),
            ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(g, BhorSpace.s4, g, g),
        child: StudentsListPane(selectedId: selectedId, table: table, bottomInset: wc.isWide ? 0 : pill),
      ),
    );
  }
}
