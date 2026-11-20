// State of one roll call (no widgets, no providers): who is present / absent /
// late / excused, undo, the draft that survives an app kill, and the save
// model of UX 2b: the first save commits the day, afterwards every change
// autosaves. Persistence is injected, so unit tests need no repository.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/student.dart';

/// Writes the marks (and the class note) of the roll call being edited.
typedef RollSaveFn = Future<void> Function(
    Map<String, AttendanceStatus> statuses, String? note);

/// Stores (`json`) or removes (`null`) the unsaved draft.
typedef RollDraftWriter = Future<void> Function(String? json);

/// Live counts of the header.
class RollCounts {
  const RollCounts({this.present = 0, this.absent = 0, this.late = 0, this.leave = 0});

  final int present;
  final int absent;
  final int late;
  final int leave;

  int get total => present + absent + late + leave;

  /// Present or late.
  int get attended => present + late;
}

/// An unsaved roll call as stored under `rollcall_draft:<occ>`.
class RollDraft {
  const RollDraft(this.statuses, this.note);

  final Map<String, AttendanceStatus> statuses;
  final String? note;
}

abstract final class RollDraftCodec {
  static String encode(Map<String, AttendanceStatus> statuses, String? note) {
    final Map<String, Object?> out = <String, Object?>{
      'v': 1,
      's': <String, String>{
        for (final MapEntry<String, AttendanceStatus> e in statuses.entries) e.key: e.value.code,
      },
    };
    if (note != null && note.isNotEmpty) out['n'] = note;
    return jsonEncode(out);
  }

  /// `null` for anything unreadable (a corrupt draft is simply dropped).
  static RollDraft? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final Object? parsed = jsonDecode(raw);
      if (parsed is! Map) return null;
      final Object? marks = parsed['s'];
      if (marks is! Map) return null;
      final Map<String, AttendanceStatus> statuses = <String, AttendanceStatus>{};
      for (final MapEntry<Object?, Object?> e in marks.entries) {
        final Object? key = e.key;
        final Object? value = e.value;
        if (key is String && value is String) {
          statuses[key] = AttendanceStatus.parse(value);
        }
      }
      final Object? note = parsed['n'];
      return RollDraft(statuses, note is String ? note : null);
    } on Object {
      return null;
    }
  }
}

class RollCallController extends ChangeNotifier {
  RollCallController({
    required List<Student> students,
    required Map<String, AttendanceStatus> initial,
    required this.persist,
    this.writeDraft,
    bool saved = false,
    String? note,
    this.restoredFromDraft = false,
    this.readOnly = false,
  })  : students = List<Student>.unmodifiable(students),
        _saved = saved,
        _note = note,
        _edited = restoredFromDraft,
        _dirty = restoredFromDraft,
        _draftStored = restoredFromDraft {
    for (final Student s in this.students) {
      _status[s.id] = initial[s.id] ?? AttendanceStatus.present;
    }
  }

  /// In roll order.
  final List<Student> students;
  final RollSaveFn persist;
  final RollDraftWriter? writeDraft;

  /// The marks came from an unsaved draft of an earlier session.
  final bool restoredFromDraft;

  /// Archived batch or future date: nothing can change.
  final bool readOnly;

  final Map<String, AttendanceStatus> _status = <String, AttendanceStatus>{};
  final List<Map<String, AttendanceStatus>> _history = <Map<String, AttendanceStatus>>[];
  String? _note;
  bool _saved;
  bool _edited;
  bool _dirty;
  bool _saving = false;
  bool _resave = false;
  bool _disposed = false;
  bool _draftStored;
  Object? _error;

  AttendanceStatus statusOf(String studentId) => _status[studentId] ?? AttendanceStatus.present;

  Map<String, AttendanceStatus> get statuses => Map<String, AttendanceStatus>.unmodifiable(_status);

  RollCounts get counts {
    var present = 0, absent = 0, late = 0, leave = 0;
    for (final AttendanceStatus s in _status.values) {
      switch (s) {
        case AttendanceStatus.present:
          present++;
        case AttendanceStatus.absent:
          absent++;
        case AttendanceStatus.late:
          late++;
        case AttendanceStatus.leave:
          leave++;
      }
    }
    return RollCounts(present: present, absent: absent, late: late, leave: leave);
  }

