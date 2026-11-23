// The students list: search field, filter chips (batch, has dues, left) and
// either rows or, on large windows, the data table with a sticky header (UX 3b
// columns: রোল · নাম · ব্যাচ · অভিভাবকের ফোন · হাজিরা % · বকেয়া · শেষ পেমেন্ট).
// Multi-select (item 10): Ctrl+click, Shift+click, Ctrl+A, Esc, a hover select
// box on desktop, long press on phones; the selection bar sits at the bottom.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/features/students/controllers/student_nav.dart';
import 'package:attendance_alamin/features/students/controllers/student_selection.dart';
import 'package:attendance_alamin/features/students/students_entry.dart';
import 'package:attendance_alamin/features/students/controllers/student_providers.dart';
import 'package:attendance_alamin/features/batches/widgets/batch_table.dart';
import 'package:attendance_alamin/features/students/widgets/student_bulk_actions.dart';
import 'package:attendance_alamin/features/students/widgets/student_keys.dart';
import 'package:attendance_alamin/features/students/widgets/student_row_tile.dart';

class StudentsListPane extends ConsumerStatefulWidget {
  const StudentsListPane({super.key, this.selectedId, this.table = false, this.bottomInset = 0});

  final String? selectedId;

  /// Large windows: rows become the data table.
  final bool table;

  /// Space the selection bar keeps free at the bottom (the phone nav pill).
  final double bottomInset;

  @override
  ConsumerState<StudentsListPane> createState() => _StudentsListPaneState();
}

class _StudentsListPaneState extends ConsumerState<StudentsListPane> {
  final TextEditingController _query = TextEditingController();
  final FocusNode _searchFocus = FocusNode(debugLabel: 'students search');
  StudentFilter _filter = const StudentFilter();

  /// Ids of the listed rows, in list order (Shift+click ranges, Ctrl+A).
  List<String> _order = const <String>[];

