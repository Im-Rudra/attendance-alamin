// Fees tab › বকেয়া (UX 2d, 3b). Phones and mediums: segments, summary, filter
// chips and the severity-grouped list. Wide windows (>= 840): dues list ||
// payment panel through PaneSplit (the overview while nobody is selected);
// large windows turn the list into the dues data table, extra-large ones add
// the level rail. `/fees/s/:studentId` passes [selectedStudentId].

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/pane_split.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/features/dues/controllers/dues_model.dart';
import 'package:attendance_alamin/features/dues/controllers/dues_state.dart';
import 'package:attendance_alamin/features/dues/widgets/dues_keys.dart';
import 'package:attendance_alamin/features/dues/widgets/dues_list_pane.dart';
import 'package:attendance_alamin/features/dues/widgets/dues_overview.dart';
import 'package:attendance_alamin/features/dues/widgets/dues_row.dart';
import 'package:attendance_alamin/features/dues/widgets/dues_selected_pane.dart';
import 'package:attendance_alamin/features/dues/widgets/fees_segments.dart';
import 'package:attendance_alamin/features/dues/widgets/take_money_picker.dart';

class FeesScreen extends ConsumerWidget {
  const FeesScreen({super.key, this.selectedStudentId});

  /// Student whose payment panel is shown on wide windows.
  final String? selectedStudentId;

  /// Width of the payment panel next to the table (large windows).
  static const double tablePanelWidth = 420;

  /// The list pane shows the table from this width (large windows).
  static const double tableMinPaneWidth = 560;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? id = selectedStudentId;
    final WindowClass wc = WindowClass.of(context);
    return DuesKeys(
      onCollect: id == null ? null : () => duesCollect(context, id),
      onEscape: id == null ? null : () => GoRouter.maybeOf(context)?.go(Routes.fees),
      onMove: wc.isWide ? (int delta) => _move(context, ref, id, delta) : null,
      child: _body(context, wc, id),
    );
  }

  /// Up / down: the previous / next student of the list.
  void _move(BuildContext context, WidgetRef ref, String? current, int delta) {
    final DuesView? view = ref.read(duesViewProvider).value;
    if (view == null) return;
    final List<DuesRow> rows = view.all;
    if (rows.isEmpty) return;
    final int at = rows.indexWhere((DuesRow r) => r.studentId == current);
    int next;
    if (at < 0) {
      next = delta > 0 ? 0 : rows.length - 1;
    } else {
      next = at + delta;
      if (next < 0) next = 0;
      if (next > rows.length - 1) next = rows.length - 1;
    }
    openDuesStudent(context, rows[next].studentId);
  }

  Widget _body(BuildContext context, WindowClass wc, String? id) {
    if (!wc.isWide) return _FeesListScaffold(selectedId: id);
    final bool large = wc.index >= WindowClass.large.index;
    final Widget panes = PaneSplit(
      screen: 'fees',
      listMax: large ? double.infinity : 440,
      detailMax: large ? tablePanelWidth : 720,
      preferList: id == null,
      list: _FeesListScaffold(selectedId: id),
      detail: id == null ? const DuesOverview() : DuesSelectedPane(studentId: id),
    );
    if (wc != WindowClass.extraLarge) return panes;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(width: 240, child: DuesOverview(rail: true)),
        Expanded(child: panes),
      ],
    );
  }
}

class _FeesListScaffold extends StatelessWidget {
  const _FeesListScaffold({required this.selectedId});

  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final WindowClass wc = WindowClass.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final bool table =
            wc.index >= WindowClass.large.index && c.maxWidth >= FeesScreen.tableMinPaneWidth;
        return BhorScaffold(
          header: BhorHeader(
            title: l10n.navFees,
            showBack: PaneScope.isEmbedded(context) ? false : null,
            actions: <Widget>[
              if (wc.usesRail)
                BhorButton(
                  key: const ValueKey<String>('fees-take-money'),
                  icon: Icons.payments_outlined,
                  label: l10n.payTitle,
                  onPressed: () => showTakeMoneyPicker(context),
                ),
              if (wc.usesRail) const SizedBox(width: BhorSpace.s12),
              BhorIconButton(
                icon: Icons.manage_search,
                semanticLabel: l10n.commonSearch,
                onPressed: () => GoRouter.maybeOf(context)?.push(Routes.search),
              ),
              const SizedBox(width: BhorSpace.s8),
            ],
          ),
          floating: wc.usesRail
              ? null
              : Padding(
                  // Lift the button above the bottom navigation.
                  padding: const EdgeInsets.only(bottom: 64),
                  child: BhorButton(
                    key: const ValueKey<String>('fees-take-money'),
                    icon: Icons.payments_outlined,
                    label: l10n.payTitle,
                    onPressed: () => showTakeMoneyPicker(context),
                  ),
                ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const FeesSegments(selected: FeesSegment.dues),
              Expanded(
                child: DuesListPane(
                  selectedId: selectedId,
                  table: table,
                  showSummary: !wc.isWide,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
