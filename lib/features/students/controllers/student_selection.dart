// Multi-select on the students list (item 10): Ctrl+click toggles, Shift+click
// selects the range from the last clicked row, Ctrl+A selects every listed
// row, Esc clears. On phones a long press starts selecting and taps toggle.
// The selection outlives opening a profile (it is app state, not pane state).

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The selected student ids plus the anchor row for Shift+click ranges.
class StudentSelection {
  const StudentSelection({this.ids = const <String>{}, this.anchor});

  final Set<String> ids;

  /// The row the next Shift+click range starts from.
  final String? anchor;

  bool get isEmpty => ids.isEmpty;
  bool get isNotEmpty => ids.isNotEmpty;
  bool contains(String id) => ids.contains(id);

  /// Adds or removes [id]; it becomes the anchor.
  StudentSelection toggle(String id) {
    final Set<String> next = <String>{...ids};
    if (!next.remove(id)) next.add(id);
    return StudentSelection(ids: next, anchor: id);
  }

  /// The rows from the anchor to [id] in [order] (just [id] without an
  /// anchor, or when the anchor is no longer listed). The anchor stays, so a
  /// second Shift+click re-draws the range from the same row.
  StudentSelection range(List<String> order, String id) {
    final int to = order.indexOf(id);
    final String? a = anchor;
    final int from = a == null ? -1 : order.indexOf(a);
    if (to < 0) return this;
    if (from < 0) return StudentSelection(ids: <String>{id}, anchor: id);
    final int lo = from < to ? from : to;
    final int hi = from < to ? to : from;
    return StudentSelection(ids: <String>{...order.sublist(lo, hi + 1)}, anchor: a);
  }

  /// Every row of [order].
  StudentSelection all(List<String> order) =>
      StudentSelection(ids: <String>{...order}, anchor: anchor);

  /// The selected ids that are still listed, in list order.
  List<String> visibleIn(List<String> order) => <String>[
        for (final String id in order)
          if (ids.contains(id)) id,
      ];
}

class StudentSelectionController extends Notifier<StudentSelection> {
  @override
  StudentSelection build() => const StudentSelection();

  void toggle(String id) => state = state.toggle(id);

  void range(List<String> order, String id) => state = state.range(order, id);

  void selectAll(List<String> order) => state = state.all(order);

  void clear() {
    if (state.isNotEmpty || state.anchor != null) state = const StudentSelection();
  }
}

final stuSelectionProvider =
    NotifierProvider<StudentSelectionController, StudentSelection>(StudentSelectionController.new);
