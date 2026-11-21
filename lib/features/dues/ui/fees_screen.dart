// Fees tab: one page, one header. The বকেয়া | আদায় segmented control swaps the
// body in place (fade-through) - `/fees/collection` just opens on the আদায়
// segment. বকেয়া: a large title with the "N unpaid · M overdue" subtitle, the
// বকেয়া | আদায় segments and the primary "টাকা নিন". Phones: summary card,
// one filter line and the grouped dues list with a floating "টাকা নিন". Wide
// windows (>= 840): one full-width list under three count-up summary tiles;
// a row (or "টাকা নিন") opens the payment flow in the floating side panel.
// `/fees/s/:studentId` on a wide window opens that student's panel on top of
// the list (phones show the profile instead).

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/dues_providers.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/features/dues/widgets/collection_body.dart';
import 'package:attendance_alamin/features/dues/widgets/dues_keys.dart';
import 'package:attendance_alamin/features/dues/widgets/dues_list_pane.dart';
import 'package:attendance_alamin/features/dues/widgets/dues_row.dart';
import 'package:attendance_alamin/features/dues/widgets/fees_segments.dart';
import 'package:attendance_alamin/features/dues/widgets/take_money_picker.dart';

class FeesScreen extends ConsumerStatefulWidget {
  const FeesScreen({super.key, this.selectedStudentId, this.initialSegment = FeesSegment.dues});

  /// Segment shown first (`/fees/collection` opens on আদায়).
  final FeesSegment initialSegment;

  /// Student whose payment panel opens on wide windows.
  final String? selectedStudentId;

  @override
  ConsumerState<FeesScreen> createState() => _FeesScreenState();
}

class _FeesScreenState extends ConsumerState<FeesScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.selectedStudentId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_openSelected()));
    }
  }

  /// Deep link `/fees/s/:id` on a wide window: the payment panel opens over
  /// the list; closing it goes back to `/fees`.
  Future<void> _openSelected() async {
    final String? id = widget.selectedStudentId;
    if (id == null || !mounted || !WindowClass.of(context).isWide) return;
    await duesCollect(context, id);
    if (!mounted) return;
    GoRouter.maybeOf(context)?.go(Routes.fees);
  }

  @override
  Widget build(BuildContext context) {
    final String? id = widget.selectedStudentId;
    return DuesKeys(
      onCollect: () => id == null ? showTakeMoneyPicker(context) : duesCollect(context, id),
      child: _FeesListScaffold(selectedId: id, initialSegment: widget.initialSegment),
    );
  }
}

class _FeesListScaffold extends ConsumerStatefulWidget {
  const _FeesListScaffold({required this.selectedId, required this.initialSegment});

  final String? selectedId;
  final FeesSegment initialSegment;

  @override
  ConsumerState<_FeesListScaffold> createState() => _FeesListScaffoldState();
}

class _FeesListScaffoldState extends ConsumerState<_FeesListScaffold> {
  late FeesSegment _segment = widget.initialSegment;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final WindowClass wc = WindowClass.of(context);
    final DuesReport? report = ref.watch(duesReportProvider).value;
    final bool dues = _segment == FeesSegment.dues;
    final String? subtitle = !dues || report == null || report.studentsWithDues == 0
        ? null
        : l10n.duesHeadline(fmt.number(report.studentsWithDues), fmt.number(report.overdueStudents));
    final double g = wc.gutter;
    return BhorScaffold(
      header: BhorHeader(
        title: l10n.navFees,
        subtitle: subtitle,
        large: true,
        // One tab root: never a back arrow, even on `/fees/collection`.
        showBack: false,
        actions: <Widget>[
          if (!dues) ...<Widget>[
            const CollectionActions(),
            const SizedBox(width: BhorSpace.s8),
          ] else if (wc.usesRail) ...<Widget>[
            BhorButton(
              key: const ValueKey<String>('fees-take-money'),
              icon: BhorIcons.takeMoney,
              label: l10n.payTitle,
              onPressed: () => showTakeMoneyPicker(context),
            ),
            const SizedBox(width: BhorSpace.s12),
          ],
          BhorIconButton(
            icon: BhorIcons.search,
            semanticLabel: l10n.commonSearch,
            variant: BhorButtonVariant.secondary,
            circle: true,
            onPressed: () => GoRouter.maybeOf(context)?.push(Routes.search),
          ),
          const SizedBox(width: BhorSpace.s8),
        ],
      ),
      floating: wc.usesRail || !dues
          ? null
          : Padding(
              // Lift the button above the bottom navigation.
              padding: const EdgeInsets.only(bottom: 64),
              child: BhorButton(
                key: const ValueKey<String>('fees-take-money'),
                icon: BhorIcons.takeMoney,
                label: l10n.payTitle,
                size: BhorButtonSize.lg,
                pill: true,
                onPressed: () => showTakeMoneyPicker(context),
              ),
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: wc.isWide ? 360 + 2 * g : double.infinity),
              child: FeesSegments(
                selected: _segment,
                onChanged: (FeesSegment s) => setState(() => _segment = s),
              ),
            ),
          ),
          Expanded(
            child: BhorFadeThrough(
              child: KeyedSubtree(
                key: ValueKey<FeesSegment>(_segment),
                child: dues
                    ? DuesListPane(selectedId: widget.selectedId, showSummary: !wc.isWide)
                    : CollectionBody(
                        onSeeDues: () => setState(() => _segment = FeesSegment.dues),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
