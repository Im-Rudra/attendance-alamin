// Settings › Coaching centres (feedback item 3). With one active place it is
// the centre fields as before plus one "Add another centre" row. With 2+ it is
// the list of places: the main one first (tagged), each with its open batches,
// a row opens its form, ⋮ moves it up / down or archives it. Archived places
// sit in their own card with "Restore".

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/data/repositories/place_providers.dart';
import 'package:attendance_alamin/data/repositories/structure_providers.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/place.dart';
import 'package:attendance_alamin/features/settings/places/place_form.dart';
import 'package:attendance_alamin/features/settings/widgets/setting_widgets.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

/// Open (not finished) batches and tuitions, for the per-place counts and the
/// archive rule.
final placeOpenBatchesProvider = StreamProvider<List<Batch>>(
    (ref) => ref.watch(batchesRepositoryProvider).watchAll());

/// Open batches per place id.
Map<String, int> openBatchCounts(List<Batch> open) {
  final Map<String, int> counts = <String, int>{};
  for (final Batch b in open) {
    if (!b.archived) counts[b.placeId] = (counts[b.placeId] ?? 0) + 1;
  }
  return counts;
}

/// Active places in list order: the main place first, then the rest in the
/// teacher's order.
List<Place> orderedActivePlaces(List<Place> all) => <Place>[
      for (final Place p in all)
        if (!p.archived && p.isDefault) p,
      for (final Place p in all)
        if (!p.archived && !p.isDefault) p,
    ];

/// Why [place] can't be archived now, or null when it can: the main place
/// and the last active place never; a place with open batches not yet.
enum PlaceArchiveBlock { mainPlace, lastPlace, openBatches }

PlaceArchiveBlock? placeArchiveBlock(Place place, {required int activeCount, required int openBatches}) {
  if (place.isDefault) return PlaceArchiveBlock.mainPlace;
  if (activeCount <= 1) return PlaceArchiveBlock.lastPlace;
  if (openBatches > 0) return PlaceArchiveBlock.openBatches;
  return null;
}

/// The cards of the group. [fields] is the single-centre card (name, phone,
/// address of the settings), shown while there is only one active place.
class PlacesSection extends ConsumerWidget {
  const PlacesSection({super.key, required this.fields});

  final Widget fields;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Place>? all = ref.watch(allPlacesProvider).value;
    final List<Place> active = orderedActivePlaces(all ?? const <Place>[]);
    final List<Place> archived = <Place>[
      for (final Place p in all ?? const <Place>[])
        if (p.archived) p,
    ];
    final Map<String, int> counts = openBatchCounts(ref.watch(placeOpenBatchesProvider).value ?? const <Batch>[]);
    final List<Widget> cards = <Widget>[
      if (active.length <= 1) ...<Widget>[
        fields,
        if (all != null) const _AddPlaceCard(),
      ] else
        _PlacesListCard(places: active, counts: counts),
      if (archived.isNotEmpty) _ArchivedPlacesCard(places: archived),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < cards.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: BhorSpace.s12),
          cards[i],
        ],
      ],
    );
  }
}

class _AddPlaceCard extends StatelessWidget {
  const _AddPlaceCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SettingsCard(children: <Widget>[
      SettingRow(
        key: const ValueKey<String>('place-add'),
        icon: BhorIcons.addCircle,
        title: l10n.placeAdd,
        value: l10n.placeAddHint,
        onTap: () => unawaited(showPlaceFormPanel(context)),
      ),
    ]);
  }
}

String _countText(AppLocalizations l10n, String Function(int) number, int n) {
  if (n == 0) return l10n.placeNoBatches;
  return n == 1 ? l10n.placeBatchCountOne(number(n)) : l10n.placeBatchCount(number(n));
}

class _PlacesListCard extends ConsumerWidget {
  const _PlacesListCard({required this.places, required this.counts});

  final List<Place> places;
  final Map<String, int> counts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final BhorThemeData b = context.bhor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(BhorSpace.s4, 0, BhorSpace.s4, BhorSpace.s8),
          child: Text(l10n.placeSectionHelp, style: b.type.meta),
        ),
        SettingsCard(children: <Widget>[
          for (int i = 0; i < places.length; i++)
            _PlaceRow(
              key: ValueKey<String>('place-row-${places[i].id}'),
              place: places[i],
              index: i,
              places: places,
              openBatches: counts[places[i].id] ?? 0,
            ),
          SettingRow(
            key: const ValueKey<String>('place-add'),
            icon: BhorIcons.addCircle,
            title: l10n.placeAdd,
            onTap: () => unawaited(showPlaceFormPanel(context)),
          ),
        ]),
      ],
    );
  }
}

