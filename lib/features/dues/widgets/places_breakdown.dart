// Fees › Collected with 2+ places and "All places": each place's month on its
// own line (fee money collected, what is still owed, its other income) plus
// the other income that belongs to no place. Tapping a place narrows the page
// to it (the same place filter as the header chip).

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/data/repositories/place_providers.dart';
import 'package:attendance_alamin/domain/models/place.dart';
import 'package:attendance_alamin/features/dues/controllers/collection_model.dart';
import 'package:attendance_alamin/features/dues/controllers/dues_state.dart';
import 'package:attendance_alamin/features/settings/settings_entry.dart';

class PlacesBreakdownCard extends ConsumerWidget {
  const PlacesBreakdownCard({super.key, required this.month});

  final YearMonth month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final BhorThemeData b = context.bhor;
    final PlacesMonthBreakdown? data = ref.watch(placesMonthBreakdownProvider(month)).value;
    if (data == null) return const BhorSkeleton(height: 120, radius: BhorRadius.card);
    final Map<String, String> names = <String, String>{
      for (final Place p in ref.watch(placesProvider).value ?? const <Place>[]) p.id: p.name,
    };
    final ProviderContainer container = ProviderScope.containerOf(context, listen: false);

    Widget amount(int taka) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(l10n.placeCollected, style: b.type.meta),
            BhorMoney(taka, style: b.type.heading, muteSign: true),
          ],
        );

    return BhorCard(
      key: const ValueKey<String>('coll-places-breakdown'),
      padding: const EdgeInsets.symmetric(vertical: BhorSpace.s12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Semantics(header: true, child: Text(l10n.placeByPlace, style: b.type.heading)),
                const SizedBox(height: 2),
                Text(l10n.placeByPlaceHint, style: b.type.meta),
              ],
            ),
          ),
          const SizedBox(height: BhorSpace.s8),
          for (int i = 0; i < data.places.length; i++)
            BhorListRow(
              key: ValueKey<String>('coll-place-${data.places[i].placeId}'),
              title: names[data.places[i].placeId] ?? '',
              subtitle: '${l10n.placeDues} ${fmt.money(data.places[i].dues)} · '
                  '${l10n.placeOtherIncome} ${fmt.money(data.places[i].otherIncome)}',
              trailing: amount(data.places[i].collected),
              divider: i < data.places.length - 1 || data.generalOtherIncome > 0,
              onTap: () => unawaited(setPlaceFilter(container, data.places[i].placeId)),
            ),
          if (data.generalOtherIncome > 0)
            BhorListRow(
              key: const ValueKey<String>('coll-place-general'),
              title: l10n.placeGeneralIncome,
              trailing: BhorMoney(data.generalOtherIncome, style: b.type.bodyStrong, muteSign: true),
              divider: false,
            ),
        ],
      ),
    );
  }
}
