// This month's collection (UX 3b): the cash received as a big number, the
// share of the month's fees it covers on a progress track, and the split by
// payment method. Tap opens the monthly collection summary.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/money_text.dart';
import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/features/home/controllers/today_model.dart';
import 'package:attendance_alamin/features/home/controllers/today_providers.dart';
import 'package:attendance_alamin/features/home/widgets/tile_frame.dart';
import 'package:attendance_alamin/features/home/widgets/today_actions.dart';
import 'package:attendance_alamin/features/settings/settings_entry.dart';

class CollectionTile extends ConsumerWidget {
  const CollectionTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final AppFormat fmt = context.fmt;
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final MonthCollection? c = ref.watch(todayCollectionProvider).value;

    final Widget header = TileHeader(
      icon: Icons.savings_outlined,
      title: l10n.todayCollectionTitle,
      trailing: Icon(Icons.chevron_right, color: tokens.textSecondary),
    );
    if (c == null) {
      return TileFrame(header: header, child: const SizedBox(height: 96));
    }

    final int? percent = c.percent;
    return LayoutBuilder(builder: (BuildContext context, BoxConstraints box) {
      // In a short bento tile the method chips would be cut at the edge, so
      // they only show when there is room (QA-10).
      final bool roomy = !box.hasBoundedHeight || box.maxHeight >= 230;
      return TileFrame(
      onTap: () => goRoute(context, Routes.feesCollection),
      header: header,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: MoneyText(fmt.money(c.collected), maxLines: 1, style: context.statNumber),
              ),
              Text(
                c.expected > 0
                    ? l10n.todayCollectionOf(fmt.money(c.expected))
                    : l10n.todayCollectionNone,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: tt.labelMedium?.copyWith(color: tokens.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (c.expected > 0)
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: c.fraction,
                    minHeight: 10,
                    backgroundColor: tokens.track,
                    color: tokens.accent,
                    semanticsLabel: l10n.todayCollectionProgress(fmt.percent(percent ?? 0)),
                  ),
                ),
              if (roomy && c.byMethod.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: <Widget>[
                    for (final MethodAmount m in c.byMethod.take(3))
                      DecoratedBox(
                        decoration: ShapeDecoration(color: tokens.track, shape: const StadiumBorder()),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          child: Text(
                            '${paymentMethodLabel(l10n, m.method)} ${fmt.money(m.amount)}',
                            maxLines: 1,
                            style: tt.labelMedium?.copyWith(color: tokens.textPrimary),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
    });
  }
}
