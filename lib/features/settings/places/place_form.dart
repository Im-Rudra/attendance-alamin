// Add / edit one teaching place (feedback item 3): name (required, unique
// among every place, archived ones included), phone and address. A side panel
// on desktop, a sheet on phones; Save lives in the panel footer and closing
// with changes asks first (`dirty:`). Editing the main place also updates the
// centre settings (the repository does that).

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/error_text.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/core/validation/validators.dart';
import 'package:attendance_alamin/data/repositories/place_providers.dart';
import 'package:attendance_alamin/domain/models/place.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

/// Opens the place form; returns the saved place's id, null when dismissed.
Future<String?> showPlaceFormPanel(BuildContext context, {Place? place}) {
  final l10n = context.l10n;
  final ValueNotifier<PlaceFormSpec?> bar = ValueNotifier<PlaceFormSpec?>(null);
  final ValueNotifier<bool> dirty = ValueNotifier<bool>(false);
  return showBhorPanel<String>(
    context,
    title: place == null ? l10n.placeNewTitle : l10n.placeEditTitle,
    kind: BhorPanelKind.form,
    width: 440,
    dirty: dirty,
    footer: (BuildContext ctx) => PlaceFormBar(sink: bar),
    builder: (BuildContext ctx) => PlaceForm(place: place, barSink: bar, dirtySink: dirty),
  );
}

/// Case- and space-insensitive form of a place name (the uniqueness check).
String placeNameKey(String name) => name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// True when a place other than [excludeId] already has [name].
bool isPlaceNameTaken(List<Place> places, String name, {String? excludeId}) {
  final String key = placeNameKey(name);
  if (key.isEmpty) return false;
  for (final Place p in places) {
    if (p.id != excludeId && placeNameKey(p.name) == key) return true;
  }
  return false;
}

/// What the footer shows (published by the form).
typedef PlaceFormSpec = ({bool canSave, bool busy, String? reason, VoidCallback save});

class PlaceForm extends ConsumerStatefulWidget {
  const PlaceForm({super.key, this.place, this.barSink, this.dirtySink});

  /// Null = a new place.
  final Place? place;

  /// When set, Save is drawn by the panel footer ([PlaceFormBar]).
  final ValueNotifier<PlaceFormSpec?>? barSink;
  final ValueNotifier<bool>? dirtySink;

  @override
  ConsumerState<PlaceForm> createState() => _PlaceFormState();
}

class _PlaceFormState extends ConsumerState<PlaceForm> {
  late final TextEditingController _name = TextEditingController(text: widget.place?.name ?? '');
  late final TextEditingController _phone = TextEditingController(text: widget.place?.phone ?? '');
  late final TextEditingController _address = TextEditingController(text: widget.place?.address ?? '');
  bool _busy = false;
  String? _error;

  bool get _editing => widget.place != null;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  bool get _dirty =>
      _name.text != (widget.place?.name ?? '') ||
      _phone.text != (widget.place?.phone ?? '') ||
      _address.text != (widget.place?.address ?? '');

  String? _phoneError(AppLocalizations l10n) {
    if (_phone.text.trim().isEmpty) return null;
    try {
      Validators.phone(_phone.text);
      return null;
    } on Object catch (e) {
      return errorText(l10n, e);
    }
  }

  String? _reason(AppLocalizations l10n, List<Place> all) {
    if (_editing && !_dirty) return l10n.placeReasonNoChange;
    if (_name.text.trim().isEmpty) return l10n.placeReasonName;
    if (isPlaceNameTaken(all, _name.text, excludeId: widget.place?.id)) return l10n.placeNameTaken;
    return _phoneError(l10n);
  }

