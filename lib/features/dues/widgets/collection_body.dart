// Fees tab › আদায়: the body of the monthly collection summary (the Fees page
// owns the header and the segments) (Product 3.7, UX 3b).
// Phone: one scrolling column (billing month, cash in, receipts). Wide windows:
// two scrolling columns (billing month || cash in + receipts) so both fill the
// height. Tapping "outstanding" opens the dues list filtered to that month.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/data/repositories/place_providers.dart';
import 'package:attendance_alamin/features/dues/controllers/collection_model.dart';
import 'package:attendance_alamin/features/dues/controllers/dues_state.dart';
import 'package:attendance_alamin/features/dues/widgets/collection_blocks.dart';
import 'package:attendance_alamin/features/dues/widgets/fees_segments.dart';
import 'package:attendance_alamin/features/dues/widgets/places_breakdown.dart';
import 'package:attendance_alamin/features/settings/settings_entry.dart';

class CollectionBody extends ConsumerWidget {
  const CollectionBody({super.key, required this.onSeeDues});

  /// "Outstanding" tapped: show the dues list (filter already set to the month).
  final VoidCallback onSeeDues;

  /// Two columns from this body width.
  static const double twoColumnsFrom = 720;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final double g = WindowClass.of(context).gutter;
    final YearMonth current = ref.watch(todayProvider).yearMonth;
    final YearMonth month = ref.watch(collMonthProvider) ?? current;
    final AsyncValue<CollectionSummary> async = ref.watch(feesCollectionSummaryProvider(month));
    // 2+ places and "All places": each place's totals lead the page.
    final bool byPlace = ref.watch(hasManyPlacesProvider) && ref.watch(placeFilterProvider) == null;
    final Widget? places = byPlace ? PlacesBreakdownCard(month: month) : null;

    void seeDues() {
      ref.read(duesFilterProvider.notifier).setMonth(month);
      onSeeDues();
    }

    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Wide windows put the stepper next to the segments (the page
          // header row); phones keep it here, compact and left-aligned.
          if (!WindowClass.of(context).isWide)
            Padding(
              padding: EdgeInsets.fromLTRB(g, 0, g, BhorSpace.s8),
              child: const CollectionMonthNav(),
            ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: BhorSpinner()),
              error: (Object e, StackTrace s) => BhorEmptyState(
                icon: BhorIcons.warning,
                title: l10n.commonLoadingFailed,
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
                          Expanded(child: _Column(children: <Widget>[?places, billing])),
                          SizedBox(width: g),
                          Expanded(child: _Column(children: <Widget>[cash, log])),
                        ],
                      ),
                    );
                  }
                  return _Column(
                    padding: EdgeInsets.fromLTRB(g, 0, g, 112),
                    children: <Widget>[?places, billing, cash, log],
                  );
                },
              ),
            ),
          ),
        ],
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
          if (i > 0) const SizedBox(height: BhorSpace.s12),
          children[i],
        ],
      ],
    );
  }
}

/// The month stepper of the Collected segment ("‹ November 2026 ›"), compact
/// and grouped. Shared by the page header row (wide) and the body (phones).
class CollectionMonthNav extends ConsumerWidget {
  const CollectionMonthNav({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final YearMonth current = ref.watch(todayProvider).yearMonth;
    final YearMonth month = ref.watch(collMonthProvider) ?? current;
    final YearMonth? earliest = ref.watch(collEarliestMonthProvider);
    return MonthPickerRow(
      month: month,
      canPrev: canStepBack(month, earliest),
      canNext: canStepForward(month, current),
      onChanged: (YearMonth m) => ref.read(collMonthProvider.notifier).select(m == current ? null : m),
    );
  }
}
