// State of the weekly slot editor (no widgets, no providers): the draft slots,
// the "same time on every day" mode, local validation and the live clash
// check. The check is injected, so the same controller drives the batch form
// field, onboarding and the full-screen editor, and unit-tests need no
// database.

import 'package:flutter/foundation.dart';

import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/domain/models/drafts.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';

/// Why the save button is disabled (none = it is enabled).
enum SlotBlocker { none, noDays, badTime, checking, clash, noChange }

/// Runs the live clash check for the given drafts.
typedef SlotChecker = Future<SlotCheckResult> Function(List<SlotDraft> slots);

/// One class time on screen; [index] addresses it in the controller.
class SlotRow {
  const SlotRow(this.index, this.draft);

  final int index;
  final SlotDraft draft;
}

class SlotEditorController extends ChangeNotifier {
  SlotEditorController({
    required List<SlotDraft> initial,
    required SlotChecker checker,
    this.defaultStartMin = 960,
    this.defaultDurationMin = 60,
  })  : _checker = checker,
        _initial = List<SlotDraft>.unmodifiable(initial),
        _slots = List<SlotDraft>.of(initial) {
    final first = _earliest(_slots);
    _commonStart = first?.startMin ?? defaultStartMin;
    _commonEnd = first?.endMin ?? defaultStartMin + defaultDurationMin;
    _sameAll = _isUniform(_slots);
  }

  /// Latest day a class may end (minutes, midnight exclusive).
  static const int dayEnd = 1440;

  final SlotChecker _checker;
  final List<SlotDraft> _initial;
  final int defaultStartMin;
  final int defaultDurationMin;

  List<SlotDraft> _slots;
  late bool _sameAll;
  late int _commonStart;
  late int _commonEnd;
  SlotCheckResult? _check;
  bool _checking = false;
  int _version = 0;
  bool _disposed = false;

  // ---- reading ---------------------------------------------------------

  List<SlotDraft> get slots => List<SlotDraft>.unmodifiable(_slots);
  bool get sameAll => _sameAll;
  int get commonStart => _commonStart;
  int get commonEnd => _commonEnd;
  SlotCheckResult? get check => _check;
  bool get checking => _checking;
  bool get isEmpty => _slots.isEmpty;

  /// Weekdays (ISO) that have at least one class.
  Set<int> get days => <int>{for (final s in _slots) s.weekday};

  /// Any slot whose end is not after its start (or leaves the day).
  bool get hasBadTime => _slots.any(_isBad);

  bool isBadAt(int index) => _isBad(_slots[index]);

  static bool _isBad(SlotDraft s) =>
      s.startMin < 0 || s.endMin <= s.startMin || s.endMin > dayEnd;

  /// Whether the drafts differ from what the editor started with.
  bool get changed {
    final a = _sortedByTime(_slots);
    final b = _sortedByTime(_initial);
    if (a.length != b.length) return true;
    for (var i = 0; i < a.length; i++) {
      final x = a[i];
      final y = b[i];
      if (x.weekday != y.weekday ||
          x.startMin != y.startMin ||
          x.endMin != y.endMin) {
        return true;
      }
    }
    return false;
  }

  /// The current reason the schedule cannot be saved. [requireChange] adds
  /// [SlotBlocker.noChange] (the full-screen editor); the batch form does not.
  SlotBlocker blocker({bool requireChange = false}) {
    if (_slots.isEmpty) return SlotBlocker.noDays;
    if (hasBadTime) return SlotBlocker.badTime;
    if (requireChange && !changed) return SlotBlocker.noChange;
    if (_checking) return SlotBlocker.checking;
    final c = _check;
    if (c != null && !c.ok) return SlotBlocker.clash;
    return SlotBlocker.none;
  }

  /// Rows of [weekday], by start time.
  List<SlotRow> rowsOf(int weekday) {
    final rows = <SlotRow>[
      for (var i = 0; i < _slots.length; i++)
        if (_slots[i].weekday == weekday) SlotRow(i, _slots[i]),
    ];
    rows.sort((a, b) => a.draft.startMin.compareTo(b.draft.startMin));
    return rows;
  }

  /// Weekdays that have rows, in week order starting at [weekStart].
  List<int> orderedDays(int weekStart) {
    final out = days.toList()
      ..sort((a, b) => _offset(a, weekStart).compareTo(_offset(b, weekStart)));
    return out;
  }

