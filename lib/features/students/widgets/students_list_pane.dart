// The students list: search field, filter chips (batch, has dues, left) and
// either rows or, on large windows, the data table with a sticky header (UX 3b
// columns: রোল · নাম · ব্যাচ · অভিভাবকের ফোন · হাজিরা % · বকেয়া · শেষ পেমেন্ট).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/features/students/controllers/student_nav.dart';
import 'package:attendance_alamin/features/students/controllers/student_providers.dart';
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

  void _new() => stuPush(context, Routes.studentNew);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.aurora;
    final bool wide = WindowClass.of(context).isWide;
    final AsyncValue<List<StudentRow>> async = ref.watch(stuRowsProvider);
    final List<Batch> batches = <Batch>[
      for (final Batch b in ref.watch(stuBatchesProvider).value ?? const <Batch>[])
        if (!b.archived) b,
    ];
    String? batchLabel;
    for (final Batch b in batches) {
      if (b.id == _filter.batchId) batchLabel = b.name;
    }

    final Widget search = TextField(
      key: const ValueKey<String>('stu-search'),
      controller: _query,
      autofocus: wide,
      textInputAction: TextInputAction.search,
      onChanged: (String v) => setState(() => _filter = _filter.copyWith(query: v)),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: l10n.stuSearchHint,
        suffixIcon: _query.text.isEmpty
            ? null
            : IconButton(
                tooltip: l10n.commonClose,
                icon: const Icon(Icons.close),
                onPressed: () {
                  _query.clear();
                  setState(() => _filter = _filter.copyWith(query: ''));
                },
              ),
      ),
    );

    final Widget chips = Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        PopupMenuButton<String>(
          tooltip: l10n.stuFilterBatch,
          onSelected: (String id) => setState(() => _filter = id.isEmpty
              ? _filter.copyWith(clearBatch: true)
              : _filter.copyWith(batchId: id)),
          itemBuilder: (BuildContext ctx) => <PopupMenuEntry<String>>[
            PopupMenuItem<String>(value: '', child: Text(l10n.commonAll)),
            for (final Batch b in batches)
              PopupMenuItem<String>(value: b.id, child: Text(b.name)),
          ],
          child: SizedBox(
            height: 48,
            child: Center(
              child: Chip(
                avatar: const Icon(Icons.groups_outlined, size: 18),
                label: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Flexible(
                        child: Text(batchLabel ?? l10n.stuFilterBatch,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        FilterChip(
          label: Text(l10n.stuFilterDues),
          selected: _filter.onlyDues,
          onSelected: (bool v) =>
              setState(() => _filter = _filter.copyWith(onlyDues: v)),
        ),
        FilterChip(
          label: Text(l10n.stuFilterLeft),
          selected: _filter.onlyLeft,
          onSelected: (bool v) =>
              setState(() => _filter = _filter.copyWith(onlyLeft: v)),
        ),
      ],
    );

    final Widget body = async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object e, StackTrace st) =>
          EmptyState(icon: Icons.error_outline, message: l10n.commonLoadingFailed),
      data: (List<StudentRow> all) {
        if (all.isEmpty) {
          return EmptyState(
            icon: Icons.group_outlined,
            message: l10n.stuEmptyAll,
            actionLabel: l10n.stuNewStudent,
            onAction: _new,
          );
        }
        final List<StudentRow> rows = applyStudentFilter(all, _filter);
        if (rows.isEmpty) {
          final String q = _filter.query.trim();
          return EmptyState(
            icon: Icons.person_search_outlined,
            message: q.isEmpty ? l10n.stuNoMatchFilters : l10n.stuNoMatch(q),
            actionLabel: q.isEmpty ? null : l10n.stuNewStudent,
            onAction: q.isEmpty ? null : _new,
          );
        }
        StudentRow? selected;
        for (final StudentRow r in rows) {
          if (r.id == widget.selectedId) selected = r;
        }
        if (widget.table) {
          return _Table(rows: rows, selected: selected, onOpen: _open);
        }
        return GlassCard(
          dense: true,
          padding: EdgeInsets.zero,
          child: ListView.separated(
            padding: const EdgeInsets.only(top: 4, bottom: 88),
            itemCount: rows.length,
            separatorBuilder: (BuildContext c, int i) =>
                Divider(height: 1, thickness: 1, color: tokens.track),
            itemBuilder: (BuildContext c, int i) => StudentRowTile(
              key: ValueKey<String>('stu-row-${rows[i].id}'),
              row: rows[i],
              selected: rows[i].id == widget.selectedId,
              onTap: () => _open(rows[i].id),
            ),
          ),
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        search,
        const SizedBox(height: 8),
        chips,
        const SizedBox(height: 4),
        Expanded(child: body),
      ],
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.rows, required this.selected, required this.onOpen});

  final List<StudentRow> rows;
  final StudentRow? selected;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final tokens = context.aurora;
    final TextStyle? style =
        Theme.of(context).textTheme.bodyMedium?.copyWith(color: tokens.textPrimary);

    Widget text(String s, {TextStyle? override}) => Text(
          s,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: override ?? style,
        );

    Widget menu(StudentRow r, Widget child) => GestureDetector(
          behavior: HitTestBehavior.translucent,
          onSecondaryTapUp: (TapUpDetails d) =>
              showStudentContextMenu(context, d.globalPosition, r),
          child: child,
        );

    return DenseTable<StudentRow>(
      rows: rows,
      selected: selected,
      onRowTap: (StudentRow r) => onOpen(r.id),
      columns: <DenseColumn<StudentRow>>[
        DenseColumn<StudentRow>(
          label: l10n.stuColRoll,
          flex: 2,
          cell: (StudentRow r) => menu(
              r, text(r.student.roll == null ? '—' : fmt.digits(r.student.roll!))),
        ),
        DenseColumn<StudentRow>(
          label: l10n.stuColName,
          flex: 6,
          cell: (StudentRow r) => menu(
            r,
            text(r.student.name,
                override: style?.copyWith(fontWeight: FontWeight.w600)),
          ),
        ),
        DenseColumn<StudentRow>(
          label: l10n.stuColBatch,
          flex: 5,
          cell: (StudentRow r) => menu(r, text(batchNames(r.batches))),
        ),
        DenseColumn<StudentRow>(
          label: l10n.stuColGuardianPhone,
          flex: 4,
          cell: (StudentRow r) {
            final Student s = r.student;
            final String? p = s.guardianPhone ?? s.phone;
            return menu(r, text(p == null ? '—' : fmt.digits(p)));
          },
        ),
        DenseColumn<StudentRow>(
          label: l10n.stuColAttendance,
          flex: 3,
          numeric: true,
          cell: (StudentRow r) => menu(
              r,
              text(r.attendancePercent == null
                  ? '—'
                  : fmt.percent(r.attendancePercent!))),
        ),
        DenseColumn<StudentRow>(
          label: l10n.stuColDues,
          flex: 6,
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
        DenseColumn<StudentRow>(
          label: l10n.stuColLastPayment,
          flex: 4,
          cell: (StudentRow r) => menu(
              r,
              text(r.lastPaidOn == null ? '—' : fmt.dateShort(r.lastPaidOn!))),
        ),
      ],
    );
  }
}
