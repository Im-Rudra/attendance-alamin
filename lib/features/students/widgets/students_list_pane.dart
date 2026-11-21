// The students list: search field, filter chips (batch, has dues, left) and
// either rows or, on large windows, the data table with a sticky header (UX 3b
// columns: রোল · নাম · ব্যাচ · অভিভাবকের ফোন · হাজিরা % · বকেয়া · শেষ পেমেন্ট).

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/features/students/controllers/student_nav.dart';
import 'package:attendance_alamin/features/students/ui/student_form_screen.dart';
import 'package:attendance_alamin/features/students/controllers/student_providers.dart';
import 'package:attendance_alamin/features/batches/widgets/batch_table.dart';
import 'package:attendance_alamin/features/students/widgets/student_row_tile.dart';

class StudentsListPane extends ConsumerStatefulWidget {
  const StudentsListPane({super.key, this.selectedId, this.table = false});

  final String? selectedId;

  /// Large windows: rows become the data table.
  final bool table;

  @override
  ConsumerState<StudentsListPane> createState() => _StudentsListPaneState();
}

class _StudentsListPaneState extends ConsumerState<StudentsListPane> {
  final TextEditingController _query = TextEditingController();
  StudentFilter _filter = const StudentFilter();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _open(String id) => stuGo(context, Routes.student(id));

  void _new() => showStudentFormPanel(context);

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

    // One horizontally scrolling row (never wraps onto a second line).
    final Widget chips = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: 200,
          child: BhorSelect<String>(
            semanticLabel: l10n.stuFilterBatch,
            hint: l10n.stuFilterBatch,
            value: batches.any((Batch b) => b.id == _filter.batchId) ? _filter.batchId : null,
            options: <BhorOption<String>>[
              BhorOption<String>('', l10n.commonAll),
              for (final Batch b in batches) BhorOption<String>(b.id, b.name),
            ],
            onChanged: (String id) => setState(() => _filter = id.isEmpty
                ? _filter.copyWith(clearBatch: true)
                : _filter.copyWith(batchId: id)),
          ),
        ),
        const SizedBox(width: BhorSpace.s8),
        BhorChip(
          label: l10n.stuFilterDues,
          selected: _filter.onlyDues,
          onSelected: (bool v) => setState(() => _filter = _filter.copyWith(onlyDues: v)),
        ),
        const SizedBox(width: BhorSpace.s8),
        BhorChip(
          label: l10n.stuFilterLeft,
          selected: _filter.onlyLeft,
          onSelected: (bool v) => setState(() => _filter = _filter.copyWith(onlyLeft: v)),
        ),
      ],
      ),
    );

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
        if (rows.isEmpty) {
          final String q = _filter.query.trim();
          return BhorEmptyState(
            icon: BhorIcons.search,
            title: q.isEmpty ? l10n.stuNoMatchFilters : l10n.stuNoMatch(q),
            action: q.isEmpty ? null : BhorButton(label: l10n.stuNewStudent, onPressed: _new),
          );
        }
        if (widget.table) {
          return _Table(rows: rows, selectedId: widget.selectedId, onOpen: _open);
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
                      onTap: () => _open(rows[i].id),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        search,
        const SizedBox(height: BhorSpace.s8),
        chips,
        const SizedBox(height: BhorSpace.s4),
        Expanded(child: body),
      ],
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.rows, required this.selectedId, required this.onOpen});

  final List<StudentRow> rows;
  final String? selectedId;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
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

    Widget menu(StudentRow r, Widget child) => GestureDetector(
          behavior: HitTestBehavior.translucent,
          onSecondaryTapUp: (TapUpDetails d) => showStudentContextMenu(context, d.globalPosition, r),
          child: child,
        );

    // Fixed widths for phone / percent / tag so nothing collides; name and
    // batch share the rest and are the only columns that ellipsize.
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final bool showBatch = box.maxWidth >= 800;
        final bool showLast = box.maxWidth >= 960;
        return BatchTable<StudentRow>(
          rows: rows,
          semanticLabel: (StudentRow r) => r.student.name,
          isSelected: (StudentRow r) => r.id == selectedId,
          onRowTap: (StudentRow r) => onOpen(r.id),
          columns: <BatchColumn<StudentRow>>[
            BatchColumn<StudentRow>(
              label: l10n.stuColRoll,
              fixedWidth: 48,
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
                cell: (StudentRow r) => menu(r, text(batchNames(r.batches))),
              ),
            BatchColumn<StudentRow>(
              label: l10n.stuColGuardianPhone,
              fixedWidth: 128,
              cell: (StudentRow r) {
                final Student s = r.student;
                final String? p = s.guardianPhone ?? s.phone;
                return menu(r, text(p == null ? '—' : fmt.digits(p)));
              },
            ),
            BatchColumn<StudentRow>(
              label: l10n.stuColAttendance,
              fixedWidth: 72,
              numeric: true,
              cell: (StudentRow r) => menu(
                r,
                text(
                  r.attendancePercent == null ? '—' : fmt.percent(r.attendancePercent!),
                  override: BhorType.tabular(style),
                ),
              ),
            ),
            BatchColumn<StudentRow>(
              label: l10n.stuColDues,
              fixedWidth: 168,
              cell: (StudentRow r) => menu(
                r,
                r.dues == null
                    ? text('—')
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: StudentDuesBadge(dues: r.dues),
                      ),
              ),
            ),
            if (showLast)
              BatchColumn<StudentRow>(
                label: l10n.stuColLastPayment,
                fixedWidth: 96,
                cell: (StudentRow r) =>
                    menu(r, text(r.lastPaidOn == null ? '—' : fmt.dateShort(r.lastPaidOn!))),
              ),
          ],
        );
      },
    );
  }
}
