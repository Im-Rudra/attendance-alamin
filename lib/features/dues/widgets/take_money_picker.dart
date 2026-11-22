// "টাকা নিন" on the Fees tab: a fast student picker (search by name, roll or
// phone in Bangla or ASCII digits; most-owing first) that hands the chosen
// student to the existing collect-payment sheet.

import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/dues_providers.dart';
import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/features/dues/controllers/dues_state.dart';
import 'package:attendance_alamin/features/dues/widgets/dues_tags.dart';
import 'package:attendance_alamin/features/payments/payments_entry.dart';

/// One line of the picker.
class PickerStudent {
  const PickerStudent({
    required this.student,
    required this.owed,
    this.batch = '',
    this.level,
  });

  final Student student;

  /// Outstanding taka over all live enrollments.
  final int owed;

  /// Names of the live batches of the student, joined (empty when unknown).
  final String batch;

  /// The worst due level (null when nothing is due).
  final DueLevel? level;
}

/// Live students that have an enrollment, most owing first, then by name.
List<PickerStudent> buildPickerRows({
  required List<Student> students,
  required List<EnrollmentTerms> terms,
  required DuesReport? report,
}) {
  final Set<String> enrolled = <String>{
    for (final EnrollmentTerms t in terms)
      if (!t.studentLeft && !t.batchArchived && !t.enrollmentEnded) t.studentId,
  };
  final Map<String, int> owed = <String, int>{
    if (report != null)
      for (final StudentDues d in report.active) d.studentId: d.totalOutstanding,
  };
  final Map<String, DueLevel?> levels = <String, DueLevel?>{
    if (report != null)
      for (final StudentDues d in report.active) d.studentId: d.worst,
  };
  final Map<String, List<String>> batches = <String, List<String>>{};
  for (final EnrollmentTerms t in terms) {
    if (t.studentLeft || t.batchArchived || t.enrollmentEnded) continue;
    final List<String> names = batches.putIfAbsent(t.studentId, () => <String>[]);
    if (!names.contains(t.batchName)) names.add(t.batchName);
  }
  final List<PickerStudent> rows = <PickerStudent>[
    for (final Student s in students)
      if (s.status == StudentStatus.active && enrolled.contains(s.id))
        PickerStudent(
          student: s,
          owed: owed[s.id] ?? 0,
          batch: (batches[s.id] ?? const <String>[]).join(', '),
          level: levels[s.id],
        ),
  ];
  rows.sort((PickerStudent a, PickerStudent b) {
    final int byOwed = b.owed.compareTo(a.owed);
    if (byOwed != 0) return byOwed;
    return a.student.name.toLowerCase().compareTo(b.student.name.toLowerCase());
  });
  return rows;
}

/// Name, roll or phone contains [query] (Bangla and ASCII digits alike).
bool pickerMatches(Student s, String query) {
  final String q = AppFormat.toAsciiDigits(query.trim().toLowerCase());
  if (q.isEmpty) return true;
  bool has(String? v) => v != null && AppFormat.toAsciiDigits(v.toLowerCase()).contains(q);
  return has(s.name) || has(s.roll) || has(s.phone) || has(s.guardianPhone);
}


/// Opens the picker (sheet on phones, a popover at its button on desktop,
/// hugging its rows), then the
/// collect-payment sheet / side panel of the chosen student.
Future<void> showTakeMoneyPicker(BuildContext context, {BuildContext? anchor}) async {
  final String? id = await showBhorPanel<String>(
    context,
    anchor: anchor,
    title: context.l10n.duesPickerTitle,
    kind: BhorPanelKind.list,
    width: 420,
    scroll: false,
    builder: (BuildContext ctx) => const TakeMoneyPicker(),
  );
  if (id == null || !context.mounted) return;
  await showCollectPaymentSheet(context, studentId: id);
}

class TakeMoneyPicker extends ConsumerStatefulWidget {
  const TakeMoneyPicker({super.key});

  @override
  ConsumerState<TakeMoneyPicker> createState() => _TakeMoneyPickerState();
}

class _TakeMoneyPickerState extends ConsumerState<TakeMoneyPicker> {
  String _query = '';
  final ScrollController _scroll = ScrollController();
  final Map<String, GlobalKey> _rowKeys = <String, GlobalKey>{};

  /// A press that landed while the list was still gliding (a touchpad fling):
  /// the scroll view swallows it to stop the glide, so the row never sees
  /// it. Remembered here and picked on release (review b277 X7: one click
  /// always selects).
  Offset? _downWhileMoving;