  @override
  void dispose() {
    _query.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _open(String id) => stuGo(context, Routes.student(id));

  StudentSelectionController get _selection => ref.read(stuSelectionProvider.notifier);

  /// A row click: Shift = range, Ctrl (or the select box) = toggle; while
  /// selecting on a phone a tap toggles; otherwise the profile opens.
  void _onRowTap(String id, {bool box = false}) {
    final HardwareKeyboard kb = HardwareKeyboard.instance;
    if (kb.isShiftPressed) {
      _selection.range(_order, id);
      _leaveSearch();
      return;
    }
    if (box || kb.isControlPressed || kb.isMetaPressed) {
      _selection.toggle(id);
      _leaveSearch();
      return;
    }
    if (!WindowClass.of(context).isWide && ref.read(stuSelectionProvider).isNotEmpty) {
      _selection.toggle(id);
      return;
    }
    _open(id);
  }

  /// Hands the keyboard back to the list (Ctrl+A, Esc) after a selection click.
  void _leaveSearch() {
    if (_searchFocus.hasFocus) _searchFocus.unfocus();
  }

  void _new() => openAddStudent(context);

  void _clearFilters() {
    _query.clear();
    setState(() => _filter = const StudentFilter());
  }

  bool get _filtered =>
      _filter.query.trim().isNotEmpty || _filter.batchId != null || _filter.onlyDues || _filter.onlyLeft;

  /// The batch filter: a short choice list anchored to its chip.
  Future<void> _pickBatch(BuildContext chip, List<Batch> batches, String? current) async {
    final l10n = context.l10n;
    final String? id = await showBhorPanel<String>(
      context,
      anchor: chip,
      kind: BhorPanelKind.choice,
      title: l10n.stuFilterBatch,
      builder: (BuildContext ctx) {
        final List<(String, String)> items = <(String, String)>[
          ('', l10n.stuFilterBatchAll),
          for (final Batch b in batches) (b.id, b.name),
        ];
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int i = 0; i < items.length; i++)
              BhorListRow(
                key: ValueKey<String>('stu-batch-choice-${items[i].$1}'),
                title: items[i].$2,
                selected: (current ?? '') == items[i].$1,
                divider: i != items.length - 1,
                onTap: () => Navigator.of(ctx).pop(items[i].$1),
              ),
          ],
        );
      },
    );
    if (id == null || !mounted) return;
    setState(() => _filter = id.isEmpty ? _filter.copyWith(clearBatch: true) : _filter.copyWith(batchId: id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bool wide = WindowClass.of(context).isWide;
    final AsyncValue<List<StudentRow>> async = ref.watch(stuRowsProvider);
    final List<Batch> batches = <Batch>[
      for (final Batch b in ref.watch(stuBatchesProvider).value ?? const <Batch>[])
        if (!b.archived) b,
    ];

    final Widget search = BhorTextField(
      key: const ValueKey<String>('stu-search'),
      controller: _query,
      focusNode: _searchFocus,
      autofocus: wide,
      textInputAction: TextInputAction.search,
      onChanged: (String v) => setState(() => _filter = _filter.copyWith(query: v)),
      prefix: const Icon(BhorIcons.search),
      hint: l10n.stuSearchHint,
      semanticLabel: l10n.stuSearchHint,
      suffix: _query.text.isEmpty
          ? null
          : BhorIconButton(
              semanticLabel: l10n.commonClose,
              icon: BhorIcons.close,
              size: BhorButtonSize.sm,
              onPressed: () {
                _query.clear();
                setState(() => _filter = _filter.copyWith(query: ''));
              },
            ),
    );

    // One row of equal-height pills; at a narrow pane it wraps (never clips).
    final String? pickedBatch = batches.any((Batch b) => b.id == _filter.batchId) ? _filter.batchId : null;
    String? pickedName;
    for (final Batch b in batches) {
      if (b.id == pickedBatch) pickedName = b.name;
    }
    final Widget chips = Wrap(
      spacing: BhorSpace.s8,
      children: <Widget>[
        Builder(
          builder: (BuildContext chip) => BhorChip(
            key: const ValueKey<String>('stu-filter-batch'),
            label: pickedName ?? l10n.stuFilterBatch,
            icon: BhorIcons.chevronDown,
            selected: pickedBatch != null,
            onSelected: (_) => _pickBatch(chip, batches, pickedBatch),
          ),
        ),
        BhorChip(
          key: const ValueKey<String>('stu-filter-dues'),
          label: l10n.stuFilterDues,
          selected: _filter.onlyDues,
          onSelected: (bool v) => setState(() => _filter = _filter.copyWith(onlyDues: v)),
        ),
        BhorChip(
          key: const ValueKey<String>('stu-filter-left'),
          label: l10n.stuFilterLeft,
          selected: _filter.onlyLeft,
          onSelected: (bool v) => setState(() => _filter = _filter.copyWith(onlyLeft: v)),
        ),
      ],
    );

    final StudentSelection selection = ref.watch(stuSelectionProvider);
    // Only listed rows count: a filter hides the others from the bar too.
    final List<StudentRow>? loaded = async.value;
    final List<StudentRow> listed =
        loaded == null ? const <StudentRow>[] : applyStudentFilter(loaded, _filter);
    final List<Student> picked = <Student>[
      for (final StudentRow r in listed)
        if (selection.contains(r.id)) r.student,
    ];
    final bool selecting = picked.isNotEmpty;

    final Widget body = async.when(
      loading: () => const Center(child: BhorSpinner()),
      error: (Object e, StackTrace st) =>
          BhorEmptyState(icon: BhorIcons.warning, title: l10n.commonLoadingFailed),
      data: (List<StudentRow> all) {
        if (all.isEmpty) {
          return BhorEmptyState(
            icon: BhorIcons.students,
            title: l10n.stuEmptyAll,
            action: BhorButton(label: l10n.stuNewStudent, onPressed: _new),
          );
        }
        final List<StudentRow> rows = applyStudentFilter(all, _filter);
        _order = <String>[for (final StudentRow r in rows) r.id];
        if (rows.isEmpty) {
          final String q = _filter.query.trim();
          return Align(
            alignment: Alignment.topCenter,
            child: BhorEmptyState(
              icon: BhorIcons.search,
              title: q.isEmpty ? l10n.stuNoMatchFilters : l10n.stuNoMatch(q),
              action: Wrap(
                alignment: WrapAlignment.center,
                spacing: BhorSpace.s8,
                runSpacing: BhorSpace.s8,
                children: <Widget>[
                  if (_filtered)
                    BhorButton(
                      key: const ValueKey<String>('stu-clear-filters'),
                      label: l10n.stuClearFilters,
                      variant: q.isEmpty ? BhorButtonVariant.primary : BhorButtonVariant.secondary,
                      onPressed: _clearFilters,
                    ),
                  if (q.isNotEmpty) BhorButton(label: l10n.stuNewStudent, onPressed: _new),
                ],
              ),
            ),
          );
        }
        if (widget.table) {
          return _Table(
            rows: rows,
            selectedId: widget.selectedId,
            checked: selection.ids,
            selecting: selecting,
            onTap: _onRowTap,
            onToggle: (String id) => _onRowTap(id, box: true),
          );
        }
        return BhorStaggerScope(
          // The card hugs its rows; 88 px of tail clears the FAB.
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 88),
            child: BhorList(
              children: <Widget>[
                for (int i = 0; i < rows.length; i++)
                  BhorStagger(
                    index: i,
                    child: StudentRowTile(
                      key: ValueKey<String>('stu-row-${rows[i].id}'),
                      row: rows[i],
                      selected: rows[i].id == widget.selectedId,
                      last: i == rows.length - 1,
                      checked: selection.contains(rows[i].id),
                      selecting: selecting,
                      onTap: () => _onRowTap(rows[i].id),
                      onToggle: () => _onRowTap(rows[i].id, box: true),
                      onLongPress: () => _selection.toggle(rows[i].id),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );

    return StudentKeys(
      onSelectAll: () => _selection.selectAll(_order),
      selectAllWhileTyping: () => _searchFocus.hasFocus && _query.text.isEmpty,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          search,
          const SizedBox(height: BhorSpace.s8),
          chips,
          const SizedBox(height: BhorSpace.s4),
          Expanded(child: body),
          if (selecting)
            Padding(
              padding: EdgeInsets.only(top: BhorSpace.s8, bottom: widget.bottomInset),
              child: StudentSelectionBar(
                students: picked,
                onClear: () => ref.read(stuSelectionProvider.notifier).clear(),
              ),
            ),
        ],
      ),
    );
  }
}

class _Table extends StatefulWidget {
  const _Table({
    required this.rows,
    required this.selectedId,
    required this.checked,
    required this.selecting,
    required this.onTap,
    required this.onToggle,
  });

  final List<StudentRow> rows;
  final String? selectedId;
  final Set<String> checked;
  final bool selecting;
  final ValueChanged<String> onTap;
  final ValueChanged<String> onToggle;

  @override
  State<_Table> createState() => _TableState();
}

class _TableState extends State<_Table> {
  /// The row under the mouse: its select box shows.
  final ValueNotifier<String?> _hovered = ValueNotifier<String?>(null);

  @override
  void dispose() {
    _hovered.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<StudentRow> rows = widget.rows;
    final String? selectedId = widget.selectedId;
    final l10n = context.l10n;
    final fmt = context.fmt;
    final BhorThemeData b = context.bhor;
    final TextStyle style = b.type.body;

    Widget text(String s, {TextStyle? override}) => Text(
          s,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: override ?? style,
        );

    Widget menu(StudentRow r, Widget child) => MouseRegion(
          onEnter: (_) => _hovered.value = r.id,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onSecondaryTapUp: (TapUpDetails d) => showStudentContextMenu(context, d.globalPosition, r),
            child: child,
          ),
        );

    // The Due column exists only when somebody owes (amount + level tag);
    // otherwise it would be a column of dashes.
    final bool anyDues = rows.any((StudentRow r) => r.dues != null);

    // Fixed widths hold every header and value on one line; name and batch
    // share the rest and are the only columns that ellipsize.
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final bool showPhone = box.maxWidth >= 720;
        final bool showBatch = box.maxWidth >= 880;
        final bool showLast = box.maxWidth >= 1040;
        // The card hugs its rows (a scroll view gives the table an unbounded
        // height); long lists scroll as one card.
        return MouseRegion(
          onExit: (_) => _hovered.value = null,
          child: SingleChildScrollView(
            child: BatchTable<StudentRow>(
            rows: rows,
            semanticLabel: (StudentRow r) => r.student.name,
            isSelected: (StudentRow r) => r.id == selectedId || widget.checked.contains(r.id),
            onRowTap: (StudentRow r) => widget.onTap(r.id),
            columns: <BatchColumn<StudentRow>>[
              BatchColumn<StudentRow>(
                label: '',
                fixedWidth: 32,
                cell: (StudentRow r) => menu(
                  r,
                  ValueListenableBuilder<String?>(
                    valueListenable: _hovered,
                    builder: (BuildContext context, String? hovered, Widget? _) {
                      final bool on = widget.checked.contains(r.id);
                      final bool show = on || widget.selecting || hovered == r.id;
                      return AnimatedOpacity(
                        opacity: show ? 1 : 0,
                        duration: BhorMotion.of(context, BhorMotion.fast),
                        child: StudentSelectBox(
                          key: ValueKey<String>('stu-check-${r.id}'),
                          checked: on,
                          size: 32,
                          semanticLabel: l10n.stuSelect(r.student.name),
                          onTap: () => widget.onToggle(r.id),
                        ),
                      );
                    },
                  ),
                ),
              ),
              BatchColumn<StudentRow>(
                label: l10n.stuColRoll,
                fixedWidth: 56,
                cell: (StudentRow r) => menu(r, text(r.student.roll == null ? '—' : fmt.digits(r.student.roll!))),
              ),
              BatchColumn<StudentRow>(
                label: l10n.stuColName,
                flex: 6,
                cell: (StudentRow r) => menu(r, text(r.student.name, override: b.type.bodyStrong)),
              ),
              if (showBatch)
                BatchColumn<StudentRow>(
                  label: l10n.stuColBatch,
                  flex: 4,
                  cell: (StudentRow r) => menu(r, Text(r.batchesText(l10n, separator: '\n'), style: style)),
                ),
              if (showPhone)
                BatchColumn<StudentRow>(
                  label: l10n.stuColGuardianPhone,
                  fixedWidth: 140,
                  cell: (StudentRow r) {
                    final Student s = r.student;
                    final String? p = s.guardianPhone ?? s.phone;
                    return menu(r, text(p == null ? '—' : fmt.digits(p)));
                  },
                ),
              BatchColumn<StudentRow>(
                label: l10n.stuColAttendance,
                fixedWidth: 120,
                numeric: true,
                cell: (StudentRow r) => menu(
                  r,
                  text(
                    r.attendancePercent == null ? '—' : fmt.percent(r.attendancePercent!),
                    override: BhorType.tabular(style),
                  ),
                ),
              ),
              if (anyDues)
                BatchColumn<StudentRow>(
                  label: l10n.stuColDues,
                  fixedWidth: 232,
                  cell: (StudentRow r) => menu(r, _DueCell(dues: r.dues)),
                ),
              if (showLast)
                BatchColumn<StudentRow>(
                  label: l10n.stuColLastPayment,
                  fixedWidth: 128,
                  cell: (StudentRow r) =>
                      menu(r, text(r.lastPaidOn == null ? '—' : fmt.dateShort(r.lastPaidOn!))),
                ),
            ],
            ),
          ),
        );
      },
    );
  }
}

/// The real due: the amount and the level tag (the tag alone for a student
/// who left, whose grey money text already is the amount).
class _DueCell extends StatelessWidget {
  const _DueCell({required this.dues});

  final StudentDues? dues;

  @override
  Widget build(BuildContext context) {
    final StudentDues? d = dues;
    if (d == null) return Text('—', style: context.bhor.type.body);
    if (d.worst == null) return StudentDuesBadge(dues: d);
    return Row(
      children: <Widget>[
        BhorMoney(d.totalOutstanding, style: context.bhor.type.bodyStrong),
        const SizedBox(width: BhorSpace.s8),
        Flexible(child: StudentDuesBadge(dues: d)),
      ],
    );
  }
}