  /// Weekdays without a class, in week order.
  List<int> missingDays(int weekStart) => <int>[
        for (var i = 0; i < 7; i++)
          if (!days.contains(((weekStart - 1 + i) % 7) + 1))
            ((weekStart - 1 + i) % 7) + 1,
      ];

  static int _offset(int weekday, int weekStart) => (weekday - weekStart + 7) % 7;

  // ---- editing ---------------------------------------------------------

  /// Same-time mode: add or remove [weekday].
  void toggleDay(int weekday) {
    if (days.contains(weekday)) {
      _slots = [
        for (final s in _slots)
          if (s.weekday != weekday) s,
      ];
    } else {
      _slots = [
        ..._slots,
        SlotDraft(weekday: weekday, startMin: _commonStart, endMin: _commonEnd),
      ];
    }
    _changed();
  }

  /// Switches mode. Turning it on makes every day use one time (the earliest
  /// class's) and one row per day.
  void setSameAll(bool value) {
    if (value == _sameAll) return;
    _sameAll = value;
    if (value) {
      final first = _earliest(_slots);
      if (first != null) {
        _commonStart = first.startMin;
        _commonEnd = first.endMin;
      }
      final seen = <int>{};
      _slots = [
        for (final s in _slots)
          if (seen.add(s.weekday))
            SlotDraft(
                id: s.id,
                weekday: s.weekday,
                startMin: _commonStart,
                endMin: _commonEnd),
      ];
    }
    _changed();
  }

  /// Same-time mode: moves the start, keeping the length.
  void setCommonStart(int startMin) {
    final len = _commonEnd - _commonStart;
    _commonStart = startMin;
    _commonEnd = startMin + (len > 0 ? len : defaultDurationMin);
    _applyCommon();
  }

  void setCommonEnd(int endMin) {
    _commonEnd = endMin;
    _applyCommon();
  }

  void _applyCommon() {
    _slots = [
      for (final s in _slots)
        SlotDraft(
            id: s.id,
            weekday: s.weekday,
            startMin: _commonStart,
            endMin: _commonEnd),
    ];
    _changed();
  }

  /// Moves one class's start, keeping its length.
  void setStart(int index, int startMin) {
    final s = _slots[index];
    final len = s.endMin - s.startMin;
    _replace(index, startMin, startMin + (len > 0 ? len : defaultDurationMin));
  }

  void setEnd(int index, int endMin) =>
      _replace(index, _slots[index].startMin, endMin);

  void _replace(int index, int start, int end) {
    final s = _slots[index];
    _slots = List<SlotDraft>.of(_slots)
      ..[index] =
          SlotDraft(id: s.id, weekday: s.weekday, startMin: start, endMin: end);
    _changed();
  }

  /// Adds a class on a day that already has one, right after its last class
  /// (touching is fine) with the same length.
  void addTime(int weekday) {
    final rows = rowsOf(weekday);
    var start = _commonStart;
    var len = defaultDurationMin;
    if (rows.isNotEmpty) {
      final last = rows.last.draft;
      len = last.endMin - last.startMin;
      if (len <= 0) len = defaultDurationMin;
      start = last.endMin;
    }
    if (start + len > dayEnd) start = dayEnd - len;
    _slots = [
      ..._slots,
      SlotDraft(weekday: weekday, startMin: start, endMin: start + len),
    ];
    _changed();
  }

  /// Adds a day with the time most recently used.
  void addDay(int weekday) {
    _slots = [
      ..._slots,
      SlotDraft(weekday: weekday, startMin: _commonStart, endMin: _commonEnd),
    ];
    _changed();
  }

  void removeAt(int index) {
    _slots = List<SlotDraft>.of(_slots)..removeAt(index);
    _changed();
  }