  String? get note => _note;

  /// A roll call exists in the database; changes autosave.
  bool get saved => _saved;

  /// Something was changed (or restored from a draft) since opening.
  bool get edited => _edited;

  /// There are changes that are not stored yet (drives the leave guard).
  bool get dirty => _dirty;
  bool get saving => _saving;

  /// The last save failed (the draft is kept).
  Object? get error => _error;
  bool get canUndo => _history.isNotEmpty;

  // ---- editing ---------------------------------------------------------

  /// Tap on a row: present becomes absent, anything else becomes... absent
  /// when it was attended, present when it was absent (UX 2b).
  void toggle(String studentId) {
    final AttendanceStatus now = statusOf(studentId);
    _set(<String, AttendanceStatus>{
      studentId: now == AttendanceStatus.absent ? AttendanceStatus.present : AttendanceStatus.absent,
    });
  }

  /// The trailing late button: late <-> present.
  void toggleLate(String studentId) {
    final AttendanceStatus now = statusOf(studentId);
    _set(<String, AttendanceStatus>{
      studentId: now == AttendanceStatus.late ? AttendanceStatus.present : AttendanceStatus.late,
    });
  }

  void setStatus(String studentId, AttendanceStatus status) =>
      _set(<String, AttendanceStatus>{studentId: status});

  void markAll(AttendanceStatus status) => _set(<String, AttendanceStatus>{
        for (final Student s in students) s.id: status,
      });

  void setNote(String? value) {
    if (readOnly) return;
    final String? next = (value == null || value.trim().isEmpty) ? null : value.trim();
    if (next == _note) return;
    _note = next;
    _touched();
  }

  void undo() {
    if (readOnly || _history.isEmpty) return;
    final Map<String, AttendanceStatus> previous = _history.removeLast();
    _status
      ..clear()
      ..addAll(previous);
    _touched();
  }

  void _set(Map<String, AttendanceStatus> changes) {
    if (readOnly) return;
    var differs = false;
    for (final MapEntry<String, AttendanceStatus> e in changes.entries) {
      if (_status.containsKey(e.key) && _status[e.key] != e.value) differs = true;
    }
    if (!differs) return;
    _history.add(Map<String, AttendanceStatus>.of(_status));
    if (_history.length > 50) _history.removeAt(0);
    for (final MapEntry<String, AttendanceStatus> e in changes.entries) {
      if (_status.containsKey(e.key)) _status[e.key] = e.value;
    }
    _touched();
  }

  void _touched() {
    _edited = true;
    _dirty = true;
    _error = null;
    _notify();
    if (_saved || _saving) {
      unawaited(save());
    } else {
      _storeDraft();
    }
  }

  // ---- persistence -----------------------------------------------------

  void _storeDraft() {
    final RollDraftWriter? w = writeDraft;
    if (w == null) return;
    _draftStored = true;
    unawaited(w(RollDraftCodec.encode(_status, _note)).catchError((Object _) {}));
  }

  /// Removes the stored draft (after a save or a deliberate discard).
  void discardDraft() {
    final RollDraftWriter? w = writeDraft;
    if (w == null || !_draftStored) return;
    _draftStored = false;
    unawaited(w(null).catchError((Object _) {}));
  }

  /// Saves the roll call; changes made while saving are written by a second
  /// round. Returns false (and keeps [error]) when the write failed.
  Future<bool> save() async {
    if (readOnly) return false;
    if (_saving) {
      _resave = true;
      return true;
    }
    _saving = true;
    _error = null;
    _notify();
    var ok = true;
    try {
      do {
        _resave = false;
        await persist(Map<String, AttendanceStatus>.of(_status), _note);
        _saved = true;
      } while (_resave && !_disposed);
    } on Object catch (e) {
      _resave = false;
      _error = e;
      ok = false;
    }
    _saving = false;
    if (ok) {
      _dirty = false;
      discardDraft();
    }
    _notify();
    return ok;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