class _PlaceRow extends ConsumerWidget {
  const _PlaceRow({
    super.key,
    required this.place,
    required this.index,
    required this.places,
    required this.openBatches,
  });

  final Place place;
  final int index;

  /// Every active place in list order (the main one first).
  final List<Place> places;
  final int openBatches;

  /// The main place stays first: only the others move.
  bool get _canUp => !place.isDefault && index > 1;
  bool get _canDown => !place.isDefault && index < places.length - 1;

  Future<void> _move(WidgetRef ref, int by) async {
    final List<Place> next = List<Place>.of(places);
    final Place p = next.removeAt(index);
    next.insert(index + by, p);
    await ref.read(placesRepositoryProvider).reorder(<String>[for (final Place x in next) x.id]);
  }

  Future<void> _archive(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final PlaceArchiveBlock? block =
        placeArchiveBlock(place, activeCount: places.length, openBatches: openBatches);
    if (block == PlaceArchiveBlock.openBatches) {
      BhorToast.show(context, message: l10n.placeArchiveBlocked(place.name));
      return;
    }
    if (block != null) return;
    final bool ok = await showBhorConfirm(
      context,
      title: l10n.placeArchiveTitle(place.name),
      message: l10n.placeArchiveBody,
      confirmLabel: l10n.placeArchive,
    );
    if (!ok || !context.mounted) return;
    await ref.read(placesRepositoryProvider).archive(place.id);
    if (context.mounted) BhorToast.show(context, message: l10n.placeArchived(place.name), tone: BhorTone.ok);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final String count = _countText(l10n, context.fmt.number, openBatches);
    final String? phone = place.phone;
    final String value = <String>[
      count,
      if (phone != null && phone.isNotEmpty) context.fmt.digits(phone),
    ].join(' · ');
    final bool canArchive = placeArchiveBlock(place, activeCount: places.length, openBatches: 0) == null;
    final List<BhorMenuItem> items = <BhorMenuItem>[
      BhorMenuItem(
        key: ValueKey<String>('place-edit-${place.id}'),
        icon: BhorIcons.edit,
        label: l10n.commonEdit,
        onTap: () => unawaited(showPlaceFormPanel(context, place: place)),
      ),
      if (_canUp)
        BhorMenuItem(
          key: ValueKey<String>('place-up-${place.id}'),
          icon: BhorIcons.chevronUp,
          label: l10n.placeMoveUp,
          onTap: () => unawaited(_move(ref, -1)),
        ),
      if (_canDown)
        BhorMenuItem(
          key: ValueKey<String>('place-down-${place.id}'),
          icon: BhorIcons.chevronDown,
          label: l10n.placeMoveDown,
          onTap: () => unawaited(_move(ref, 1)),
        ),
      if (canArchive)
        BhorMenuItem(
          key: ValueKey<String>('place-archive-${place.id}'),
          icon: BhorIcons.archive,
          label: l10n.placeArchive,
          destructive: true,
          onTap: () => unawaited(_archive(context, ref)),
        ),
    ];
    return SettingRow(
      icon: BhorIcons.explore,
      title: place.name,
      value: value,
      onTap: () => unawaited(showPlaceFormPanel(context, place: place)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (place.isDefault) ...<Widget>[
            BhorTag(key: const ValueKey<String>('place-main-tag'), label: l10n.placeMainTag, tone: BhorTone.accent),
            const SizedBox(width: BhorSpace.s4),
          ],
          Builder(
            builder: (BuildContext bc) => BhorIconButton(
              key: ValueKey<String>('place-menu-${place.id}'),
              icon: BhorIcons.overflowVertical,
              semanticLabel: l10n.placeMenuLabel(place.name),
              size: BhorButtonSize.sm,
              onPressed: () => showBhorMenu(context, anchor: bc, items: items),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchivedPlacesCard extends ConsumerWidget {
  const _ArchivedPlacesCard({required this.places});

  final List<Place> places;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SettingsHeader(l10n.placeArchivedGroup),
        const SizedBox(height: BhorSpace.s8),
        SettingsCard(children: <Widget>[
          for (final Place p in places)
            SettingRow(
              key: ValueKey<String>('place-archived-${p.id}'),
              icon: BhorIcons.archive,
              title: p.name,
              trailing: BhorButton(
                key: ValueKey<String>('place-restore-${p.id}'),
                label: l10n.placeRestore,
                variant: BhorButtonVariant.secondary,
                size: BhorButtonSize.sm,
                onPressed: () async {
                  await ref.read(placesRepositoryProvider).unarchive(p.id);
                  if (context.mounted) {
                    BhorToast.show(context, message: l10n.placeRestored(p.name), tone: BhorTone.ok);
                  }
                },
              ),
            ),
        ]),
      ],
    );
  }
}