  /// Applies a suggested start from the clash card: the class that was
  /// checked first (matching the suggestion's start and length) moves to
  /// [newStartMin]; in same-time mode the shared time moves.
  void applyFix(FreeSuggestion suggestion, int newStartMin, Set<int> clashWeekdays) {
    final want = suggestion.preferredStartMin;
    final sorted = <int>[
      for (var i = 0; i < _slots.length; i++) i,
    ]..sort((a, b) {
        final c = _slots[a].weekday.compareTo(_slots[b].weekday);
        return c != 0 ? c : _slots[a].startMin.compareTo(_slots[b].startMin);
      });
    int? find(bool Function(SlotDraft) weekdayOk) {
      for (final i in sorted) {
        final s = _slots[i];
        if (s.endMin - s.startMin != suggestion.durationMin) continue;
        if (want != null && s.startMin != want) continue;
        if (weekdayOk(s)) return i;
      }
      return null;
    }

    final int? target = find(
            (s) => clashWeekdays.isEmpty || clashWeekdays.contains(s.weekday)) ??
        find((_) => true);
    if (target == null) return;
    if (_sameAll) {
      _commonStart = newStartMin;
      _commonEnd = newStartMin + suggestion.durationMin;
      _applyCommon();
    } else {
      _replace(target, newStartMin, newStartMin + suggestion.durationMin);
    }
  }

  /// Runs the first live check (call once after the editor appears).
  void start() {
    if (_slots.isNotEmpty) _runCheck();
  }

  // ---- internals -------------------------------------------------------

  void _changed() {
    _check = null;
    if (_slots.isEmpty || hasBadTime) {
      _version++;
      _checking = false;
      notifyListeners();
      return;
    }
    _runCheck();
    notifyListeners();
  }

  void _runCheck() {
    final mine = ++_version;
    _checking = true;
    final snapshot = List<SlotDraft>.of(_slots);
    _checker(snapshot).then<void>((SlotCheckResult result) {
      if (_disposed || mine != _version) return;
      _check = result;
      _checking = false;
      notifyListeners();
    }, onError: (Object _) {
      if (_disposed || mine != _version) return;
      // A failed check must never block saving; the repository checks again.
      _check = const SlotCheckResult();
      _checking = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// The class that starts first in the day (ties: the shorter one).
  static SlotDraft? _earliest(List<SlotDraft> list) {
    SlotDraft? best;
    for (final s in list) {
      if (best == null ||
          s.startMin < best.startMin ||
          (s.startMin == best.startMin && s.endMin < best.endMin)) {
        best = s;
      }
    }
    return best;
  }

  static List<SlotDraft> _sortedByTime(List<SlotDraft> list) {
    final out = List<SlotDraft>.of(list);
    out.sort((a, b) {
      var c = a.weekday.compareTo(b.weekday);
      if (c != 0) return c;
      c = a.startMin.compareTo(b.startMin);
      if (c != 0) return c;
      return a.endMin.compareTo(b.endMin);
    });
    return out;
  }

  /// One class per day, all with the same time (or nothing at all).
  static bool _isUniform(List<SlotDraft> slots) {
    if (slots.isEmpty) return true;
    final seen = <int>{};
    for (final s in slots) {
      if (!seen.add(s.weekday)) return false;
      if (s.startMin != slots.first.startMin ||
          s.endMin != slots.first.endMin) {
        return false;
      }
    }
    return true;
  }
}

/// "শনি, সোম — বিকাল ৪:০০–৫:০০; রবি — সকাল ১০:০০–১১:০০": days with identical
/// times are joined, a day with two classes lists both ("A ও B"). Days follow
/// the week order that starts at [weekStart].
String scheduleSentence(
  AppFormat fmt,
  List<SlotDraft> slots, {
  required int weekStart,
  required String andWord,
}) {
  final byDay = <int, List<SlotDraft>>{};
  for (final s in slots) {
    (byDay[s.weekday] ??= <SlotDraft>[]).add(s);
  }
  final days = byDay.keys.toList()
    ..sort((a, b) =>
        ((a - weekStart + 7) % 7).compareTo((b - weekStart + 7) % 7));
  final groupKeys = <String>[];
  final groupDays = <String, List<int>>{};
  final groupText = <String, String>{};
  for (final d in days) {
    final list = byDay[d]!
      ..sort((a, b) => a.startMin.compareTo(b.startMin));
    final text = [
      for (final s in list) fmt.timeRange(s.startMin, s.endMin),
    ].join(' $andWord ');
    if (!groupDays.containsKey(text)) {
      groupKeys.add(text);
      groupText[text] = text;
      groupDays[text] = <int>[];
    }
    groupDays[text]!.add(d);
  }
  return [
    for (final k in groupKeys)
      '${groupDays[k]!.map(fmt.weekdayShort).join(', ')} — ${groupText[k]}',
  ].join('; ');
}