  void _publish(PlaceFormSpec spec) {
    final ValueNotifier<PlaceFormSpec?>? bar = widget.barSink;
    final ValueNotifier<bool>? d = widget.dirtySink;
    final bool dirty = _dirty;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (bar != null && bar.value != spec) bar.value = spec;
      if (d != null && d.value != dirty) d.value = dirty;
    });
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final List<Place> all = ref.read(allPlacesProvider).value ?? const <Place>[];
    if (_busy || _reason(l10n, all) != null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final String name = _name.text.trim();
    final String phone = _phone.text.trim();
    final String address = _address.text.trim();
    try {
      final repo = ref.read(placesRepositoryProvider);
      final Place? old = widget.place;
      final String id;
      if (old == null) {
        id = await repo.create(
          name: name,
          phone: phone.isEmpty ? null : phone,
          address: address.isEmpty ? null : address,
        );
      } else {
        id = old.id;
        await repo.update(
          id,
          name: name,
          phone: phone.isEmpty ? null : phone,
          address: address.isEmpty ? null : address,
        );
      }
      if (!mounted) return;
      // The panel closes with the success moment; nothing is dirty any more.
      widget.dirtySink?.value = false;
      await showBhorSuccess<String>(
        context,
        result: id,
        toast: old == null ? l10n.placeAdded(name) : l10n.placeSaved,
      );
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = errorText(l10n, e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final BhorThemeData b = context.bhor;
    final List<Place> all = ref.watch(allPlacesProvider).value ?? const <Place>[];
    final bool taken = isPlaceNameTaken(all, _name.text, excludeId: widget.place?.id);
    final String? reason = _reason(l10n, all);
    final PlaceFormSpec spec = (canSave: reason == null && !_busy, busy: _busy, reason: reason, save: _save);
    _publish(spec);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(l10n.placeFormHelp, style: b.type.body.copyWith(color: b.colors.text2)),
        const SizedBox(height: BhorSpace.s16),
        BhorTextField(
          key: const ValueKey<String>('place-form-name'),
          controller: _name,
          autofocus: !_editing,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          maxLength: Validators.nameMaxLength,
          label: l10n.placeNameLabel,
          hint: l10n.placeNameHint,
          error: taken ? l10n.placeNameTaken : null,
          onChanged: (_) => setState(() => _error = null),
        ),
        const SizedBox(height: BhorSpace.s16),
        BhorTextField(
          key: const ValueKey<String>('place-form-phone'),
          controller: _phone,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          maxLength: 20,
          label: l10n.placePhoneLabel,
          hint: l10n.placePhoneHint,
          error: _phoneError(l10n),
          onChanged: (_) => setState(() => _error = null),
        ),
        const SizedBox(height: BhorSpace.s16),
        BhorTextField(
          key: const ValueKey<String>('place-form-address'),
          controller: _address,
          minLines: 1,
          maxLines: 3,
          maxLength: 120,
          label: l10n.placeAddressLabel,
          onChanged: (_) => setState(() => _error = null),
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: BhorSpace.s12),
          Text(_error!, style: b.type.body.copyWith(color: b.colors.danger)),
        ],
        if (widget.barSink == null) ...<Widget>[
          const SizedBox(height: BhorSpace.s20),
          PlaceFormButtons(spec: spec),
        ],
      ],
    );
  }
}

/// The footer of the place panel.
class PlaceFormBar extends StatelessWidget {
  const PlaceFormBar({super.key, required this.sink});

  final ValueListenable<PlaceFormSpec?> sink;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<PlaceFormSpec?>(
        valueListenable: sink,
        builder: (BuildContext context, PlaceFormSpec? spec, Widget? _) => PlaceFormButtons(spec: spec),
      );
}

/// Save, and under it why it is off.
class PlaceFormButtons extends StatelessWidget {
  const PlaceFormButtons({super.key, required this.spec});

  final PlaceFormSpec? spec;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final PlaceFormSpec? sp = spec;
    final bool can = sp != null && sp.canSave;
    final VoidCallback? save = (sp != null && sp.canSave) ? sp.save : null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        BhorButton(
          key: const ValueKey<String>('place-form-save'),
          label: context.l10n.commonSave,
          expand: true,
          loading: sp?.busy ?? false,
          onPressed: save,
        ),
        if (!can && sp?.reason != null) ...<Widget>[
          const SizedBox(height: BhorSpace.s8),
          Text(sp!.reason!, textAlign: TextAlign.center, style: b.type.meta),
        ],
      ],
    );
  }
}
