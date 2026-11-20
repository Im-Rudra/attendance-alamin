// Fees tab › আদায়: the monthly collection summary (Product 3.7, UX 3b).
// Phone: one scrolling column (billing month, cash in, receipts). Wide windows:
// two scrolling columns (billing month || cash in + receipts) so both fill the
// height. Tapping "outstanding" opens the dues list filtered to that month.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/features/dues/controllers/collection_model.dart';
import 'package:attendance_alamin/features/dues/controllers/dues_state.dart';
import 'package:attendance_alamin/features/dues/widgets/collection_blocks.dart';
import 'package:attendance_alamin/features/dues/widgets/fees_segments.dart';

class CollectionScreen extends ConsumerWidget {
  const CollectionScreen({super.key});

  /// Two columns from this body width.
  static const double twoColumnsFrom = 720;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final double g = WindowClass.of(context).gutter;
    final YearMonth current = ref.watch(todayProvider).yearMonth;
    final YearMonth month = ref.watch(collMonthProvider) ?? current;
    final YearMonth? earliest = ref.watch(collEarliestMonthProvider);
    final AsyncValue<CollectionSummary> async = ref.watch(collectionSummaryProvider(month));

    void seeDues() {
      ref.read(duesFilterProvider.notifier).setMonth(month);
      GoRouter.maybeOf(context)?.go(Routes.fees);
    }

    return Scaffold(
      appBar: AppBar(title: Semantics(header: true, child: Text(l10n.collTitle))),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const FeesSegments(selected: FeesSegment.collection),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: g),
              child: MonthPickerRow(
                month: month,
                canPrev: canStepBack(month, earliest),
                canNext: canStepForward(month, current),
                onChanged: (YearMonth m) =>
                    ref.read(collMonthProvider.notifier).select(m == current ? null : m),
              ),
            ),
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (Object e, StackTrace s) => EmptyState(
                  icon: Icons.error_outline,
                  message: l10n.commonLoadingFailed,
                ),
                data: (CollectionSummary summary) => LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints c) {
                    final Widget billing = BillingBlock(summary: summary, onSeeDues: seeDues);
                    final Widget cash = CashBlock(summary: summary);
                    final Widget log = ReceiptLog(summary: summary);
                    if (c.maxWidth >= twoColumnsFrom) {
                      return Padding(
                        padding: EdgeInsets.fromLTRB(g, 0, g, g),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(child: _Column(children: <Widget>[billing])),
                            SizedBox(width: g),
                            Expanded(child: _Column(children: <Widget>[cash, log])),
                          ],
                        ),
                      );
                    }
                    return _Column(
                      padding: EdgeInsets.fromLTRB(g, 0, g, 112),
                      children: <Widget>[billing, cash, log],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A scrolling column of blocks with 12dp between them.
class _Column extends StatelessWidget {
  const _Column({required this.children, this.padding = EdgeInsets.zero});

  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: padding,
      children: <Widget>[
        for (int i = 0; i < children.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: 12),
          children[i],
        ],
      ],
    );
  }
}
