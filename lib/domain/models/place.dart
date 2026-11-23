/// Where classes happen (schema v2, feedback item 3): a coaching centre, a
/// second centre, "Student's home"... Each batch / private tuition belongs to
/// one place; other income may belong to one (null = general).
library;

/// Id of the place every v1 database is migrated to and every fresh database
/// starts with. Its name / phone / address follow the centre settings
/// (`SettingKeys.centerName` / `centerPhone` / `centerAddress`), it cannot be
/// archived and it is the default `batches.place_id`. Fixed, so two devices
/// that migrate separately agree on it.
///
/// Keep in sync with the literal default of `Batches.placeId`
/// (`lib/data/db/tables/structure_tables.dart`); a test asserts it.
const String kDefaultPlaceId = '00000000-0000-4000-8000-00000000d1ac';

class Place {
  const Place({
    required this.id,
    required this.name,
    required this.sortOrder,
    this.phone,
    this.address,
    this.archived = false,
  });

  final String id;
  final String name;
  final String? phone;
  final String? address;
  final int sortOrder;
  final bool archived;

  /// The migrated / first place (follows the centre settings).
  bool get isDefault => id == kDefaultPlaceId;

  @override
  bool operator ==(Object other) =>
      other is Place &&
      other.id == id &&
      other.name == name &&
      other.phone == phone &&
      other.address == address &&
      other.sortOrder == sortOrder &&
      other.archived == archived;

  @override
  int get hashCode =>
      Object.hash(id, name, phone, address, sortOrder, archived);

  @override
  String toString() => 'Place($id, $name)';
}