  /// Last time the list moved (a fling keeps updating it every frame).
  final Stopwatch _sinceScroll = Stopwatch();
  bool _picked = false;

  /// Closes the picker with [id] once (the row's own tap and the
  /// glide fallback can both fire for one click).
  void _pick(String id) {
    if (_picked || !mounted) return;
    _picked = true;
    Navigator.of(context).pop(id);
  }

  bool _onScroll(ScrollNotification n) {
    if (n is ScrollUpdateNotification) {
      _sinceScroll
        ..reset()
        ..start();
    }
    return false;
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onDown(PointerDownEvent e) {
    final bool moving = (_scroll.hasClients && _scroll.position.isScrollingNotifier.value) ||
        (_sinceScroll.isRunning && _sinceScroll.elapsedMilliseconds < 120);
    _downWhileMoving = moving ? e.position : null;
  }

  void _onUp(PointerUpEvent e) {
    final Offset? from = _downWhileMoving;
    _downWhileMoving = null;
    if (from == null || (e.position - from).distance > 8) return;
    for (final MapEntry<String, GlobalKey> k in _rowKeys.entries) {
      final RenderObject? ro = k.value.currentContext?.findRenderObject();
      if (ro is! RenderBox || !ro.attached || !ro.hasSize) continue;
      final Offset local = ro.globalToLocal(e.position);
      if ((Offset.zero & ro.size).contains(local)) {
        _pick(k.key);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Student> students = ref.watch(duesStudentsProvider).value ?? const <Student>[];
    final List<EnrollmentTerms> terms = ref.watch(enrollmentTermsProvider).value ?? const <EnrollmentTerms>[];
    final DuesReport? report = ref.watch(duesReportProvider).value;
    final List<PickerStudent> rows = <PickerStudent>[
      for (final PickerStudent r in buildPickerRows(students: students, terms: terms, report: report))
        if (pickerMatches(r.student, _query)) r,
    ];
    // Hugs its rows: as tall as the list, at most ~60% of the window or the
    // room the popover has (then the list scrolls), never a fixed box with
    // blank space under it.
    final double window = MediaQuery.sizeOf(context).height * 0.6;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) => _body(context, rows, box, window),
    );
  }

  Widget _body(BuildContext context, List<PickerStudent> rows, BoxConstraints box, double window) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final BhorThemeData b = context.bhor;
    final double room = box.maxHeight.isFinite ? box.maxHeight - 64 : double.infinity;
    final double maxList = math.max(120.0, math.min(window, room));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        BhorTextField(
          key: const ValueKey<String>('picker-search'),
          semanticLabel: l10n.duesPickerSearch,
          textInputAction: TextInputAction.search,
          prefix: const Icon(BhorIcons.search),
          hint: l10n.duesPickerSearch,
          onChanged: (String v) => setState(() => _query = v),
        ),
        const SizedBox(height: BhorSpace.s8),
        if (rows.isEmpty)
          BhorEmptyState(icon: BhorIcons.search, title: l10n.duesPickerNone)
        else
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxList),
            child: Listener(
              onPointerDown: _onDown,
              onPointerUp: _onUp,
              child: NotificationListener<ScrollNotification>(
                onNotification: _onScroll,
                child: ListView.builder(
                  key: const ValueKey<String>('picker-list'),
                  controller: _scroll,
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: rows.length,
                  itemBuilder: (BuildContext ctx, int i) {
                    final PickerStudent r = rows[i];
                    final List<String> sub = <String>[
                      if (r.student.roll != null && r.student.roll!.isNotEmpty)
                        l10n.duesPickerRoll(fmt.digits(r.student.roll!)),
                      if (r.batch.isNotEmpty) r.batch,
                    ];
                    return KeyedSubtree(
                      key: _rowKeys.putIfAbsent(r.student.id, () => GlobalKey()),
                      child: BhorListRow(
                        key: ValueKey<String>('picker-${r.student.id}'),
                        leading: BhorAvatar(name: r.student.name, size: 40),
                        title: r.student.name,
                        subtitle: sub.isEmpty ? null : sub.join(' · '),
                        divider: i < rows.length - 1,
                        trailing: r.owed > 0
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: <Widget>[
                                  BhorMoney(r.owed, style: b.type.bodyStrong),
                                  if (r.level != null) ...<Widget>[
                                    const SizedBox(height: 2),
                                    dueLevelTag(context, r.level!, compact: true),
                                  ],
                                ],
                              )
                            : BhorTag(label: l10n.uiStatePaid, tone: BhorTone.ok, icon: BhorIcons.checkCircleFill),
                        onTap: () => _pick(r.student.id),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}
