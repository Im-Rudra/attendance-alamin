// The "All places ▾" filter (feedback item 3): one choice per device, shared
// by the Today, Batches, Fees and Students headers, that narrows their lists
// and totals to one teaching place. It exists only with 2+ active places: with
// one place every provider here gives the unfiltered value and the chip is
// never built, so the app looks exactly as before.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/async_combine.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/providers/dues_providers.dart';
import 'package:attendance_alamin/data/repositories/local_meta_repository.dart';
import 'package:attendance_alamin/data/repositories/place_providers.dart';
import 'package:attendance_alamin/data/repositories/settings_providers.dart';
import 'package:attendance_alamin/data/repositories/structure_providers.dart';
import 'package:attendance_alamin/domain/dues/dues_engine.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/place.dart';

/// The place id saved on this device (null / empty = all places).
final placeFilterStoredProvider = StreamProvider<String?>(
    (ref) => ref.watch(localMetaRepositoryProvider).watchRaw(LocalMetaKeys.placeFilter));

/// The place the lists and totals are narrowed to; null = all places. Always
/// null with fewer than two active places, or when the saved place was
/// archived since.
final placeFilterProvider = Provider<String?>((ref) {
  if (!ref.watch(hasManyPlacesProvider)) return null;
  final String? id = ref.watch(placeFilterStoredProvider).value;
  if (id == null || id.isEmpty) return null;
  final List<Place> places = ref.watch(placesProvider).value ?? const <Place>[];
  for (final Place p in places) {
    if (p.id == id) return id;
  }
  return null;
});

/// Saves the filter on this device (null = all places).
Future<void> setPlaceFilter(ProviderContainer container, String? placeId) => container
    .read(localMetaRepositoryProvider)
    .setRaw(LocalMetaKeys.placeFilter, (placeId == null || placeId.isEmpty) ? null : placeId);

/// Every batch, finished ones included: batch id -> place id.
final placeOfBatchProvider = Provider<Map<String, String>>((ref) {
  final List<Batch> all = ref.watch(_everyBatchProvider).value ?? const <Batch>[];
  return <String, String>{for (final Batch b in all) b.id: b.placeId};
});

final _everyBatchProvider = StreamProvider<List<Batch>>(
    (ref) => ref.watch(batchesRepositoryProvider).watchAll(includeArchived: true));

/// The enrollment terms at [placeId] (all of them when null).
List<EnrollmentTerms> termsAtPlace(List<EnrollmentTerms> terms, String? placeId) => placeId == null
    ? terms
    : <EnrollmentTerms>[
        for (final EnrollmentTerms t in terms)
          if (t.placeId == placeId) t,
      ];

/// The dues report narrowed to the place filter (the app-wide report when
/// no place is picked).
final placeDuesReportProvider = Provider<AsyncValue<DuesReport>>((ref) {
  final String? place = ref.watch(placeFilterProvider);
  if (place == null) return ref.watch(duesReportProvider);
  final today = ref.watch(todayProvider);
  return combine2(
    ref.watch(enrollmentTermsProvider),
    ref.watch(paymentFactsProvider),
    (List<EnrollmentTerms> terms, List<PaymentFact> facts) =>
        DuesEngine.report(today: today, terms: termsAtPlace(terms, place), payments: facts),
  );
});

/// The header chip "All places ▾" / "<place> ▾". Build it only when
/// `hasManyPlacesProvider` is true (callers check, so one place adds no gap).
/// Tapping opens a short choice list anchored to the chip.
class PlaceFilterChip extends ConsumerWidget {
  const PlaceFilterChip({super.key, this.maxWidth = 200});

  /// Long place names end in "…" past this width.
  final double maxWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final List<Place> places = ref.watch(placesProvider).value ?? const <Place>[];
    final String? current = ref.watch(placeFilterProvider);
    String label = l10n.placeFilterAll;
    for (final Place p in places) {
      if (p.id == current) label = p.name;
    }
    return Builder(
      builder: (BuildContext anchor) => PlacePill(
        key: const ValueKey<String>('place-filter'),
        label: label,
        semanticLabel: l10n.placeFilterLabel(label),
        selected: current != null,
        maxWidth: maxWidth,
        onTap: () => pickPlaceFilter(context, anchor, places, current),
      ),
    );
  }
}

/// The choice list of the filter: "All places", then each active place.
Future<void> pickPlaceFilter(
  BuildContext context,
  BuildContext anchor,
  List<Place> places,
  String? current,
) async {
  final l10n = context.l10n;
  final ProviderContainer container = ProviderScope.containerOf(context, listen: false);
  final List<(String, String)> items = <(String, String)>[
    ('', l10n.placeFilterAll),
    for (final Place p in places) (p.id, p.name),
  ];
  final String? picked = await showBhorPanel<String>(
    context,
    anchor: anchor,
    kind: BhorPanelKind.choice,
    title: l10n.placeFilterTitle,
    builder: (BuildContext ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < items.length; i++)
          BhorListRow(
            key: ValueKey<String>('place-filter-choice-${items[i].$1}'),
            title: items[i].$2,
            selected: (current ?? '') == items[i].$1,
            divider: i != items.length - 1,
            onTap: () => Navigator.of(ctx).pop(items[i].$1),
          ),
      ],
    ),
  );
  if (picked == null || picked == (current ?? '')) return;
  await setPlaceFilter(container, picked.isEmpty ? null : picked);
}

/// A compact soft pill (the chip look) with a place glyph, the label
/// (ellipsised past [maxWidth]) and a chevron.
class PlacePill extends StatelessWidget {
  const PlacePill({
    super.key,
    required this.label,
    required this.onTap,
    this.semanticLabel,
    this.selected = false,
    this.maxWidth = 200,
  });

  final String label;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final bool selected;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final Duration fast = BhorMotion.of(context, BhorMotion.fast);
    final Color fg = selected ? c.accent : c.text2;
    return BhorPressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: semanticLabel ?? label,
      excludeChildSemantics: true,
      radius: BhorSize.compact / 2,
      builder: (BuildContext context, BhorStates s) => AnimatedContainer(
        duration: fast,
        curve: BhorMotion.ease,
        height: BhorSize.compact,
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? c.accentTint : (s.hovered || s.pressed ? c.soft2 : c.soft),
          borderRadius: BorderRadius.circular(BhorRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(BhorIcons.explore, size: BhorIconSize.inline, color: fg),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: b.type.label.copyWith(color: selected ? c.accent : c.text, fontSize: 13.5),
              ),
            ),
            const SizedBox(width: 4),
            Icon(BhorIcons.chevronDown, size: BhorIconSize.inline, color: fg),
          ],
        ),
      ),
    );
  }
}
