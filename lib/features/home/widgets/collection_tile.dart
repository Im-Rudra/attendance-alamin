// This month's collection (UX 3b): the cash received as a big number, the
// share of the month's fees it covers on a progress track, and the split by
// payment method. Tap opens the monthly collection summary.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/routes.dart';
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
    final BhorThemeData b = context.bhor;
    final MonthCollection? c = ref.watch(todayCollectionProvider).value;

    final Widget header = TileHeader(
      icon: BhorIcons.money,
      title: l10n.todayCollectionTitle,
      trailing: Icon(BhorIcons.chevronRight, color: b.colors.text2),
    );
    if (c == null) {
      return TileFrame(header: header, child: const BhorSkeleton(height: 96, radius: 12));
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
                child: BhorCountUp.money(amount: c.collected, style: b.type.display),
              ),
              Text(
                c.expected > 0
                    ? l10n.todayCollectionOf(fmt.money(c.expected))
                    : l10n.todayCollectionNone,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: b.type.meta,
              ),
            ],
          ),
          const SizedBox(height: BhorSpace.s12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (c.expected > 0)
                BhorProgress(
                  value: c.fraction,
                  height: 10,
                  semanticLabel: l10n.todayCollectionProgress(fmt.percent(percent ?? 0)),
                ),
              if (roomy && c.byMethod.isNotEmpty) ...<Widget>[
                const SizedBox(height: BhorSpace.s12),
                Wrap(
                  spacing: BhorSpace.s8,
                  runSpacing: BhorSpace.s8,
                  children: <Widget>[
                    for (final MethodAmount m in c.byMethod.take(3))
                      BhorTag(label: '${paymentMethodLabel(l10n, m.method)} ${fmt.money(m.amount)}'),
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
