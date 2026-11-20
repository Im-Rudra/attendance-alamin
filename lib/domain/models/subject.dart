class Subject {
  const Subject({
    required this.id,
    required this.name,
    required this.sortOrder,
    this.notes,
    this.archived = false,
  });

  final String id;
  final String name;
  final int sortOrder;
  final String? notes;
  final bool archived;

  @override
  bool operator ==(Object other) =>
      other is Subject &&
      other.id == id &&
      other.name == name &&
      other.sortOrder == sortOrder &&
      other.notes == notes &&
      other.archived == archived;

  @override
  int get hashCode => Object.hash(id, name, sortOrder, notes, archived);

  @override
  String toString() => 'Subject($id, $name)';
}
